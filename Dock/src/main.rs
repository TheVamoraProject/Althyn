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

    // X11 only for now: tag ourselves as an EWMH dock and keep the native
    // dock window above maximized apps. QML still controls autohide, so this
    // does NOT make the dock permanently visible; it only prevents the hidden
    // reveal strip / revealed dock from getting buried by a maximized window.
    x11docktype::mark_as_dock(DOCK_TITLE);

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
