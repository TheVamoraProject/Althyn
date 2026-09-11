//! Auto-hide detection for the dock.
//!
//! macOS-style behaviour: hide the dock whenever the active window is
//! maximized — EXCEPT when that window is vamora-homescreen, which is
//! always full-screen and shouldn't be treated as "an app taking over".
//!
//! X11-only for now (matches vamora-statusbar's x11strut.rs). On Wayland
//! this just always reports "don't hide" until a compositor-side protocol
//! exists.
//!
//! Polled from QML via a Timer calling shouldHide() rather than pushed
//! from a background thread — keeps this dead simple for the dummy-icon
//! milestone. Can move to an event-driven PropertyNotify watcher later.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type DockAutoHide = super::DockAutoHideRust;

        /// True if the dock should be hidden right now.
        #[qinvokable]
        #[cxx_name = "shouldHide"]
        fn should_hide(self: &DockAutoHide) -> bool;
    }
}

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{AtomEnum, ConnectionExt};

/// Window title/class substring that exempts a maximized window from
/// triggering auto-hide.
const EXCLUDED_WINDOW: &str = "vamora-homescreen";

#[derive(Default)]
pub struct DockAutoHideRust;

impl qobject::DockAutoHide {
    pub fn should_hide(&self) -> bool {
        active_window_is_maximized_and_not_excluded().unwrap_or(false)
    }
}

fn active_window_is_maximized_and_not_excluded() -> Result<bool, Box<dyn std::error::Error>> {
    let (conn, screen_num) = x11rb::connect(None)?;
    let root = conn.setup().roots[screen_num].root;

    let net_active_window = intern(&conn, b"_NET_ACTIVE_WINDOW")?;
    let net_wm_state = intern(&conn, b"_NET_WM_STATE")?;
    let net_wm_state_maximized_vert = intern(&conn, b"_NET_WM_STATE_MAXIMIZED_VERT")?;
    let net_wm_state_maximized_horz = intern(&conn, b"_NET_WM_STATE_MAXIMIZED_HORZ")?;
    let wm_class = intern(&conn, b"WM_CLASS")?;
    let net_wm_name = intern(&conn, b"_NET_WM_NAME")?;
    let utf8_string = intern(&conn, b"UTF8_STRING")?;

    let Some(active) = get_window_property(&conn, root, net_active_window, AtomEnum::WINDOW)? else {
        return Ok(false);
    };
    if active == 0 {
        return Ok(false);
    }

    let states = get_atom_list(&conn, active, net_wm_state)?;
    let is_maximized = states.contains(&net_wm_state_maximized_vert)
        && states.contains(&net_wm_state_maximized_horz);
    if !is_maximized {
        return Ok(false);
    }

    if window_matches_excluded(&conn, active, wm_class, net_wm_name, utf8_string, EXCLUDED_WINDOW)? {
        return Ok(false);
    }

    Ok(true)
}

fn window_matches_excluded(
    conn: &impl Connection,
    window: u32,
    wm_class: u32,
    net_wm_name: u32,
    utf8_string: u32,
    needle: &str,
) -> Result<bool, Box<dyn std::error::Error>> {
    let needle = needle.to_lowercase();

    // WM_CLASS is two NUL-separated strings: "instance\0class\0".
    let class_reply = conn
        .get_property(false, window, wm_class, AtomEnum::STRING, 0, u32::MAX)?
        .reply()?;
    let class_str = String::from_utf8_lossy(&class_reply.value).to_lowercase();
    if class_str.contains(&needle) {
        return Ok(true);
    }

    // Fall back to _NET_WM_NAME (UTF8_STRING) in case the class doesn't
    // carry the vamora-homescreen identity.
    let name_reply = conn
        .get_property(false, window, net_wm_name, utf8_string, 0, u32::MAX)?
        .reply()?;
    let name_str = String::from_utf8_lossy(&name_reply.value).to_lowercase();
    Ok(name_str.contains(&needle))
}

fn get_window_property(
    conn: &impl Connection,
    window: u32,
    property: u32,
    property_type: AtomEnum,
) -> Result<Option<u32>, Box<dyn std::error::Error>> {
    let reply = conn
        .get_property(false, window, property, property_type, 0, 1)?
        .reply()?;
    Ok(reply.value32().and_then(|mut v| v.next()))
}

fn get_atom_list(
    conn: &impl Connection,
    window: u32,
    property: u32,
) -> Result<Vec<u32>, Box<dyn std::error::Error>> {
    let reply = conn
        .get_property(false, window, property, AtomEnum::ATOM, 0, u32::MAX)?
        .reply()?;
    Ok(reply.value32().map(|v| v.collect()).unwrap_or_default())
}

fn intern(conn: &impl Connection, name: &[u8]) -> Result<u32, Box<dyn std::error::Error>> {
    Ok(conn.intern_atom(false, name)?.reply()?.atom)
}
