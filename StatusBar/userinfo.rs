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
use std::path::PathBuf;

pub struct UserInfoRust {
    pfp_path: QString,
    username: QString,
    wifi_strength: i32,
}

impl Default for UserInfoRust {
    fn default() -> Self {
        Self {
            pfp_path: QString::from(&find_pfp_path()),
            username: QString::from(&env::var("USER").unwrap_or_default()),
            wifi_strength: read_wifi_strength(),
        }
    }
}

impl qobject::UserInfo {
    pub fn refresh(mut self: Pin<&mut Self>) {
        let path = find_pfp_path();
        self.as_mut().set_pfp_path(QString::from(&path));
        let user = env::var("USER").unwrap_or_default();
        self.as_mut().set_username(QString::from(&user));
        self.set_wifi_strength(read_wifi_strength());
    }
}

/// Reads wifi link quality (dosnt work? or maybe my wifi is always one dot?)
fn read_wifi_strength() -> i32 {
    let content = std::fs::read_to_string("/proc/net/wireless").unwrap_or_default();
    for line in content.lines().skip(2) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 3 {
            let quality_str = parts[2].trim_end_matches('.');
            if let Ok(quality) = quality_str.parse::<f64>() {
                return match quality as i32 {
                    q if q >= 56 => 4,
                    q if q >= 42 => 3,
                    q if q >= 28 => 2,
                    q if q >= 1  => 1,
                    _            => 0,
                };
            }
        }
    }
    0
}

/// tries to get the pfp
fn find_pfp_path() -> String {
    let user = env::var("USER").unwrap_or_default();
    let home = env::var("HOME").unwrap_or_default();

    let candidates = [
        format!("/var/lib/AccountsService/icons/{}", user),
        format!("{}/.face", home),
        format!("{}/.face.icon", home),
    ];

    for candidate in candidates {
        if PathBuf::from(&candidate).exists() {
            return format!("file://{}", candidate);
        }
    }

    // fallback
    "qrc:/assets/icons/account.svg".to_string()
}
