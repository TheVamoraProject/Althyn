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
        #[qproperty(QString, full_name)]
        #[qproperty(i32, wifi_strength)]
        #[qproperty(bool, wifi_enabled)]
        #[qproperty(bool, bluetooth_on)]
        #[qproperty(bool, battery_present)]
        #[qproperty(i32, battery_percent)]
        #[qproperty(bool, battery_charging)]
        #[qproperty(i32, battery_type)]
        type UserInfo = super::UserInfoRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut UserInfo>);
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;
use std::env;
use std::path::PathBuf;

pub struct UserInfoRust {
    pfp_path: QString,
    username: QString,
    full_name: QString,
    wifi_strength: i32,
    wifi_enabled: bool,
    bluetooth_on: bool,
    battery_present: bool,
    battery_percent: i32,
    battery_charging: bool,
    battery_type: i32,
}

impl Default for UserInfoRust {
    fn default() -> Self {
        let net = crate::network::read();
        let bat = crate::power::read();
        Self {
            pfp_path: QString::from(&find_pfp_path()),
            username: QString::from(&current_username()),
            full_name: QString::from(&find_full_name()),
            wifi_strength: net.wifi_bars,
            wifi_enabled: net.wifi_on,
            bluetooth_on: net.bluetooth_on,
            battery_present: bat.present,
            battery_percent: bat.percent,
            battery_charging: bat.charging,
            battery_type: crate::power::effective_type(crate::power::battery_type()),
        }
    }
}

impl qobject::UserInfo {
    pub fn refresh(mut self: Pin<&mut Self>) {
        let path = find_pfp_path();
        self.as_mut().set_pfp_path(QString::from(&path));
        let user = current_username();
        self.as_mut().set_username(QString::from(&user));
        self.as_mut().set_full_name(QString::from(&find_full_name()));
        let net = crate::network::read();
        self.as_mut().set_wifi_strength(net.wifi_bars);
        self.as_mut().set_wifi_enabled(net.wifi_on);
        self.as_mut().set_bluetooth_on(net.bluetooth_on);
        let bat = crate::power::read();
        self.as_mut().set_battery_present(bat.present);
        self.as_mut().set_battery_percent(bat.percent);
        self.as_mut().set_battery_charging(bat.charging);
        self.set_battery_type(crate::power::effective_type(crate::power::battery_type()));
    }
}

fn current_username() -> String {
    env::var("USER").unwrap_or_default()
}

/// Reads the user's display name from the GECOS field. If no full name is
/// configured, keep the login name as a useful, non-empty fallback.
fn find_full_name() -> String {
    let user = current_username();

    let accounts_service_path = format!("/var/lib/AccountsService/users/{}", user);
    if let Ok(accounts_service) =
        std::fs::read_to_string(accounts_service_path)
    {
        for line in accounts_service.lines() {
            if let Some(value) = line.strip_prefix("RealName=") {
                let name = value.trim().trim_matches('"');
                if !name.is_empty() {
                    return name.to_string();
                }
            }
        }
    }

    if let Ok(passwd) = std::fs::read_to_string("/etc/passwd") {
        for line in passwd.lines() {
            let fields: Vec<&str> = line.split(':').collect();
            if fields.first().copied() == Some(user.as_str()) {
                let gecos = fields.get(4)
                    .and_then(|value| value.split(',').next())
                    .unwrap_or("")
                    .trim();
                if !gecos.is_empty()
                    && gecos != "x"
                    && gecos != "User"
                {
                    return gecos.to_string();
                }
            }
        }
    }

    user
}

/// Checks the common places a Linux profile picture actually lives, in
/// priority order, and returns a file:// URL QML's Image can load directly.
/// Falls back to the bundled account.svg if the user has no pfp set.
fn find_pfp_path() -> String {
    let user = env::var("USER").unwrap_or_default();
    let home = env::var("HOME").unwrap_or_default();

    let candidates = [
        // AccountsService — what GNOME/Budgie's user switcher actually reads
        format!("/var/lib/AccountsService/icons/{}", user),
        // classic dotfile convention (some DMs/greeters use this)
        format!("{}/.face", home),
        format!("{}/.face.icon", home),
    ];

    for candidate in candidates {
        if PathBuf::from(&candidate).exists() {
            return format!("file://{}", candidate);
        }
    }

    // fallback: your existing bundled icon, unchanged
    "qrc:/assets/icons/account.svg".to_string()
}
