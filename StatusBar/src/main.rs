use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod cxxqt_object;
mod theme;
mod userinfo;
mod x11strut;

// Must match the `title:` set on the root Window in statusbar.qml, and the
// `height:` it uses, or the strut lookup in x11strut.rs never finds the window.
const STATUSBAR_TITLE: &str = "Vamora StatusBar";
const STATUSBAR_HEIGHT: i32 = 30;

fn main() {
    // Only Openbox (X11) needs the EWMH strut poked in manually; labwc
    // (Wayland) is the default session now, so this has to be opt-in via
    // --run-x11 instead of unconditional like it was pre-runner.
    let run_x11 = std::env::args().skip(1).any(|arg| arg == "--run-x11");

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