//! `wlr-foreign-toplevel-management-unstable-v1` (version 3).
//!
//! This is what lets Althyn's Dock and StatusBar know about application
//! windows on Wayland, the same way they read `_NET_CLIENT_LIST` / the active
//! window on X11: which apps have windows, which one is focused, and whether
//! the focused window is maximized (the Dock hides, the StatusBar turns
//! solid). They can also ask us to activate or close a window.
//!
//! Smithay only ships the stateless `ext-foreign-toplevel-list`, so the
//! `wlr` protocol is implemented here directly on top of `wayland-server`.
//!
//! Design: instead of hooking every place a window can change, a timer calls
//! [`State::refresh_foreign_toplevels`] a few times per second. It compares a
//! small snapshot (title, app id, maximized / activated / fullscreen) of every
//! mapped toplevel with what each client was last told and sends only the
//! differences. That costs almost nothing and cannot get out of sync.

use std::collections::HashMap;

use smithay::{
    desktop::Window,
    reexports::{
        wayland_protocols::xdg::shell::server::xdg_toplevel,
        wayland_server::{
            Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
            backend::ClientId,
        },
    },
    wayland::{compositor::with_states, shell::xdg::XdgToplevelSurfaceData},
};
use wayland_protocols_wlr::foreign_toplevel::v1::server::{
    zwlr_foreign_toplevel_handle_v1::{self, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::{self, ZwlrForeignToplevelManagerV1},
};

use crate::state::State;

const VERSION: u32 = 3;

/// What a client has been told about one window.
#[derive(Clone, PartialEq, Eq, Default)]
struct Snapshot {
    title: String,
    app_id: String,
    maximized: bool,
    activated: bool,
    fullscreen: bool,
}

struct Tracked {
    window: Window,
    /// One handle per client that bound the manager.
    handles: Vec<ZwlrForeignToplevelHandleV1>,
    last: Snapshot,
}

#[derive(Default)]
pub struct ForeignToplevelState {
    managers: Vec<ZwlrForeignToplevelManagerV1>,
    toplevels: HashMap<u64, Tracked>,
    next_id: u64,
}

impl ForeignToplevelState {
    pub fn new(dh: &DisplayHandle) -> Self {
        dh.create_global::<State, ZwlrForeignToplevelManagerV1, ()>(VERSION, ());
        Self::default()
    }
}

fn snapshot(window: &Window) -> Option<Snapshot> {
    let toplevel = window.toplevel()?;
    let (title, app_id) = with_states(toplevel.wl_surface(), |states| {
        let data = states
            .data_map
            .get::<XdgToplevelSurfaceData>()
            .map(|d| d.lock().unwrap());
        (
            data.as_ref().and_then(|d| d.title.clone()).unwrap_or_default(),
            data.as_ref().and_then(|d| d.app_id.clone()).unwrap_or_default(),
        )
    });
    let states = toplevel.with_committed_state(|s| s.map(|s| s.states.clone()))?;
    Some(Snapshot {
        title,
        app_id,
        maximized: states.contains(xdg_toplevel::State::Maximized),
        activated: states.contains(xdg_toplevel::State::Activated),
        fullscreen: states.contains(xdg_toplevel::State::Fullscreen),
    })
}

fn state_array(s: &Snapshot) -> Vec<u8> {
    use zwlr_foreign_toplevel_handle_v1::State as S;
    let mut out = Vec::new();
    for (on, value) in [
        (s.maximized, S::Maximized),
        (s.activated, S::Activated),
        (s.fullscreen, S::Fullscreen),
    ] {
        if on {
            out.extend_from_slice(&(value as u32).to_ne_bytes());
        }
    }
    out
}

/// Sends the differences between `old` and `new` (everything when `full`).
fn send_changes(
    handle: &ZwlrForeignToplevelHandleV1,
    old: &Snapshot,
    new: &Snapshot,
    full: bool,
) {
    let mut changed = full;
    if full || old.title != new.title {
        handle.title(new.title.clone());
        changed = true;
    }
    if full || old.app_id != new.app_id {
        handle.app_id(new.app_id.clone());
        changed = true;
    }
    if full
        || old.maximized != new.maximized
        || old.activated != new.activated
        || old.fullscreen != new.fullscreen
    {
        handle.state(state_array(new));
        changed = true;
    }
    if changed {
        handle.done();
    }
}

/// Creates the per-client handle for a window and announces it.
fn announce(
    dh: &DisplayHandle,
    client: &Client,
    manager: &ZwlrForeignToplevelManagerV1,
    id: u64,
    snap: &Snapshot,
) -> Option<ZwlrForeignToplevelHandleV1> {
    let handle = client
        .create_resource::<ZwlrForeignToplevelHandleV1, u64, State>(dh, manager.version(), id)
        .ok()?;
    manager.toplevel(&handle);
    send_changes(&handle, &Snapshot::default(), snap, true);
    Some(handle)
}

impl State {
    /// Brings every client's view of the toplevels up to date. Cheap enough
    /// to run on a short timer.
    pub fn refresh_foreign_toplevels(&mut self) {
        let dh = self.display_handle.clone();

        let current: Vec<(Window, Snapshot)> = self
            .space
            .elements()
            .filter_map(|w| snapshot(w).map(|s| (w.clone(), s)))
            .collect();

        let ft = &mut self.foreign_toplevel;
        ft.managers.retain(|m| m.is_alive());

        // Closed windows.
        let gone: Vec<u64> = ft
            .toplevels
            .iter()
            .filter(|(_, t)| !current.iter().any(|(w, _)| *w == t.window))
            .map(|(id, _)| *id)
            .collect();
        for id in gone {
            if let Some(t) = ft.toplevels.remove(&id) {
                for h in t.handles.iter().filter(|h| h.is_alive()) {
                    h.closed();
                }
            }
        }

        for (window, snap) in current {
            let existing = ft
                .toplevels
                .iter_mut()
                .find(|(_, t)| t.window == window)
                .map(|(_, t)| t);
            match existing {
                Some(t) => {
                    t.handles.retain(|h| h.is_alive());
                    if t.last != snap {
                        for h in &t.handles {
                            send_changes(h, &t.last, &snap, false);
                        }
                        t.last = snap;
                    }
                }
                None => {
                    let id = ft.next_id;
                    ft.next_id += 1;
                    let mut handles = Vec::new();
                    for manager in &ft.managers {
                        if let Some(client) = manager.client() {
                            handles.extend(announce(&dh, &client, manager, id, &snap));
                        }
                    }
                    ft.toplevels.insert(id, Tracked { window, handles, last: snap });
                }
            }
        }
    }
}

impl GlobalDispatch<ZwlrForeignToplevelManagerV1, (), State> for State {
    fn bind(
        state: &mut State,
        dh: &DisplayHandle,
        client: &Client,
        resource: New<ZwlrForeignToplevelManagerV1>,
        _: &(),
        data_init: &mut DataInit<'_, State>,
    ) {
        let manager = data_init.init(resource, ());
        // Tell the new client about every window that already exists.
        let ft = &mut state.foreign_toplevel;
        for (id, t) in ft.toplevels.iter_mut() {
            t.handles.retain(|h| h.is_alive());
            t.handles.extend(announce(dh, client, &manager, *id, &t.last));
        }
        ft.managers.push(manager);
    }
}

impl Dispatch<ZwlrForeignToplevelManagerV1, (), State> for State {
    fn request(
        state: &mut State,
        _: &Client,
        resource: &ZwlrForeignToplevelManagerV1,
        request: zwlr_foreign_toplevel_manager_v1::Request,
        _: &(),
        _: &DisplayHandle,
        _: &mut DataInit<'_, State>,
    ) {
        if let zwlr_foreign_toplevel_manager_v1::Request::Stop = request {
            resource.finished();
            state.foreign_toplevel.managers.retain(|m| m != resource);
        }
    }
}

impl Dispatch<ZwlrForeignToplevelHandleV1, u64, State> for State {
    fn request(
        state: &mut State,
        _: &Client,
        _: &ZwlrForeignToplevelHandleV1,
        request: zwlr_foreign_toplevel_handle_v1::Request,
        id: &u64,
        _: &DisplayHandle,
        _: &mut DataInit<'_, State>,
    ) {
        use zwlr_foreign_toplevel_handle_v1::Request as R;
        let Some(window) = state
            .foreign_toplevel
            .toplevels
            .get(id)
            .map(|t| t.window.clone())
        else {
            return;
        };
        let Some(toplevel) = window.toplevel().cloned() else {
            return;
        };
        match request {
            R::SetMaximized => {
                state.set_window_expanded(&toplevel, xdg_toplevel::State::Maximized, None)
            }
            R::UnsetMaximized => state.restore_window(&toplevel, xdg_toplevel::State::Maximized),
            R::SetFullscreen { output } => {
                let output = output.as_ref().and_then(smithay::output::Output::from_resource);
                state.set_window_expanded(&toplevel, xdg_toplevel::State::Fullscreen, output)
            }
            R::UnsetFullscreen => state.restore_window(&toplevel, xdg_toplevel::State::Fullscreen),
            R::Activate { .. } => {
                state.focus_window(Some(&window));
            }
            R::Close => toplevel.send_close(),
            // There is no minimized state yet (see `minimize_request`), and
            // the rectangle is only a hint for minimize animations.
            R::SetMinimized | R::UnsetMinimized | R::SetRectangle { .. } | R::Destroy => {}
            _ => {}
        }
    }

    fn destroyed(
        state: &mut State,
        _: ClientId,
        resource: &ZwlrForeignToplevelHandleV1,
        id: &u64,
    ) {
        if let Some(t) = state.foreign_toplevel.toplevels.get_mut(id) {
            t.handles.retain(|h| h != resource);
        }
    }
}
