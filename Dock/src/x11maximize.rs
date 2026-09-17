//! X11/EWMH integration for the dock.
//!
//! This module deliberately does nothing when the dock is running without an
//! X11 display. Wayland window tracking needs compositor-specific protocols,
//! so the dock keeps its existing Wayland behavior and only uses this code
//! when an X11 connection is available.

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

use std::path::Path;

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    AtomEnum, ClientMessageEvent, ConnectionExt, EventMask,
};

/// Window title/class substring that exempts a maximized window from
/// triggering auto-hide.
const EXCLUDED_WINDOW: &str = "vamora-homescreen";
const NET_ACTIVE_WINDOW_SOURCE: u32 = 1;

#[derive(Default)]
pub struct DockAutoHideRust;

/// The stable identity information available from a pinned desktop entry.
/// `StartupWMClass` is the most reliable match when it is supplied; the
/// process executable is the fallback used by most simple desktop entries.
pub struct WindowMatch {
    pub key: String,
    pub app_name: String,
    pub startup_wm_class: String,
    pub exec_binary: String,
}

pub struct WindowState {
    pub key: String,
    pub window_count: usize,
    pub focused_index: isize,
}

impl qobject::DockAutoHide {
    pub fn should_hide(&self) -> bool {
        active_window_is_maximized_and_not_excluded().unwrap_or(false)
    }
}

/// Finds all managed X11 windows belonging to each pinned app.
///
/// EWMH defines `_NET_CLIENT_LIST` and `_NET_CLIENT_LIST_STACKING` as the
/// window-manager-owned lists of managed windows. We use stacking order for
/// the indicator order, and `_NET_ACTIVE_WINDOW` for the focused indicator.
pub fn window_states_for_apps(apps: &[WindowMatch]) -> Vec<WindowState> {
    let mut states = apps
        .iter()
        .map(|app| WindowState {
            key: app.key.clone(),
            window_count: 0,
            focused_index: -1,
        })
        .collect::<Vec<_>>();

    if !should_use_x11() {
        return states;
    }

    let Ok((conn, screen_num)) = x11rb::connect(None) else {
        return states;
    };
    let root = conn.setup().roots[screen_num].root;

    let Ok(atoms) = Atoms::intern(&conn) else {
        return states;
    };
    let Ok(windows) = client_windows(&conn, root, atoms.net_client_list_stacking, atoms.net_client_list)
    else {
        return states;
    };
    let active = read_window_property(&conn, root, atoms.net_active_window)
        .ok()
        .flatten()
        .unwrap_or(0);

    for window in windows {
        let Ok(Some(info)) = inspect_window(&conn, window, &atoms) else {
            continue;
        };
        let Some((app_index, _score)) = apps
            .iter()
            .enumerate()
            .filter_map(|(index, app)| {
                let score = match_score(&info, app);
                (score > 0).then_some((index, score))
            })
            .max_by_key(|(_, score)| *score)
        else {
            continue;
        };

        let state = &mut states[app_index];
        if info.window == active {
            state.focused_index = state.window_count as isize;
        }
        state.window_count += 1;
    }

    states
}

/// Activates the topmost matching window for a pinned app. Returns false when
/// no matching X11 window exists, allowing the caller to launch a new process.
pub fn activate_window_for_exec(exec: &str) -> bool {
    if !should_use_x11() {
        return false;
    }

    let Ok((conn, screen_num)) = x11rb::connect(None) else {
        return false;
    };
    let root = conn.setup().roots[screen_num].root;
    let Ok(atoms) = Atoms::intern(&conn) else {
        return false;
    };
    let Ok(windows) = client_windows(&conn, root, atoms.net_client_list_stacking, atoms.net_client_list)
    else {
        return false;
    };

    let active = read_window_property(&conn, root, atoms.net_active_window)
        .ok()
        .flatten()
        .unwrap_or(0);

    let app = WindowMatch {
        key: exec.to_string(),
        app_name: String::new(),
        startup_wm_class: String::new(),
        exec_binary: command_binary(exec),
    };
    let Some(window) = windows.into_iter().rev().find(|window| {
        inspect_window(&conn, *window, &atoms)
            .ok()
            .flatten()
            .is_some_and(|info| match_score(&info, &app) > 0)
    }) else {
        return false;
    };

    // Clicking the icon of the already-focused app toggles that app
    // minimized instead of pointlessly activating the same window again.
    if window == active {
        let event = ClientMessageEvent::new(
            32,
            window,
            atoms.wm_change_state,
            [3, 0, 0, 0, 0], // IconicState
        );
        if conn
            .send_event(false, root, EventMask::SUBSTRUCTURE_NOTIFY, event)
            .is_err()
        {
            return false;
        }
        return conn.flush().is_ok();
    }

    let event = ClientMessageEvent::new(
        32,
        window,
        atoms.net_active_window,
        [NET_ACTIVE_WINDOW_SOURCE, 0, 0, 0, 0],
    );
    if conn
        .send_event(
            false,
            root,
            EventMask::SUBSTRUCTURE_NOTIFY | EventMask::SUBSTRUCTURE_REDIRECT,
            event,
        )
        .is_err()
    {
        return false;
    }
    conn.flush().is_ok()
}

fn active_window_is_maximized_and_not_excluded() -> Result<bool, Box<dyn std::error::Error>> {
    if !should_use_x11() {
        return Ok(false);
    }

    let (conn, screen_num) = x11rb::connect(None)?;
    let root = conn.setup().roots[screen_num].root;
    let atoms = Atoms::intern(&conn)?;

    let Some(active) = read_window_property(&conn, root, atoms.net_active_window)? else {
        return Ok(false);
    };
    if active == 0 {
        return Ok(false);
    }

    let states = read_atom_property(&conn, active, atoms.net_wm_state)?;
    let is_maximized = states.contains(&atoms.net_wm_state_maximized_vert)
        && states.contains(&atoms.net_wm_state_maximized_horz);
    if !is_maximized {
        return Ok(false);
    }

    if window_matches_excluded(&conn, active, &atoms, EXCLUDED_WINDOW)? {
        return Ok(false);
    }

    Ok(true)
}

struct Atoms {
    net_client_list: u32,
    net_client_list_stacking: u32,
    net_active_window: u32,
    wm_change_state: u32,
    net_wm_state: u32,
    net_wm_state_maximized_vert: u32,
    net_wm_state_maximized_horz: u32,
    net_wm_state_skip_taskbar: u32,
    net_wm_window_type: u32,
    net_wm_window_type_dock: u32,
    net_wm_window_type_desktop: u32,
    net_wm_window_type_notification: u32,
    net_wm_window_type_splash: u32,
    net_wm_window_type_tooltip: u32,
    net_wm_window_type_menu: u32,
    net_wm_window_type_popup_menu: u32,
    net_wm_window_type_dropdown_menu: u32,
    net_wm_window_type_combo: u32,
    net_wm_window_type_dnd: u32,
    net_wm_pid: u32,
    wm_class: u32,
    net_wm_name: u32,
    utf8_string: u32,
}

impl Atoms {
    fn intern(conn: &impl Connection) -> Result<Self, Box<dyn std::error::Error>> {
        Ok(Self {
            net_client_list: intern(conn, b"_NET_CLIENT_LIST")?,
            net_client_list_stacking: intern(conn, b"_NET_CLIENT_LIST_STACKING")?,
            net_active_window: intern(conn, b"_NET_ACTIVE_WINDOW")?,
            wm_change_state: intern(conn, b"WM_CHANGE_STATE")?,
            net_wm_state: intern(conn, b"_NET_WM_STATE")?,
            net_wm_state_maximized_vert: intern(conn, b"_NET_WM_STATE_MAXIMIZED_VERT")?,
            net_wm_state_maximized_horz: intern(conn, b"_NET_WM_STATE_MAXIMIZED_HORZ")?,
            net_wm_state_skip_taskbar: intern(conn, b"_NET_WM_STATE_SKIP_TASKBAR")?,
            net_wm_window_type: intern(conn, b"_NET_WM_WINDOW_TYPE")?,
            net_wm_window_type_dock: intern(conn, b"_NET_WM_WINDOW_TYPE_DOCK")?,
            net_wm_window_type_desktop: intern(conn, b"_NET_WM_WINDOW_TYPE_DESKTOP")?,
            net_wm_window_type_notification: intern(conn, b"_NET_WM_WINDOW_TYPE_NOTIFICATION")?,
            net_wm_window_type_splash: intern(conn, b"_NET_WM_WINDOW_TYPE_SPLASH")?,
            net_wm_window_type_tooltip: intern(conn, b"_NET_WM_WINDOW_TYPE_TOOLTIP")?,
            net_wm_window_type_menu: intern(conn, b"_NET_WM_WINDOW_TYPE_MENU")?,
            net_wm_window_type_popup_menu: intern(conn, b"_NET_WM_WINDOW_TYPE_POPUP_MENU")?,
            net_wm_window_type_dropdown_menu: intern(conn, b"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU")?,
            net_wm_window_type_combo: intern(conn, b"_NET_WM_WINDOW_TYPE_COMBO")?,
            net_wm_window_type_dnd: intern(conn, b"_NET_WM_WINDOW_TYPE_DND")?,
            net_wm_pid: intern(conn, b"_NET_WM_PID")?,
            wm_class: intern(conn, b"WM_CLASS")?,
            net_wm_name: intern(conn, b"_NET_WM_NAME")?,
            utf8_string: intern(conn, b"UTF8_STRING")?,
        })
    }
}

struct WindowInfo {
    window: u32,
    class_values: Vec<String>,
    title: String,
    process_name: String,
}

fn client_windows(
    conn: &impl Connection,
    root: u32,
    stacking_atom: u32,
    fallback_atom: u32,
) -> Result<Vec<u32>, Box<dyn std::error::Error>> {
    let stacking = read_window_list(conn, root, stacking_atom)?;
    if !stacking.is_empty() {
        return Ok(stacking);
    }
    read_window_list(conn, root, fallback_atom)
}

fn inspect_window(
    conn: &impl Connection,
    window: u32,
    atoms: &Atoms,
) -> Result<Option<WindowInfo>, Box<dyn std::error::Error>> {
    let types = read_atom_property(conn, window, atoms.net_wm_window_type)?;
    let ignored_types = [
        atoms.net_wm_window_type_dock,
        atoms.net_wm_window_type_desktop,
        atoms.net_wm_window_type_notification,
        atoms.net_wm_window_type_splash,
        atoms.net_wm_window_type_tooltip,
        atoms.net_wm_window_type_menu,
        atoms.net_wm_window_type_popup_menu,
        atoms.net_wm_window_type_dropdown_menu,
        atoms.net_wm_window_type_combo,
        atoms.net_wm_window_type_dnd,
    ];
    if types.iter().any(|atom| ignored_types.contains(atom)) {
        return Ok(None);
    }

    let states = read_atom_property(conn, window, atoms.net_wm_state)?;
    if states.contains(&atoms.net_wm_state_skip_taskbar) {
        return Ok(None);
    }

    let class_bytes = read_property_bytes(conn, window, atoms.wm_class, AtomEnum::STRING)?;
    let class_values = class_bytes
        .split(|byte| *byte == 0)
        .filter(|part| !part.is_empty())
        .map(|part| String::from_utf8_lossy(part).to_lowercase())
        .collect::<Vec<_>>();
    let title = String::from_utf8_lossy(&read_property_bytes(
        conn,
        window,
        atoms.net_wm_name,
        atoms.utf8_string,
    )?)
    .trim_end_matches('\0')
    .to_lowercase();
    let process_name = read_u32_property(conn, window, atoms.net_wm_pid)
        .and_then(process_name_for_pid)
        .unwrap_or_default();

    Ok(Some(WindowInfo {
        window,
        class_values,
        title,
        process_name,
    }))
}

fn match_score(info: &WindowInfo, app: &WindowMatch) -> u32 {
    let startup = app.startup_wm_class.trim().to_lowercase();
    if !startup.is_empty()
        && (info.class_values.iter().any(|value| value == &startup)
            || info.title == startup)
    {
        return 100;
    }

    let exec = app.exec_binary.trim().to_lowercase();
    if !exec.is_empty() && info.process_name == exec {
        return 80;
    }

    if !exec.is_empty()
        && info
            .class_values
            .iter()
            .any(|value| value == &exec || value.ends_with(&format!(".{exec}")))
    {
        return 60;
    }

    let app_name = app.app_name.trim().to_lowercase();
    if !app_name.is_empty()
        && info
            .class_values
            .iter()
            .any(|value| value == &app_name)
    {
        return 20;
    }

    0
}

fn window_matches_excluded(
    conn: &impl Connection,
    window: u32,
    atoms: &Atoms,
    needle: &str,
) -> Result<bool, Box<dyn std::error::Error>> {
    let needle = needle.to_lowercase();
    let class_bytes = read_property_bytes(conn, window, atoms.wm_class, AtomEnum::STRING)?;
    let class_str = String::from_utf8_lossy(&class_bytes).to_lowercase();
    if class_str.contains(&needle) {
        return Ok(true);
    }

    let name_bytes =
        read_property_bytes(conn, window, atoms.net_wm_name, atoms.utf8_string)?;
    let name_str = String::from_utf8_lossy(&name_bytes).to_lowercase();
    Ok(name_str.contains(&needle))
}

fn read_window_list(
    conn: &impl Connection,
    window: u32,
    property: u32,
) -> Result<Vec<u32>, Box<dyn std::error::Error>> {
    let reply = conn
        .get_property(false, window, property, AtomEnum::WINDOW, 0, u32::MAX)?
        .reply()?;
    Ok(reply.value32().map(|values| values.collect()).unwrap_or_default())
}

fn read_window_property(
    conn: &impl Connection,
    window: u32,
    property: u32,
) -> Result<Option<u32>, Box<dyn std::error::Error>> {
    Ok(read_u32_property(conn, window, property))
}

fn read_u32_property(conn: &impl Connection, window: u32, property: u32) -> Option<u32> {
    conn.get_property(false, window, property, AtomEnum::ANY, 0, 1)
        .ok()?
        .reply()
        .ok()?
        .value32()
        .and_then(|mut values| values.next())
}

fn read_atom_property(
    conn: &impl Connection,
    window: u32,
    property: u32,
) -> Result<Vec<u32>, Box<dyn std::error::Error>> {
    let reply = conn
        .get_property(false, window, property, AtomEnum::ATOM, 0, u32::MAX)?
        .reply()?;
    Ok(reply.value32().map(|values| values.collect()).unwrap_or_default())
}

fn read_property_bytes<T: Into<u32>>(
    conn: &impl Connection,
    window: u32,
    property: u32,
    property_type: T,
) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let property_type: u32 = property_type.into();
    let reply = conn
        .get_property(false, window, property, property_type, 0, u32::MAX)?
        .reply()?;
    Ok(reply.value)
}

fn process_name_for_pid(pid: u32) -> Option<String> {
    let bytes = std::fs::read(format!("/proc/{pid}/cmdline")).ok()?;
    let command = bytes.split(|byte| *byte == 0).next()?;
    let command = String::from_utf8_lossy(command);
    let command: &str = command.as_ref();
    Path::new(command)
        .file_name()
        .and_then(|name| name.to_str())
        .map(str::to_lowercase)
}

fn command_binary(exec: &str) -> String {
    exec.split_whitespace()
        .next()
        .and_then(|part| Path::new(part).file_name())
        .and_then(|name| name.to_str())
        .unwrap_or_default()
        .to_lowercase()
}

fn should_use_x11() -> bool {
    let qt_platform = std::env::var("QT_QPA_PLATFORM")
        .unwrap_or_default()
        .to_lowercase();
    if qt_platform == "wayland" || qt_platform.starts_with("wayland-") {
        return false;
    }

    if qt_platform == "xcb" {
        return std::env::var_os("DISPLAY").is_some();
    }

    if std::env::var("XDG_SESSION_TYPE")
        .unwrap_or_default()
        .eq_ignore_ascii_case("wayland")
    {
        return false;
    }

    std::env::var_os("DISPLAY").is_some()
}

fn intern(conn: &impl Connection, name: &[u8]) -> Result<u32, Box<dyn std::error::Error>> {
    Ok(conn.intern_atom(false, name)?.reply()?.atom)
}
