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

        /// Pins dropped `.desktop` files (newline-separated file URIs):
        /// moved into the dock's contents directory when `move_files`
        /// (the drag came from the homescreen or a Move drop), copied
        /// otherwise. Returns how many entries were handled.
        #[qinvokable]
        #[cxx_name = "addDropped"]
        fn add_dropped(self: &DockModel, uris: &QString, move_files: bool) -> i32;
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

    pub fn add_dropped(&self, uris: &QString, move_files: bool) -> i32 {
        let Some(dir) = dock_contents_dir() else { return 0 };
        if std::fs::create_dir_all(&dir).is_err() { return 0 }
        let mut handled = 0;
        for uri in format!("{}", uris).lines() {
            let Some(src) = uri_to_path(uri) else { continue };
            if src.extension().and_then(|x| x.to_str()) != Some("desktop") { continue }
            let Some(new_app) = parse_desktop_file(&src) else { continue };
            if src.parent() == Some(dir.as_path()) { continue } // already pinned
            // Same app already pinned under this name: nothing to add, but a
            // move still takes the dropped file away from where it was.
            let same_name = src.file_name().map(|n| dir.join(n));
            if let Some(existing) = same_name.as_ref().filter(|p| p.exists()) {
                if parse_desktop_file(existing).is_some_and(|a| a.exec == new_app.exec) {
                    if move_files { let _ = std::fs::remove_file(&src); }
                    handled += 1;
                    continue;
                }
            }
            let Some(name) = src.file_name() else { continue };
            if move_or_copy(&src, &unique_dest(&dir, name), move_files) { handled += 1; }
        }
        handled
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


/// `file:///a%20b` (or a plain absolute path) -> `/a b`.
fn uri_to_path(uri: &str) -> Option<PathBuf> {
    use std::os::unix::ffi::OsStringExt;
    let u = uri.trim();
    let rest = if let Some(r) = u.strip_prefix("file://") {
        r.strip_prefix("localhost").unwrap_or(r)
    } else if u.starts_with('/') {
        u
    } else {
        return None;
    };
    let b = rest.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() && b[i + 1].is_ascii_hexdigit() && b[i + 2].is_ascii_hexdigit() {
            out.push(u8::from_str_radix(std::str::from_utf8(&b[i + 1..i + 3]).ok()?, 16).ok()?);
            i += 3;
        } else {
            out.push(b[i]);
            i += 1;
        }
    }
    if out.first() != Some(&b'/') { return None }
    Some(PathBuf::from(std::ffi::OsString::from_vec(out)))
}

/// `dir/name`, or `dir/stem-N.ext` when that name is taken.
fn unique_dest(dir: &Path, name: &std::ffi::OsStr) -> PathBuf {
    let first = dir.join(name);
    if !first.exists() { return first }
    let p = Path::new(name);
    let stem = p.file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or_default();
    let ext = p.extension().map(|s| format!(".{}", s.to_string_lossy())).unwrap_or_default();
    for n in 1..1000 {
        let c = dir.join(format!("{stem}-{n}{ext}"));
        if !c.exists() { return c }
    }
    first
}

/// Moves (rename, falling back to copy + delete across filesystems) or copies.
fn move_or_copy(src: &Path, dest: &Path, move_files: bool) -> bool {
    if move_files {
        if std::fs::rename(src, dest).is_ok() { return true }
        if std::fs::copy(src, dest).is_ok() {
            let _ = std::fs::remove_file(src); // may not be allowed (system file): the copy still counts
            return true;
        }
        false
    } else {
        std::fs::copy(src, dest).is_ok()
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
    let icon_path = resolve_icon(&icon);
    let direct_round = direct_round || pack_is_vamora(&icon_path);
    Some(App {
        name,
        icon_path,
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
    find_themed_icon(icon).map(|p| format!("file://{p}")).unwrap_or_default()
}

/// Icon pack chosen in settings (`icons.theme`); falls back to hicolor when unset
/// or unknown to VamoraSys.
fn icon_theme() -> String {
    std::process::Command::new("vamorasys").args(["settings", "get", "icons.theme"]).output().ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && !s.contains('/') && !s.contains(".."))
        .unwrap_or_else(|| "hicolor".to_string())
}

/// Look `icon` up in the chosen icon pack first, then hicolor, then pixmaps.
fn find_themed_icon(icon: &str) -> Option<String> {
    use std::path::Path;
    if icon.is_empty() || icon.contains('/') || icon.contains("..") { return None }
    let theme = icon_theme();
    let mut themes = vec![theme.clone()];
    if theme != "hicolor" { themes.push("hicolor".to_string()) }
    for t in &themes {
        let base = format!("/usr/share/icons/{t}");
        for sub in ["scalable/apps", "64x64/apps", "48x48/apps", "128x128/apps", "256x256/apps", "apps/scalable", "apps/64", "apps/48", "32/apps", "24/apps", "22/apps", "16/apps"] {
            for ext in ["svg", "png"] {
                let p = format!("{base}/{sub}/{icon}.{ext}");
                if Path::new(&p).exists() { return Some(p) }
            }
        }
    }
    for p in [format!("/usr/share/pixmaps/{icon}.png"), format!("/usr/share/pixmaps/{icon}.svg")] {
        if Path::new(&p).exists() { return Some(p) }
    }
    None
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
    #[test] fn uri_decodes() {
        assert_eq!(uri_to_path("file:///home/a%20b/x.desktop"), Some(PathBuf::from("/home/a b/x.desktop")));
        assert_eq!(uri_to_path("/plain/path"), Some(PathBuf::from("/plain/path")));
        assert_eq!(uri_to_path("https://x"), None);
    }
    #[test] fn unique_names() {
        let d = std::env::temp_dir().join(format!("althyn-dock-test-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        std::fs::write(d.join("a.desktop"), "x").unwrap();
        assert_eq!(unique_dest(&d, std::ffi::OsStr::new("a.desktop")), d.join("a-1.desktop"));
        assert_eq!(unique_dest(&d, std::ffi::OsStr::new("b.desktop")), d.join("b.desktop"));
        let _ = std::fs::remove_dir_all(&d);
    }
}

/// An icon pack opts in with `VamoraPackage=true` in its index.theme: its icons
/// are full-bleed and drawn like Vamora icons (rounded by the corner-radius
/// setting, no backing tile). Icons from other packs keep the tile.
fn pack_is_vamora(icon_url: &str) -> bool {
    let path = icon_url.strip_prefix("file://").unwrap_or(icon_url);
    let Some(rest) = path.strip_prefix("/usr/share/icons/") else { return false };
    let Some(theme) = rest.split('/').next() else { return false };
    std::fs::read_to_string(format!("/usr/share/icons/{theme}/index.theme")).map(|s| {
        s.lines().any(|l| { let l = l.trim(); l.eq_ignore_ascii_case("VamoraPackage=true") })
    }).unwrap_or(false)
}
