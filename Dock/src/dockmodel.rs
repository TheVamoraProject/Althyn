//! Dummy dock entries for early UI/UX work. Once VamoraSys app discovery
//! lands here (mirroring AppList in vamora-statusbar), get_dummy_apps_json
//! will be swapped for a real .desktop scan.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type DockModel = super::DockModelRust;

        /// Returns a JSON array of {appName, iconPath} dummy entries.
        #[qinvokable]
        #[cxx_name = "getDummyAppsJson"]
        fn get_dummy_apps_json(self: &DockModel) -> QString;

        /// Stub launcher — dummy entries have nothing real to run yet.
        #[qinvokable]
        #[cxx_name = "launchApp"]
        fn launch_app(self: &DockModel, app_name: &QString);
    }
}

use cxx_qt_lib::QString;

#[derive(Default)]
pub struct DockModelRust;

struct DummyApp {
    name: &'static str,
    icon: &'static str,
}

const DUMMY_APPS: &[DummyApp] = &[
    DummyApp { name: "Calculator", icon: "qrc:/assets/icons/dock/calculator.png" },
    DummyApp { name: "Calendar", icon: "qrc:/assets/icons/dock/calendar.png" },
    DummyApp { name: "Camera", icon: "qrc:/assets/icons/dock/camera.png" },
    DummyApp { name: "Clock", icon: "qrc:/assets/icons/dock/clock.png" },
    DummyApp { name: "Compass", icon: "qrc:/assets/icons/dock/compass.png" },
];

impl qobject::DockModel {
    pub fn get_dummy_apps_json(&self) -> QString {
        let mut out = String::from("[");
        for (i, app) in DUMMY_APPS.iter().enumerate() {
            if i > 0 {
                out.push(',');
            }
            out.push_str(&format!(
                r#"{{"appName":"{}","iconPath":"{}"}}"#,
                json_escape(app.name),
                json_escape(app.icon),
            ));
        }
        out.push(']');
        QString::from(out.as_str())
    }

    pub fn launch_app(&self, app_name: &QString) {
        println!("vamora-dock: launch requested for dummy app '{app_name}' (no-op)");
    }
}

fn json_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}
