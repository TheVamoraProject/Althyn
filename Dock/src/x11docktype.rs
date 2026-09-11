//! Marks our own window as an EWMH "dock" so window managers give it the
//! stacking treatment real docks/panels get: always above other windows,
//! including ones that just got maximized.
//!
//! Why this is needed: our window's flags (Qt.WindowStaysOnTopHint) alone
//! aren't reliably honored by every WM once another window is maximized
//! and raised/focused — that window can end up stacked above our 1px
//! reveal strip, so it eats the mouse events instead of us and hovering
//! the bottom edge does nothing. Setting _NET_WM_WINDOW_TYPE_DOCK and
//! explicitly requesting _NET_WM_STATE_ABOVE via EWMH fixes that at the
//! window-manager level instead of fighting it from Qt.
//!
//! X11-only, mirrors vamora-statusbar's x11strut.rs: our window isn't
//! mapped yet at process start, so this runs in a background thread that
//! waits for it to appear in _NET_CLIENT_LIST before tagging it.

use std::thread;
use std::time::Duration;

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    AtomEnum, ClientMessageEvent, ConnectionExt, EventMask, PropMode,
};
use x11rb::wrapper::ConnectionExt as WrapperConnectionExt;

/// _NET_WM_STATE source indication: 1 = normal application (per EWMH spec).
const SOURCE_INDICATION_APPLICATION: u32 = 1;
/// _NET_WM_STATE action: add the given state.
const NET_WM_STATE_ADD: u32 = 1;

pub fn mark_as_dock(title: &'static str) {
    thread::spawn(move || {
        if let Err(err) = try_mark_as_dock(title) {
            eprintln!(
                "vamora-dock: could not set EWMH dock hints ({err}); the dock \
                 may get stacked behind maximized windows and stop responding \
                 to hover-to-reveal"
            );
        }
    });
}

fn try_mark_as_dock(title: &str) -> Result<(), Box<dyn std::error::Error>> {
    let (conn, screen_num) = x11rb::connect(None)?;
    let root = conn.setup().roots[screen_num].root;
    let my_pid = std::process::id();

    let net_client_list = intern(&conn, b"_NET_CLIENT_LIST")?;
    let net_wm_pid = intern(&conn, b"_NET_WM_PID")?;
    let net_wm_name = intern(&conn, b"_NET_WM_NAME")?;
    let utf8_string = intern(&conn, b"UTF8_STRING")?;
    let net_wm_window_type = intern(&conn, b"_NET_WM_WINDOW_TYPE")?;
    let net_wm_window_type_dock = intern(&conn, b"_NET_WM_WINDOW_TYPE_DOCK")?;
    let net_wm_state = intern(&conn, b"_NET_WM_STATE")?;
    let net_wm_state_above = intern(&conn, b"_NET_WM_STATE_ABOVE")?;
    let net_supporting_wm_check = intern(&conn, b"_NET_SUPPORTING_WM_CHECK")?;

    const MAX_ATTEMPTS: u32 = 30;
    const RETRY_DELAY: Duration = Duration::from_millis(200);

    wait_for_wm(&conn, root, net_supporting_wm_check)?;

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
            // Most WMs give DOCK-typed windows special stacking: always
            // above, never covered by a maximize.
            conn.change_property32(
                PropMode::REPLACE,
                window,
                net_wm_window_type,
                AtomEnum::ATOM,
                &[net_wm_window_type_dock],
            )?;

            // The window is already mapped by the time we find it, so
            // setting _NET_WM_STATE directly won't take effect — post-map
            // state changes have to go through a client message per the
            // EWMH spec. Belt-and-braces alongside the window type above.
            send_net_wm_state_add(&conn, root, window, net_wm_state, net_wm_state_above)?;

            conn.flush()?;
            return Ok(());
        }

        if attempt + 1 < MAX_ATTEMPTS {
            thread::sleep(RETRY_DELAY);
        }
    }

    Err(format!("window titled '{title}' never appeared in _NET_CLIENT_LIST").into())
}

fn send_net_wm_state_add(
    conn: &impl Connection,
    root: u32,
    window: u32,
    net_wm_state: u32,
    state_atom: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    let event = ClientMessageEvent::new(
        32,
        window,
        net_wm_state,
        [
            NET_WM_STATE_ADD,
            state_atom,
            0,
            SOURCE_INDICATION_APPLICATION,
            0,
        ],
    );
    conn.send_event(
        false,
        root,
        EventMask::SUBSTRUCTURE_NOTIFY | EventMask::SUBSTRUCTURE_REDIRECT,
        event,
    )?;
    Ok(())
}

fn wait_for_wm(
    conn: &impl Connection,
    root: u32,
    net_supporting_wm_check: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    const MAX_ATTEMPTS: u32 = 30;
    const RETRY_DELAY: Duration = Duration::from_millis(200);

    for attempt in 0..MAX_ATTEMPTS {
        let reply = conn
            .get_property(false, root, net_supporting_wm_check, AtomEnum::WINDOW, 0, 1)?
            .reply()?;
        if reply.value32().and_then(|mut v| v.next()).is_some() {
            return Ok(());
        }
        if attempt + 1 < MAX_ATTEMPTS {
            thread::sleep(RETRY_DELAY);
        }
    }

    Err("no EWMH-compliant window manager detected (_NET_SUPPORTING_WM_CHECK unset)".into())
}

fn intern(conn: &impl Connection, name: &[u8]) -> Result<u32, Box<dyn std::error::Error>> {
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

    for win in windows {
        let pid_reply = conn
            .get_property(false, win, net_wm_pid, AtomEnum::CARDINAL, 0, 1)?
            .reply()?;
        if let Some(pid) = pid_reply.value32().and_then(|mut v| v.next()) {
            if pid == my_pid {
                return Ok(Some(win));
            }
        }

        let name_reply = conn
            .get_property(false, win, net_wm_name, utf8_string, 0, u32::MAX)?
            .reply()?;
        if String::from_utf8_lossy(&name_reply.value) == title {
            return Ok(Some(win));
        }
    }

    Ok(None)
}
