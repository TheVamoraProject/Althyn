/// CXX-Qt bridge — exposes WelcomeController to QML under com.vamora.welcome.
///
/// The UI and all animations live in QML; Rust handles OS-level calls:
/// exit, locale detection, os-release reading, and installer launch.

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

        /// Exits the welcome screen (Ctrl+Shift+Q or OS-level signal).
        #[qinvokable]
        fn request_exit(self: Pin<&mut WelcomeController>);

        /// Called when the user finishes the "Try" flow — exits the welcome
        /// screen so the live session can take over.
        #[qinvokable]
        fn finish_setup(self: Pin<&mut WelcomeController>);

        /// Reads /etc/os-release and returns PRETTY_NAME (or NAME), falling
        /// back to "VamoraOS". Called once at startup to populate QML labels.
        #[qinvokable]
        fn os_name(self: &WelcomeController) -> QString;

        /// Spawns /opt/vamora/installer as a detached process, then exits this
        /// welcome screen. The installer owns the display from this point on.
        #[qinvokable]
        fn launch_installer(self: Pin<&mut WelcomeController>);

        /// Returns the two-letter system language code ("en", "fr", "ja" …).
        #[qinvokable]
        fn system_locale(self: &WelcomeController) -> QString;

        /// Battery charge percentage from /sys/class/power_supply/BAT*, or
        /// -1 if no battery is present (e.g. a desktop / AC-only device).
        #[qinvokable]
        fn battery_percent(self: &WelcomeController) -> i32;

        /// True if the battery is currently charging (or full while on AC).
        /// Always false when no battery is present.
        #[qinvokable]
        fn battery_charging(self: &WelcomeController) -> bool;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;

#[derive(Default)]
pub struct WelcomeControllerRust;

impl qobject::WelcomeController {
    pub fn request_exit(self: Pin<&mut Self>) {
        std::process::exit(0);
    }

    pub fn finish_setup(self: Pin<&mut Self>) {
        std::process::exit(0);
    }

    pub fn os_name(&self) -> QString {
        let content = std::fs::read_to_string("/etc/os-release").unwrap_or_default();
        // Prefer PRETTY_NAME, fall back to NAME
        for field in &["PRETTY_NAME", "NAME"] {
            for line in content.lines() {
                if let Some(val) = line.strip_prefix(&format!("{}=", field)) {
                    let clean = val.trim_matches('"').trim_matches('\'').trim();
                    if !clean.is_empty() {
                        return QString::from(clean);
                    }
                }
            }
        }
        QString::from("VamoraOS")
    }

    pub fn launch_installer(self: Pin<&mut Self>) {
        // Spawn detached — installer takes over the display
        let _ = std::process::Command::new("/opt/vamora/installer").spawn();
        std::process::exit(0);
    }

    pub fn system_locale(&self) -> QString {
        let raw = std::env::var("LANG")
            .or_else(|_| std::env::var("LC_ALL"))
            .or_else(|_| std::env::var("LC_MESSAGES"))
            .unwrap_or_else(|_| "en_US.UTF-8".to_string());
        let lang = raw.split('_').next().unwrap_or("en").to_string();
        QString::from(&lang)
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
                .map(|s| {
                    let s = s.trim().to_lowercase();
                    s == "charging" || s == "full"
                })
                .unwrap_or(false),
            None => false,
        }
    }
}

/// Finds the first /sys/class/power_supply/BAT* directory, if any.
fn find_battery_dir() -> Option<std::path::PathBuf> {
    let entries = std::fs::read_dir("/sys/class/power_supply").ok()?;
    for entry in entries.flatten() {
        if entry.file_name().to_string_lossy().starts_with("BAT") {
            return Some(entry.path());
        }
    }
    None
}
