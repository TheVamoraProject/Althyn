//! Keeps the homescreen pinned to the bottom of the X11 stacking order.
//!
//! Qt's `Qt.WindowStaysOnBottomHint` is only applied once, when the window
//! is first mapped, and only if a window manager is already running and
//! advertising support for it at that exact moment. If the homescreen maps
//! before the WM starts (or before the WM has finished reading its initial
//! state), the hint is silently dropped and never retried — so the window
//! ends up wherever it happens to land in the stack, which can be on top
//! of the statusbar or other panels.
//!
//! This sets things up explicitly and robustly instead:
//!   1. marks the window `_NET_WM_WINDOW_TYPE_DESKTOP`, the EWMH type for
//!      a desktop/background layer (no decorations, excluded from
//!      taskbar/pager, WMs default it to the bottom layer)
//!   2. sends a live `_NET_WM_STATE` ClientMessage requesting the `BELOW`
//!      state — this is the spec's mechanism for changing window state
//!      *after* it's already mapped and managed, unlike a raw property
//!      write (which WMs are only required to honor pre-map).
//!
//! This is X11-only. On Wayland this does nothing.

use std::thread;
use std::time::Duration;

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    AtomEnum, ClientMessageEvent, ConnectionExt, EventMask, PropMode,
};
use x11rb::wrapper::ConnectionExt as _;

const NET_WM_STATE_ADD: u32 = 1;

pub fn keep_below(title: &'static str) {
    thread::spawn(move || {
        if let Err(err) = try_keep_below(title) {
            eprintln!(
                "vamora-homescreen: could not pin window below others ({err}); \
                 it may end up on top of the statusbar or other panels"
            );
        }
    });
}

fn try_keep_below(title: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (conn, screen_num) = x11rb::connect(None)?;
    let root = conn.setup().roots[screen_num].root;
    let my_pid = std::process::id();

    let net_client_list = intern(&conn, b"_NET_CLIENT_LIST")?;
    let net_wm_pid = intern(&conn, b"_NET_WM_PID")?;
    let net_wm_name = intern(&conn, b"_NET_WM_NAME")?;
    let utf8_string = intern(&conn, b"UTF8_STRING")?;
    let net_wm_window_type = intern(&conn, b"_NET_WM_WINDOW_TYPE")?;
    let net_wm_window_type_desktop = intern(&conn, b"_NET_WM_WINDOW_TYPE_DESKTOP")?;
    let net_wm_state = intern(&conn, b"_NET_WM_STATE")?;
    let net_wm_state_below = intern(&conn, b"_NET_WM_STATE_BELOW")?;

    const MAX_ATTEMPTS: u32 = 30;
    const RETRY_DELAY: Duration = Duration::from_millis(200);

    for attempt in 0..MAX_ATTEMPTS {
        if let Some(window) = find_window(
            &conn,
            root,
            net_client_list,
            net_wm_pid,
            net_wm_name,
            utf8_string,
            my_pid,
            title,
        )? {
            conn.change_property32(
                PropMode::REPLACE,
                window,
                net_wm_window_type,
                AtomEnum::ATOM,
                &[net_wm_window_type_desktop],
            )?;
            conn.flush()?;

            let event = ClientMessageEvent::new(
                32,
                window,
                net_wm_state,
                [NET_WM_STATE_ADD, net_wm_state_below, 0, 0, 0],
            );
            conn.send_event(
                false,
                root,
                EventMask::SUBSTRUCTURE_REDIRECT | EventMask::SUBSTRUCTURE_NOTIFY,
                event,
            )?;
            conn.flush()?;
            return Ok(());
        }

        if attempt + 1 < MAX_ATTEMPTS {
            thread::sleep(RETRY_DELAY);
        }
    }

    Err(format!("window titled '{title}' never appeared in _NET_CLIENT_LIST").into())
}

fn intern(
    conn: &impl Connection,
    name: &[u8],
) -> Result<u32, Box<dyn std::error::Error>> {
    Ok(conn.intern_atom(false, name)?.reply()?.atom)
}

#[allow(clippy::too_many_arguments)]
fn find_window(
    conn: &impl Connection,
    root: u32,
    net_client_list: u32,
    net_wm_pid: u32,
    net_wm_name: u32,
    utf8_string: u32,
    my_pid: u32,
    title: &str,
) -> Result<Option<u32>, Box<dyn std::error::Error>> {
    let list_reply = conn
        .get_property(false, root, net_client_list, AtomEnum::WINDOW, 0, u32::MAX)?
        .reply()?;
    let Some(windows) = list_reply.value32() else {
        return Ok(None);
    };

    for window in windows {
        let pid_reply = conn
            .get_property(false, window, net_wm_pid, AtomEnum::CARDINAL, 0, 1)?
            .reply()?;
        let Some(mut pid_iter) = pid_reply.value32() else {
            continue;
        };
        if pid_iter.next() != Some(my_pid) {
            continue;
        }

        let name_reply = conn
            .get_property(false, window, net_wm_name, utf8_string, 0, u32::MAX)?
            .reply()?;
        let name = String::from_utf8_lossy(&name_reply.value);
        if name == title {
            return Ok(Some(window));
        }
    }

    Ok(None)
}
