//! Reserves screen space for the status bar on X11
//! X11 window managers (tested in Openbox) don't let maximized
//! windows sit underneath the bar.
//!
//! This is X11-only. On Wayland this does nothing (it just sits in the center)

use std::thread;
use std::time::Duration;

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{AtomEnum, ConnectionExt, PropMode};
use x11rb::wrapper::ConnectionExt as WrapperConnectionExt;

pub fn reserve_top_strut(title: &'static str, height: i32) {
    thread::spawn(move || {
        if let Err(err) = try_reserve_top_strut(title, height) {
            eprintln!(
                "vamora-statusbar: could not reserve X11 strut space ({err}); \
                 maximized windows may overlap the status bar"
            );
        }
    });
}

fn try_reserve_top_strut(title: &str, height: i32) -> Result<(), Box<dyn std::error::Error>> {
    let (conn, screen_num) = x11rb::connect(None)?;
    let screen = conn.setup().roots[screen_num].clone();
    let root = screen.root;
    let screen_width = screen.width_in_pixels as u32;
    let my_pid = std::process::id();

    let net_client_list = intern(&conn, b"_NET_CLIENT_LIST")?;
    let net_wm_pid = intern(&conn, b"_NET_WM_PID")?;
    let net_wm_name = intern(&conn, b"_NET_WM_NAME")?;
    let utf8_string = intern(&conn, b"UTF8_STRING")?;
    let net_wm_strut = intern(&conn, b"_NET_WM_STRUT")?;
    let net_wm_strut_partial = intern(&conn, b"_NET_WM_STRUT_PARTIAL")?;
    let net_supporting_wm_check = intern(&conn, b"_NET_SUPPORTING_WM_CHECK")?;

    const MAX_ATTEMPTS: u32 = 30;
    const RETRY_DELAY: Duration = Duration::from_millis(200);

    // Wait for a spec-compliant WM to actually be up (Openbox may still be
    // starting when this runs, e.g. if the session script launches the bar
    // before `exec openbox-session`). Without this we'd poll
    // _NET_CLIENT_LIST before it's even populated and just burn the retry
    // budget racing Openbox's startup.
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
            let strut: [u32; 4] = [0, 0, height as u32, 0];
            let strut_partial: [u32; 12] = [
                0,
                0,
                height as u32,
                0,
                0,
                0,
                0,
                0,
                0,
                screen_width.saturating_sub(1),
                0,
                0,
            ];

            conn.change_property32(
                PropMode::REPLACE,
                window,
                net_wm_strut,
                AtomEnum::CARDINAL,
                &strut,
            )?;
            conn.change_property32(
                PropMode::REPLACE,
                window,
                net_wm_strut_partial,
                AtomEnum::CARDINAL,
                &strut_partial,
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