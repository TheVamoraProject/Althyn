//! Wi-Fi and Bluetooth state for the status bar.
//!
//! NetworkManager (`nmcli`) and BlueZ (`bluetoothctl`) are asked first; when
//! they are not installed the kernel's rfkill / sysfs / procfs files are used.

use std::process::Command;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct NetState {
    /// A Wi-Fi radio exists and is switched on (the icon is hidden otherwise).
    pub wifi_on: bool,
    /// 0 = not connected, 1–4 = signal bars.
    pub wifi_bars: i32,
    pub bluetooth_on: bool,
}

pub fn read() -> NetState {
    let (wifi_on, wifi_bars) = wifi();
    NetState { wifi_on, wifi_bars, bluetooth_on: bluetooth() }
}

fn run(cmd: &str, args: &[&str]) -> Option<String> {
    // `timeout` keeps a stuck daemon from freezing the bar's refresh.
    let out = Command::new("timeout").arg("1").arg(cmd).args(args).output().ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).into_owned())
}

pub fn bars_from_percent(p: i32) -> i32 {
    match p {
        p if p >= 75 => 4,
        p if p >= 50 => 3,
        p if p >= 25 => 2,
        p if p >= 1 => 1,
        _ => 0,
    }
}

/// `nmcli -t -f IN-USE,SIGNAL device wifi list` → percent of the active network.
pub fn parse_active_signal(list: &str) -> Option<i32> {
    list.lines()
        .find_map(|l| l.strip_prefix("*:"))
        .and_then(|s| s.trim().parse().ok())
}

/// `nmcli -t -f TYPE,STATE device` → (has a Wi-Fi device, it is associated).
pub fn parse_devices(list: &str) -> (bool, bool) {
    let mut has = false;
    let mut connected = false;
    for l in list.lines() {
        if let Some(state) = l.strip_prefix("wifi:") {
            has = true;
            if state.starts_with("connected") || state.starts_with("connecting") {
                connected = true;
            }
        }
    }
    (has, connected)
}

fn wifi() -> (bool, i32) {
    if let Some(radio) = run("nmcli", &["-t", "radio", "wifi"]) {
        if radio.trim() != "enabled" {
            return (false, 0);
        }
        let devices = run("nmcli", &["-t", "-f", "TYPE,STATE", "device"]).unwrap_or_default();
        let (has, connected) = parse_devices(&devices);
        if !has {
            return (false, 0);
        }
        if !connected {
            return (true, 0);
        }
        let list = run("nmcli", &["-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list"])
            .unwrap_or_default();
        return match parse_active_signal(&list) {
            Some(p) => (true, bars_from_percent(p).max(1)),
            None => (true, proc_wireless_bars().max(1)),
        };
    }
    // No NetworkManager: sysfs + rfkill.
    if !has_wireless_iface() || rfkill_blocked("wlan") {
        return (false, 0);
    }
    (true, proc_wireless_bars())
}

fn has_wireless_iface() -> bool {
    std::fs::read_dir("/sys/class/net")
        .map(|d| {
            d.flatten().any(|e| {
                let p = e.path();
                p.join("wireless").exists() || p.join("phy80211").exists()
            })
        })
        .unwrap_or(false)
}

/// True when every rfkill switch of this type is blocked (or none is unblocked).
fn rfkill_blocked(kind: &str) -> bool {
    let Ok(dir) = std::fs::read_dir("/sys/class/rfkill") else { return false };
    let mut seen = false;
    for e in dir.flatten() {
        let p = e.path();
        let t = std::fs::read_to_string(p.join("type")).unwrap_or_default();
        if t.trim() != kind {
            continue;
        }
        seen = true;
        let blocked = |f: &str| std::fs::read_to_string(p.join(f)).map(|s| s.trim() == "1").unwrap_or(false);
        if !blocked("soft") && !blocked("hard") {
            return false;
        }
    }
    seen
}

/// Link quality from /proc/net/wireless (0–70) as 0–4 bars; 0 if unconnected.
fn proc_wireless_bars() -> i32 {
    let content = std::fs::read_to_string("/proc/net/wireless").unwrap_or_default();
    for line in content.lines().skip(2) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 3 {
            if let Ok(q) = parts[2].trim_end_matches('.').parse::<f64>() {
                return bars_from_percent((q / 70.0 * 100.0) as i32);
            }
        }
    }
    0
}

pub fn parse_powered(show: &str) -> bool {
    show.lines().any(|l| l.trim() == "Powered: yes")
}

fn bluetooth() -> bool {
    if let Some(show) = run("bluetoothctl", &["show"]) {
        return parse_powered(&show);
    }
    let has_adapter = std::fs::read_dir("/sys/class/bluetooth")
        .map(|mut d| d.next().is_some())
        .unwrap_or(false);
    has_adapter && !rfkill_blocked("bluetooth")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bars() {
        assert_eq!(bars_from_percent(90), 4);
        assert_eq!(bars_from_percent(60), 3);
        assert_eq!(bars_from_percent(30), 2);
        assert_eq!(bars_from_percent(5), 1);
        assert_eq!(bars_from_percent(0), 0);
    }

    #[test]
    fn signal_of_active_network() {
        assert_eq!(parse_active_signal(" :88\n*:64\n :20\n"), Some(64));
        assert_eq!(parse_active_signal(" :88\n"), None);
    }

    #[test]
    fn devices() {
        assert_eq!(parse_devices("ethernet:connected\nwifi:connected\n"), (true, true));
        assert_eq!(parse_devices("wifi:disconnected\n"), (true, false));
        assert_eq!(parse_devices("ethernet:connected\n"), (false, false));
    }

    #[test]
    fn powered() {
        assert!(parse_powered("Controller AA\n\tPowered: yes\n"));
        assert!(!parse_powered("Controller AA\n\tPowered: no\n"));
    }
}
