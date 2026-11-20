/// CXX-Qt bridge — exposes SettingsController to QML under com.vamora.settings.
///
/// All settings logic lives in QML for now (design-first).
/// Rust handles OS-level calls: quit, os-release reading.

#[cxx_qt::bridge]
pub mod qobject {

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[namespace = "vamora_settings"]
        type SettingsController = super::SettingsControllerRust;

        /// Quit the application.
        #[qinvokable]
        fn request_quit(self: Pin<&mut SettingsController>);

        /// Read PRETTY_NAME from /etc/os-release, falling back to "VamoraOS".
        #[qinvokable]
        fn os_name(self: &SettingsController) -> QString;

        /// Read VERSION_ID from /etc/os-release, falling back to "1.0".
        #[qinvokable]
        fn os_version(self: &SettingsController) -> QString;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;

#[derive(Default)]
pub struct SettingsControllerRust;

impl qobject::SettingsController {
    pub fn request_quit(self: Pin<&mut Self>) {
        std::process::exit(0);
    }

    pub fn os_name(&self) -> QString {
        read_os_release_field(&["PRETTY_NAME", "NAME"], "VamoraOS")
    }

    pub fn os_version(&self) -> QString {
        read_os_release_field(&["VERSION_ID", "VERSION"], "1.0")
    }
}

fn read_os_release_field(fields: &[&str], fallback: &str) -> QString {
    let content = std::fs::read_to_string("/etc/os-release")
        .or_else(|_| std::fs::read_to_string("/usr/lib/os-release"))
        .unwrap_or_default();

    for field in fields {
        for line in content.lines() {
            if let Some(val) = line.strip_prefix(&format!("{}=", field)) {
                let clean = val.trim_matches('"').trim_matches('\'').trim();
                if !clean.is_empty() {
                    return QString::from(clean);
                }
            }
        }
    }
    QString::from(fallback)
}
