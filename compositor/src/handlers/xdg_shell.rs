use smithay::{
    desktop::{
        PopupKeyboardGrab, PopupKind, PopupPointerGrab, PopupUngrabStrategy, Window,
        find_popup_root_surface, get_popup_toplevel_coords, layer_map_for_output,
    },
    input::{
        Seat,
        pointer::{Focus, GrabStartData as PointerGrabStartData},
    },
    output::Output,
    reexports::{
        wayland_protocols::xdg::shell::server::xdg_toplevel,
        wayland_server::{
            Resource,
            protocol::{wl_output, wl_seat, wl_surface::WlSurface},
        },
    },
    utils::{Rectangle, Serial},
    wayland::{
        compositor::with_states,
        shell::xdg::{
            PopupSurface, PositionerState, ToplevelSurface, XdgShellHandler, XdgShellState,
            XdgToplevelSurfaceData,
        },
    },
};
use tracing::debug;

use crate::{
    grabs::{MoveSurfaceGrab, ResizeSurfaceGrab},
    shell::window_data,
    state::State,
};

impl XdgShellHandler for State {
    fn xdg_shell_state(&mut self) -> &mut XdgShellState {
        &mut self.xdg_shell_state
    }

    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        let window = Window::new_wayland_window(surface.clone());

        // Tell the client how much room there is so it can pick a sensible size.
        let zone = self.active_output().and_then(|o| self.usable_zone(&o));
        if let Some(zone) = zone {
            surface.with_pending_state(|s| s.bounds = Some(zone.size));
        }

        // Announce the window to taskbars / docks (ext-foreign-toplevel-list).
        // Title and app id arrive later and are forwarded by the hooks below.
        let handle = self.foreign_toplevel_list.new_toplevel::<State>("", "");
        window_data(&window).borrow_mut().foreign = Some(handle);

        // Mapped right away at the corner of the usable area so commits can be
        // matched to it; it is moved to its real position (and focused) on the
        // first commit that carries a size. Nothing is drawn before that.
        let loc = zone.map(|z| z.loc).unwrap_or_default();
        self.space.map_element(window, loc, false);
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let had_focus = self
            .seat
            .get_keyboard()
            .and_then(|k| k.current_focus())
            .is_some_and(|f| &f == surface.wl_surface());

        if let Some(handle) = window_data(&window).borrow_mut().foreign.take() {
            handle.send_closed();
        }
        self.space.unmap_elem(&window);

        if had_focus && !self.focus_exclusive_layer() {
            self.focus_top_window();
        }
    }

    fn title_changed(&mut self, surface: ToplevelSurface) {
        self.forward_toplevel_info(&surface);
    }

    fn app_id_changed(&mut self, surface: ToplevelSurface) {
        self.forward_toplevel_info(&surface);
    }

    fn new_popup(&mut self, surface: PopupSurface, _positioner: PositionerState) {
        self.unconstrain_popup(&surface);
        let _ = self.popups.track_popup(PopupKind::Xdg(surface));
    }

    fn reposition_request(
        &mut self,
        surface: PopupSurface,
        positioner: PositionerState,
        token: u32,
    ) {
        surface.with_pending_state(|state| {
            let geometry = positioner.get_geometry();
            state.geometry = geometry;
            state.positioner = positioner;
        });
        self.unconstrain_popup(&surface);
        surface.send_repositioned(token);
    }

    fn grab(&mut self, surface: PopupSurface, seat: wl_seat::WlSeat, serial: Serial) {
        let Some(seat) = Seat::<State>::from_resource(&seat) else {
            return;
        };
        let kind = PopupKind::Xdg(surface);
        let Ok(root) = find_popup_root_surface(&kind) else {
            return;
        };

        let Ok(mut grab) = self.popups.grab_popup(root, kind, &seat, serial) else {
            return;
        };

        if let Some(keyboard) = seat.get_keyboard() {
            if keyboard.is_grabbed()
                && !(keyboard.has_grab(serial)
                    || keyboard.has_grab(grab.previous_serial().unwrap_or(serial)))
            {
                grab.ungrab(PopupUngrabStrategy::All);
                return;
            }
            keyboard.set_focus(self, grab.current_grab(), serial);
            keyboard.set_grab(self, PopupKeyboardGrab::new(&grab), serial);
        }
        if let Some(pointer) = seat.get_pointer() {
            if pointer.is_grabbed()
                && !(pointer.has_grab(serial)
                    || pointer.has_grab(grab.previous_serial().unwrap_or_else(|| grab.serial())))
            {
                grab.ungrab(PopupUngrabStrategy::All);
                return;
            }
            pointer.set_grab(self, PopupPointerGrab::new(&grab), serial, Focus::Keep);
        }
    }

    fn move_request(&mut self, surface: ToplevelSurface, seat: wl_seat::WlSeat, serial: Serial) {
        let Some(seat) = Seat::<State>::from_resource(&seat) else {
            return;
        };
        let Some(start_data) = check_grab(&seat, surface.wl_surface(), serial) else {
            return;
        };
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let Some(initial_window_location) = self.space.element_location(&window) else {
            return;
        };

        let pointer = seat.get_pointer().unwrap();
        let grab = MoveSurfaceGrab {
            start_data,
            window,
            initial_window_location,
        };
        pointer.set_grab(self, grab, serial, Focus::Clear);
    }

    fn resize_request(
        &mut self,
        surface: ToplevelSurface,
        seat: wl_seat::WlSeat,
        serial: Serial,
        edges: xdg_toplevel::ResizeEdge,
    ) {
        let Some(seat) = Seat::<State>::from_resource(&seat) else {
            return;
        };
        let Some(start_data) = check_grab(&seat, surface.wl_surface(), serial) else {
            return;
        };
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let Some(initial_window_location) = self.space.element_location(&window) else {
            return;
        };
        let initial_window_size = window.geometry().size;

        surface.with_pending_state(|state| {
            state.states.set(xdg_toplevel::State::Resizing);
        });
        surface.send_pending_configure();

        let pointer = seat.get_pointer().unwrap();
        let grab = ResizeSurfaceGrab::start(
            start_data,
            window,
            edges.into(),
            Rectangle::new(initial_window_location, initial_window_size),
        );
        pointer.set_grab(self, grab, serial, Focus::Clear);
    }

    fn maximize_request(&mut self, surface: ToplevelSurface) {
        self.set_window_expanded(&surface, xdg_toplevel::State::Maximized, None);
    }

    fn unmaximize_request(&mut self, surface: ToplevelSurface) {
        self.restore_window(&surface, xdg_toplevel::State::Maximized);
    }

    fn fullscreen_request(
        &mut self,
        surface: ToplevelSurface,
        output: Option<wl_output::WlOutput>,
    ) {
        let output = output.as_ref().and_then(Output::from_resource);
        self.set_window_expanded(&surface, xdg_toplevel::State::Fullscreen, output);
    }

    fn unfullscreen_request(&mut self, surface: ToplevelSurface) {
        self.restore_window(&surface, xdg_toplevel::State::Fullscreen);
    }

    fn minimize_request(&mut self, surface: ToplevelSurface) {
        // There is nothing that could bring a minimized window back yet (that
        // needs the dock to speak a window management protocol), so the window
        // is deliberately left visible instead of being lost.
        debug!(
            app_id = ?with_states(surface.wl_surface(), |s| s
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .and_then(|d| d.lock().ok().and_then(|d| d.app_id.clone()))),
            "minimize requested; ignored until a dock protocol exists"
        );
    }
}

fn check_grab(
    seat: &Seat<State>,
    surface: &WlSurface,
    serial: Serial,
) -> Option<PointerGrabStartData<State>> {
    let pointer = seat.get_pointer()?;

    // The request must come from a click this client received.
    if !pointer.has_grab(serial) {
        return None;
    }
    let start_data = pointer.grab_start_data()?;
    let (focus, _) = start_data.focus.as_ref()?;
    if !focus.id().same_client_as(&surface.id()) {
        return None;
    }
    Some(start_data)
}

/// Called from every surface commit: initial configures and popup bookkeeping.
pub fn handle_commit(state: &mut State, surface: &WlSurface) {
    if let Some(window) = state.window_for_surface(surface) {
        let initial_configure_sent = with_states(surface, |states| {
            states
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .unwrap()
                .lock()
                .unwrap()
                .initial_configure_sent
        });
        if !initial_configure_sent {
            window.toplevel().unwrap().send_configure();
        }
    }

    state.popups.commit(surface);
    if let Some(PopupKind::Xdg(xdg)) = state.popups.find_popup(surface) {
        if !xdg.is_initial_configure_sent() {
            // The initial configure is always allowed.
            xdg.send_configure().expect("initial configure failed");
        }
    }
}

impl State {
    /// Pushes the current title / app id of a toplevel to its foreign handle.
    fn forward_toplevel_info(&mut self, surface: &ToplevelSurface) {
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let (title, app_id) = with_states(surface.wl_surface(), |states| {
            let data = states
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .unwrap()
                .lock()
                .unwrap();
            (
                data.title.clone().unwrap_or_default(),
                data.app_id.clone().unwrap_or_default(),
            )
        });
        if let Some(handle) = window_data(&window).borrow().foreign.as_ref() {
            handle.send_title(&title);
            handle.send_app_id(&app_id);
            handle.send_done();
        }
    }

    /// Maximize / fullscreen: fill the usable zone (maximize) or the whole
    /// output (fullscreen), remembering the old geometry.
    pub(crate) fn set_window_expanded(
        &mut self,
        surface: &ToplevelSurface,
        mode: xdg_toplevel::State,
        output: Option<Output>,
    ) {
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let output = output
            .or_else(|| self.space.outputs_for_element(&window).first().cloned())
            .or_else(|| self.active_output());
        let Some(output) = output else { return };

        let target = if mode == xdg_toplevel::State::Fullscreen {
            self.space.output_geometry(&output)
        } else {
            self.usable_zone(&output)
        };
        let Some(target) = target else { return };

        {
            let mut data = window_data(&window).borrow_mut();
            if data.restore.is_none() {
                data.restore = self.space.element_geometry(&window);
            }
        }

        surface.with_pending_state(|s| {
            s.states.set(mode);
            s.size = Some(target.size);
        });
        self.space.map_element(window, target.loc, true);
        if surface.is_initial_configure_sent() {
            surface.send_pending_configure();
        }
    }

    pub(crate) fn restore_window(&mut self, surface: &ToplevelSurface, mode: xdg_toplevel::State) {
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        let restore = window_data(&window).borrow_mut().restore.take();

        surface.with_pending_state(|s| {
            s.states.unset(mode);
            s.size = restore.map(|r| r.size);
        });
        if let Some(restore) = restore {
            self.space.map_element(window, restore.loc, true);
        }
        if surface.is_initial_configure_sent() {
            surface.send_pending_configure();
        }
    }

    fn unconstrain_popup(&self, popup: &PopupSurface) {
        let kind = PopupKind::Xdg(popup.clone());
        let Ok(root) = find_popup_root_surface(&kind) else {
            return;
        };

        // Where the popup's root surface sits, and the area the popup must stay in.
        let (root_loc, bounds) = if let Some(window) = self.window_for_surface(&root) {
            let output = self
                .space
                .outputs_for_element(&window)
                .first()
                .cloned()
                .or_else(|| self.space.outputs().next().cloned());
            let (Some(output), Some(window_geo)) = (output, self.space.element_geometry(&window))
            else {
                return;
            };
            let Some(output_geo) = self.space.output_geometry(&output) else {
                return;
            };
            (window_geo.loc, output_geo)
        } else if let Some((output, layer_loc)) = self.space.outputs().find_map(|o| {
            let map = layer_map_for_output(o);
            let layer =
                map.layer_for_surface(&root, smithay::desktop::WindowSurfaceType::TOPLEVEL)?;
            let loc = map.layer_geometry(layer)?.loc;
            Some((o.clone(), loc))
        }) {
            let Some(output_geo) = self.space.output_geometry(&output) else {
                return;
            };
            (output_geo.loc + layer_loc, output_geo)
        } else {
            return;
        };

        // The target for the positioner is relative to the popup's parent.
        let mut target = bounds;
        target.loc -= get_popup_toplevel_coords(&kind);
        target.loc -= root_loc;

        popup.with_pending_state(|state| {
            state.geometry = state.positioner.get_unconstrained_geometry(target);
        });
    }
}
