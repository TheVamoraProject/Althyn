//! Real-hardware backend: DRM/KMS + GBM + EGL/GLES, libinput, libseat.
//!
//! Structure and the order of operations follow Smithay's `anvil` udev backend
//! (MIT, Copyright Victor Berger / Drakulix and contributors), cut down to what
//! a first working base needs:
//!
//! * one GPU (the primary one, or `VAMORA_DRM_DEVICE=/dev/dri/cardN`) with a
//!   single `GlesRenderer`; no multi-GPU copies, no DRM leasing, no syncobj
//! * one `Output` per connected connector, placed left to right
//! * connector hot-plug (udev `Changed` events) and VT switching / session
//!   pause + resume
//! * a vblank driven render loop on top of `DrmCompositor`, which uses
//!   hardware planes (primary / cursor / overlay) whenever the driver allows
//!
//! Nothing here is architecture specific: the same code path runs on x86_64
//! (Intel / AMD / NVIDIA-nouveau) and aarch64 (Mesa drivers, Raspberry Pi
//! vc4/v3d, Panfrost, Freedreno, ...). Only generic 8/10-bit formats are asked
//! for, and `DrmCompositor` falls back through the list.

use std::{collections::HashMap, error::Error, io::Read, path::Path, sync::Mutex, time::Duration};

use smithay::{
    backend::{
        allocator::{
            Fourcc,
            dmabuf::Dmabuf,
            gbm::{GbmAllocator, GbmBufferFlags, GbmDevice},
        },
        drm::{
            DrmDevice, DrmDeviceFd, DrmEvent, DrmNode, NodeType,
            compositor::{DrmCompositor, FrameFlags},
            exporter::gbm::GbmFramebufferExporter,
        },
        egl::{EGLContext, EGLDevice, EGLDisplay, context::ContextPriority},
        input::InputEvent,
        libinput::{LibinputInputBackend, LibinputSessionInterface},
        renderer::{
            ImportDma, ImportMemWl,
            element::{
                Kind,
                memory::{MemoryRenderBuffer, MemoryRenderBufferRenderElement},
                render_elements,
                surface::{WaylandSurfaceRenderElement, render_elements_from_surface_tree},
            },
            gles::GlesRenderer,
        },
        session::{Event as SessionEvent, Session, libseat::LibSeatSession},
        udev::{UdevBackend, UdevEvent, all_gpus, primary_gpu},
    },
    desktop::{
        Window, layer_map_for_output,
        space::{SpaceRenderElements, space_render_elements},
    },
    input::pointer::{CursorImageAttributes, CursorImageStatus},
    output::{Mode as WlMode, Output, PhysicalProperties},
    reexports::{
        calloop::{
            EventLoop, RegistrationToken,
            timer::{TimeoutAction, Timer},
        },
        drm::control::{ModeTypeFlags, connector, crtc},
        input::{DeviceCapability, Libinput},
        rustix::fs::OFlags,
        wayland_server::{Display, backend::GlobalId, protocol::wl_surface::WlSurface},
    },
    utils::{DeviceFd, IsAlive, Point, Scale, Transform},
    wayland::{
        compositor::with_states,
        dmabuf::{DmabufFeedbackBuilder, DmabufGlobal},
    },
};
use smithay_drm_extras::drm_scanner::{DrmScanEvent, DrmScanner};
use tracing::{debug, error, info, warn};

use crate::{backend::Backend, state::State};

/// Scan-out formats, best first. `DrmCompositor` tests them in order until the
/// primary plane accepts one, so 10-bit is tried (and skipped) harmlessly.
const COLOR_FORMATS: &[Fourcc] = &[
    Fourcc::Abgr2101010,
    Fourcc::Argb2101010,
    Fourcc::Abgr8888,
    Fourcc::Argb8888,
];

/// Background shown behind everything (Althyn's `bgPrimary` in dark mode).
const CLEAR_COLOR: [f32; 4] = [0.0, 0.0, 0.0, 1.0];

/// How long to wait before looking for damage again when a repaint found none.
const IDLE_REPAINT: Duration = Duration::from_millis(16);

type Compositor =
    DrmCompositor<GbmAllocator<DrmDeviceFd>, GbmFramebufferExporter<DrmDeviceFd>, (), DrmDeviceFd>;

render_elements! {
    /// Everything drawn on one output, front to back.
    pub OutputElement<=GlesRenderer>;
    Cursor=MemoryRenderBufferRenderElement<GlesRenderer>,
    Surface=WaylandSurfaceRenderElement<GlesRenderer>,
    Space=SpaceRenderElements<GlesRenderer, WaylandSurfaceRenderElement<GlesRenderer>>,
}

/// One lit connector.
struct Surface {
    output: Output,
    global: GlobalId,
    compositor: Compositor,
    /// A frame was queued and its vblank has not arrived yet.
    frame_pending: bool,
    /// A repaint timer is already registered.
    render_scheduled: bool,
}

/// One opened DRM device.
struct Device {
    drm: DrmDevice,
    gbm: GbmDevice<DrmDeviceFd>,
    render_node: DrmNode,
    scanner: DrmScanner,
    surfaces: HashMap<crtc::Handle, Surface>,
    token: RegistrationToken,
}

pub struct UdevData {
    session: LibSeatSession,
    /// The GPU everything is rendered on (card node, as chosen at startup).
    primary: Option<DrmNode>,
    renderer: Option<GlesRenderer>,
    devices: HashMap<DrmNode, Device>,
    cursor: Cursor,
}

impl UdevData {
    pub fn import_dmabuf(&mut self, _global: &DmabufGlobal, dmabuf: Dmabuf) -> bool {
        self.renderer
            .as_mut()
            .map(|renderer| renderer.import_dmabuf(&dmabuf, None).is_ok())
            .unwrap_or(false)
    }

    /// With a single GPU there is nothing to import ahead of time: the
    /// renderer imports client buffers itself while drawing.
    pub fn early_import(&mut self, _surface: &WlSurface) {}

    pub fn switch_vt(&mut self, vt: i32) {
        info!(vt, "switching VT");
        if let Err(err) = self.session.change_vt(vt) {
            error!("could not switch to VT {vt}: {err}");
        }
    }
}

// ---------------------------------------------------------------------------
// Startup
// ---------------------------------------------------------------------------

pub fn init(
    event_loop: &mut EventLoop<'static, State>,
    display: Display<State>,
) -> Result<State, Box<dyn Error>> {
    let (session, session_notifier) = LibSeatSession::new()
        .map_err(|err| format!("could not open a session (libseat): {err}"))?;
    let seat_name = session.seat();

    // Which GPU? An explicit override wins (useful on ARM boards with a
    // separate display and render node), then the boot GPU, then any GPU.
    let wanted = std::env::var_os("VAMORA_DRM_DEVICE")
        .map(std::path::PathBuf::from)
        .or_else(|| primary_gpu(&seat_name).ok().flatten())
        .or_else(|| {
            all_gpus(&seat_name)
                .ok()
                .and_then(|gpus| gpus.into_iter().next())
        })
        .ok_or("no GPU found")?;
    let wanted_node = DrmNode::from_path(&wanted)
        .map_err(|err| format!("{} is not a DRM node: {err}", wanted.display()))?;
    // `primary_gpu` may name the render node; modesetting needs the card node.
    let wanted_card = wanted_node
        .node_with_type(NodeType::Primary)
        .and_then(Result::ok)
        .unwrap_or(wanted_node);
    info!("preferred GPU: {wanted_card}");

    let data = UdevData {
        session: session.clone(),
        primary: None,
        renderer: None,
        devices: HashMap::new(),
        cursor: Cursor::load(),
    };
    let mut state = State::new(
        event_loop,
        display,
        Backend::Udev(Box::new(data)),
        &seat_name,
    );
    let handle = event_loop.handle();

    // ---- udev ------------------------------------------------------------
    let udev = UdevBackend::new(&seat_name).map_err(|err| format!("udev backend: {err}"))?;

    // Try the preferred card first, then the others, until one works.
    let mut candidates: Vec<_> = udev
        .device_list()
        .map(|(id, path)| (id, path.to_path_buf()))
        .collect();
    candidates.sort_by_key(|(id, _)| *id != wanted_card.dev_id());
    let mut last_error: Option<Box<dyn Error>> = None;
    for (device_id, path) in &candidates {
        let Ok(node) = DrmNode::from_dev_id(*device_id) else {
            continue;
        };
        match state.udev_device_added(node, path) {
            Ok(()) => {
                last_error = None;
                break;
            }
            Err(err) => {
                warn!("skipping {}: {err}", path.display());
                last_error = Some(err);
            }
        }
    }
    if let Some(err) = last_error {
        return Err(format!("no usable GPU: {err}").into());
    }

    // ---- protocols that depend on the renderer ---------------------------
    {
        let State {
            backend,
            shm_state,
            dmabuf_state,
            display_handle,
            ..
        } = &mut state;
        let Backend::Udev(data) = backend else {
            unreachable!()
        };
        let primary = data.primary.ok_or("no GPU was initialised")?;
        let render_node = data
            .devices
            .get(&primary)
            .map(|d| d.render_node)
            .unwrap_or(primary);
        let renderer = data.renderer.as_mut().ok_or("no renderer")?;

        shm_state.update_formats(renderer.shm_formats());
        let formats = renderer.dmabuf_formats();
        match DmabufFeedbackBuilder::new(render_node.dev_id(), formats.clone()).build() {
            Ok(feedback) => {
                dmabuf_state
                    .create_global_with_default_feedback::<State>(display_handle, &feedback);
            }
            Err(err) => {
                warn!(
                    ?err,
                    "dmabuf feedback unavailable, advertising linux-dmabuf v3"
                );
                dmabuf_state.create_global::<State>(display_handle, formats);
            }
        }
    }

    // ---- input -----------------------------------------------------------
    let mut libinput =
        Libinput::new_with_udev::<LibinputSessionInterface<LibSeatSession>>(session.into());
    libinput
        .udev_assign_seat(&seat_name)
        .map_err(|_| format!("libinput could not use seat {seat_name}"))?;
    let libinput_backend = LibinputInputBackend::new(libinput.clone());
    handle
        .insert_source(libinput_backend, |mut event, _, state| {
            if let InputEvent::DeviceAdded { device } = &mut event {
                // Sensible touchpad defaults; everything else is left to libinput.
                if device.has_capability(DeviceCapability::Pointer)
                    && device.config_tap_finger_count() > 0
                {
                    let _ = device.config_tap_set_enabled(true);
                }
            }
            state.process_input_event(event);
        })
        .map_err(|err| format!("could not register libinput: {err}"))?;

    // ---- session (VT switches) -------------------------------------------
    handle
        .insert_source(session_notifier, move |event, _, state| match event {
            SessionEvent::PauseSession => {
                info!("session paused");
                libinput.suspend();
                if let Backend::Udev(data) = &mut state.backend {
                    for device in data.devices.values_mut() {
                        device.drm.pause();
                    }
                }
            }
            SessionEvent::ActivateSession => {
                info!("session resumed");
                if libinput.resume().is_err() {
                    error!("could not resume libinput");
                }
                state.udev_resume();
            }
        })
        .map_err(|err| format!("could not register the session: {err}"))?;

    // ---- hot-plug --------------------------------------------------------
    handle
        .insert_source(udev, |event, _, state| match event {
            UdevEvent::Added { device_id, path } => {
                // Only the GPU we already drive matters; a second GPU is
                // ignored (single GPU base).
                if state.udev_primary().is_none() {
                    if let Ok(node) = DrmNode::from_dev_id(device_id) {
                        if let Err(err) = state.udev_device_added(node, &path) {
                            warn!("skipping {}: {err}", path.display());
                        }
                    }
                }
            }
            UdevEvent::Changed { device_id } => {
                if let Ok(node) = DrmNode::from_dev_id(device_id) {
                    state.udev_device_changed(node);
                }
            }
            UdevEvent::Removed { device_id } => {
                if let Ok(node) = DrmNode::from_dev_id(device_id) {
                    state.udev_device_removed(node);
                }
            }
        })
        .map_err(|err| format!("could not register udev: {err}"))?;

    info!("hardware backend ready");
    Ok(state)
}

// ---------------------------------------------------------------------------
// Devices and connectors
// ---------------------------------------------------------------------------

impl State {
    fn udev_data(&mut self) -> Option<&mut UdevData> {
        match &mut self.backend {
            Backend::Udev(data) => Some(data),
            #[allow(unreachable_patterns)]
            _ => None,
        }
    }

    fn udev_primary(&mut self) -> Option<DrmNode> {
        self.udev_data().and_then(|data| data.primary)
    }

    fn udev_surface(&mut self, node: DrmNode, crtc: crtc::Handle) -> Option<&mut Surface> {
        self.udev_data()?
            .devices
            .get_mut(&node)?
            .surfaces
            .get_mut(&crtc)
    }

    /// Opens a DRM device, brings up EGL/GLES on it and lights its connectors.
    fn udev_device_added(&mut self, node: DrmNode, path: &Path) -> Result<(), Box<dyn Error>> {
        let loop_handle = self.loop_handle.clone();
        let Some(data) = self.udev_data() else {
            return Err("not a udev backend".into());
        };
        if data.primary.is_some() {
            return Err("a GPU is already in use".into());
        }

        let fd = data.session.open(
            path,
            OFlags::RDWR | OFlags::CLOEXEC | OFlags::NOCTTY | OFlags::NONBLOCK,
        )?;
        let fd = DrmDeviceFd::new(DeviceFd::from(fd));
        let (drm, notifier) = DrmDevice::new(fd.clone(), true)?;
        let gbm = GbmDevice::new(fd)?;

        // EGL + GLES on this device. Software rasterisers are refused: with
        // no real GPU we cannot scan out anything useful.
        let display = unsafe { EGLDisplay::new(gbm.clone())? };
        let egl_device = EGLDevice::device_for_display(&display)?;
        if egl_device.is_software() {
            return Err("EGL only offers a software renderer on this device".into());
        }
        let render_node = egl_device
            .try_get_render_node()
            .ok()
            .flatten()
            .unwrap_or(node);
        let context = EGLContext::new_with_priority(&display, ContextPriority::High)
            .or_else(|_| EGLContext::new(&display))?;
        let renderer = unsafe { GlesRenderer::new(context)? };

        let token = loop_handle
            .insert_source(notifier, move |event, _, state| match event {
                DrmEvent::VBlank(crtc) => state.udev_vblank(node, crtc),
                DrmEvent::Error(err) => error!("DRM error on {node}: {err}"),
            })
            .map_err(|err| format!("could not register the DRM device: {err}"))?;

        info!(%node, %render_node, "GPU initialised");
        data.renderer = Some(renderer);
        data.primary = Some(node);
        data.devices.insert(
            node,
            Device {
                drm,
                gbm,
                render_node,
                scanner: DrmScanner::new(),
                surfaces: HashMap::new(),
                token,
            },
        );

        self.udev_device_changed(node);
        Ok(())
    }

    /// Re-scans the connectors of a device and reacts to plug / unplug.
    fn udev_device_changed(&mut self, node: DrmNode) {
        let Some(data) = self.udev_data() else { return };
        let Some(device) = data.devices.get_mut(&node) else {
            return;
        };
        let result = match device.scanner.scan_connectors(&device.drm) {
            Ok(result) => result,
            Err(err) => {
                warn!("could not scan the connectors of {node}: {err}");
                return;
            }
        };
        for event in result {
            match event {
                DrmScanEvent::Connected {
                    connector,
                    crtc: Some(crtc),
                } => {
                    self.udev_connector_connected(node, connector, crtc);
                }
                DrmScanEvent::Disconnected {
                    connector,
                    crtc: Some(crtc),
                } => {
                    self.udev_connector_disconnected(node, connector, crtc);
                }
                _ => {}
            }
        }
        self.fix_window_positions();
    }

    fn udev_connector_connected(
        &mut self,
        node: DrmNode,
        connector: connector::Info,
        crtc: crtc::Handle,
    ) {
        let Some(data) = self.udev_data() else { return };
        let (Some(device), Some(renderer)) = (data.devices.get_mut(&node), data.renderer.as_mut())
        else {
            return;
        };

        let name = format!(
            "{}-{}",
            connector.interface().as_str(),
            connector.interface_id()
        );
        let Some(drm_mode) = connector
            .modes()
            .iter()
            .find(|mode| mode.mode_type().contains(ModeTypeFlags::PREFERRED))
            .or_else(|| connector.modes().first())
            .copied()
        else {
            warn!("{name} has no modes, leaving it dark");
            return;
        };
        info!(%name, mode = ?drm_mode.name(), "lighting connector");

        let wl_mode = WlMode::from(drm_mode);
        let (phys_w, phys_h) = connector.size().unwrap_or((0, 0));
        let output = Output::new(
            name.clone(),
            PhysicalProperties {
                size: (phys_w as i32, phys_h as i32).into(),
                subpixel: connector.subpixel().into(),
                make: "Unknown".into(),
                model: "Unknown".into(),
                serial_number: "Unknown".into(),
            },
        );

        let drm_surface = match device
            .drm
            .create_surface(crtc, drm_mode, &[connector.handle()])
        {
            Ok(surface) => surface,
            Err(err) => {
                warn!("could not create a DRM surface for {name}: {err}");
                return;
            }
        };
        let allocator = GbmAllocator::new(
            device.gbm.clone(),
            GbmBufferFlags::RENDERING | GbmBufferFlags::SCANOUT,
        );
        let exporter =
            GbmFramebufferExporter::new(device.gbm.clone(), Some(device.render_node).into());
        let render_formats = renderer
            .egl_context()
            .dmabuf_render_formats()
            .iter()
            .copied();
        let compositor = match DrmCompositor::new(
            &output,
            drm_surface,
            None,
            allocator,
            exporter,
            COLOR_FORMATS.iter().copied(),
            render_formats,
            device.drm.cursor_size(),
            Some(device.gbm.clone()),
        ) {
            Ok(compositor) => compositor,
            Err(err) => {
                warn!("could not set up the compositor for {name}: {err}");
                return;
            }
        };

        // Lay outputs out left to right.
        let x = self
            .space
            .outputs()
            .filter_map(|o| self.space.output_geometry(o))
            .map(|geo| geo.loc.x + geo.size.w)
            .max()
            .unwrap_or(0);
        let position = (x, 0).into();
        let global = output.create_global::<State>(&self.display_handle);
        output.set_preferred(wl_mode);
        output.change_current_state(Some(wl_mode), Some(Transform::Normal), None, Some(position));
        self.space.map_output(&output, position);
        layer_map_for_output(&output).arrange();

        if let Some(device) = self.udev_data().and_then(|d| d.devices.get_mut(&node)) {
            device.surfaces.insert(
                crtc,
                Surface {
                    output,
                    global,
                    compositor,
                    frame_pending: false,
                    render_scheduled: false,
                },
            );
        }
        self.udev_schedule(node, crtc, Duration::ZERO);
    }

    fn udev_connector_disconnected(
        &mut self,
        node: DrmNode,
        connector: connector::Info,
        crtc: crtc::Handle,
    ) {
        let removed = self
            .udev_data()
            .and_then(|data| data.devices.get_mut(&node))
            .and_then(|device| device.surfaces.remove(&crtc));
        if let Some(surface) = removed {
            info!(
                "{}-{} unplugged",
                connector.interface().as_str(),
                connector.interface_id()
            );
            self.space.unmap_output(&surface.output);
            self.display_handle.remove_global::<State>(surface.global);
            self.space.refresh();
        }
    }

    fn udev_device_removed(&mut self, node: DrmNode) {
        let crtcs: Vec<_> = match self.udev_data().and_then(|data| data.devices.get(&node)) {
            Some(device) => device
                .scanner
                .crtcs()
                .map(|(info, crtc)| (info.clone(), crtc))
                .collect(),
            None => return,
        };
        for (connector, crtc) in crtcs {
            self.udev_connector_disconnected(node, connector, crtc);
        }
        let loop_handle = self.loop_handle.clone();
        if let Some(data) = self.udev_data() {
            if let Some(device) = data.devices.remove(&node) {
                loop_handle.remove(device.token);
            }
            if data.primary == Some(node) {
                // The GPU is gone; the renderer is useless without it.
                data.primary = None;
                data.renderer = None;
                error!("the GPU {node} was removed; rendering stopped");
            }
        }
        self.fix_window_positions();
    }

    /// After outputs changed, make sure no window is stranded off-screen.
    fn fix_window_positions(&mut self) {
        let Some(first) = self.space.outputs().next().cloned() else {
            return;
        };
        let Some(geo) = self.space.output_geometry(&first) else {
            return;
        };
        let stranded: Vec<Window> = self
            .space
            .elements()
            .filter(|w| {
                self.space
                    .element_geometry(w)
                    .map(|g| {
                        !self.space.outputs().any(|o| {
                            self.space
                                .output_geometry(o)
                                .is_some_and(|og| og.overlaps(g))
                        })
                    })
                    .unwrap_or(false)
            })
            .cloned()
            .collect();
        for window in stranded {
            self.space
                .map_element(window, geo.loc + Point::from((32, 32)), false);
        }
    }

    /// The VT came back: re-activate the DRM devices and repaint everything.
    fn udev_resume(&mut self) {
        let mut targets = Vec::new();
        if let Some(data) = self.udev_data() {
            for (node, device) in data.devices.iter_mut() {
                // `false`: keep the current KMS state, the first commit fixes it up.
                if let Err(err) = device.drm.activate(false) {
                    error!("could not re-activate {node}: {err}");
                    continue;
                }
                for (crtc, surface) in device.surfaces.iter_mut() {
                    surface.frame_pending = false;
                    targets.push((*node, *crtc));
                }
            }
        }
        for (node, crtc) in targets {
            self.udev_schedule(node, crtc, Duration::ZERO);
        }
    }
}

// ---------------------------------------------------------------------------
// Render loop
// ---------------------------------------------------------------------------

impl State {
    /// Registers one repaint of an output, unless one is already registered.
    fn udev_schedule(&mut self, node: DrmNode, crtc: crtc::Handle, delay: Duration) {
        let Some(surface) = self.udev_surface(node, crtc) else {
            return;
        };
        if surface.render_scheduled {
            return;
        }
        surface.render_scheduled = true;
        let registered =
            self.loop_handle
                .insert_source(Timer::from_duration(delay), move |_, _, state| {
                    if let Some(surface) = state.udev_surface(node, crtc) {
                        surface.render_scheduled = false;
                    }
                    state.udev_render(node, crtc);
                    TimeoutAction::Drop
                });
        if let Err(err) = registered {
            warn!("could not schedule a repaint: {err}");
            if let Some(surface) = self.udev_surface(node, crtc) {
                surface.render_scheduled = false;
            }
        }
    }

    /// The previous frame reached the screen: tell the compositor and draw the next one.
    fn udev_vblank(&mut self, node: DrmNode, crtc: crtc::Handle) {
        let Some(surface) = self.udev_surface(node, crtc) else {
            return;
        };
        surface.frame_pending = false;
        if let Err(err) = surface.compositor.frame_submitted() {
            warn!("frame_submitted failed: {err}");
        }
        self.udev_schedule(node, crtc, Duration::ZERO);
    }

    fn udev_render(&mut self, node: DrmNode, crtc: crtc::Handle) {
        let pointer_location = self
            .seat
            .get_pointer()
            .map(|pointer| pointer.current_location())
            .unwrap_or_default();

        // `rendered`: Some(true) = a frame was queued (vblank will follow),
        // Some(false) = nothing changed, None = something failed.
        let (output, rendered) = {
            let State {
                backend,
                space,
                cursor_status,
                ..
            } = self;
            let Backend::Udev(data) = backend else { return };
            let UdevData {
                renderer,
                devices,
                cursor,
                ..
            } = &mut **data;
            let (Some(renderer), Some(device)) = (renderer.as_mut(), devices.get_mut(&node)) else {
                return;
            };
            if !device.drm.is_active() {
                return; // VT switched away; resume re-schedules us
            }
            let Some(surface) = device.surfaces.get_mut(&crtc) else {
                return;
            };
            if surface.frame_pending {
                return; // the vblank handler will call us
            }
            let output = surface.output.clone();
            let Some(output_geo) = space.output_geometry(&output) else {
                return;
            };
            let scale = Scale::from(output.current_scale().fractional_scale());

            let mut elements: Vec<OutputElement> = Vec::new();

            // Pointer first: elements are ordered front to back.
            if output_geo.to_f64().contains(pointer_location) {
                let relative = pointer_location - output_geo.loc.to_f64();
                match &*cursor_status {
                    CursorImageStatus::Hidden => {}
                    CursorImageStatus::Surface(cursor_surface) if cursor_surface.alive() => {
                        let hotspot = with_states(cursor_surface, |states| {
                            states
                                .data_map
                                .get::<Mutex<CursorImageAttributes>>()
                                .map(|attrs| attrs.lock().unwrap().hotspot)
                                .unwrap_or_default()
                        });
                        let location = (relative - hotspot.to_f64())
                            .to_physical(scale)
                            .to_i32_round();
                        elements.extend(
                            render_elements_from_surface_tree::<
                                _,
                                WaylandSurfaceRenderElement<GlesRenderer>,
                            >(
                                renderer, cursor_surface, location, scale, 1.0, Kind::Cursor
                            )
                            .into_iter()
                            .map(OutputElement::Surface),
                        );
                    }
                    // Named cursors (and dead cursor surfaces) get the theme's default arrow.
                    _ => {
                        let location = (relative - cursor.hotspot.to_f64()).to_physical(scale);
                        match MemoryRenderBufferRenderElement::from_buffer(
                            renderer,
                            location,
                            &cursor.buffer,
                            None,
                            None,
                            None,
                            Kind::Cursor,
                        ) {
                            Ok(element) => elements.push(OutputElement::Cursor(element)),
                            Err(err) => debug!("could not upload the cursor: {err}"),
                        }
                    }
                }
            }

            match space_render_elements::<_, Window, _>(renderer, [&*space], &output, 1.0) {
                Ok(space_elements) => {
                    elements.extend(space_elements.into_iter().map(OutputElement::Space));
                }
                Err(err) => warn!("could not collect the scene: {err:?}"),
            }

            let rendered = match surface.compositor.render_frame(
                renderer,
                &elements,
                CLEAR_COLOR,
                FrameFlags::DEFAULT,
            ) {
                Ok(result) => {
                    if result.is_empty {
                        Some(false)
                    } else {
                        match surface.compositor.queue_frame(()) {
                            Ok(()) => {
                                surface.frame_pending = true;
                                Some(true)
                            }
                            Err(err) => {
                                warn!("could not queue a frame: {err}");
                                None
                            }
                        }
                    }
                }
                Err(err) => {
                    warn!("render error: {err}");
                    None
                }
            };
            (output, rendered)
        };

        // Clients draw their next frame when they get this callback.
        self.send_frames(&output);
        self.space.refresh();
        self.popups.cleanup();
        let _ = self.display_handle.flush_clients();

        match rendered {
            // Queued: the vblank event schedules the next repaint.
            Some(true) => {}
            // Idle or failed: look again in about a frame.
            Some(false) | None => self.udev_schedule(node, crtc, IDLE_REPAINT),
        }
    }
}

// ---------------------------------------------------------------------------
// Cursor image
// ---------------------------------------------------------------------------

/// The default arrow, uploaded once. Client-provided cursor surfaces are
/// rendered directly and never touch this.
struct Cursor {
    buffer: MemoryRenderBuffer,
    hotspot: Point<i32, smithay::utils::Logical>,
}

impl Cursor {
    /// Loads `default` from `XCURSOR_THEME` / `XCURSOR_SIZE` (like every other
    /// toolkit), falling back to a built-in arrow if there is no theme.
    fn load() -> Self {
        let theme = std::env::var("XCURSOR_THEME").unwrap_or_else(|_| "default".into());
        let size = std::env::var("XCURSOR_SIZE")
            .ok()
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(24);

        match Self::from_theme(&theme, size) {
            Some(cursor) => cursor,
            None => {
                warn!("no xcursor theme {theme:?}, using the built-in arrow");
                Self::fallback()
            }
        }
    }

    fn from_theme(theme: &str, size: u32) -> Option<Self> {
        let path = xcursor::CursorTheme::load(theme).load_icon("default")?;
        let mut data = Vec::new();
        std::fs::File::open(path)
            .ok()?
            .read_to_end(&mut data)
            .ok()?;
        let images = xcursor::parser::parse_xcursor(&data)?;
        let image = images
            .iter()
            .min_by_key(|image| (size as i32 - image.size as i32).abs())?;
        let buffer = MemoryRenderBuffer::from_slice(
            &image.pixels_rgba,
            // xcursor stores R, G, B, A bytes; that is DRM's ABGR8888 on little endian.
            Fourcc::Abgr8888,
            (image.width as i32, image.height as i32),
            1,
            Transform::Normal,
            None,
        );
        Some(Self {
            buffer,
            hotspot: (image.xhot as i32, image.yhot as i32).into(),
        })
    }

    fn fallback() -> Self {
        const ARROW: [&str; 16] = [
            "#           ",
            "##          ",
            "#.#         ",
            "#..#        ",
            "#...#       ",
            "#....#      ",
            "#.....#     ",
            "#......#    ",
            "#.......#   ",
            "#........#  ",
            "#.....#####.",
            "#..#..#     ",
            "#.# #..#    ",
            "##  #..#    ",
            "#    #..#   ",
            "     ###    ",
        ];
        let (w, h) = (12usize, ARROW.len());
        let mut pixels = vec![0u8; w * h * 4];
        for (y, row) in ARROW.iter().enumerate() {
            for (x, c) in row.chars().take(w).enumerate() {
                let rgba = match c {
                    '#' => [0, 0, 0, 255],
                    '.' => [255, 255, 255, 255],
                    _ => [0, 0, 0, 0],
                };
                pixels[(y * w + x) * 4..][..4].copy_from_slice(&rgba);
            }
        }
        Self {
            buffer: MemoryRenderBuffer::from_slice(
                &pixels,
                Fourcc::Abgr8888,
                (w as i32, h as i32),
                1,
                Transform::Normal,
                None,
            ),
            hotspot: (0, 0).into(),
        }
    }
}
