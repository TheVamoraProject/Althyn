use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};
mod applist;
mod cxxqt_object;
mod theme;
mod userinfo;

fn main() {
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/layouts/statusbar/statusbar.qml"));
    }
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}