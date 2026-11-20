use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod cxxqt_object;
mod device;
mod wltoplevel;
mod x11maximize;
mod x11luma;
mod theme;
mod userinfo;
mod x11strut;

// Must match the `title:` set on the root Window in statusbar.qml, and the
// `height:` it uses, or the strut lookup in x11strut.rs never finds the window.
const STATUSBAR_TITLE: &str = "Vamora StatusBar";
const STATUSBAR_HEIGHT: i32 = 30;

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
    // Only Openbox (X11) needs the EWMH strut poked in manually; on Wayland
    // the bar is a layer-shell surface that reserves its own space.
    let run_x11 = session_is_x11();

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/statusbar/statusbar.qml"));
    }

    if run_x11 {
        x11strut::reserve_top_strut(STATUSBAR_TITLE, STATUSBAR_HEIGHT);
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}