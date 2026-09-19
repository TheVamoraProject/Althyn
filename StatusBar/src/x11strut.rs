//! Reserves screen space for the status bar on X11 and marks it as an EWMH
//! dock so tiling WMs (i3, etc.) don't tile it into the layout like a
//! normal client. Openbox honored the strut alone without a window type,
//! but tiling WMs decide whether to manage/tile a window based on
//! _NET_WM_WINDOW_TYPE, not on whether strut props are set — without the
//! dock type, i3 tiled the bar as a regular window and the struts never
//! got a chance to matter. Mirrors vamora-dock's x11docktype.rs.
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
    let net_wm_window_type = intern(&conn, b"_NET_WM_WINDOW_TYPE")?;
    let net_wm_window_type_dock = intern(&conn, b"_NET_WM_WINDOW_TYPE_DOCK")?;

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

            // Tiling WMs (i3, etc.) decide whether to tile a window based on
            // this, not on the strut props below — set it first so the bar
            // is treated as a panel at all, then reserve the strut space.
            conn.change_property32(
                PropMode::REPLACE,
                window,
                net_wm_window_type,
                AtomEnum::ATOM,
                &[net_wm_window_type_dock],
            )?;
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

            // Keep the reservation alive. A few WMs recalculate work areas
            // after maximize/unmaximize or desktop changes and can drop the
            // effective strut until the property is written again.
            loop {
                thread::sleep(Duration::from_millis(1000));

                let Some(current_window) = find_window(
                    &conn,
                    root,
                    net_client_list,
                    net_wm_pid,
                    net_wm_name,
                    utf8_string,
                    my_pid,
                    title,
                )? else {
                    continue;
                };

                conn.change_property32(
                    PropMode::REPLACE,
                    current_window,
                    net_wm_window_type,
                    AtomEnum::ATOM,
                    &[net_wm_window_type_dock],
                )?;
                conn.change_property32(
                    PropMode::REPLACE,
                    current_window,
                    net_wm_strut,
                    AtomEnum::CARDINAL,
                    &strut,
                )?;
                conn.change_property32(
                    PropMode::REPLACE,
                    current_window,
                    net_wm_strut_partial,
                    AtomEnum::CARDINAL,
                    &strut_partial,
                )?;
                conn.flush()?;
            }
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
