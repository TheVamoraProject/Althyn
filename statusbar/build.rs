use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("com.vamora"))
        .qt_module("Network")
        .file("src/cxxqt_object.rs")
        .file("src/userinfo.rs")
        .file("src/notifications.rs")
        .file("src/applist.rs")
        .file("src/theme.rs")
        .file("src/device.rs")
        .file("src/x11maximize.rs")
        .file("src/x11luma.rs")
        .qrc("src/qml/qml.qrc")
        .qrc("src/qml/assets.qrc")
        .build();
}
