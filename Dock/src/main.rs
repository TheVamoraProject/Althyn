use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod dockmodel;
mod x11docktype;
mod x11maximize;

const DOCK_TITLE: &str = "Vamora Dock";

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/dock/dock.qml"));
    }

    // X11 only for now: tag ourselves as an EWMH dock and request
    // _NET_WM_STATE_ABOVE so we don't end up stacked behind a window
    // that just got maximized (which would eat the hover-to-reveal
    // events at the bottom edge before we ever see them).
    x11docktype::mark_as_dock(DOCK_TITLE);

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
