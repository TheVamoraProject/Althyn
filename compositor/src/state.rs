use std::{ffi::OsString, sync::Arc, time::{Duration, Instant}};

use smithay::{
    desktop::{PopupManager, Space, Window},
    input::{Seat, SeatState, keyboard::XkbConfig, pointer::CursorImageStatus},
    utils::{Logical, Point},
    reexports::{
        calloop::{
            EventLoop, Interest, LoopHandle, LoopSignal, Mode, PostAction, channel,
            generic::Generic,
            timer::{TimeoutAction, Timer},
        },
        wayland_server::{
            Display, DisplayHandle,
            backend::{ClientData, ClientId, DisconnectReason},
            protocol::wl_surface::WlSurface,
        },
    },
    wayland::{
        compositor::{CompositorClientState, CompositorState},
        cursor_shape::CursorShapeManagerState,
        dmabuf::DmabufState,
        foreign_toplevel_list::ForeignToplevelListState,
        fractional_scale::FractionalScaleManagerState,
        output::OutputManagerState,
        selection::{data_device::DataDeviceState, primary_selection::PrimarySelectionState},
        shell::{
            wlr_layer::WlrLayerShellState,
            xdg::{XdgShellState, decoration::XdgDecorationState},
        },
        shm::ShmState,
        socket::ListeningSocketSource,
        viewporter::ViewporterState,
        xdg_activation::XdgActivationState,
    },
};
use tracing::{info, warn};

use crate::{
    backend::Backend,
    config::{self, Config, KeyboardConfig},
};

/// Repeat delay (ms) and rate (keys/s) advertised to clients.
const KEY_REPEAT_DELAY: i32 = 200;
const KEY_REPEAT_RATE: i32 = 25;

/// Drag-and-drop icon surface plus where its origin sits relative to the pointer
/// (the client moves it with attach offsets).
#[derive(Debug)]
pub struct DndIcon {
    pub surface: WlSurface,
    pub offset: Point<i32, Logical>,
    /// True once the icon has been centred on the pointer (or the client gave its own hotspot).
    pub placed: bool,
}

impl DndIcon {
    /// Where the image sits relative to the pointer. Qt on Wayland sends no
    /// hotspot, so an image without one is centred on the pointer.
    pub fn effective_offset(&self) -> Point<i32, Logical> {
        if self.placed {
            return self.offset;
        }
        let size = smithay::desktop::utils::bbox_from_surface_tree(&self.surface, (0, 0)).size;
        (self.offset.x - size.w / 2, self.offset.y - size.h / 2).into()
    }
}

pub struct State {
    pub start_time: Instant,
    pub socket_name: OsString,
    pub display_handle: DisplayHandle,
    pub loop_handle: LoopHandle<'static, State>,
    pub loop_signal: LoopSignal,

    pub backend: Backend,
    pub config: Config,

    pub space: Space<Window>,
    pub popups: PopupManager,
    pub cursor_status: CursorImageStatus,
    /// The image a client wants drawn under the pointer while it drags something.
    pub dnd_icon: Option<DndIcon>,
    /// Counter used to cascade newly placed windows.
    pub cascade: i32,
    /// Last click on a compositor titlebar (double-click to maximize).
    pub last_title_click: Option<(std::time::Instant, smithay::desktop::Window)>,

    // Smithay protocol state
    pub compositor_state: CompositorState,
    pub xdg_shell_state: XdgShellState,
    pub xdg_decoration_state: XdgDecorationState,
    pub layer_shell_state: WlrLayerShellState,
    pub shm_state: ShmState,
    pub dmabuf_state: DmabufState,
    pub output_manager_state: OutputManagerState,
    pub seat_state: SeatState<State>,
    pub data_device_state: DataDeviceState,
    pub primary_selection_state: PrimarySelectionState,
    pub viewporter_state: ViewporterState,
    pub fractional_scale_state: FractionalScaleManagerState,
    pub cursor_shape_state: CursorShapeManagerState,
    pub xdg_activation_state: XdgActivationState,
    pub foreign_toplevel_list: ForeignToplevelListState,
    /// wlr-foreign-toplevel-management (Dock / StatusBar window info).
    pub foreign_toplevel: crate::foreign_toplevel::ForeignToplevelState,
    /// Layer surfaces that were already offered keyboard focus once.
    pub layer_focus_offered: Vec<WlSurface>,

    pub seat: Seat<Self>,
}

fn xkb_config(cfg: &KeyboardConfig) -> XkbConfig<'_> {
    XkbConfig {
        model: &cfg.model,
        layout: &cfg.layouts,
        variant: &cfg.variant,
        options: if cfg.options.is_empty() {
            None
        } else {
            Some(cfg.options.clone())
        },
        ..Default::default()
    }
}

impl State {
    pub fn new(
        event_loop: &mut EventLoop<'static, Self>,
        display: Display<Self>,
        backend: Backend,
        seat_name: &str,
    ) -> Self {
        let start_time = Instant::now();
        let dh = display.handle();
        let config = Config::load_initial();

        // Protocols needed for displaying windows.
        let compositor_state = CompositorState::new::<Self>(&dh);
        let xdg_shell_state = XdgShellState::new::<Self>(&dh);
        let xdg_decoration_state = XdgDecorationState::new::<Self>(&dh);
        let layer_shell_state = WlrLayerShellState::new::<Self>(&dh);
        let shm_state = ShmState::new::<Self>(&dh, vec![]);
        let output_manager_state = OutputManagerState::new_with_xdg_output::<Self>(&dh);
        let viewporter_state = ViewporterState::new::<Self>(&dh);
        let fractional_scale_state = FractionalScaleManagerState::new::<Self>(&dh);
        let cursor_shape_state = CursorShapeManagerState::new::<Self>(&dh);
        let xdg_activation_state = XdgActivationState::new::<Self>(&dh);
        let foreign_toplevel_list = ForeignToplevelListState::new::<Self>(&dh);
        let foreign_toplevel = crate::foreign_toplevel::ForeignToplevelState::new(&dh);
        let popups = PopupManager::default();

        // Clipboard + drag and drop, and the middle-click selection.
        let data_device_state = DataDeviceState::new::<Self>(&dh);
        let primary_selection_state = PrimarySelectionState::new::<Self>(&dh);

        // One seat with a keyboard and a pointer. Hot-plugged devices are all
        // multiplexed onto this seat by the backends.
        let mut seat_state = SeatState::new();
        let mut seat: Seat<Self> = seat_state.new_wl_seat(&dh, seat_name);

        let keyboard = seat.add_keyboard(
            xkb_config(&config.keyboard),
            KEY_REPEAT_DELAY,
            KEY_REPEAT_RATE,
        );
        if let Err(err) = keyboard {
            warn!("keyboard layout from VamoraSys rejected ({err:?}), falling back to defaults");
            seat.add_keyboard(Default::default(), KEY_REPEAT_DELAY, KEY_REPEAT_RATE)
                .expect("default keymap must compile");
        }
        seat.add_pointer();
        seat.add_touch();

        let socket_name = Self::init_wayland_listener(display, event_loop);
        let loop_signal = event_loop.get_signal();
        let loop_handle = event_loop.handle();

        // Live settings: a watcher thread re-reads VamoraSys and sends us a new
        // Config whenever it changed.
        let (tx, rx) = channel::channel::<Config>();
        config::spawn_watcher(config.clone(), tx);
        loop_handle
            .insert_source(rx, |event, _, state| {
                if let channel::Event::Msg(new) = event {
                    state.apply_config(new);
                }
            })
            .expect("failed to register the settings channel");

        // Notifications: D-Bus service on its own thread, toasts expire on a timer.
        let (ntx, nrx) = channel::channel::<crate::notify::Msg>();
        crate::notify::spawn(ntx);
        loop_handle
            .insert_source(nrx, |event, _, _| {
                if let channel::Event::Msg(msg) = event {
                    match msg {
                        crate::notify::Msg::Notify { n, .. } => crate::notify::show(n),
                        crate::notify::Msg::Close(id) => {
                            crate::notify::close(id, crate::notify::REASON_CLOSED)
                        }
                    }
                }
            })
            .expect("failed to register the notification channel");
        loop_handle
            .insert_source(
                smithay::reexports::calloop::timer::Timer::from_duration(std::time::Duration::from_millis(250)),
                |_, _, _| {
                    crate::notify::expire(std::time::Instant::now());
                    smithay::reexports::calloop::timer::TimeoutAction::ToDuration(std::time::Duration::from_millis(250))
                },
            )
            .expect("failed to register the notification timer");

        Self {
            start_time,
            socket_name,
            display_handle: dh,
            loop_handle,
            loop_signal,
            backend,
            config,
            space: Space::default(),
            popups,
            cursor_status: CursorImageStatus::default_named(),
            dnd_icon: None,
            cascade: 0,
            last_title_click: None,
            compositor_state,
            xdg_shell_state,
            xdg_decoration_state,
            layer_shell_state,
            shm_state,
            dmabuf_state: DmabufState::new(),
            output_manager_state,
            seat_state,
            data_device_state,
            primary_selection_state,
            viewporter_state,
            fractional_scale_state,
            cursor_shape_state,
            xdg_activation_state,
            foreign_toplevel_list,
            foreign_toplevel,
            layer_focus_offered: Vec::new(),
            seat,
        }
    }

    /// Applies freshly read VamoraSys settings.
    pub fn apply_config(&mut self, new: Config) {
        if new.keyboard != self.config.keyboard {
            if let Some(keyboard) = self.seat.get_keyboard() {
                match keyboard.set_xkb_config(self, xkb_config(&new.keyboard)) {
                    Ok(()) => info!(layouts = %new.keyboard.layouts, "keyboard layout updated"),
                    Err(err) => {
                        warn!("rejected new keyboard layout ({err:?}), keeping the old one")
                    }
                }
            }
        }
        if new.focus_mode != self.config.focus_mode {
            info!(mode = ?new.focus_mode, "focus mode updated");
        }
        self.config = new;
    }

    fn init_wayland_listener(
        display: Display<State>,
        event_loop: &mut EventLoop<'static, Self>,
    ) -> OsString {
        let listening_socket = ListeningSocketSource::new_auto().expect("no free wayland socket");
        let socket_name = listening_socket.socket_name().to_os_string();
        let loop_handle = event_loop.handle();

        loop_handle
            .insert_source(listening_socket, move |client_stream, _, state| {
                if let Err(err) = state
                    .display_handle
                    .insert_client(client_stream, Arc::new(ClientState::default()))
                {
                    warn!("failed to accept a client: {err}");
                }
            })
            .expect("failed to init the wayland listener");

        // Keep the Dock / StatusBar's view of the windows current (see
        // foreign_toplevel.rs); a diff of a few windows is practically free.
        loop_handle
            .insert_source(Timer::from_duration(Duration::from_millis(50)), |_, _, state| {
                state.refresh_foreign_toplevels();
                TimeoutAction::ToDuration(Duration::from_millis(50))
            })
            .expect("failed to register the toplevel refresh timer");

        loop_handle
            .insert_source(
                Generic::new(display, Interest::READ, Mode::Level),
                |_, display, state| {
                    // Safety: the display is never dropped while the loop runs.
                    unsafe {
                        display.get_mut().dispatch_clients(state).unwrap();
                    }
                    Ok(PostAction::Continue)
                },
            )
            .expect("failed to register the wayland display");

        socket_name
    }
}

/// Data associated with each connected wayland client.
#[derive(Default)]
pub struct ClientState {
    pub compositor_state: CompositorClientState,
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {}
    fn disconnected(&self, _client_id: ClientId, _reason: DisconnectReason) {}
}
