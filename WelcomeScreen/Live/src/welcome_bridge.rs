/// CXX-Qt bridge — exposes WelcomeController to QML under com.vamora.welcome.

#[cxx_qt::bridge]
pub mod qobject {

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[namespace = "vamora_welcome"]
        type WelcomeController = super::WelcomeControllerRust;

        #[qinvokable] fn request_exit(self: Pin<&mut WelcomeController>);
        #[qinvokable] fn finish_setup(self: Pin<&mut WelcomeController>);
        #[qinvokable] fn os_name(self: &WelcomeController) -> QString;
        #[qinvokable] fn launch_installer(self: Pin<&mut WelcomeController>);
        #[qinvokable] fn system_locale(self: &WelcomeController) -> QString;

        /// Returns the full locale code for the current system, e.g. "en_US.UTF-8".
        /// Reads /etc/locale.conf first (systemd), then $LANG, then falls back to
        /// "en_US.UTF-8".  Used by QML to pre-select the language list entry.
        #[qinvokable] fn locale_code(self: &WelcomeController) -> QString;

        /// Applies a locale code such as "fr_FR.UTF-8" system-wide:
        ///   1. Tries `localectl set-locale LANG=<code>` (systemd).
        ///   2. Falls back to writing /etc/locale.conf directly.
        ///   3. Sets LANG in the current process environment so subsequent
        ///      Qt locale calls pick it up immediately.
        #[qinvokable] fn apply_locale(self: Pin<&mut WelcomeController>, locale: QString);

        #[qinvokable] fn battery_percent(self: &WelcomeController) -> i32;
        #[qinvokable] fn battery_charging(self: &WelcomeController) -> bool;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;

#[derive(Default)]
pub struct WelcomeControllerRust;

impl qobject::WelcomeController {
    pub fn request_exit(self: Pin<&mut Self>) { std::process::exit(0); }

    pub fn finish_setup(self: Pin<&mut Self>) { std::process::exit(0); }

    pub fn os_name(&self) -> QString {
        let content = std::fs::read_to_string("/etc/os-release").unwrap_or_default();
        for field in &["PRETTY_NAME", "NAME"] {
            for line in content.lines() {
                if let Some(val) = line.strip_prefix(&format!("{}=", field)) {
                    let clean = val.trim_matches('"').trim_matches('\'').trim();
                    if !clean.is_empty() { return QString::from(clean); }
                }
            }
        }
        QString::from("VamoraOS")
    }

    pub fn launch_installer(self: Pin<&mut Self>) {
        let _ = std::process::Command::new("/opt/vamora/installer").spawn();
        std::process::exit(0);
    }

    pub fn system_locale(&self) -> QString {
        let raw = std::env::var("LANG")
            .or_else(|_| std::env::var("LC_ALL"))
            .unwrap_or_else(|_| "en_US.UTF-8".to_string());
        let lang = raw.split('_').next().unwrap_or("en").to_string();
        QString::from(&lang)
    }

    pub fn locale_code(&self) -> QString {
        // Prefer /etc/locale.conf (written by localectl / live-installer)
        if let Ok(content) = std::fs::read_to_string("/etc/locale.conf") {
            for line in content.lines() {
                if let Some(val) = line.strip_prefix("LANG=") {
                    let clean = val.trim().trim_matches('"');
                    if !clean.is_empty() { return QString::from(clean); }
                }
            }
        }
        // Fall back to the process environment
        let raw = std::env::var("LANG")
            .or_else(|_| std::env::var("LC_ALL"))
            .unwrap_or_else(|_| "en_US.UTF-8".to_string());
        QString::from(&raw)
    }

    pub fn apply_locale(self: Pin<&mut Self>, locale: QString) {
        let code = locale.to_string();

        // 1. Try localectl (systemd-based distros, needs root or polkit)
        let ok = std::process::Command::new("localectl")
            .args(["set-locale", &format!("LANG={}", code)])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        // 2. Fallback: write /etc/locale.conf directly
        if !ok {
            let _ = std::fs::write("/etc/locale.conf", format!("LANG={}\n", code));
        }

        // 3. Also update this process so Qt picks it up for any subsequent
        //    locale-sensitive calls (date formatting, etc.)
        // SAFETY: single-threaded at this point in the setup flow.
        unsafe {
            #[allow(deprecated)]
            std::env::set_var("LANG", &code);
        }
    }

    pub fn battery_percent(&self) -> i32 {
        match find_battery_dir() {
            Some(dir) => std::fs::read_to_string(dir.join("capacity"))
                .ok()
                .and_then(|s| s.trim().parse::<i32>().ok())
                .map(|v| v.clamp(0, 100))
                .unwrap_or(-1),
            None => -1,
        }
    }

    pub fn battery_charging(&self) -> bool {
        match find_battery_dir() {
            Some(dir) => std::fs::read_to_string(dir.join("status"))
                .map(|s| { let s = s.trim().to_lowercase(); s == "charging" || s == "full" })
                .unwrap_or(false),
            None => false,
        }
    }
}

fn find_battery_dir() -> Option<std::path::PathBuf> {
    let entries = std::fs::read_dir("/sys/class/power_supply").ok()?;
    for entry in entries.flatten() {
        if entry.file_name().to_string_lossy().starts_with("BAT") {
            return Some(entry.path());
        }
    }
    None
}
