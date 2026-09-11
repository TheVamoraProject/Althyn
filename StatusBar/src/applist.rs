#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type AppList = super::AppListRust;

        /// Returns a JSON array of {appName, iconPath, execStr, desktopPath} objects.
        #[qinvokable]
        #[cxx_name = "getAppsJson"]
        fn get_apps_json(self: &AppList) -> QString;

        /// Launches an application given its Exec string.
        #[qinvokable]
        #[cxx_name = "launchApp"]
        fn launch_app(self: &AppList, exec: &QString);

        /// Copies a .desktop file to ~/Desktop/.
        #[qinvokable]
        #[cxx_name = "copyToDesktop"]
        fn copy_to_desktop(self: &AppList, desktop_file_path: &QString);

        /// Copies a .desktop file to ~/Desktop/.favorites/.
        #[qinvokable]
        #[cxx_name = "copyToFavorites"]
        fn copy_to_favorites(self: &AppList, desktop_file_path: &QString);

        /// Returns a JSON array of apps from ~/Desktop/.favorites/.
        #[qinvokable]
        #[cxx_name = "getFavoritesJson"]
        fn get_favorites_json(self: &AppList) -> QString;

        /// Loads the user's persisted control-center layout.
        #[qinvokable]
        #[cxx_name = "getQuickSettingsLayout"]
        fn get_quick_settings_layout(self: &AppList) -> QString;

        /// Persists the user's control-center layout.
        #[qinvokable]
        #[cxx_name = "saveQuickSettingsLayout"]
        fn save_quick_settings_layout(self: &AppList, layout: &QString);
    }
}

use cxx_qt_lib::QString;
use std::path::PathBuf;

#[derive(Default)]
pub struct AppListRust;

impl qobject::AppList {
    pub fn get_apps_json(&self) -> QString {
        let apps = scan_desktop_files();
        QString::from(apps_to_json(&apps).as_str())
    }

    pub fn launch_app(&self, exec: &QString) {
        let raw = format!("{}", exec);
        if raw.is_empty() {
            return;
        }
        let cleaned = clean_exec(&raw);
        let mut parts = cleaned.split_whitespace();
        if let Some(bin) = parts.next() {
            let args: Vec<&str> = parts.collect();
            let _ = std::process::Command::new(bin).args(&args).spawn();
        }
    }

    pub fn copy_to_desktop(&self, desktop_file_path: &QString) {
        let src = format!("{}", desktop_file_path);
        if src.is_empty() {
            return;
        }
        let src_path = PathBuf::from(&src);
        if !src_path.exists() {
            return;
        }
        let home = std::env::var("HOME").unwrap_or_default();
        if home.is_empty() {
            return;
        }
        let dest_dir = PathBuf::from(format!("{}/Desktop", home));
        let _ = std::fs::create_dir_all(&dest_dir);
        if let Some(file_name) = src_path.file_name() {
            let dest = dest_dir.join(file_name);
            let _ = std::fs::copy(&src_path, &dest);
        }
    }

    pub fn get_favorites_json(&self) -> QString {
        let home = std::env::var("HOME").unwrap_or_default();
        if home.is_empty() {
            return QString::from("[]");
        }
        let dir = PathBuf::from(format!("{}/Desktop/.favorites", home));
        let Ok(entries) = std::fs::read_dir(&dir) else {
            return QString::from("[]");
        };
        let mut apps: Vec<App> = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            if let Some(app) = parse_desktop_file(&path) {
                apps.push(app);
            }
        }
        apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
        QString::from(apps_to_json(&apps).as_str())
    }

    pub fn get_quick_settings_layout(&self) -> QString {
        let path = quick_settings_layout_path();
        QString::from(
            &std::fs::read_to_string(path)
                .unwrap_or_default(),
        )
    }

    pub fn save_quick_settings_layout(&self, layout: &QString) {
        let path = quick_settings_layout_path();
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let _ = std::fs::write(path, format!("{}", layout));
    }

    pub fn copy_to_favorites(&self, desktop_file_path: &QString) {
        let src = format!("{}", desktop_file_path);
        if src.is_empty() {
            return;
        }
        let src_path = PathBuf::from(&src);
        if !src_path.exists() {
            return;
        }
        let home = std::env::var("HOME").unwrap_or_default();
        if home.is_empty() {
            return;
        }
        let dest_dir = PathBuf::from(format!("{}/Desktop/.favorites", home));
        let _ = std::fs::create_dir_all(&dest_dir);
        if let Some(file_name) = src_path.file_name() {
            let dest = dest_dir.join(file_name);
            let _ = std::fs::copy(&src_path, &dest);
        }
    }
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

struct App {
    name: String,
    icon_path: String,
    exec: String,
    desktop_path: String,
}

// ---------------------------------------------------------------------------
// Desktop file scanning
// ---------------------------------------------------------------------------

fn scan_desktop_files() -> Vec<App> {
    let mut dirs = vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
    ];
    if let Ok(home) = std::env::var("HOME") {
        dirs.push(PathBuf::from(format!("{}/.local/share/applications", home)));
    }

    let mut apps: Vec<App> = Vec::new();
    for dir in &dirs {
        let Ok(entries) = std::fs::read_dir(dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            if let Some(app) = parse_desktop_file(&path) {
                apps.push(app);
            }
        }
    }

    apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    apps.dedup_by(|a, b| a.name == b.name);
    apps
}

fn parse_desktop_file(path: &PathBuf) -> Option<App> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut in_entry = false;
    let mut name = String::new();
    let mut icon = String::new();
    let mut exec = String::new();
    let mut app_type = String::new();
    let mut no_display = false;

    for line in content.lines() {
        let line = line.trim();
        if line == "[Desktop Entry]" {
            in_entry = true;
            continue;
        }
        if line.starts_with('[') && in_entry {
            break; // left the Desktop Entry section
        }
        if !in_entry {
            continue;
        }
        if let Some(v) = line.strip_prefix("Name=") {
            if name.is_empty() {
                name = v.to_string();
            }
        } else if let Some(v) = line.strip_prefix("Icon=") {
            if icon.is_empty() {
                icon = v.to_string();
            }
        } else if let Some(v) = line.strip_prefix("Exec=") {
            if exec.is_empty() {
                exec = v.to_string();
            }
        } else if let Some(v) = line.strip_prefix("Type=") {
            app_type = v.to_string();
        } else if line == "NoDisplay=true" || line == "Hidden=true" {
            no_display = true;
        }
    }

    if app_type != "Application" || no_display || name.is_empty() || exec.is_empty() {
        return None;
    }

    Some(App {
        name,
        icon_path: resolve_icon(&icon),
        exec: clean_exec(&exec),
        desktop_path: path.to_string_lossy().to_string(),
    })
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Remove %x field codes from an Exec string (e.g. %u, %f, %i, %c).
fn clean_exec(exec: &str) -> String {
    let mut result = String::with_capacity(exec.len());
    let mut chars = exec.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            chars.next(); // drop the next char (%u, %f, etc.)
        } else {
            result.push(c);
        }
    }
    // collapse extra whitespace
    result.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn quick_settings_layout_path() -> PathBuf {
    std::env::var("HOME")
        .ok()
        .filter(|value| !value.is_empty())
        .map(|home| {
            PathBuf::from(home)
                .join(".VamoraSys")
                .join("althyn")
                .join("statusbar")
                .join("controlcenter")
                .join("layout.json")
        })
        .unwrap_or_else(|| PathBuf::from("layout.json"))
}

/// Try to resolve an icon name or path to a file:// URL QML can load.
fn resolve_icon(icon: &str) -> String {
    if icon.is_empty() {
        return String::new();
    }
    // Absolute path given directly
    if icon.starts_with('/') {
        if PathBuf::from(icon).exists() {
            return format!("file://{}", icon);
        }
        return String::new();
    }
    // Search standard XDG / hicolor locations
    let candidates = [
        format!("/usr/share/icons/hicolor/48x48/apps/{}.png", icon),
        format!("/usr/share/icons/hicolor/scalable/apps/{}.svg", icon),
        format!("/usr/share/icons/hicolor/256x256/apps/{}.png", icon),
        format!("/usr/share/icons/hicolor/128x128/apps/{}.png", icon),
        format!("/usr/share/icons/hicolor/64x64/apps/{}.png", icon),
        format!("/usr/share/icons/hicolor/32x32/apps/{}.png", icon),
        format!("/usr/share/icons/Adwaita/48x48/apps/{}.png", icon),
        format!("/usr/share/icons/Adwaita/scalable/apps/{}.svg", icon),
        format!("/usr/share/pixmaps/{}.png", icon),
        format!("/usr/share/pixmaps/{}.svg", icon),
        format!("/usr/share/pixmaps/{}", icon),
    ];
    for p in &candidates {
        if PathBuf::from(p).exists() {
            return format!("file://{}", p);
        }
    }
    String::new()
}

/// Minimal JSON string escaping.
fn json_escape(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn apps_to_json(apps: &[App]) -> String {
    let mut out = String::from("[");
    for (i, app) in apps.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&format!(
            r#"{{"appName":"{}","iconPath":"{}","execStr":"{}","desktopPath":"{}"}}"#,
            json_escape(&app.name),
            json_escape(&app.icon_path),
            json_escape(&app.exec),
            json_escape(&app.desktop_path),
        ));
    }
    out.push(']');
    out
}
