use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod dockmodel;
mod wltoplevel;
mod x11docktype;
mod x11maximize;

const DOCK_TITLE: &str = "Vamora Dock";

/// Session type, following the Runner: `--run-x11` means X11 (Openbox); no
/// flag means the Wayland session. On Wayland, Qt must load the layer-shell
/// integration (LayerShellQt) *before* the application object exists, so
/// the windows' `LayerShell.Window.*` properties in QML take effect.
fn session_is_x11() -> bool {
    let run_x11 = std::env::args().skip(1).any(|arg| arg == "--run-x11");
    if !run_x11 && std::env::var_os("QT_WAYLAND_SHELL_INTEGRATION").is_none() {
        // SAFETY: called first thing in main(), before any threads exist.
        unsafe { std::env::set_var("QT_WAYLAND_SHELL_INTEGRATION", "layer-shell") };
    }
    run_x11
}

fn main() {
    let run_x11 = session_is_x11();

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/dock/dock.qml"));
    }

    // X11 only (--run-x11): tag ourselves as an EWMH dock and keep the native
    // dock window above maximized apps. QML still controls autohide, so this
    // does NOT make the dock permanently visible; it only prevents the hidden
    // reveal strip / revealed dock from getting buried by a maximized window.
    // On Wayland the layer-shell properties in dock.qml do this job.
    if run_x11 {
        x11docktype::mark_as_dock(DOCK_TITLE);
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
