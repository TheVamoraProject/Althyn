//! Wayland window tracking through `wlr-foreign-toplevel-management`.
//!
//! The Wayland counterpart of what `x11maximize.rs` reads from EWMH: the list
//! of application windows, which one is active, whether it is maximized, and
//! a way to activate one. It is used when the session is not X11; the compositor
//! (althyn-core, or any other compositor that implements it) provides the protocol.
//!
//! A background thread keeps a snapshot up to date; callers only ever read
//! the snapshot, so the QML side never blocks on the socket. If there is no
//! Wayland display or the compositor lacks the protocol, the snapshot stays
//! empty and everything degrades to "no windows" (the Dock stays visible).
//!
//! This file is identical in the Dock and StatusBar crates (like the x11
//! modules, it is duplicated rather than shared), so each crate only uses
//! part of it.
#![allow(dead_code)]

use std::sync::{Arc, Mutex, OnceLock};

use wayland_client::{
    Connection, Dispatch, Proxy, QueueHandle, event_created_child,
    globals::{GlobalListContents, registry_queue_init},
    protocol::{
        wl_output::{self, WlOutput},
        wl_registry::WlRegistry,
        wl_seat::WlSeat,
    },
};
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::{self, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::{self, ZwlrForeignToplevelManagerV1},
};

/// What the compositor reports about one window.
#[derive(Clone, Default, Debug)]
pub struct Info {
    pub app_id: String,
    pub title: String,
    pub maximized: bool,
    pub minimized: bool,
    pub activated: bool,
    pub fullscreen: bool,
}

struct Entry {
    handle: ZwlrForeignToplevelHandleV1,
    pending: Info,
    current: Info,
    /// The compositor has sent `done` at least once.
    announced: bool,
}

#[derive(Default)]
struct Shared {
    /// In order of appearance (a stand-in for stacking order).
    entries: Vec<Entry>,
    seat: Option<WlSeat>,
    conn: Option<Connection>,
    /// Current mode of the first output, in device pixels.
    output_size: Option<(i32, i32)>,
    /// The initial round trip has finished (or failed).
    settled: bool,
}

static SHARED: OnceLock<Arc<Mutex<Shared>>> = OnceLock::new();

fn shared() -> &'static Arc<Mutex<Shared>> {
    SHARED.get_or_init(|| {
        let shared = Arc::new(Mutex::new(Shared::default()));
        let thread_shared = shared.clone();
        std::thread::Builder::new()
            .name("wl-toplevels".into())
            .spawn(move || {
                run(thread_shared.clone());
                // Never leave callers waiting for a thread that has ended.
                thread_shared.lock().unwrap().settled = true;
            })
            .ok();
        shared
    })
}

/// Waits (briefly, once) for the first snapshot so the first call is useful.
fn ready() -> std::sync::MutexGuard<'static, Shared> {
    let shared = shared();
    for _ in 0..40 {
        let guard = shared.lock().unwrap();
        if guard.settled {
            return guard;
        }
        drop(guard);
        std::thread::sleep(std::time::Duration::from_millis(25));
    }
    shared.lock().unwrap()
}

/// All announced windows, oldest first.
pub fn toplevels() -> Vec<Info> {
    ready()
        .entries
        .iter()
        .filter(|e| e.announced)
        .map(|e| e.current.clone())
        .collect()
}

/// Mode of the first output in device pixels, if the compositor told us.
pub fn output_size() -> Option<(i32, i32)> {
    ready().output_size
}

/// Asks the compositor to activate the window at `index` (as returned by
/// [`toplevels`], counting only announced windows).
pub fn activate(index: usize) -> bool {
    let guard = ready();
    let Some(entry) = guard.entries.iter().filter(|e| e.announced).nth(index) else {
        return false;
    };
    let Some(seat) = guard.seat.as_ref() else {
        return false;
    };
    entry.handle.activate(seat);
    guard.conn.as_ref().is_some_and(|c| c.flush().is_ok())
}

/// Asks the compositor to minimize the window at `index`.
pub fn minimize(index: usize) -> bool {
    let guard = ready();
    let Some(entry) = guard.entries.iter().filter(|e| e.announced).nth(index) else {
        return false;
    };
    entry.handle.set_minimized();
    guard.conn.as_ref().is_some_and(|c| c.flush().is_ok())
}

// ---------------------------------------------------------------------------
// The connection thread.

struct App {
    shared: Arc<Mutex<Shared>>,
}

fn run(shared: Arc<Mutex<Shared>>) {
    let Ok(conn) = Connection::connect_to_env() else {
        return;
    };
    let Ok((globals, mut queue)) = registry_queue_init::<App>(&conn) else {
        return;
    };
    let qh = queue.handle();
    let mut app = App { shared: shared.clone() };

    if globals
        .bind::<ZwlrForeignToplevelManagerV1, _, _>(&qh, 1..=3, ())
        .is_err()
    {
        // No window management protocol: leave the snapshot empty.
        shared.lock().unwrap().settled = true;
        return;
    }
    let seat = globals.bind::<WlSeat, _, _>(&qh, 1..=1, ()).ok();
    let _output = globals.bind::<WlOutput, _, _>(&qh, 1..=2, ()).ok();
    {
        let mut s = shared.lock().unwrap();
        s.seat = seat;
        s.conn = Some(conn.clone());
    }

    // First round trip delivers the existing windows; then mark ready.
    if queue.roundtrip(&mut app).is_ok() && queue.roundtrip(&mut app).is_ok() {
        shared.lock().unwrap().settled = true;
    }
    while queue.blocking_dispatch(&mut app).is_ok() {}
}

impl Dispatch<WlRegistry, GlobalListContents> for App {
    fn event(
        _: &mut Self,
        _: &WlRegistry,
        _: <WlRegistry as Proxy>::Event,
        _: &GlobalListContents,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlSeat, ()> for App {
    fn event(
        _: &mut Self,
        _: &WlSeat,
        _: <WlSeat as Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlOutput, ()> for App {
    fn event(
        app: &mut Self,
        _: &WlOutput,
        event: wl_output::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_output::Event::Mode { flags, width, height, .. } = event {
            let current = matches!(flags, wayland_client::WEnum::Value(f) if f.contains(wl_output::Mode::Current));
            let mut s = app.shared.lock().unwrap();
            if current && s.output_size.is_none() {
                s.output_size = Some((width, height));
            }
        }
    }
}

impl Dispatch<ZwlrForeignToplevelManagerV1, ()> for App {
    fn event(
        app: &mut Self,
        _: &ZwlrForeignToplevelManagerV1,
        event: zwlr_foreign_toplevel_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zwlr_foreign_toplevel_manager_v1::Event::Toplevel { toplevel } = event {
            app.shared.lock().unwrap().entries.push(Entry {
                handle: toplevel,
                pending: Info::default(),
                current: Info::default(),
                announced: false,
            });
        }
    }

    event_created_child!(App, ZwlrForeignToplevelManagerV1, [
        zwlr_foreign_toplevel_manager_v1::EVT_TOPLEVEL_OPCODE => (ZwlrForeignToplevelHandleV1, ()),
    ]);
}

impl Dispatch<ZwlrForeignToplevelHandleV1, ()> for App {
    fn event(
        app: &mut Self,
        handle: &ZwlrForeignToplevelHandleV1,
        event: zwlr_foreign_toplevel_handle_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        use zwlr_foreign_toplevel_handle_v1::{Event, State};
        let mut s = app.shared.lock().unwrap();
        let Some(pos) = s.entries.iter().position(|e| e.handle.id() == handle.id()) else {
            return;
        };
        match event {
            Event::Title { title } => s.entries[pos].pending.title = title,
            Event::AppId { app_id } => s.entries[pos].pending.app_id = app_id,
            Event::State { state } => {
                let info = &mut s.entries[pos].pending;
                info.maximized = false;
                info.minimized = false;
                info.activated = false;
                info.fullscreen = false;
                for chunk in state.chunks_exact(4) {
                    let value = u32::from_ne_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
                    match State::try_from(value) {
                        Ok(State::Maximized) => info.maximized = true,
                        Ok(State::Minimized) => info.minimized = true,
                        Ok(State::Activated) => info.activated = true,
                        Ok(State::Fullscreen) => info.fullscreen = true,
                        _ => {}
                    }
                }
            }
            Event::Done => {
                let entry = &mut s.entries[pos];
                entry.current = entry.pending.clone();
                entry.announced = true;
            }
            Event::Closed => {
                s.entries.remove(pos);
            }
            _ => {}
        }
    }
}
