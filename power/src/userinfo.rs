#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, pfp_path)]
        #[qproperty(QString, username)]
        #[qproperty(i32, wifi_strength)]
        type UserInfo = super::UserInfoRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut UserInfo>);
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;
use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct UserInfoRust {
    pfp_path: QString,
    username: QString,
    wifi_strength: i32,
}

impl Default for UserInfoRust {
    fn default() -> Self {
        Self {
            pfp_path: QString::from(&find_pfp_path()),
            username: QString::from(&find_full_name()),
            wifi_strength: read_wifi_strength(),
        }
    }
}

impl qobject::UserInfo {
    pub fn refresh(mut self: Pin<&mut Self>) {
        let path = find_pfp_path();
        self.as_mut().set_pfp_path(QString::from(&path));
        let user = find_full_name();
        self.as_mut().set_username(QString::from(&user));
        self.set_wifi_strength(read_wifi_strength());
    }
}

/// Resolves a friendly display name instead of showing a login principal such
/// as "name@vamoraos". AccountsService is preferred, then the standard passwd
/// GECOS field, with a clean login-name fallback.
fn find_full_name() -> String {
    let login_user = current_login_name();

    if login_user.is_empty() {
        return "Vamora user".to_string();
    }

    let accounts_service = format!("/var/lib/AccountsService/users/{}", login_user);
    if let Some(name) = read_key(&accounts_service, &["RealName", "Name"]) {
        return name;
    }

    if let Ok(output) = Command::new("getent")
        .args(["passwd", &login_user])
        .output()
    {
        if output.status.success() {
            let passwd_entry = String::from_utf8_lossy(&output.stdout);
            if let Some(gecos) = passwd_entry.split(':').nth(4) {
                let name = gecos.split(',').next().unwrap_or("").trim();
                if !name.is_empty() {
                    return name.to_string();
                }
            }
        }
    }

    login_user
}

fn current_login_name() -> String {
    let raw_user = env::var("USER")
        .or_else(|_| env::var("LOGNAME"))
        .unwrap_or_default();
    raw_user
        .split_once('@')
        .map(|(name, _)| name)
        .unwrap_or(raw_user.as_str())
        .trim()
        .to_string()
}

fn read_key(path: &str, keys: &[&str]) -> Option<String> {
    let content = std::fs::read_to_string(Path::new(path)).ok()?;
    for line in content.lines() {
        for key in keys {
            if let Some(value) = line.strip_prefix(&format!("{key}=")) {
                let value = value.trim().trim_matches('"');
                if !value.is_empty() {
                    return Some(value.to_string());
                }
            }
        }
    }
    None
}

/// Reads wifi link quality from /proc/net/wireless and maps it to 0–4 bars.
/// Returns 0 if wifi is disconnected or the interface isn't found.
fn read_wifi_strength() -> i32 {
    let content = std::fs::read_to_string("/proc/net/wireless").unwrap_or_default();
    for line in content.lines().skip(2) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        // Format: iface: status link. level. noise. ...
        // parts[0] = "wlan0:", parts[2] = link quality (may have trailing dot)
        if parts.len() >= 3 {
            let quality_str = parts[2].trim_end_matches('.');
            if let Ok(quality) = quality_str.parse::<f64>() {
                // Link quality is typically 0–70 on Linux
                return match quality as i32 {
                    q if q >= 56 => 4,
                    q if q >= 42 => 3,
                    q if q >= 28 => 2,
                    q if q >= 1 => 1,
                    _ => 0,
                };
            }
        }
    }
    0
}

/// Checks the common places a Linux profile picture actually lives, in
/// priority order, and returns a file:// URL QML's Image can load directly.
/// Falls back to the bundled account.svg if the user has no pfp set.
fn find_pfp_path() -> String {
    let user = current_login_name();
    let home = env::var("HOME").unwrap_or_default();
    let accounts_service_user = format!("/var/lib/AccountsService/users/{}", user);

    let mut candidates = vec![
        // AccountsService — what GNOME/Budgie's user switcher actually reads
        format!("/var/lib/AccountsService/icons/{}", user),
        // Debian and several display managers keep user faces here.
        format!("/usr/share/pixmaps/faces/{}", user),
        format!("/usr/share/pixmaps/faces/{}.png", user),
        format!("/usr/share/pixmaps/faces/{}.jpg", user),
        // Common packaged Debian/Adwaita default avatars.
        "/usr/share/pixmaps/faces/default.png".to_string(),
        "/usr/share/icons/Adwaita/48x48/status/avatar-default.png".to_string(),
        "/usr/share/icons/Adwaita/64x64/status/avatar-default.png".to_string(),
        "/usr/share/icons/gnome/48x48/status/avatar-default.png".to_string(),
        // classic dotfile convention (some DMs/greeters use this)
        format!("{}/.face.png", home),
        format!("{}/.face", home),
        format!("{}/.face.icon", home),
    ];

    // Some Debian installations store the chosen image in the AccountsService
    // user record rather than using the conventional icon filename.
    if let Some(icon) = read_key(&accounts_service_user, &["Icon", "Picture"]) {
        let icon = icon.strip_prefix("file://").unwrap_or(&icon).to_string();
        candidates.insert(0, icon);
    }

    for candidate in candidates {
        if PathBuf::from(&candidate).is_file() {
            return format!("file://{}", candidate);
        }
    }

    // fallback: your existing bundled icon, unchanged
    "qrc:/assets/icons/account.svg".to_string()
}
