#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type DeviceInfo = super::DeviceInfoRust;

        /// `vamorasys device get form_factor` (phone, flip-phone, foldable-phone,
        /// tablet, foldable-tablet, laptop, foldable-laptop, cyberdeck, desktop,
        /// tv, watch). Falls back to "desktop" when VamoraSys is missing/fails.
        ///
        /// Like ThemeManager this is a #[qinvokable] returning a value rather than
        /// a #[qproperty]: reading qproperties back from QML is unreliable here.
        #[qinvokable]
        #[cxx_name = "formFactor"]
        fn form_factor(self: Pin<&mut DeviceInfo>) -> QString;

        /// True for the phone and tablet families (incl. foldables / flip phones).
        #[qinvokable]
        #[cxx_name = "isPhoneOrTablet"]
        fn is_phone_or_tablet(self: Pin<&mut DeviceInfo>) -> bool;

        /// Extra left/right content padding (dp) for screens with rounded corners
        /// (Android calls it rounded_corner_content_padding). VamoraSys setting
        /// `statusbar.corner_padding` when > 0, otherwise automatic: 16 on the
        /// phone/tablet families, 0 elsewhere. The caller still keeps its own
        /// minimum margin (max of the two), so desktops are unchanged.
        #[qinvokable]
        #[cxx_name = "cornerPadding"]
        fn corner_padding(self: Pin<&mut DeviceInfo>) -> i32;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;
use std::process::Command;

#[derive(Default)]
pub struct DeviceInfoRust;

impl qobject::DeviceInfo {
    pub fn form_factor(self: Pin<&mut Self>) -> QString {
        QString::from(read_form_factor().as_str())
    }

    pub fn is_phone_or_tablet(self: Pin<&mut Self>) -> bool {
        matches!(
            read_form_factor().as_str(),
            "phone" | "flip-phone" | "foldable-phone" | "tablet" | "foldable-tablet"
        )
    }
}

impl qobject::DeviceInfo {
    pub fn corner_padding(self: Pin<&mut Self>) -> i32 {
        let configured = Command::new("sh")
            .arg("-lc")
            .arg("vamorasys settings get statusbar.corner_padding")
            .output()
            .ok()
            .filter(|o| o.status.success())
            .and_then(|o| {
                String::from_utf8_lossy(&o.stdout)
                    .lines()
                    .map(|l| l.trim().to_string())
                    .filter(|l| !l.is_empty())
                    .last()
            })
            .and_then(|l| l.parse::<i32>().ok())
            .unwrap_or(0);
        if configured > 0 {
            return configured.min(64);
        }
        match read_form_factor().as_str() {
            "phone" | "flip-phone" | "foldable-phone" | "tablet" | "foldable-tablet" => 16,
            _ => 0,
        }
    }
}

/// Asks VamoraSys (never reads /etc/VamoraSys/device.vmf directly — apps are
/// supposed to go through VamoraSys). Never run via sudo.
fn read_form_factor() -> String {
    let out = Command::new("sh")
        .arg("-lc")
        .arg("vamorasys device get form_factor")
        .output();
    match out {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout)
            .lines()
            .map(|l| l.trim().to_lowercase())
            .filter(|l| !l.is_empty())
            .last()
            .unwrap_or_else(|| "desktop".to_string()),
        _ => "desktop".to_string(),
    }
}
