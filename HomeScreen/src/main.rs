use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod x11below;

const HOMESCREEN_TITLE: &str = "Vamora Homescreen";

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/homescreen/window.qml"));
    }

    // X11 only for now: explicitly pin below other windows so we don't
    // end up on top of the statusbar/other panels depending on launch order.
    x11below::keep_below(HOMESCREEN_TITLE);

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
