#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type PowerActions = super::PowerActionsRust;

        /// Captures the root X11 window before the overlay is shown.
        #[qinvokable]
        #[cxx_name = "captureScreen"]
        fn capture_screen(&self) -> QString;

        /// Runs one of the six allow-listed desktop power actions.
        #[qinvokable]
        #[cxx_name = "executeAction"]
        fn execute_action(&self, action: &QString);
    }
}

use cxx_qt_lib::QString;
use std::env;
use std::path::Path;
use std::process::Command;

#[derive(Default)]
pub struct PowerActionsRust;

impl qobject::PowerActions {
    pub fn capture_screen(&self) -> QString {
        let path = env::temp_dir().join(format!(
            "vamora-powermenu-background-{}.png",
            std::process::id()
        ));
        let path_string = path.to_string_lossy().to_string();

        let captured = capture_with("import", &["-window", "root", path_string.as_str()], &path)
            || capture_with("scrot", &[path_string.as_str()], &path)
            || capture_with("gnome-screenshot", &["--file", path_string.as_str()], &path)
            || capture_with("maim", &[path_string.as_str()], &path);

        if captured {
            QString::from(format!("file://{}", path_string).as_str())
        } else {
            QString::from("")
        }
    }

    pub fn execute_action(&self, action: &QString) {
        match format!("{}", action).as_str() {
            "lock" => lock_session(),
            "sleep" => run_first(&[("systemctl", &["suspend"]), ("loginctl", &["suspend"])]),
            "hibernate" => {
                run_first(&[("systemctl", &["hibernate"]), ("loginctl", &["hibernate"])])
            }
            "logout" => logout_session(),
            "restart" => run_first(&[("systemctl", &["reboot"]), ("loginctl", &["reboot"])]),
            "shutdown" => run_first(&[("systemctl", &["poweroff"]), ("loginctl", &["poweroff"])]),
            _ => eprintln!("vamora-powermenu: rejected unknown action"),
        }
    }
}

fn capture_with(program: &str, args: &[&str], path: &Path) -> bool {
    Command::new(program)
        .args(args)
        .status()
        .map(|status| status.success() && path.exists())
        .unwrap_or(false)
}

fn lock_session() {
    let session = env::var("XDG_SESSION_ID").unwrap_or_default();
    if !session.is_empty() && run_command("loginctl", &["lock-session", &session]) {
        return;
    }

    run_first(&[
        ("xdg-screensaver", &["lock"]),
        ("gnome-screensaver-command", &["--lock"]),
        ("dm-tool", &["lock"]),
    ]);
}

fn logout_session() {
    let session = env::var("XDG_SESSION_ID").unwrap_or_default();
    if !session.is_empty() && run_command("loginctl", &["terminate-session", &session]) {
        return;
    }

    run_first(&[
        ("gnome-session-quit", &["--logout", "--no-prompt"]),
        ("xfce4-session-logout", &["--logout"]),
        ("openbox", &["--exit"]),
        (
            "qdbus6",
            &["org.kde.ksmserver", "/KSMServer", "logout", "0", "0", "0"],
        ),
        (
            "qdbus",
            &["org.kde.ksmserver", "/KSMServer", "logout", "0", "0", "0"],
        ),
    ]);
}

fn run_first(commands: &[(&str, &[&str])]) {
    for (program, args) in commands {
        if run_command(program, args) {
            return;
        }
    }
    eprintln!("vamora-powermenu: no usable desktop power command was found");
}

fn run_command(program: &str, args: &[&str]) -> bool {
    Command::new(program)
        .args(args)
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}
