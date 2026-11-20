use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod x11below;

const HOMESCREEN_TITLE: &str = "Vamora Homescreen";

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
        engine.load(&QUrl::from("qrc:/layouts/homescreen/window.qml"));
    }

    // X11 only (--run-x11): explicitly pin below other windows so we don't
    // end up on top of the statusbar/other panels depending on launch order.
    // On Wayland the bottom layer in window.qml does this job.
    if run_x11 {
        x11below::keep_below(HOMESCREEN_TITLE);
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
