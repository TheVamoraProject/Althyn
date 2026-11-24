use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("com.vamora"))
        .file("src/applist.rs")
        .file("src/wallluma.rs")
        .qrc("src/qml/qml.qrc")
        .qrc("src/qml/assets.qrc")
        .build();
}
