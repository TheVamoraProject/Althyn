#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type ThemeManager = super::ThemeManagerRust;

        /// Reads vamorasys once when the overlay starts. There is
        /// intentionally no polling timer.
        #[qinvokable]
        fn refresh(self: Pin<&mut ThemeManager>) -> bool;
    }
}

use core::pin::Pin;
use std::process::Command;

#[derive(Default)]
pub struct ThemeManagerRust;

impl qobject::ThemeManager {
    pub fn refresh(self: Pin<&mut Self>) -> bool {
        read_is_dark()
    }
}

/// Reads the current user's VamoraSys theme through a login shell, matching
/// the same source used by the Vamora installer. It is called exactly once
/// from QML at startup and intentionally defaults to dark.
fn read_is_dark() -> bool {
    match Command::new("sh")
        .arg("-lc")
        .arg("vamorasys settings get appearance.theme")
        .output()
    {
        Ok(output) if output.status.success() => String::from_utf8_lossy(&output.stdout)
            .trim()
            .eq_ignore_ascii_case("dark"),
        _ => true,
    }
}
