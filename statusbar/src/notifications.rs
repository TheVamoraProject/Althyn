//! Notification centre data: the compositor owns the notification daemon
//! (`org.freedesktop.Notifications`) and keeps the history; this reads it over
//! its `org.vamora.Notifications` interface on the session bus.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type NotificationStore = super::NotificationStoreRust;

        /// History as a JSON array (newest first): id, app, summary, body, time.
        /// `[]` when the compositor is not reachable.
        #[qinvokable]
        fn json(self: &NotificationStore) -> QString;

        #[qinvokable]
        fn clear(self: &NotificationStore);

        #[qinvokable]
        fn dismiss(self: &NotificationStore, id: i32);
    }
}

use std::sync::{Mutex, OnceLock};

use cxx_qt_lib::QString;

#[derive(Default)]
pub struct NotificationStoreRust;

const DEST: &str = "org.freedesktop.Notifications";
const PATH: &str = "/org/vamora/Notifications";
const IFACE: &str = "org.vamora.Notifications";

fn connection() -> Option<zbus::blocking::Connection> {
    static CONN: OnceLock<Mutex<Option<zbus::blocking::Connection>>> = OnceLock::new();
    let cell = CONN.get_or_init(|| Mutex::new(None));
    let mut guard = cell.lock().ok()?;
    if guard.is_none() {
        *guard = zbus::blocking::Connection::session().ok();
    }
    guard.clone()
}

fn call<B>(method: &str, body: &B) -> Option<zbus::Message>
where
    B: serde::ser::Serialize + zbus::zvariant::DynamicType,
{
    connection()?.call_method(Some(DEST), PATH, Some(IFACE), method, body).ok()
}

impl qobject::NotificationStore {
    pub fn json(&self) -> QString {
        let text = call("List", &())
            .and_then(|m| m.body().deserialize::<String>().ok())
            .unwrap_or_else(|| "[]".to_string());
        QString::from(text.as_str())
    }

    pub fn clear(&self) {
        let _ = call("Clear", &());
    }

    pub fn dismiss(&self, id: i32) {
        let _ = call("Dismiss", &(id.max(0) as u32));
    }
}
