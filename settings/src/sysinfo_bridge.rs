/// System information and appearance settings exposed to QML.
///
/// Read at runtime from /etc/VamoraSys/vamora-release (newer VamoraSys
/// builds) or /etc/VamoraSys/vamora-release.vmf (older builds). Nothing is
/// embedded into the binary at compile time — if neither file is present,
/// each field just falls back to a hardcoded default value in code.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[namespace = "dev_vamoraos_sysinfo"]
        #[qproperty(QString, vmf_version)]
        #[qproperty(QString, name)]
        #[qproperty(QString, os_id)]
        #[qproperty(QString, id_like)]
        #[qproperty(QString, pretty_name)]
        #[qproperty(QString, version_id)]
        #[qproperty(QString, version)]
        #[qproperty(QString, codename)]
        #[qproperty(QString, arch)]
        #[qproperty(QString, kernel)]
        #[qproperty(QString, build_id)]
        #[qproperty(QString, channel)]
        #[qproperty(QString, device)]
        #[qproperty(QString, logo)]
        #[qproperty(QString, vamorasys_version)]
        #[qproperty(QString, environment)]
        #[qproperty(QString, home_url)]
        #[qproperty(QString, docs_url)]
        #[qproperty(QString, bug_url)]
        #[qproperty(QString, source_url)]
        type SysInfo = super::SysInfoRust;

        /// Collects the same core hardware modules used by Vaminfo.
        #[cxx_name = "getHardwareInfo"]
        #[qinvokable]
        fn get_hardware_info(self: &SysInfo) -> QString;

        /// Refreshes the live RAM and battery readings used by Hardware Info.
        #[cxx_name = "getHardwareUsage"]
        #[qinvokable]
        fn get_hardware_usage(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings get appearance.theme
        #[cxx_name = "getAppearanceTheme"]
        #[qinvokable]
        fn get_appearance_theme(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set appearance.theme <light|dark>
        /// Returns the selected theme on success, or an error message.
        #[cxx_name = "setAppearanceTheme"]
        #[qinvokable]
        fn set_appearance_theme(self: Pin<&mut SysInfo>, theme: QString) -> QString;

        /// Runs: vamorasys settings get appearance.accent_color
        #[cxx_name = "getAccentColor"]
        #[qinvokable]
        fn get_accent_color(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set appearance.accent_color '<#rrggbb>'
        /// Returns the selected color on success, or an error message.
        #[cxx_name = "setAccentColor"]
        #[qinvokable]
        fn set_accent_color(self: &SysInfo, color: QString) -> QString;

        /// Runs: vamorasys settings get homescreen.grid
        #[cxx_name = "getHomescreenGrid"]
        #[qinvokable]
        fn get_homescreen_grid(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set homescreen.grid <value>
        #[cxx_name = "setHomescreenGrid"]
        #[qinvokable]
        fn set_homescreen_grid(self: &SysInfo, grid: QString) -> QString;

        /// Runs: vamorasys settings get homescreen.icon_size
        #[cxx_name = "getHomescreenIconSize"]
        #[qinvokable]
        fn get_homescreen_icon_size(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set homescreen.icon_size <value>
        #[cxx_name = "setHomescreenIconSize"]
        #[qinvokable]
        fn set_homescreen_icon_size(self: &SysInfo, size: QString) -> QString;

        /// Runs: vamorasys settings get <key>
        /// Generic getter for any VamoraSys setting not covered by one of
        /// the dedicated methods above (e.g. "icons.corner_radius",
        /// "wm.animations", "keyboard.layout"). Returns the raw value on
        /// success, or an "error: ..." message on failure.
        #[cxx_name = "getSetting"]
        #[qinvokable]
        fn get_setting(self: &SysInfo, key: QString) -> QString;

        /// Runs: vamorasys settings set <key> <value>
        /// Generic setter matching getSetting. Returns the value that was
        /// set on success, or an "error: ..." message on failure.
        #[cxx_name = "setSetting"]
        #[qinvokable]
        fn set_setting(self: &SysInfo, key: QString, value: QString) -> QString;

        /// Returns whether the VamoraSys command backend is available.
        #[cxx_name = "isVamoraSysInstalled"]
        #[qinvokable]
        fn is_vamora_sys_installed(self: &SysInfo) -> bool;

        /// Returns whether apt is available on a Debian-family OS.
        #[cxx_name = "isDebianBased"]
        #[qinvokable]
        fn is_debian_based(self: &SysInfo) -> bool;

        /// Installs the Qt 6 WebView QML module without putting the password
        /// in command-line arguments or persisting it anywhere.
        #[cxx_name = "installQtWebView"]
        #[qinvokable]
        fn install_qt_webview(self: &SysInfo, password: QString) -> QString;
    }
}

use core::pin::Pin;
use cxx_qt_lib::QString;
use std::io::Write;
use std::process::{Command, Stdio};

pub struct SysInfoRust {
    pub vmf_version: QString,
    pub name: QString,
    pub os_id: QString,
    pub id_like: QString,
    pub pretty_name: QString,
    pub version_id: QString,
    pub version: QString,
    pub codename: QString,
    pub arch: QString,
    pub kernel: QString,
    pub build_id: QString,
    pub channel: QString,
    pub device: QString,
    pub logo: QString,
    pub home_url: QString,
    pub docs_url: QString,
    pub bug_url: QString,
    pub source_url: QString,
    pub vamorasys_version: QString,
    pub environment: QString,
}

impl Default for SysInfoRust {
    fn default() -> Self {
        let info = OsInfo::read();
        Self {
            vmf_version: qs(&info.vmf_version),
            name: qs(&info.name),
            os_id: qs(&info.os_id),
            id_like: qs(&info.id_like),
            pretty_name: qs(&info.pretty_name),
            version_id: qs(&info.version_id),
            version: qs(&info.version),
            codename: qs(&info.codename),
            arch: qs(&info.arch),
            kernel: qs(&info.kernel),
            build_id: qs(&info.build_id),
            channel: qs(&info.channel),
            device: qs(&info.device),
            logo: qs(&info.logo),
            home_url: qs(&info.home_url),
            docs_url: qs(&info.docs_url),
            bug_url: qs(&info.bug_url),
            source_url: qs(&info.source_url),
            vamorasys_version: qs(&info.vamorasys_version),
            environment: qs(&info.environment),
        }
    }
}

impl qobject::SysInfo {
    pub fn get_appearance_theme(&self) -> QString {
        let output = std::process::Command::new("vamorasys")
            .args(["settings", "get", "appearance.theme"])
            .output();

        match output {
            Ok(result) if result.status.success() => {
                let value = String::from_utf8_lossy(&result.stdout)
                    .trim()
                    .to_lowercase();
                if value == "dark" || value == "light" {
                    return qs(&value);
                }
                qs("error: vamorasys returned an invalid appearance.theme value")
            }
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys settings get failed")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn get_accent_color(&self) -> QString {
        let output = std::process::Command::new("vamorasys")
            .args(["settings", "get", "appearance.accent_color"])
            .output();

        match output {
            Ok(result) if result.status.success() => {
                let value = String::from_utf8_lossy(&result.stdout).trim().to_string();
                if is_hex_color(&value) {
                    qs(&value)
                } else {
                    qs("error: vamorasys returned an invalid appearance.accent_color value")
                }
            }
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys settings get failed")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn set_accent_color(&self, color: QString) -> QString {
        let selected = color.to_string().trim().to_lowercase();
        if !is_hex_color(&selected) {
            return qs("error: color must be a hex value like #2563eb");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "set", "appearance.accent_color", &selected])
            .output()
        {
            Ok(result) if result.status.success() => qs(&selected),
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys could not set the accent color")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn get_hardware_info(&self) -> QString {
        let hardware = [
            ("BIOS", collect_bios()),
            ("CPU", collect_cpu()),
            ("GPU", collect_gpu()),
            ("RAM", collect_ram()),
            ("Disk", collect_disk()),
            ("Battery", collect_battery()),
        ];

        qs(&hardware_json(&hardware))
    }

    pub fn get_hardware_usage(&self) -> QString {
        let hardware = [
            ("RAM", collect_ram()),
            ("Battery", collect_battery()),
        ];

        qs(&hardware_json(&hardware))
    }

    pub fn set_appearance_theme(mut self: Pin<&mut Self>, theme: QString) -> QString {
        let selected = theme.to_string().trim().to_lowercase();
        if selected != "dark" && selected != "light" {
            return qs("error: theme must be light or dark");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "set", "appearance.theme", &selected])
            .output()
        {
            Ok(result) if result.status.success() => qs(&selected),
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys could not set the theme")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn get_homescreen_grid(&self) -> QString {
        match std::process::Command::new("vamorasys")
            .args(["settings", "get", "homescreen.grid"])
            .output()
        {
            Ok(result) if result.status.success() => {
                let value = String::from_utf8_lossy(&result.stdout).trim().to_string();
                if value.is_empty() {
                    qs("error: vamorasys returned an empty homescreen.grid value")
                } else {
                    qs(&value)
                }
            }
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys settings get failed")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn set_homescreen_grid(&self, grid: QString) -> QString {
        let selected = grid.to_string().trim().to_string();
        if selected.is_empty() {
            return qs("error: grid size cannot be empty");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "set", "homescreen.grid", &selected])
            .output()
        {
            Ok(result) if result.status.success() => qs(&selected),
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys could not set the grid size")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn get_homescreen_icon_size(&self) -> QString {
        match std::process::Command::new("vamorasys")
            .args(["settings", "get", "homescreen.icon_size"])
            .output()
        {
            Ok(result) if result.status.success() => {
                let value = String::from_utf8_lossy(&result.stdout).trim().to_string();
                if value.is_empty() {
                    qs("error: vamorasys returned an empty homescreen.icon_size value")
                } else {
                    qs(&value)
                }
            }
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys settings get failed")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn set_homescreen_icon_size(&self, size: QString) -> QString {
        let selected = size.to_string().trim().to_string();
        if selected.is_empty() {
            return qs("error: icon size cannot be empty");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "set", "homescreen.icon_size", &selected])
            .output()
        {
            Ok(result) if result.status.success() => qs(&selected),
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys could not set the icon size")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    /// Runs: vamorasys settings get <key>
    pub fn get_setting(&self, key: QString) -> QString {
        let key = key.to_string();
        if key.trim().is_empty() {
            return qs("error: setting key cannot be empty");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "get", &key])
            .output()
        {
            Ok(result) if result.status.success() => {
                let value = String::from_utf8_lossy(&result.stdout).trim().to_string();
                qs(&value)
            }
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys settings get failed")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    /// Runs: vamorasys settings set <key> <value>
    pub fn set_setting(&self, key: QString, value: QString) -> QString {
        let key = key.to_string();
        let selected = value.to_string();
        if key.trim().is_empty() {
            return qs("error: setting key cannot be empty");
        }

        match std::process::Command::new("vamorasys")
            .args(["settings", "set", &key, &selected])
            .output()
        {
            Ok(result) if result.status.success() => qs(&selected),
            Ok(result) => {
                let detail = String::from_utf8_lossy(&result.stderr).trim().to_string();
                if detail.is_empty() {
                    qs("error: vamorasys could not set that value")
                } else {
                    qs(&format!("error: {detail}"))
                }
            }
            Err(error) => qs(&format!("error: {error}")),
        }
    }

    pub fn is_vamora_sys_installed(&self) -> bool {
        std::process::Command::new("vamorasys")
            .arg("--help")
            .output()
            .is_ok()
    }

    pub fn is_debian_based(&self) -> bool {
        if !Command::new("apt-get").arg("--version").output().is_ok() {
            return false;
        }

        let release = std::fs::read_to_string("/etc/os-release")
            .or_else(|_| std::fs::read_to_string("/usr/lib/os-release"))
            .unwrap_or_default();
        let values = parse_kv_file(&release);
        let id_like = values.get("ID_LIKE").cloned().unwrap_or_default();
        let id = values.get("ID").cloned().unwrap_or_default();

        id == "debian"
            || id == "ubuntu"
            || id == "linuxmint"
            || id_like.split_whitespace().any(|value| value == "debian" || value == "ubuntu")
    }

    pub fn install_qt_webview(&self, password: QString) -> QString {
        if !self.is_debian_based() {
            return qs("This build is not Debian-based. Install qml6-module-qtwebview manually.");
        }

        let password = password.to_string();
        if password.trim().is_empty() {
            return qs("Enter your administrator password to continue.");
        }

        let child = Command::new("sudo")
            .args(["-S", "-p", "", "apt-get", "install", "-y", "qml6-module-qtwebview"])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn();

        let mut child = match child {
            Ok(child) => child,
            Err(error) => return qs(&format!("Could not start sudo: {error}")),
        };

        if let Some(stdin) = child.stdin.as_mut() {
            if stdin.write_all(password.as_bytes()).is_err() || stdin.write_all(b"\n").is_err() {
                return qs("Could not send the administrator password to sudo.");
            }
        }

        match child.wait_with_output() {
            Ok(output) if output.status.success() => qs("installed"),
            Ok(_) => qs("Installation failed. Check your password and apt package sources."),
            Err(error) => qs(&format!("Installation could not be completed: {error}")),
        }
    }
}

/// Accepts #rgb or #rrggbb (case-insensitive), which covers the swatch
/// values used by the accent color picker as well as anything typed
/// directly via `vamorasys settings set`.
fn is_hex_color(value: &str) -> bool {
    let hex = match value.strip_prefix('#') {
        Some(rest) => rest,
        None => return false,
    };
    (hex.len() == 3 || hex.len() == 6) && hex.chars().all(|c| c.is_ascii_hexdigit())
}

fn qs(value: &str) -> QString {
    QString::from(value)
}

// These collectors intentionally follow Vaminfo's hardware modules rather
// than inventing a second set of hardware-detection rules for Settings.
fn collect_bios() -> Option<String> {
    let base = "/sys/class/dmi/id";
    let vendor = std::fs::read_to_string(format!("{base}/bios_vendor"))
        .ok()?
        .trim()
        .to_string();
    let version = std::fs::read_to_string(format!("{base}/bios_version"))
        .unwrap_or_default()
        .trim()
        .to_string();
    let date = std::fs::read_to_string(format!("{base}/bios_date"))
        .unwrap_or_default()
        .trim()
        .to_string();

    if vendor.is_empty() {
        return None;
    }

    let mut parts = vec![vendor];
    if !version.is_empty() {
        parts.push(version);
    }
    if !date.is_empty() {
        parts.push(date);
    }
    Some(parts.join("  "))
}

fn collect_cpu() -> Option<String> {
    use sysinfo::{CpuRefreshKind, RefreshKind, System};

    let mut system = System::new_with_specifics(
        RefreshKind::new().with_cpu(CpuRefreshKind::everything()),
    );
    std::thread::sleep(sysinfo::MINIMUM_CPU_UPDATE_INTERVAL);
    system.refresh_cpu_usage();

    let cpus = system.cpus();
    if cpus.is_empty() {
        return None;
    }

    let brand = cpus[0].brand().trim().to_string();
    let cores = cpus.len();
    let usage: f32 = cpus.iter().map(|cpu| cpu.cpu_usage()).sum::<f32>() / cores as f32;
    let frequency = cpus[0].frequency();

    Some(format!(
        "{} ({} cores) @ {:.0} MHz  [{:.1}% load]",
        brand, cores, frequency, usage
    ))
}

fn collect_gpu() -> Option<String> {
    #[cfg(target_os = "linux")]
    {
        if let Ok(entries) = std::fs::read_dir("/sys/class/drm") {
            for entry in entries.flatten() {
                let path = entry.path().join("device/product_name");
                if let Ok(name) = std::fs::read_to_string(&path) {
                    let name = name.trim().to_string();
                    if !name.is_empty() {
                        return Some(name);
                    }
                }

                let vendor_path = entry.path().join("device/vendor");
                let device_path = entry.path().join("device/device");
                if let (Ok(vendor), Ok(device)) = (
                    std::fs::read_to_string(&vendor_path),
                    std::fs::read_to_string(&device_path),
                ) {
                    let vendor = vendor.trim();
                    let device = device.trim();
                    if !vendor.is_empty() && !device.is_empty() {
                        return Some(format!("GPU [{vendor} {device}]"));
                    }
                }
            }
        }
    }

    None
}

fn collect_ram() -> Option<String> {
    use sysinfo::{MemoryRefreshKind, RefreshKind, System};

    let mut system = System::new_with_specifics(
        RefreshKind::new().with_memory(MemoryRefreshKind::everything()),
    );
    system.refresh_memory();

    let total = system.total_memory();
    let used = system.used_memory();
    let percent = if total > 0 {
        used as f64 / total as f64 * 100.0
    } else {
        0.0
    };

    Some(format!(
        "{} / {} ({:.1}%)",
        format_bytes_binary(used, 2),
        format_bytes_binary(total, 2),
        percent
    ))
}

fn collect_disk() -> Option<String> {
    use sysinfo::Disks;

    let disks = Disks::new_with_refreshed_list();
    let mut parts = Vec::new();

    for disk in disks.list() {
        let mount = disk.mount_point().to_string_lossy();
        if mount != "/" && !mount.starts_with("/home") {
            continue;
        }

        let total = disk.total_space();
        let free = disk.available_space();
        let used = total.saturating_sub(free);
        let percent = if total > 0 {
            used as f64 / total as f64 * 100.0
        } else {
            0.0
        };

        parts.push(format!(
            "{}: {} / {} ({:.1}%)",
            mount,
            format_bytes_binary(used, 1),
            format_bytes_binary(total, 1),
            percent
        ));
    }

    if parts.is_empty() {
        None
    } else {
        Some(parts.join("  |  "))
    }
}

fn collect_battery() -> Option<String> {
    #[cfg(target_os = "linux")]
    {
        for battery in ["/sys/class/power_supply/BAT0", "/sys/class/power_supply/BAT1"] {
            let capacity_path = format!("{battery}/capacity");
            let status_path = format!("{battery}/status");
            if let Ok(capacity) = std::fs::read_to_string(&capacity_path) {
                let capacity = capacity.trim();
                let status = std::fs::read_to_string(&status_path)
                    .unwrap_or_default()
                    .trim()
                    .to_string();
                return Some(format!("{capacity}%  [{status}]"));
            }
        }
    }

    None
}

fn format_bytes_binary(bytes: u64, decimals: usize) -> String {
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;

    if bytes >= GIB {
        let value = bytes as f64 / GIB as f64;
        if decimals == 2 {
            format!("{value:.2} GiB")
        } else {
            format!("{value:.1} GiB")
        }
    } else {
        format!("{:.0} MiB", bytes as f64 / MIB as f64)
    }
}

fn json_quote(value: &str) -> String {
    let mut quoted = String::with_capacity(value.len() + 2);
    quoted.push('"');
    for character in value.chars() {
        match character {
            '"' => quoted.push_str("\\\""),
            '\\' => quoted.push_str("\\\\"),
            '\n' => quoted.push_str("\\n"),
            '\r' => quoted.push_str("\\r"),
            '\t' => quoted.push_str("\\t"),
            character if character.is_control() => {
                quoted.push_str(&format!("\\u{:04x}", character as u32))
            }
            character => quoted.push(character),
        }
    }
    quoted.push('"');
    quoted
}

fn hardware_json(hardware: &[(&str, Option<String>)]) -> String {
    let entries = hardware
        .iter()
        .map(|(label, value)| {
            format!(
                "{{\"label\":{},\"value\":{}}}",
                json_quote(label),
                json_quote(value.as_deref().unwrap_or(""))
            )
        })
        .collect::<Vec<_>>()
        .join(",");

    format!("[{entries}]")
}

struct OsInfo {
    vmf_version: String,
    name: String,
    os_id: String,
    id_like: String,
    pretty_name: String,
    version_id: String,
    version: String,
    codename: String,
    arch: String,
    kernel: String,
    build_id: String,
    channel: String,
    device: String,
    logo: String,
    home_url: String,
    docs_url: String,
    bug_url: String,
    source_url: String,
    vamorasys_version: String,
    environment: String,
}

impl OsInfo {
    fn read() -> Self {
        // Newer VamoraSys builds drop the .vmf extension; older ones keep it.
        // Try both at runtime. If neither exists (e.g. running this UI on a
        // machine without VamoraSys installed), `vmf` is just empty and every
        // field below falls back to the hardcoded defaults in `get(...)` —
        // nothing here is ever baked into the binary at compile time.
        let vmf = read_kv_file("/etc/VamoraSys/vamora-release")
            .or_else(|| read_kv_file("/etc/VamoraSys/vamora-release.vmf"))
            .unwrap_or_default();

        let release = read_kv_file("/etc/os-release")
            .or_else(|| read_kv_file("/usr/lib/os-release"))
            .unwrap_or_default();

        let get = |keys: &[&str], fallback: &str| -> String {
            keys.iter()
                .find_map(|key| vmf.get(*key).or_else(|| release.get(*key)))
                .cloned()
                .unwrap_or_else(|| fallback.to_string())
        };

        let arch = get(
            &["ARCHITECTURE", "ARCH", "UNAME_M"],
            &uname("-m", std::env::consts::ARCH),
        );
        let kernel_fallback = {
            let value = uname("-r", "Linux");
            if value == "Linux" {
                value
            } else {
                format!("Linux {value}")
            }
        };
        let kernel = get(&["KERNEL"], &kernel_fallback);

        Self {
            vmf_version: get(&["VMF_VERSION"], ""),
            name: get(&["NAME"], "VamoraOS"),
            os_id: get(&["ID"], "vamora"),
            id_like: get(&["ID_LIKE"], "linux"),
            pretty_name: get(&["PRETTY_NAME", "NAME"], "VamoraOS"),
            version_id: get(&["VERSION_ID"], "1.0"),
            version: get(&["VERSION", "PRETTY_NAME"], "VamoraOS"),
            codename: get(&["VERSION_CODENAME"], ""),
            arch,
            kernel,
            build_id: get(&["BUILD_ID"], ""),
            channel: get(&["CHANNEL"], ""),
            device: get(&["DEVICE"], "Unknown Device"),
            logo: get(&["LOGO"], ""),
            home_url: get(&["HOME_URL"], "https://vamora.vercel.app"),
            docs_url: get(&["DOCUMENTATION_URL"], "https://vamora.vercel.app/docs"),
            bug_url: get(
                &["BUG_REPORT_URL", "SUPPORT_URL"],
                "https://github.com/TheVamoraProject/VamoraOS/issues",
            ),
            source_url: get(
                &["SOURCE_URL", "VCS_URL"],
                "https://github.com/TheVamoraProject/VamoraOS",
            ),
            vamorasys_version: get(&["VAMORASYS_VERSION"], ""),
            environment: detect_environment(),
        }
    }
}

/// Detects the running desktop environment (e.g. "GNOME", "KDE") from the
/// standard session env vars. Falls back to "Althyn" (VamoraOS's own shell)
/// when nothing recognizable is set, rather than showing a blank/unknown value.
fn detect_environment() -> String {
    let candidates = ["XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION"];
    for key in candidates {
        if let Ok(value) = std::env::var(key) {
            let value = value.trim();
            if !value.is_empty() {
                // XDG_CURRENT_DESKTOP can be a colon-separated list (e.g. "ubuntu:GNOME");
                // the first entry is the one that matters for display.
                return value
                    .split(':')
                    .next()
                    .unwrap_or(value)
                    .to_string();
            }
        }
    }
    "Althyn".to_string()
}

fn uname(argument: &str, fallback: &str) -> String {
    std::process::Command::new("uname")
        .arg(argument)
        .output()
        .ok()
        .and_then(|output| String::from_utf8(output.stdout).ok())
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| fallback.to_string())
}

fn read_kv_file(path: &str) -> Option<std::collections::HashMap<String, String>> {
    let content = std::fs::read_to_string(path).ok()?;
    Some(parse_kv_file(&content))
}

fn parse_kv_file(content: &str) -> std::collections::HashMap<String, String> {
    let mut values = std::collections::HashMap::new();
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            values.insert(
                key.trim().to_string(),
                value
                    .trim()
                    .trim_matches('"')
                    .trim_matches('\'')
                    .to_string(),
            );
        }
    }
    values
}
