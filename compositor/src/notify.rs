//! Notifications: the `org.freedesktop.Notifications` service, so anything
//! that calls `notify-send` / libnotify shows up as a toast drawn by the
//! compositor (top right of the usable area, themed with `appearance.theme`).
//!
//! The D-Bus side runs on its own thread and hands messages to the event loop
//! through a calloop channel; the list of toasts lives in [`TOASTS`] so the
//! renderers, the input code and the expiry timer can all reach it.

use std::{
    collections::HashMap,
    sync::{
        Mutex, OnceLock,
        atomic::{AtomicU32, Ordering},
    },
    time::{Duration, Instant},
};

use smithay::{
    backend::renderer::element::memory::MemoryRenderBuffer,
    reexports::calloop::channel::Sender,
    utils::{Logical, Point, Rectangle},
};
use tracing::{info, warn};

use crate::{
    notify_icons,
    titlebar::{Canvas, draw_text, text_width},
};
use std::path::PathBuf;

pub const TOAST_W: i32 = 344;
pub const TOAST_H: i32 = 84;
pub const TOAST_GAP: i32 = 10;
pub const TOAST_MARGIN: i32 = 16;
/// Most toasts on screen at once; older ones are dropped.
pub const MAX_TOASTS: usize = 5;
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(6);

pub const REASON_EXPIRED: u32 = 1;
pub const REASON_DISMISSED: u32 = 2;
pub const REASON_CLOSED: u32 = 3;

#[derive(Clone, Debug)]
pub struct Notification {
    pub id: u32,
    pub app: String,
    pub summary: String,
    pub body: String,
    /// `None`: stays until dismissed.
    pub timeout: Option<Duration>,
    /// App icon and (optional) picture, as files.
    pub icon: Option<PathBuf>,
    pub image: Option<PathBuf>,
    #[allow(dead_code)]
    pub critical: bool,
}

pub struct Toast {
    pub n: Notification,
    pub shown_at: Instant,
    /// Text raster cache: (what it shows, buffer).
    pub buf: Option<(TextKey, MemoryRenderBuffer)>,
}

#[derive(Clone, PartialEq)]
pub struct TextKey {
    pub app: String,
    pub summary: String,
    pub body: String,
    pub icon: Option<PathBuf>,
    pub image: Option<PathBuf>,
    pub scale: i32,
    pub dark: bool,
}

pub static TOASTS: Mutex<Vec<Toast>> = Mutex::new(Vec::new());

/// Everything that was shown, newest first, for the status bar's notification
/// centre (`org.vamora.Notifications`). Closing a toast does not remove it.
#[derive(Clone)]
pub struct Entry {
    pub id: u32,
    pub app: String,
    pub summary: String,
    pub body: String,
    pub icon: String,
    pub image: String,
    /// Unix seconds.
    pub time: u64,
}

static HISTORY: Mutex<Vec<Entry>> = Mutex::new(Vec::new());
const MAX_HISTORY: usize = 50;

fn record(n: &Notification) {
    let time = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs());
    let mut h = HISTORY.lock().unwrap();
    h.retain(|e| e.id != n.id);
    h.insert(0, Entry { id: n.id, app: n.app.clone(), summary: n.summary.clone(), body: n.body.clone(), icon: path_str(&n.icon), image: path_str(&n.image), time });
    h.truncate(MAX_HISTORY);
}

fn path_str(p: &Option<PathBuf>) -> String {
    p.as_ref().map(|p| p.display().to_string()).unwrap_or_default()
}

fn json_str(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => {}
            '\t' => out.push(' '),
            c if (c as u32) < 0x20 => {}
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn history_json() -> String {
    let h = HISTORY.lock().unwrap();
    let items: Vec<String> = h
        .iter()
        .map(|e| {
            format!(
                "{{\"id\":{},\"app\":{},\"summary\":{},\"body\":{},\"icon\":{},\"image\":{},\"time\":{}}}",
                e.id,
                json_str(&e.app),
                json_str(&e.summary),
                json_str(&e.body),
                json_str(&e.icon),
                json_str(&e.image),
                e.time
            )
        })
        .collect();
    format!("[{}]", items.join(","))
}

pub enum Msg {
    Notify { n: Notification, #[allow(dead_code)] replaces: u32 },
    Close(u32),
}

/// Global rectangle of toast number `index` inside the usable zone.
pub fn toast_rect(zone: Rectangle<i32, Logical>, index: usize) -> Rectangle<i32, Logical> {
    let x = zone.loc.x + zone.size.w - TOAST_W - TOAST_MARGIN;
    let y = zone.loc.y + TOAST_MARGIN / 2 + index as i32 * (TOAST_H + TOAST_GAP);
    Rectangle::new((x, y).into(), (TOAST_W, TOAST_H).into())
}

/// Adds or replaces a toast (event-loop side).
pub fn show(n: Notification) {
    record(&n);
    let mut toasts = TOASTS.lock().unwrap();
    if let Some(t) = toasts.iter_mut().find(|t| t.n.id == n.id) {
        t.n = n;
        t.buf = None;
        t.shown_at = Instant::now();
        return;
    }
    toasts.push(Toast { n, shown_at: Instant::now(), buf: None });
    while toasts.len() > MAX_TOASTS {
        let old = toasts.remove(0);
        emit_closed(old.n.id, REASON_EXPIRED);
    }
}

pub fn close(id: u32, reason: u32) {
    let mut toasts = TOASTS.lock().unwrap();
    if let Some(pos) = toasts.iter().position(|t| t.n.id == id) {
        toasts.remove(pos);
        drop(toasts);
        emit_closed(id, reason);
    }
}

/// Removes toasts whose time is up. Called from a timer.
pub fn expire(now: Instant) {
    let mut gone = Vec::new();
    TOASTS.lock().unwrap().retain(|t| {
        let alive = t.n.timeout.is_none_or(|d| now.duration_since(t.shown_at) < d);
        if !alive {
            gone.push(t.n.id);
        }
        alive
    });
    for id in gone {
        emit_closed(id, REASON_EXPIRED);
    }
}

/// Index of the toast under `pos`, if any.
pub fn toast_at(zone: Rectangle<i32, Logical>, pos: Point<f64, Logical>) -> Option<u32> {
    let toasts = TOASTS.lock().unwrap();
    (0..toasts.len())
        .find(|i| toast_rect(zone, *i).contains(pos.to_i32_floor()))
        .map(|i| toasts[i].n.id)
}

//
// D-Bus
//

static CONNECTION: OnceLock<zbus::blocking::Connection> = OnceLock::new();
static NEXT_ID: AtomicU32 = AtomicU32::new(1);

fn emit_closed(id: u32, reason: u32) {
    if let Some(conn) = CONNECTION.get()
        && let Err(err) = conn.emit_signal(
            None::<&str>,
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "NotificationClosed",
            &(id, reason),
        )
    {
        warn!("could not emit NotificationClosed: {err}");
    }
}

struct Server {
    tx: Sender<Msg>,
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl Server {
    fn get_capabilities(&self) -> Vec<String> {
        vec!["body".into()]
    }

    #[allow(clippy::too_many_arguments)]
    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        _actions: Vec<String>,
        hints: HashMap<String, zbus::zvariant::OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {
        let id = if replaces_id != 0 { replaces_id } else { NEXT_ID.fetch_add(1, Ordering::Relaxed) };
        let critical = hints
            .get("urgency")
            .and_then(|v| u8::try_from(v.clone()).ok())
            .is_some_and(|u| u >= 2);
        let timeout = match expire_timeout {
            0 => None,
            t if t > 0 => Some(Duration::from_millis(t as u64)),
            _ => (!critical).then_some(DEFAULT_TIMEOUT),
        };
        let icon = notify_icons::resolve_icon(&app_icon);
        let image = notify_icons::hint_image(&hints, id);
        let n = Notification { id, app: app_name, summary, body: strip_markup(&body), timeout, icon, image, critical };
        let _ = self.tx.send(Msg::Notify { n, replaces: replaces_id });
        id
    }

    fn close_notification(&self, id: u32) {
        let _ = self.tx.send(Msg::Close(id));
    }

    fn get_server_information(&self) -> (String, String, String, String) {
        ("Althyn".into(), "Vamora".into(), env!("CARGO_PKG_VERSION").into(), "1.2".into())
    }
}

/// The status bar's side: read the history, clear it, drop one entry.
struct VamoraServer;

#[zbus::interface(name = "org.vamora.Notifications")]
impl VamoraServer {
    fn list(&self) -> String {
        history_json()
    }

    fn clear(&self) {
        HISTORY.lock().unwrap().clear();
    }

    fn dismiss(&self, id: u32) {
        HISTORY.lock().unwrap().retain(|e| e.id != id);
    }
}

/// The spec allows a little markup in bodies; show it as plain text.
fn strip_markup(s: &str) -> String {
    let mut out = String::new();
    let mut in_tag = false;
    for c in s.chars() {
        match c {
            '<' => in_tag = true,
            '>' if in_tag => in_tag = false,
            _ if !in_tag => out.push(c),
            _ => {}
        }
    }
    out.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"")
}

/// Claims `org.freedesktop.Notifications` on the session bus. If another
/// notification daemon already owns it, this logs and does nothing.
pub fn spawn(tx: Sender<Msg>) {
    std::thread::Builder::new()
        .name("notifications".into())
        .spawn(move || {
            let built = zbus::blocking::connection::Builder::session()
                .and_then(|b| b.name("org.freedesktop.Notifications"))
                .and_then(|b| b.serve_at("/org/freedesktop/Notifications", Server { tx }))
                .and_then(|b| b.serve_at("/org/vamora/Notifications", VamoraServer))
                .and_then(|b| b.build());
            match built {
                Ok(conn) => {
                    info!("notification service running on the session bus");
                    let _ = CONNECTION.set(conn);
                    loop {
                        std::thread::park();
                    }
                }
                Err(err) => warn!("notifications disabled: {err}"),
            }
        })
        .ok();
}

//
// Drawing
//

/// ARGB8888 layer for a toast: icon, picture and text (the card behind it is
/// a shader quad).
pub fn rasterize(key: &TextKey) -> Vec<u8> {
    let sc = key.scale as f32;
    let (w, h) = (TOAST_W * key.scale, TOAST_H * key.scale);
    let mut c = Canvas::new(w, h);
    let fg: [f32; 3] = if key.dark { [0.957, 0.957, 0.965] } else { [0.094, 0.094, 0.106] };
    let muted: [f32; 3] = if key.dark { [0.631, 0.631, 0.667] } else { [0.322, 0.322, 0.357] };

    // app icon, or a coloured initial when there is none
    let icon_px = (40 * key.scale) as u32;
    let (ix, iy) = (16 * key.scale, 22 * key.scale);
    let icon = key.icon.as_deref().and_then(|p| notify_icons::load_square(p, icon_px));
    match icon {
        Some(img) => c.blit(&img, ix, iy, (11 * key.scale) as f32),
        None => c.avatar(&key.app, ix, iy, icon_px as i32, key.dark),
    }

    // picture on the right
    let mut right = w as f32 - 18.0 * sc;
    if let Some(path) = key.image.as_deref() {
        let px = (56 * key.scale) as u32;
        if let Some(img) = notify_icons::load_square(path, px) {
            let x = w - 16 * key.scale - px as i32;
            c.blit(&img, x, 14 * key.scale, (10 * key.scale) as f32);
            right = x as f32 - 12.0 * sc;
        }
    }

    let pad = 68.0 * sc;
    draw_text(&mut c, &key.app.to_uppercase(), pad, 25.0 * sc, 10.5 * sc, muted, 1.0, right);
    draw_text(&mut c, &key.summary, pad, 45.0 * sc, 14.5 * sc, fg, 1.0, right);

    // body: up to two lines, wrapped on spaces
    let px = 12.5 * sc;
    let mut lines: Vec<String> = Vec::new();
    let mut cur = String::new();
    for word in key.body.split_whitespace() {
        let trial = if cur.is_empty() { word.to_string() } else { format!("{cur} {word}") };
        if text_width(&trial, px) > right - pad && !cur.is_empty() {
            lines.push(std::mem::take(&mut cur));
            cur = word.to_string();
        } else {
            cur = trial;
        }
    }
    if !cur.is_empty() {
        lines.push(cur);
    }
    for (i, line) in lines.iter().take(2).enumerate() {
        let more = i == 1 && lines.len() > 2;
        let text = if more { format!("{line}…") } else { line.clone() };
        draw_text(&mut c, &text, pad, (62.0 + 15.0 * i as f32) * sc, px, muted, 1.0, right);
    }
    c.into_argb()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn markup_is_stripped() {
        assert_eq!(strip_markup("<b>Hi</b> &amp; bye"), "Hi & bye");
    }

    #[test]
    fn history_json_escapes_and_orders_newest_first() {
        HISTORY.lock().unwrap().clear();
        let mk = |id, summary: &str| Notification {
            id,
            app: "app".into(),
            summary: summary.into(),
            body: "line1\nsay \"hi\"".into(),
            timeout: None,
            critical: false,
        };
        record(&mk(1, "first"));
        record(&mk(2, "second"));
        record(&mk(1, "first again"));
        let j = history_json();
        assert!(j.starts_with("[{\"id\":1,\"app\":\"app\",\"summary\":\"first again\""));
        assert!(j.contains("line1\\nsay \\\"hi\\\""));
        assert_eq!(j.matches("\"id\"").count(), 2);
    }

    #[test]
    fn toasts_stack_downwards() {
        let zone = Rectangle::new((0, 30).into(), (1000, 700).into());
        let a = toast_rect(zone, 0);
        let b = toast_rect(zone, 1);
        assert_eq!(a.loc.x, b.loc.x);
        assert_eq!(b.loc.y - a.loc.y, TOAST_H + TOAST_GAP);
        assert!(a.loc.x + a.size.w <= 1000);
    }

    #[test]
    fn newest_toasts_replace_by_id_and_expire() {
        TOASTS.lock().unwrap().clear();
        let mk = |id, timeout| Notification {
            id,
            app: "a".into(),
            summary: "s".into(),
            body: String::new(),
            timeout,
            icon: None,
            image: None,
            critical: false,
        };
        show(mk(1, Some(Duration::from_millis(1))));
        show(mk(1, Some(Duration::from_millis(1))));
        assert_eq!(TOASTS.lock().unwrap().len(), 1);
        show(mk(2, None));
        expire(Instant::now() + Duration::from_secs(1));
        let left: Vec<u32> = TOASTS.lock().unwrap().iter().map(|t| t.n.id).collect();
        assert_eq!(left, vec![2]);
    }
}
