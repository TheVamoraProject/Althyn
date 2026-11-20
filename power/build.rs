use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("com.vamora.powermenu"))
        .file("src/power.rs")
        .file("src/theme.rs")
        .file("src/userinfo.rs")
        .qrc("src/qml/qml.qrc")
        .qrc("src/qml/assets.qrc")
        .build();
}
