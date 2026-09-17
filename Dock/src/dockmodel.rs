//! Dock entries: `.desktop` files dropped into
//! ~/.VamoraSys/althyn/dock/contents/. If that directory has nothing
//! (or doesn't exist yet), the dock falls back to a single Settings
//! entry so it's never empty.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type DockModel = super::DockModelRust;

        /// Returns a JSON array of {appName, iconPath, execStr,
        /// directRound, bgColor} entries scanned from
        /// ~/.VamoraSys/althyn/dock/contents/*.desktop, falling back to
        /// a single Settings entry if there's nothing there.
        #[qinvokable]
        #[cxx_name = "getAppsJson"]
        fn get_apps_json(self: &DockModel) -> QString;

        /// Returns JSON window counts for the applications currently pinned
        /// in the dock. On X11 this is derived from EWMH client-list data;
        /// on Wayland it is intentionally empty until a compositor-side
        /// protocol is available.
        #[qinvokable]
        #[cxx_name = "getWindowStatesJson"]
        fn get_window_states_json(self: &DockModel) -> QString;

        /// Launches a dock entry's Exec string.
        #[qinvokable]
        #[cxx_name = "launchApp"]
        fn launch_app(self: &DockModel, exec: &QString);

        /// Reads `icons.corner_radius` (0-32, 32 = full circle) from
        /// VamoraSys once at startup, same as the launcher, homescreen
        /// and start menu.
        #[qinvokable]
        #[cxx_name = "getIconCornerRadius"]
        fn get_icon_corner_radius(self: &DockModel) -> QString;
    }
}

use cxx_qt_lib::QString;
use crate::x11maximize;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Default)]
pub struct DockModelRust;

struct App {
    name: String,
    icon_path: String,
    exec: String,
    direct_round: bool,
    bg_color: String,
    startup_wm_class: String,
}

impl qobject::DockModel {
    pub fn get_apps_json(&self) -> QString {
        let mut apps = scan_dock_contents();
        if apps.is_empty() {
            apps.push(fallback_settings_app());
        }
        QString::from(apps_to_json(&apps).as_str())
    }

    pub fn get_window_states_json(&self) -> QString {
        let mut apps = scan_dock_contents();
        if apps.is_empty() {
            apps.push(fallback_settings_app());
        }

        let matches = apps
            .iter()
            .map(|app| x11maximize::WindowMatch {
                key: app.exec.clone(),
                app_name: app.name.clone(),
                startup_wm_class: app.startup_wm_class.clone(),
                exec_binary: command_binary(&app.exec),
            })
            .collect::<Vec<_>>();
        let states = x11maximize::window_states_for_apps(&matches);

        let mut json = String::from("[");
        for (index, state) in states.iter().enumerate() {
            if index > 0 {
                json.push(',');
            }
            json.push_str(&format!(
                r#"{{"execStr":"{}","windowCount":{},"focusedIndex":{}}}"#,
                json_escape(&state.key),
                state.window_count,
                state.focused_index
            ));
        }
        json.push(']');
        QString::from(json.as_str())
    }

    pub fn launch_app(&self, exec: &QString) {
        let cleaned = clean_exec(&format!("{}", exec));
        if x11maximize::activate_window_for_exec(&cleaned) {
            return;
        }
        let mut parts = cleaned.split_whitespace();
        if let Some(bin) = parts.next() {
            let _ = Command::new(bin).args(parts).spawn();
        }
    }

    pub fn get_icon_corner_radius(&self) -> QString {
        let radius = Command::new("vamorasys")
            .args(["settings", "get", "icons.corner_radius"])
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|v| v.trim().to_string())
            .and_then(|v| v.parse::<f64>().ok())
            .filter(|v| v.is_finite() && *v >= 0.0)
            .unwrap_or(8.0);
        QString::from(radius.to_string().as_str())
    }
}

fn dock_contents_dir() -> Option<PathBuf> {
    std::env::var("HOME")
        .ok()
        .map(|h| PathBuf::from(h).join(".VamoraSys/althyn/dock/contents"))
}

fn scan_dock_contents() -> Vec<App> {
    let Some(dir) = dock_contents_dir() else { return vec![] };
    let Ok(entries) = std::fs::read_dir(&dir) else { return vec![] };
    let mut apps = vec![];
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|x| x.to_str()) == Some("desktop") {
            if let Some(app) = parse_desktop_file(&path) {
                apps.push(app);
            }
        }
    }
    apps.sort_by_key(|a| a.name.to_lowercase());
    apps
}

fn parse_desktop_file(path: &Path) -> Option<App> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut active = false;
    let mut name = String::new();
    let mut icon = String::new();
    let mut exec = String::new();
    let mut typ = String::new();
    let mut hidden = false;
    let mut direct_round = false;
    let mut bg_color = String::new();
    let mut startup_wm_class = String::new();
    for line in content.lines().map(str::trim) {
        if line == "[Desktop Entry]" { active = true; continue }
        if line.starts_with('[') && active { break }
        if !active { continue }
        if let Some(v) = line.strip_prefix("Name=") { if name.is_empty() { name = v.into() } }
        else if let Some(v) = line.strip_prefix("Icon=") { if icon.is_empty() { icon = v.into() } }
        else if let Some(v) = line.strip_prefix("Exec=") { if exec.is_empty() { exec = v.into() } }
        else if let Some(v) = line.strip_prefix("Type=") { typ = v.into() }
        else if line == "NoDisplay=true" || line == "Hidden=true" { hidden = true }
        else if let Some(v) = line.strip_prefix("VamoraPackage=") { if !v.trim().is_empty() { direct_round = true } }
        else if let Some(v) = line.strip_prefix("BGColor=") { if v.trim().starts_with('#') { bg_color = v.trim().to_string() } }
        else if let Some(v) = line.strip_prefix("StartupWMClass=") { if startup_wm_class.is_empty() { startup_wm_class = v.trim().to_string() } }
        else if let Some(v) = line.strip_prefix("X-GNOME-WMClass=") { if startup_wm_class.is_empty() { startup_wm_class = v.trim().to_string() } }
    }
    if typ != "Application" || hidden || name.is_empty() || exec.is_empty() { return None }
    Some(App {
        name,
        icon_path: resolve_icon(&icon),
        exec: clean_exec(&exec),
        direct_round,
        bg_color,
        startup_wm_class,
    })
}

/// Bundled fallback shown when ~/.VamoraSys/althyn/dock/contents/ has no
/// valid entries, mirroring the Settings .desktop file shipped alongside
/// the dock (VamoraPackage set => direct-round-safe icon).
fn fallback_settings_app() -> App {
    App {
        name: "Settings".to_string(),
        icon_path: resolve_icon("/etc/VamoraSys/alpha-temp/icons/settings.png"),
        exec: "vamora-settings".to_string(),
        direct_round: true,
        bg_color: String::new(),
        startup_wm_class: String::new(),
    }
}

fn clean_exec(exec: &str) -> String {
    let mut out = String::new();
    let mut c = exec.chars().peekable();
    while let Some(x) = c.next() {
        if x == '%' { c.next(); } else { out.push(x); }
    }
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn command_binary(exec: &str) -> String {
    exec.split_whitespace()
        .next()
        .and_then(|part| Path::new(part).file_name())
        .and_then(|name| name.to_str())
        .unwrap_or_default()
        .to_lowercase()
}

fn resolve_icon(icon: &str) -> String {
    if icon.is_empty() { return String::new() }
    if icon.starts_with('/') && Path::new(icon).exists() { return format!("file://{icon}") }
    for p in [
        format!("/usr/share/icons/hicolor/48x48/apps/{icon}.png"),
        format!("/usr/share/icons/hicolor/scalable/apps/{icon}.svg"),
        format!("/usr/share/pixmaps/{icon}.png"),
        format!("/usr/share/pixmaps/{icon}.svg"),
    ] {
        if Path::new(&p).exists() { return format!("file://{p}") }
    }
    String::new()
}

fn json_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r")
}

fn apps_to_json(apps: &[App]) -> String {
    let mut o = String::from("[");
    for (i, a) in apps.iter().enumerate() {
        if i > 0 { o.push(',') }
        o.push_str(&format!(
            r#"{{"appName":"{}","iconPath":"{}","execStr":"{}","directRound":{},"bgColor":"{}"}}"#,
            json_escape(&a.name), json_escape(&a.icon_path), json_escape(&a.exec), a.direct_round, json_escape(&a.bg_color)
        ));
    }
    o.push(']');
    o
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn exec_codes_removed() { assert_eq!(clean_exec("foo %U --bar"), "foo --bar"); }
    #[test] fn fallback_is_direct_round() { assert!(fallback_settings_app().direct_round); }
}
