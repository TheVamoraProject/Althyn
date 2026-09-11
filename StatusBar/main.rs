// meh
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod cxxqt_object;
mod userinfo;
mod x11strut;

const STATUSBAR_TITLE: &str = "Vamora StatusBar";
const STATUSBAR_HEIGHT: i32 = 30;

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/statusbar/statusbar.qml"));
    }

    // X11 only for now: reserve screen space so maximized
    // windows don't sit underneath the bar.
    x11strut::reserve_top_strut(STATUSBAR_TITLE, STATUSBAR_HEIGHT);

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}