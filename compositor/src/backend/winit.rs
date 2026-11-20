//! Nested backend: a window inside another Wayland / X11 session.
//!
//! This is the development and CI backend; it needs no GPU access beyond what
//! the host session already gives the window. Based on Smithay's smallvil and
//! anvil winit backends (MIT).

use std::time::Duration;

use smithay::{
    backend::{
        egl::EGLDevice,
        renderer::{
            ImportDma, ImportMemWl, damage::OutputDamageTracker,
            element::surface::WaylandSurfaceRenderElement, gles::GlesRenderer,
        },
        winit::{self, WinitEvent, WinitGraphicsBackend},
    },
    desktop::{layer_map_for_output, space::render_output},
    output::{Mode, Output, PhysicalProperties, Subpixel},
    reexports::{
        calloop::EventLoop,
        winit::{
            cursor::{Cursor, CursorIcon},
            dpi::LogicalSize,
            window::WindowAttributes,
        },
        wayland_server::Display,
    },
    utils::Transform,
    wayland::dmabuf::DmabufFeedbackBuilder,
};
use tracing::{info, warn};

use crate::{backend::Backend, state::State};

pub const OUTPUT_NAME: &str = "winit";
/// Background shown behind everything (Althyn's `bgPrimary` in dark mode).
const CLEAR_COLOR: [f32; 4] = [0.0, 0.0, 0.0, 1.0];

pub struct WinitData {
    pub backend: WinitGraphicsBackend<GlesRenderer>,
    pub damage_tracker: OutputDamageTracker,
    pub output: Output,
}

impl WinitData {
    pub fn import_dmabuf(&mut self, dmabuf: &smithay::backend::allocator::dmabuf::Dmabuf) -> bool {
        self.backend.renderer().import_dmabuf(dmabuf, None).is_ok()
    }
}

pub fn init(
    event_loop: &mut EventLoop<'static, State>,
    display: Display<State>,
    size: Option<(f64, f64)>,
) -> Result<State, Box<dyn std::error::Error>> {
    let (width, height) = size.unwrap_or((1280.0, 800.0));
    let attributes = WindowAttributes::default()
        .with_surface_size(LogicalSize::new(width, height))
        .with_title("Althyn")
        .with_visible(true);
    let (mut graphics, winit_source) = winit::init_from_attributes::<GlesRenderer>(attributes)
        .map_err(|err| format!("could not open a nested window: {err}"))?;
    // The compositor does not draw a cursor itself when nested; without this
    // the host shows its default root cursor (an X) over our window.
    graphics.window().set_cursor(Cursor::Icon(CursorIcon::Default));

    let mode = Mode {
        size: graphics.window_size(),
        refresh: 60_000,
    };
    let output = Output::new(
        OUTPUT_NAME.to_string(),
        PhysicalProperties {
            size: (0, 0).into(),
            subpixel: Subpixel::Unknown,
            make: "Vamora".into(),
            model: "Winit".into(),
            serial_number: "Unknown".into(),
        },
    );
    output.change_current_state(
        Some(mode),
        Some(Transform::Flipped180),
        None,
        Some((0, 0).into()),
    );
    output.set_preferred(mode);

    // linux-dmabuf: lets GPU clients (Qt Quick, Mesa) hand over buffers
    // without a copy. v4 feedback needs the render node of the EGL device.
    let renderer = graphics.renderer();
    let render_node = EGLDevice::device_for_display(renderer.egl_context().display())
        .and_then(|device| device.try_get_render_node());
    let dmabuf_formats = renderer.dmabuf_formats();
    let shm_formats = renderer.shm_formats();
    let default_feedback = match render_node {
        Ok(Some(node)) => DmabufFeedbackBuilder::new(node.dev_id(), dmabuf_formats.clone())
            .build()
            .ok(),
        Ok(None) => {
            warn!("no render node for the EGL device, advertising linux-dmabuf v3");
            None
        }
        Err(err) => {
            warn!(
                ?err,
                "could not query the EGL device, advertising linux-dmabuf v3"
            );
            None
        }
    };

    let damage_tracker = OutputDamageTracker::from_output(&output);
    let data = WinitData {
        backend: graphics,
        damage_tracker,
        output: output.clone(),
    };
    let mut state = State::new(
        event_loop,
        display,
        Backend::Winit(Box::new(data)),
        OUTPUT_NAME,
    );

    let dh = state.display_handle.clone();
    output.create_global::<State>(&dh);
    state.space.map_output(&output, (0, 0));
    state.shm_state.update_formats(shm_formats);
    match default_feedback {
        Some(feedback) => {
            state
                .dmabuf_state
                .create_global_with_default_feedback::<State>(&dh, &feedback);
        }
        None => {
            state
                .dmabuf_state
                .create_global::<State>(&dh, dmabuf_formats);
        }
    }

    event_loop
        .handle()
        .insert_source(winit_source, move |event, _, state| match event {
            WinitEvent::Resized { size, .. } => {
                let mode = Mode {
                    size,
                    refresh: 60_000,
                };
                if let Some(output) = state.space.outputs().next().cloned() {
                    output.change_current_state(Some(mode), None, None, None);
                    output.set_preferred(mode);
                    layer_map_for_output(&output).arrange();
                }
            }
            WinitEvent::Input(event) => state.process_input_event(event),
            WinitEvent::Redraw => state.winit_redraw(),
            WinitEvent::CloseRequested => state.loop_signal.stop(),
            WinitEvent::Focus(_) => {}
        })
        .map_err(|err| format!("could not register the winit event source: {err}"))?;

    info!("nested backend ready");
    Ok(state)
}

impl State {
    fn winit_redraw(&mut self) {
        #[allow(irrefutable_let_patterns)]
        let Backend::Winit(data) = &mut self.backend else {
            return;
        };
        let output = data.output.clone();
        let size = data.backend.window_size();
        if size.w == 0 || size.h == 0 {
            return;
        }

        let age = data.backend.buffer_age().unwrap_or(0);
        let damage = {
            let Ok((renderer, mut framebuffer)) = data.backend.bind() else {
                warn!("could not bind the nested framebuffer");
                return;
            };
            match render_output::<_, WaylandSurfaceRenderElement<GlesRenderer>, _, _>(
                &output,
                renderer,
                &mut framebuffer,
                1.0,
                age,
                [&self.space],
                &[],
                &mut data.damage_tracker,
                CLEAR_COLOR,
            ) {
                Ok(result) => result.damage.cloned(),
                Err(err) => {
                    warn!("render error: {err}");
                    None
                }
            }
        };
        if let Some(damage) = damage {
            if let Err(err) = data.backend.submit(Some(&damage)) {
                warn!("failed to submit the frame: {err}");
            }
        }

        self.send_frames(&output);
        self.space.refresh();
        self.popups.cleanup();
        let _ = self.display_handle.flush_clients();

        // Keep rendering: ask the host for the next frame.
        #[allow(irrefutable_let_patterns)]
        if let Backend::Winit(data) = &self.backend {
            data.backend.window().request_redraw();
        }
    }

    /// Tells every visible client that it may draw its next frame.
    pub fn send_frames(&self, output: &Output) {
        let time = self.start_time.elapsed();
        let throttle = Some(Duration::ZERO);

        for window in self.space.elements() {
            window.send_frame(output, time, throttle, |_, _| Some(output.clone()));
        }
        for layer in layer_map_for_output(output).layers() {
            layer.send_frame(output, time, throttle, |_, _| Some(output.clone()));
        }
    }
}
