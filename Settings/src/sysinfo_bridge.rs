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
        #[qproperty(QString, ansi_color)]
        #[qproperty(QString, vamorasys_version)]
        #[qproperty(QString, environment)]
        #[qproperty(QString, home_url)]
        #[qproperty(QString, docs_url)]
        #[qproperty(QString, bug_url)]
        #[qproperty(QString, source_url)]
        type SysInfo = super::SysInfoRust;

        /// Runs: vamorasys settings get appearance.theme
        #[cxx_name = "getAppearanceTheme"]
        #[qinvokable]
        fn get_appearance_theme(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set appearance.theme <light|dark>
        /// Returns the selected theme on success, or an error message.
        #[cxx_name = "setAppearanceTheme"]
        #[qinvokable]
        fn set_appearance_theme(self: Pin<&mut SysInfo>, theme: QString) -> QString;

        /// Runs: vamorasys settings get homescreen.grid
        #[cxx_name = "getHomescreenGrid"]
        #[qinvokable]
        fn get_homescreen_grid(self: &SysInfo) -> QString;

        /// Runs: vamorasys settings set homescreen.grid <value>
        #[cxx_name = "setHomescreenGrid"]
        #[qinvokable]
        fn set_homescreen_grid(self: &SysInfo, grid: QString) -> QString;

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
    pub ansi_color: QString,
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
            ansi_color: qs(&info.ansi_color),
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

fn qs(value: &str) -> QString {
    QString::from(value)
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
    ansi_color: String,
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
            ansi_color: get(&["ANSI_COLOR"], ""),
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
