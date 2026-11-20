//! Compositor settings, read from VamoraSys.
//!
//! The compositor never parses VamoraSys' own storage. It does exactly what
//! every other Althyn component does: shell out to
//! `vamorasys settings get <key>` and treat stdout as the value. Keys and
//! value formats mirror what the Settings app (Vamify page) reads and writes:
//!
//! | key                  | values            | default |
//! |----------------------|-------------------|---------|
//! | `wm.focus_mode`      | `click` / `hover` | click   |
//! | `wm.animations`      | `true` / `false`  | true    |
//! | `wm.transparency`    | `true` / `false`  | false   |
//! | `wm.window_effects`  | `true` / `false`  | true    |
//! | `keyboard.layout`    | xkb layout        | us      |
//! | `keyboard.layouts`   | comma separated   | us      |
//! | `keyboard.model`     | xkb model         | pc105   |
//! | `keyboard.variant`   | xkb variant       | (empty) |
//! | `keyboard.options`   | xkb options       | (empty) |
//!
//! A missing `vamorasys`, a failing command or an unparsable value always
//! falls back to the default; the compositor must never fail to start because
//! of settings.
//!
//! VamoraSys has no change notification that the compositor knows about, so
//! a small watcher thread re-reads the keys every [`POLL_INTERVAL`] and only
//! notifies the compositor when something actually changed.

use std::{
    process::{Command, Stdio},
    sync::mpsc,
    thread,
    time::Duration,
};

use smithay::reexports::calloop::channel::Sender;
use tracing::{debug, info, warn};

pub const POLL_INTERVAL: Duration = Duration::from_secs(2);
/// How long startup waits for the first read before using defaults.
const INITIAL_READ_TIMEOUT: Duration = Duration::from_millis(1500);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FocusMode {
    /// Focus changes when a window is clicked.
    Click,
    /// Focus follows the pointer.
    Hover,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KeyboardConfig {
    /// Comma separated xkb layout list. The primary layout (`keyboard.layout`)
    /// is always first.
    pub layouts: String,
    pub model: String,
    pub variant: String,
    pub options: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Config {
    pub focus_mode: FocusMode,
    /// Stored for the render path; no animations exist in the base yet.
    pub animations: bool,
    /// Stored for the render path; no transparency effects in the base yet.
    pub transparency: bool,
    /// Stored for the render path; no window effects in the base yet.
    pub window_effects: bool,
    pub keyboard: KeyboardConfig,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            focus_mode: FocusMode::Click,
            animations: true,
            transparency: false,
            window_effects: true,
            keyboard: KeyboardConfig {
                layouts: "us".into(),
                model: "pc105".into(),
                variant: String::new(),
                options: String::new(),
            },
        }
    }
}

/// `vamorasys settings get <key>`; `None` on any failure or empty output.
fn get_setting(key: &str) -> Option<String> {
    let out = Command::new("vamorasys")
        .args(["settings", "get", key])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let value = String::from_utf8_lossy(&out.stdout).trim().to_string();
    // Settings treats a leading "error:" as a failed read; do the same.
    if value.is_empty() || value.starts_with("error:") {
        return None;
    }
    Some(value)
}

/// Same rule as Settings' `toBool`: exactly "true" / "false", else fallback.
fn parse_bool(value: Option<String>, fallback: bool) -> bool {
    match value.as_deref() {
        Some("true") => true,
        Some("false") => false,
        _ => fallback,
    }
}

impl Config {
    /// Reads every key once (blocking; spawns one process per key).
    pub fn load() -> Self {
        let d = Config::default();

        let focus_mode = match get_setting("wm.focus_mode").as_deref() {
            Some("click") => FocusMode::Click,
            Some("hover") => FocusMode::Hover,
            Some(other) => {
                warn!("ignoring unknown wm.focus_mode {other:?}");
                d.focus_mode
            }
            None => d.focus_mode,
        };

        // `keyboard.layout` is the primary layout, `keyboard.layouts` the full
        // list. Build one xkb list with the primary layout first.
        let primary = get_setting("keyboard.layout");
        let list = get_setting("keyboard.layouts");
        let mut layouts: Vec<String> = list
            .as_deref()
            .unwrap_or("")
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();
        if let Some(primary) = primary.filter(|p| !p.trim().is_empty()) {
            let primary = primary.trim().to_string();
            layouts.retain(|l| *l != primary);
            layouts.insert(0, primary);
        }
        let layouts = if layouts.is_empty() {
            d.keyboard.layouts.clone()
        } else {
            layouts.join(",")
        };

        Config {
            focus_mode,
            animations: parse_bool(get_setting("wm.animations"), d.animations),
            transparency: parse_bool(get_setting("wm.transparency"), d.transparency),
            window_effects: parse_bool(get_setting("wm.window_effects"), d.window_effects),
            keyboard: KeyboardConfig {
                layouts,
                model: get_setting("keyboard.model").unwrap_or(d.keyboard.model),
                variant: get_setting("keyboard.variant").unwrap_or(d.keyboard.variant),
                options: get_setting("keyboard.options").unwrap_or(d.keyboard.options),
            },
        }
    }

    /// Initial config for startup: never blocks longer than
    /// [`INITIAL_READ_TIMEOUT`].
    pub fn load_initial() -> Self {
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            let _ = tx.send(Config::load());
        });
        match rx.recv_timeout(INITIAL_READ_TIMEOUT) {
            Ok(config) => {
                info!(?config, "loaded VamoraSys settings");
                config
            }
            Err(_) => {
                warn!("reading VamoraSys settings timed out, using defaults");
                Config::default()
            }
        }
    }
}

/// Re-reads the settings in the background and sends the new [`Config`] to the
/// compositor whenever it differs from the previous one.
pub fn spawn_watcher(initial: Config, sender: Sender<Config>) {
    let spawned = thread::Builder::new()
        .name("vamorasys-watch".into())
        .spawn(move || {
            let mut last = initial;
            loop {
                thread::sleep(POLL_INTERVAL);
                let current = Config::load();
                if current != last {
                    debug!(?current, "VamoraSys settings changed");
                    if sender.send(current.clone()).is_err() {
                        return; // compositor is gone
                    }
                    last = current;
                }
            }
        });
    if let Err(err) = spawned {
        warn!("could not start settings watcher: {err}");
    }
}
