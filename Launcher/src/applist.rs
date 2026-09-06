#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type AppList = super::AppListRust;

        /// Returns all visible desktop applications as JSON.
        #[qinvokable]
        #[cxx_name = "getAppsJson"]
        fn get_apps_json(self: &AppList) -> QString;

        /// Returns executable commands matching the current query as JSON.
        #[qinvokable]
        #[cxx_name = "getCommandJson"]
        fn get_command_json(self: &AppList, query: &QString) -> QString;

        /// Launches a desktop Exec string or terminal command. When
        /// `terminal` is true, the command is run inside a terminal
        /// emulator instead of being spawned directly.
        #[qinvokable]
        #[cxx_name = "launchApp"]
        fn launch_app(self: &AppList, exec: &QString, terminal: bool);

        /// Checks whether the first token in a command is executable.
        #[qinvokable]
        #[cxx_name = "commandExists"]
        fn command_exists(self: &AppList, command: &QString) -> bool;

        /// Reads the Vamora appearance once when the launcher starts.
        #[qinvokable]
        #[cxx_name = "getTheme"]
        fn get_theme(self: &AppList) -> QString;
    }
}

use cxx_qt_lib::QString;
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Default)]
pub struct AppListRust;

#[derive(Clone)]
struct App {
    name: String,
    icon_path: String,
    exec: String,
    terminal: bool,
}

#[derive(Clone)]
struct CommandResult {
    name: String,
    exec: String,
}

impl qobject::AppList {
    pub fn get_apps_json(&self) -> QString {
        let apps = scan_desktop_files();
        QString::from(apps_to_json(&apps).as_str())
    }

    pub fn get_command_json(&self, query: &QString) -> QString {
        let query = format!("{}", query).trim().to_string();
        if query.is_empty() {
            return QString::from("[]");
        }

        let commands = scan_commands(&query);
        QString::from(commands_to_json(&commands).as_str())
    }

    pub fn launch_app(&self, exec: &QString, terminal: bool) {
        let raw = format!("{}", exec);
        let args = split_command_line(&remove_field_codes(&raw));
        let Some(program) = args.first() else {
            return;
        };

        if terminal {
            if let Some(spawned) = launch_in_terminal(&args) {
                let _ = spawned;
                return;
            }
            // No terminal emulator could be found; fall back to a direct
            // launch below rather than silently doing nothing.
        }

        let _ = Command::new(program).args(args.iter().skip(1)).spawn();
    }

    pub fn command_exists(&self, command: &QString) -> bool {
        let raw = format!("{}", command);
        let args = split_command_line(&raw);
        args.first()
            .map(|program| is_executable(program))
            .unwrap_or(false)
    }

    pub fn get_theme(&self) -> QString {
        let theme = Command::new("vamorasys")
            .args(["settings", "get", "appearance.theme"])
            .output()
            .ok()
            .and_then(|output| String::from_utf8(output.stdout).ok())
            .map(|value| value.trim().to_lowercase())
            .filter(|value| value == "light" || value == "dark")
            .unwrap_or_else(|| "dark".to_string());

        QString::from(theme.as_str())
    }
}

fn scan_desktop_files() -> Vec<App> {
    let mut directories = Vec::new();
    let home = env::var("HOME").unwrap_or_default();

    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            directories.push(PathBuf::from(data_home).join("applications"));
        }
    } else if !home.is_empty() {
        directories.push(PathBuf::from(&home).join(".local/share/applications"));
    }

    directories.push(PathBuf::from("/usr/local/share/applications"));
    directories.push(PathBuf::from("/usr/share/applications"));

    if let Ok(data_dirs) = env::var("XDG_DATA_DIRS") {
        for directory in data_dirs.split(':').filter(|value| !value.is_empty()) {
            directories.push(PathBuf::from(directory).join("applications"));
        }
    }

    let mut seen = HashSet::new();
    let mut apps = Vec::new();

    for directory in directories {
        let Ok(entries) = fs::read_dir(directory) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|extension| extension.to_str()) != Some("desktop") {
                continue;
            }
            let key = path.to_string_lossy().to_string();
            if !seen.insert(key) {
                continue;
            }
            if let Some(app) = parse_desktop_file(&path) {
                apps.push(app);
            }
        }
    }

    apps.sort_by(|left, right| left.name.to_lowercase().cmp(&right.name.to_lowercase()));
    apps
}

fn parse_desktop_file(path: &Path) -> Option<App> {
    let content = fs::read_to_string(path).ok()?;
    let mut in_desktop_entry = false;
    let mut name = String::new();
    let mut icon = String::new();
    let mut exec = String::new();
    let mut app_type = String::new();
    let mut hidden = false;
    let mut terminal = false;

    for line in content.lines() {
        let line = line.trim();
        if line == "[Desktop Entry]" {
            in_desktop_entry = true;
            continue;
        }
        if line.starts_with('[') && in_desktop_entry {
            break;
        }
        if !in_desktop_entry || line.starts_with('#') {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        match key {
            "Name" if name.is_empty() => name = value.to_string(),
            "Icon" if icon.is_empty() => icon = value.to_string(),
            "Exec" if exec.is_empty() => exec = value.to_string(),
            "Type" => app_type = value.to_string(),
            "NoDisplay" | "Hidden" if value.eq_ignore_ascii_case("true") => hidden = true,
            "Terminal" => terminal = value.eq_ignore_ascii_case("true"),
            _ => {}
        }
    }

    if app_type != "Application" || hidden || name.is_empty() || exec.is_empty() {
        return None;
    }

    Some(App {
        name,
        icon_path: resolve_icon(&icon),
        exec: remove_field_codes(&exec),
        terminal,
    })
}

fn scan_commands(query: &str) -> Vec<CommandResult> {
    let typed_args = split_command_line(query);
    let typed_program = typed_args.first().cloned().unwrap_or_default();
    let typed_has_arguments = typed_args.len() > 1;
    let prefix = typed_program.to_lowercase();
    if prefix.is_empty() {
        return Vec::new();
    }

    // With arguments, only the exact executable is useful: the rest is passed
    // through unchanged when the result is launched.
    if typed_has_arguments && is_executable(&typed_program) {
        return vec![CommandResult {
            name: query.to_string(),
            exec: query.to_string(),
        }];
    }

    let mut matches = HashMap::<String, String>::new();
    let path_value = env::var_os("PATH").unwrap_or_default();
    for directory in env::split_paths(&path_value) {
        let Ok(entries) = fs::read_dir(directory) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
                continue;
            };
            if !name.to_lowercase().starts_with(&prefix) || !is_executable_path(&path) {
                continue;
            }
            matches.entry(name.to_string()).or_insert_with(|| name.to_string());
        }
    }

    // A direct path is a valid command even though it cannot be found by the
    // PATH directory scan above.
    if is_executable(&typed_program) {
        matches
            .entry(typed_program.clone())
            .or_insert_with(|| typed_program.clone());
    }

    let mut results: Vec<CommandResult> = matches
        .into_values()
        .map(|name| CommandResult {
            name: name.clone(),
            exec: name,
        })
        .collect();
    results.sort_by(|left, right| left.name.to_lowercase().cmp(&right.name.to_lowercase()));
    results.truncate(24);
    results
}

fn resolve_icon(icon: &str) -> String {
    if icon.is_empty() {
        return String::new();
    }

    let icon_path = PathBuf::from(icon);
    if icon_path.is_absolute() && icon_path.exists() {
        return file_url(&icon_path);
    }

    let mut candidates = Vec::new();
    let home = env::var("HOME").unwrap_or_default();
    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        candidates.push(PathBuf::from(data_home).join("icons"));
    } else if !home.is_empty() {
        candidates.push(PathBuf::from(&home).join(".local/share/icons"));
    }
    if let Ok(data_dirs) = env::var("XDG_DATA_DIRS") {
        candidates.extend(data_dirs.split(':').filter(|value| !value.is_empty()).map(PathBuf::from));
    }
    candidates.extend([
        PathBuf::from("/usr/share/icons"),
        PathBuf::from("/usr/local/share/icons"),
        PathBuf::from("/usr/share/pixmaps"),
    ]);

    let icon_names = if Path::new(icon).extension().is_some() {
        vec![icon.to_string()]
    } else {
        vec![format!("{icon}.png"), format!("{icon}.svg"), format!("{icon}.xpm")]
    };

    let icon_sizes = ["48x48", "64x64", "128x128", "256x256", "scalable"];
    for base in candidates {
        for theme in ["hicolor", "Adwaita"] {
            for size in icon_sizes {
                for icon_name in &icon_names {
                    let candidate = base.join(theme).join(size).join("apps").join(icon_name);
                    if candidate.exists() {
                        return file_url(&candidate);
                    }
                }
            }
        }
        for icon_name in &icon_names {
            let candidate = base.join(icon_name);
            if candidate.exists() {
                return file_url(&candidate);
            }
        }
    }
    String::new()
}

fn file_url(path: &Path) -> String {
    format!("file://{}", path.to_string_lossy())
}

fn is_executable(command: &str) -> bool {
    let path = Path::new(command);
    if path.components().count() > 1 {
        return is_executable_path(path);
    }

    let path_value = env::var_os("PATH").unwrap_or_default();
    env::split_paths(&path_value)
        .map(|directory| directory.join(command))
        .any(|candidate| is_executable_path(&candidate))
}

#[cfg(unix)]
fn is_executable_path(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    path.is_file() && path.metadata().map(|meta| meta.permissions().mode() & 0o111 != 0).unwrap_or(false)
}

#[cfg(not(unix))]
fn is_executable_path(path: &Path) -> bool {
    path.is_file()
}

/// Runs `args` (program + arguments) inside a terminal emulator. Returns
/// `None` if no terminal emulator could be found, so the caller can fall
/// back to a direct launch.
fn launch_in_terminal(args: &[String]) -> Option<()> {
    let command_line = args.iter().map(|arg| shell_quote(arg)).collect::<Vec<_>>().join(" ");
    // Keep the window open after the command exits so output (or an error
    // from a program that isn't actually installed) stays readable instead
    // of flashing shut immediately.
    let wrapped = format!(
        "{command_line}; status=$?; printf '\\n[Process exited with status %s. Press Enter to close.]' \"$status\"; read _"
    );

    let (terminal, mut terminal_args) = find_terminal()?;
    terminal_args.push("sh".to_string());
    terminal_args.push("-c".to_string());
    terminal_args.push(wrapped);

    Command::new(&terminal).args(&terminal_args).spawn().ok()?;
    Some(())
}

/// Locates an available terminal emulator and returns its executable name
/// together with the flags needed before the `sh -c "..."` invocation.
fn find_terminal() -> Option<(String, Vec<String>)> {
    if let Ok(preferred) = env::var("TERMINAL") {
        let preferred = preferred.trim();
        if !preferred.is_empty() && is_executable(preferred) {
            return Some((preferred.to_string(), terminal_exec_flag(preferred)));
        }
    }

    let candidates = [
        "x-terminal-emulator",
        "kitty",
        "alacritty",
        "foot",
        "wezterm",
        "gnome-terminal",
        "konsole",
        "xfce4-terminal",
        "xterm",
    ];

    candidates
        .iter()
        .find(|candidate| is_executable(candidate))
        .map(|candidate| (candidate.to_string(), terminal_exec_flag(candidate)))
}

/// Returns the flag(s) a given terminal emulator needs before the command
/// to run, since not all terminals agree on `-e`.
fn terminal_exec_flag(terminal: &str) -> Vec<String> {
    let name = Path::new(terminal)
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or(terminal);

    match name {
        "kitty" | "foot" => vec![],
        "gnome-terminal" => vec!["--".to_string()],
        "wezterm" => vec!["start".to_string(), "--".to_string()],
        "xfce4-terminal" => vec!["-x".to_string()],
        _ => vec!["-e".to_string()],
    }
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

fn remove_field_codes(exec: &str) -> String {
    let mut result = String::with_capacity(exec.len());
    let mut chars = exec.chars().peekable();
    while let Some(character) = chars.next() {
        if character == '%' {
            chars.next();
        } else {
            result.push(character);
        }
    }
    result.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn split_command_line(value: &str) -> Vec<String> {
    let mut result = Vec::new();
    let mut current = String::new();
    let mut quote = None;
    let mut escaped = false;

    for character in value.chars() {
        if escaped {
            current.push(character);
            escaped = false;
        } else if character == '\\' {
            escaped = true;
        } else if let Some(active_quote) = quote {
            if character == active_quote {
                quote = None;
            } else {
                current.push(character);
            }
        } else if character == '\'' || character == '"' {
            quote = Some(character);
        } else if character.is_whitespace() {
            if !current.is_empty() {
                result.push(std::mem::take(&mut current));
            }
        } else {
            current.push(character);
        }
    }

    if escaped {
        current.push('\\');
    }
    if !current.is_empty() {
        result.push(current);
    }
    result
}

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn apps_to_json(apps: &[App]) -> String {
    let mut output = String::from("[");
    for (index, app) in apps.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        output.push_str(&format!(
            r#"{{"appName":"{}","iconPath":"{}","execStr":"{}","isCommand":false,"terminal":{}}}"#,
            json_escape(&app.name),
            json_escape(&app.icon_path),
            json_escape(&app.exec),
            app.terminal
        ));
    }
    output.push(']');
    output
}

fn commands_to_json(commands: &[CommandResult]) -> String {
    let mut output = String::from("[");
    for (index, command) in commands.iter().enumerate() {
        if index > 0 {
            output.push(',');
        }
        output.push_str(&format!(
            r#"{{"appName":"{}","iconPath":"","execStr":"{}","isCommand":true,"terminal":true}}"#,
            json_escape(&command.name),
            json_escape(&command.exec)
        ));
    }
    output.push(']');
    output
}