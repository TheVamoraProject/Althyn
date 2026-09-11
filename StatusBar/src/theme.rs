#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type ThemeManager = super::ThemeManagerRust;

        /// Re-reads appearance.theme from vamorasys and returns whether
        /// dark mode is currently active.
        ///
        /// Not exposed as a #[qproperty] — see the git history / prior
        /// notes if curious, but reading a qproperty back from QML
        /// wasn't working in this project, while #[qinvokable] calls
        /// returning a value work reliably. Every window's ThemeManager
        /// instance shares the same underlying poll state (see the
        /// module-level statics below), so "theme changed" is only ever
        /// logged once total, not once per window.
        #[qinvokable]
        fn refresh(self: Pin<&mut ThemeManager>) -> bool;
    }
}

use core::pin::Pin;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

#[derive(Default)]
pub struct ThemeManagerRust;

// Shared across every window's ThemeManager instance (they all live in the
// same process). `LAST_DARK` is the last known-good value, used both to
// only log on an actual change and as the answer while `vamorasys` is
// known to be missing. `VAMORASYS_MISSING` is a one-way latch: once we've
// confirmed the binary genuinely isn't on PATH, we stop spawning a shell
// for it every 5 seconds and just keep returning the last value until the
// app is restarted.
static LAST_DARK: AtomicBool = AtomicBool::new(true);
static VAMORASYS_MISSING: AtomicBool = AtomicBool::new(false);

impl qobject::ThemeManager {
    pub fn refresh(self: Pin<&mut Self>) -> bool {
        if VAMORASYS_MISSING.load(Ordering::Relaxed) {
            return LAST_DARK.load(Ordering::Relaxed);
        }

        match read_theme() {
            Some(dark) => {
                let previous = LAST_DARK.swap(dark, Ordering::Relaxed);
                if previous != dark {
                    eprintln!(
                        "[vamora-statusbar] theme changed -> {}",
                        if dark { "dark" } else { "light" }
                    );
                }
                dark
            }
            None => {
                VAMORASYS_MISSING.store(true, Ordering::Relaxed);
                eprintln!(
                    "[vamora-statusbar] vamorasys not found on PATH — keeping current theme until restart"
                );
                LAST_DARK.load(Ordering::Relaxed)
            }
        }
    }
}

/// Reads the logged-in user's theme preference exactly the way a normal
/// (non-root) shell session would (never with sudo — that reports the
/// system default, not this user's override).
///
/// Returns `None` specifically when `vamorasys` isn't installed / isn't on
/// PATH, so the caller can stop polling for the rest of this session.
/// Any other failure (bad config, transient error, etc.) falls back to the
/// last known value instead of giving up permanently.
fn read_theme() -> Option<bool> {
    let result = Command::new("sh")
        .arg("-lc")
        .arg("vamorasys settings get appearance.theme")
        .output();

    match result {
        Ok(output) if output.status.success() => {
            let theme = String::from_utf8_lossy(&output.stdout)
                .trim()
                .to_lowercase();
            Some(theme == "dark")
        }
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr).to_lowercase();
            // Exit code 127 from `sh -c` means "command not found"; some
            // shells also just say so in stderr.
            if output.status.code() == Some(127)
                || stderr.contains("not found")
                || stderr.contains("no such file or directory")
            {
                None
            } else {
                Some(LAST_DARK.load(Ordering::Relaxed))
            }
        }
        // Couldn't even launch a shell — treat the same as "not installed".
        Err(_) => None,
    }
}
