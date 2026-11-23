//! Battery state from /sys/class/power_supply.

use std::path::PathBuf;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Battery {
    pub present: bool,
    pub percent: i32,
    pub charging: bool,
}

fn root() -> PathBuf {
    // Overridable so the bar can be tried without real hardware.
    std::env::var_os("VAMORA_POWER_SUPPLY_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/sys/class/power_supply"))
}

pub fn parse_status(status: &str) -> bool {
    matches!(status.trim(), "Charging" | "Full")
}

pub fn read() -> Battery {
    let none = Battery { present: false, percent: 0, charging: false };
    let Ok(dir) = std::fs::read_dir(root()) else { return none };
    let mut names: Vec<_> = dir.flatten().map(|e| e.path()).collect();
    names.sort();
    for p in names {
        let get = |f: &str| std::fs::read_to_string(p.join(f)).unwrap_or_default();
        if get("type").trim() != "Battery" || get("scope").trim() == "Device" {
            continue; // not the system battery (e.g. a wireless mouse)
        }
        let Ok(pct) = get("capacity").trim().parse::<i32>() else { continue };
        return Battery {
            present: true,
            percent: pct.clamp(0, 100),
            charging: parse_status(&get("status")),
        };
    }
    none
}

/// `statusbar.battery_type` from VamoraSys (1 when unset or unreadable).
/// Which numbers are real styles is the status bar's call, so future-proofing
/// lives in `effective_type`.
pub fn battery_type() -> i32 {
    std::process::Command::new("vamorasys")
        .args(["settings", "get", "statusbar.battery_type"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .and_then(|o| String::from_utf8_lossy(&o.stdout).trim().parse().ok())
        .unwrap_or(1)
}

/// Styles this status bar can draw: 1 = % beside, 2 = % inside, 3 = no %.
pub const SUPPORTED_TYPES: i32 = 3;

pub fn effective_type(requested: i32) -> i32 {
    if (1..=SUPPORTED_TYPES).contains(&requested) { requested } else { 1 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_types_fall_back_to_one() {
        assert_eq!(effective_type(2), 2);
        assert_eq!(effective_type(3), 3);
        assert_eq!(effective_type(4), 1);
        assert_eq!(effective_type(99), 1);
        assert_eq!(effective_type(0), 1);
        assert_eq!(effective_type(-5), 1);
    }

    #[test]
    fn status() {
        assert!(parse_status("Charging\n"));
        assert!(parse_status("Full\n"));
        assert!(!parse_status("Discharging\n"));
    }

    #[test]
    fn reads_fake_supply() {
        let d = std::env::temp_dir().join(format!("ps-{}", std::process::id()));
        let bat = d.join("BAT0");
        let mouse = d.join("hidpp");
        std::fs::create_dir_all(&bat).unwrap();
        std::fs::create_dir_all(&mouse).unwrap();
        for (k, v) in [("type", "Battery"), ("capacity", "74"), ("status", "Discharging")] {
            std::fs::write(bat.join(k), v).unwrap();
        }
        for (k, v) in [("type", "Battery"), ("capacity", "5"), ("scope", "Device")] {
            std::fs::write(mouse.join(k), v).unwrap();
        }
        // SAFETY: only this test touches the variable.
        unsafe { std::env::set_var("VAMORA_POWER_SUPPLY_DIR", &d) };
        assert_eq!(read(), Battery { present: true, percent: 74, charging: false });
        std::fs::remove_dir_all(&d).ok();
    }
}
