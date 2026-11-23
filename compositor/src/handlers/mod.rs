mod compositor;
mod layer_shell;
mod xdg_shell;

use smithay::{
    backend::allocator::dmabuf::Dmabuf,
    input::{
        Seat, SeatHandler, SeatState,
        dnd::{DnDGrab, DndGrabHandler, DndTarget, GrabType, Source},
        pointer::{CursorImageStatus, Focus},
        tablet::TabletSeatHandler,
    },
    reexports::{
        wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        wayland_server::{Resource, protocol::wl_surface::WlSurface},
    },
    utils::{Logical, Point, Serial},
    wayland::{
        dmabuf::{DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier},
        foreign_toplevel_list::{ForeignToplevelListHandler, ForeignToplevelListState},
        fractional_scale::FractionalScaleHandler,
        output::OutputHandler,
        pointer_constraints::PointerConstraintsHandler,
        selection::{
            SelectionHandler,
            data_device::{
                DataDeviceHandler, DataDeviceState, WaylandDndGrabHandler, set_data_device_focus,
            },
            primary_selection::{
                PrimarySelectionHandler, PrimarySelectionState, set_primary_focus,
            },
        },
        shell::xdg::{ToplevelSurface, decoration::XdgDecorationHandler},
        xdg_activation::{
            XdgActivationHandler, XdgActivationState, XdgActivationToken, XdgActivationTokenData,
        },
    },
};
use tracing::debug;

use crate::state::State;

//
// Seat
//

impl SeatHandler for State {
    type KeyboardFocus = WlSurface;
    type PointerFocus = WlSurface;
    type TouchFocus = WlSurface;

    fn seat_state(&mut self) -> &mut SeatState<State> {
        &mut self.seat_state
    }

    fn cursor_image(&mut self, _seat: &Seat<Self>, image: CursorImageStatus) {
        self.cursor_status = image;
    }

    fn focus_changed(&mut self, seat: &Seat<Self>, focused: Option<&WlSurface>) {
        let dh = &self.display_handle;
        let client = focused.and_then(|s| dh.get_client(s.id()).ok());
        set_data_device_focus(dh, seat, client.clone());
        set_primary_focus(dh, seat, client);
    }
}

impl TabletSeatHandler for State {
    type ToolFocus = WlSurface;
}
impl PointerConstraintsHandler for State {}

//
// Clipboard, primary selection, drag and drop
//

impl SelectionHandler for State {
    type SelectionUserData = ();
}

impl DataDeviceHandler for State {
    fn data_device_state(&mut self) -> &mut DataDeviceState {
        &mut self.data_device_state
    }
}

impl PrimarySelectionHandler for State {
    fn primary_selection_state(&mut self) -> &mut PrimarySelectionState {
        &mut self.primary_selection_state
    }
}

impl DndGrabHandler for State {
    fn dropped(
        &mut self,
        _target: Option<DndTarget<'_, Self>>,
        _validated: bool,
        _seat: Seat<Self>,
        _location: Point<f64, Logical>,
    ) {
        self.dnd_icon = None;
    }

    fn cancelled(&mut self, _seat: Seat<Self>, _location: Point<f64, Logical>) {
        self.dnd_icon = None;
    }
}
impl WaylandDndGrabHandler for State {
    fn dnd_requested<S: Source>(
        &mut self,
        source: S,
        icon: Option<WlSurface>,
        seat: Seat<Self>,
        serial: Serial,
        type_: GrabType,
    ) {
        self.dnd_icon = icon.map(|surface| crate::state::DndIcon {
            surface,
            offset: (0, 0).into(), placed: false,
        });

        match type_ {
            GrabType::Pointer => {
                let ptr = seat.get_pointer().unwrap();
                let Some(start_data) = ptr.grab_start_data() else {
                    source.cancel();
                    self.dnd_icon = None;
                    return;
                };
                let grab = DnDGrab::new_pointer(&self.display_handle, start_data, source, seat);
                ptr.set_grab(self, grab, serial, Focus::Keep);
            }
            GrabType::Touch => {
                let touch = seat.get_touch().unwrap();
                let Some(start_data) = touch.grab_start_data() else {
                    source.cancel();
                    self.dnd_icon = None;
                    return;
                };
                let grab = DnDGrab::new_touch(&self.display_handle, start_data, source, seat);
                touch.set_grab(self, grab, serial);
            }
        }
    }
}

//
// Output
//

impl OutputHandler for State {}

//
// Window decorations
//
// The base draws no server-side decorations (look and feel comes later), and
// Althyn's own apps are frameless with their own titlebars, so every client is
// told to decorate itself.
//

impl State {
    /// Server-side for clients that want a titlebar from us; Althyn's own apps
    /// and clients that ask for client-side keep drawing their own.
    fn negotiate_decoration(&mut self, toplevel: ToplevelSurface, wants_client: bool) {
        let own = {
            let id = smithay::wayland::compositor::with_states(toplevel.wl_surface(), |s| {
                s.data_map
                    .get::<smithay::wayland::shell::xdg::XdgToplevelSurfaceData>()
                    .and_then(|d| d.lock().ok().and_then(|d| d.app_id.clone()))
            })
            .unwrap_or_default();
            crate::render::is_self_decorated(&id)
        };
        let server = !wants_client && !own;
        toplevel.with_pending_state(|s| {
            s.decoration_mode = Some(if server { DecorationMode::ServerSide } else { DecorationMode::ClientSide });
        });
        crate::titlebar::set_server_decorated(toplevel.wl_surface(), server);
        if toplevel.is_initial_configure_sent() {
            toplevel.send_pending_configure();
        }
    }
}

impl XdgDecorationHandler for State {
    fn new_decoration(&mut self, toplevel: ToplevelSurface) {
        self.negotiate_decoration(toplevel, false);
    }

    fn request_mode(&mut self, toplevel: ToplevelSurface, mode: DecorationMode) {
        self.negotiate_decoration(toplevel, mode == DecorationMode::ClientSide);
    }

    fn unset_mode(&mut self, toplevel: ToplevelSurface) {
        self.negotiate_decoration(toplevel, false);
    }
}

//
// Misc protocols
//

impl FractionalScaleHandler for State {}

impl ForeignToplevelListHandler for State {
    fn foreign_toplevel_list_state(&mut self) -> &mut ForeignToplevelListState {
        &mut self.foreign_toplevel_list
    }
}

impl XdgActivationHandler for State {
    fn activation_state(&mut self) -> &mut XdgActivationState {
        &mut self.xdg_activation_state
    }

    fn request_activation(
        &mut self,
        _token: XdgActivationToken,
        token_data: XdgActivationTokenData,
        surface: WlSurface,
    ) {
        // Only honour tokens that were handed out recently, so a stale token
        // cannot steal focus.
        if token_data.timestamp.elapsed().as_secs() > 10 {
            debug!("ignoring stale activation token");
            return;
        }
        if let Some(window) = self.window_for_surface(&surface) {
            self.focus_window(Some(&window));
        }
    }
}

//
// Buffers
//

impl DmabufHandler for State {
    fn dmabuf_state(&mut self) -> &mut DmabufState {
        &mut self.dmabuf_state
    }

    fn dmabuf_imported(&mut self, global: &DmabufGlobal, dmabuf: Dmabuf, notifier: ImportNotifier) {
        if self.backend.import_dmabuf(global, dmabuf) {
            let _ = notifier.successful::<State>();
        } else {
            notifier.failed();
        }
    }
}

smithay::delegate_dispatch2!(State);
