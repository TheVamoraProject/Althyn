//! wlr-layer-shell: wallpaper, status bar, dock, home screen, launcher.
//!
//! Layout is done by Smithay's `LayerMap` (anchors, margins and exclusive
//! zones); this module maps / unmaps surfaces and handles focus.

use smithay::{
    backend::renderer::utils::with_renderer_surface_state,
    desktop::{LayerSurface, WindowSurfaceType, layer_map_for_output},
    output::Output,
    reexports::wayland_server::protocol::{wl_output::WlOutput, wl_surface::WlSurface},
    wayland::{
        compositor::with_states,
        shell::wlr_layer::{
            KeyboardInteractivity, Layer, LayerSurface as WlrLayerSurface, LayerSurfaceData,
            WlrLayerShellHandler, WlrLayerShellState,
        },
    },
};
use smithay::{reexports::wayland_server::Resource, utils::SERIAL_COUNTER};
use tracing::{debug, warn};

use crate::state::State;

impl WlrLayerShellHandler for State {
    fn shell_state(&mut self) -> &mut WlrLayerShellState {
        &mut self.layer_shell_state
    }

    fn new_layer_surface(
        &mut self,
        surface: WlrLayerSurface,
        wl_output: Option<WlOutput>,
        layer: Layer,
        namespace: String,
    ) {
        let output = wl_output
            .as_ref()
            .and_then(Output::from_resource)
            .or_else(|| self.active_output());
        let Some(output) = output else {
            warn!(%namespace, "layer surface without any output, closing it");
            surface.send_close();
            return;
        };
        debug!(%namespace, ?layer, output = %output.name(), "new layer surface");

        let mut map = layer_map_for_output(&output);
        if let Err(err) = map.map_layer(&LayerSurface::new(surface, namespace)) {
            warn!("could not map layer surface: {err}");
        }
    }

    fn layer_destroyed(&mut self, surface: WlrLayerSurface) {
        let had_focus = self
            .seat
            .get_keyboard()
            .and_then(|k| k.current_focus())
            .is_some_and(|f| &f == surface.wl_surface());

        if let Some((mut map, layer)) = self.space.outputs().find_map(|o| {
            let map = layer_map_for_output(o);
            let layer = map
                .layers()
                .find(|l| l.layer_surface() == &surface)
                .cloned();
            layer.map(|layer| (map, layer))
        }) {
            map.unmap_layer(&layer);
        }

        // Do not leave the keyboard on a dead surface.
        if had_focus && !self.focus_exclusive_layer() {
            self.focus_top_window();
        }
    }
}

impl State {
    /// Called from every surface commit; does nothing for non-layer surfaces.
    pub fn handle_layer_commit(&mut self, surface: &WlSurface) {
        let Some(output) = self.space.outputs().find(|o| {
            layer_map_for_output(o)
                .layer_for_surface(surface, WindowSurfaceType::TOPLEVEL)
                .is_some()
        }) else {
            return;
        };

        let initial_configure_sent = with_states(surface, |states| {
            states
                .data_map
                .get::<LayerSurfaceData>()
                .unwrap()
                .lock()
                .unwrap()
                .initial_configure_sent
        });

        {
            let mut map = layer_map_for_output(output);
            // Arrange first so the initial configure respects the requested
            // size, anchors and exclusive zone.
            map.arrange();
            if !initial_configure_sent {
                if let Some(layer) = map.layer_for_surface(surface, WindowSurfaceType::TOPLEVEL) {
                    layer.layer_surface().send_configure();
                }
            }
        }

        // A launcher-style surface asking for exclusive keyboard focus gets it.
        if !self.focus_exclusive_layer() {
            self.focus_new_on_demand_layer(surface);
        }
    }

    /// Popups such as the status bar's menus are Top/Overlay layer surfaces
    /// with on-demand keyboard interactivity. Give such a surface the keyboard
    /// the first time it shows content, like a newly opened window, so that
    /// clicking anywhere else takes focus away again and lets it close itself.
    /// Later commits never steal the focus back.
    fn focus_new_on_demand_layer(&mut self, surface: &WlSurface) {
        self.layer_focus_offered.retain(|s| s.is_alive());
        if self.layer_focus_offered.contains(surface) {
            return;
        }
        // The commit handler has already moved the attached buffer into the
        // renderer's surface state, so ask that whether there is content.
        let has_buffer = with_renderer_surface_state(surface, |state| state.buffer().is_some())
            .unwrap_or(false);
        if !has_buffer {
            return;
        }
        let wanted = self
            .layer_shell_state
            .layer_surfaces()
            .find(|l| l.wl_surface() == surface)
            .is_some_and(|l| {
                l.with_cached_state(|d| {
                    d.keyboard_interactivity == KeyboardInteractivity::OnDemand
                        && matches!(d.layer, Layer::Top | Layer::Overlay)
                })
            });
        self.layer_focus_offered.push(surface.clone());
        if wanted && let Some(keyboard) = self.seat.get_keyboard() {
            keyboard.set_focus(self, Some(surface.clone()), SERIAL_COUNTER.next_serial());
        }
    }
}
