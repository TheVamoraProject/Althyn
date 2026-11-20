//! Window management policy: placement, focus, hit testing.
//!
//! Althyn's base is a plain floating window manager. Layer-shell surfaces
//! (wallpaper, status bar, dock, launcher, ...) are laid out by Smithay's
//! `LayerMap`; normal windows live in the `Space` and are kept inside the
//! "non-exclusive zone", i.e. the output minus whatever the layer surfaces
//! reserved with their exclusive zones.

use std::cell::RefCell;

use smithay::{
    desktop::{Window, WindowSurfaceType, layer_map_for_output},
    output::Output,
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    utils::{Logical, Point, Rectangle, SERIAL_COUNTER, Size},
    wayland::{
        foreign_toplevel_list::ForeignToplevelHandle,
        shell::wlr_layer::{KeyboardInteractivity, Layer},
    },
};

use crate::state::State;

/// Compositor-side bookkeeping attached to every toplevel [`Window`].
#[derive(Default)]
pub struct WindowData {
    /// The window has been given its initial position.
    pub placed: bool,
    /// Geometry to return to when leaving maximized / fullscreen.
    pub restore: Option<Rectangle<i32, Logical>>,
    /// Handle announced through ext-foreign-toplevel-list.
    pub foreign: Option<ForeignToplevelHandle>,
}

pub fn window_data(window: &Window) -> &RefCell<WindowData> {
    window
        .user_data()
        .get_or_insert(|| RefCell::new(WindowData::default()))
}

/// Offset between cascaded windows.
const CASCADE_STEP: i32 = 28;
const CASCADE_STEPS: i32 = 8;

impl State {
    pub fn window_for_surface(&self, surface: &WlSurface) -> Option<Window> {
        self.space
            .elements()
            .find(|w| w.toplevel().is_some_and(|t| t.wl_surface() == surface))
            .cloned()
    }

    /// The output the pointer is on, else the first output.
    pub fn active_output(&self) -> Option<Output> {
        let pos = self.seat.get_pointer()?.current_location();
        self.space
            .output_under(pos)
            .next()
            .or_else(|| self.space.outputs().next())
            .cloned()
    }

    /// Output rectangle minus layer-shell exclusive zones, in global
    /// coordinates. Windows are placed and maximized inside this.
    pub fn usable_zone(&self, output: &Output) -> Option<Rectangle<i32, Logical>> {
        let geo = self.space.output_geometry(output)?;
        let zone = layer_map_for_output(output).non_exclusive_zone();
        Some(Rectangle::new(geo.loc + zone.loc, zone.size))
    }

    /// Gives a window its first position once its size is known: centred in
    /// the usable zone, cascaded so consecutive windows do not stack exactly.
    pub fn place_window(&mut self, window: &Window) {
        let Some(output) = self.active_output() else {
            return;
        };
        let Some(zone) = self.usable_zone(&output) else {
            return;
        };

        let size = window.geometry().size;
        let free: Size<i32, Logical> =
            Size::from(((zone.size.w - size.w).max(0), (zone.size.h - size.h).max(0)));
        let step = (self.cascade % CASCADE_STEPS) * CASCADE_STEP;
        self.cascade += 1;
        let x = (free.w / 2 + step).min(free.w);
        let y = (free.h / 2 + step).min(free.h);

        self.space
            .map_element(window.clone(), zone.loc + Point::from((x, y)), false);
        window_data(window).borrow_mut().placed = true;
    }

    /// Focuses (and raises) `window`; `None` clears window focus.
    pub fn focus_window(&mut self, window: Option<&Window>) {
        let serial = SERIAL_COUNTER.next_serial();
        let Some(keyboard) = self.seat.get_keyboard() else {
            return;
        };

        match window {
            Some(window) => {
                // Raising with `activate` also deactivates every other window.
                self.space.raise_element(window, true);
                let surface = window.toplevel().map(|t| t.wl_surface().clone());
                keyboard.set_focus(self, surface, serial);
            }
            None => {
                self.space.elements().for_each(|w| {
                    w.set_activated(false);
                });
                keyboard.set_focus(self, Option::<WlSurface>::None, serial);
            }
        }
        for w in self.space.elements() {
            if let Some(t) = w.toplevel() {
                t.send_pending_configure();
            }
        }
    }

    /// Focus the top-most window, used after a window or layer goes away.
    pub fn focus_top_window(&mut self) {
        let top = self.space.elements().last().cloned();
        self.focus_window(top.as_ref());
    }

    /// A Top/Overlay layer surface asking for exclusive keyboard focus (for
    /// example the launcher) takes it. Returns whether one was found.
    pub fn focus_exclusive_layer(&mut self) -> bool {
        let serial = SERIAL_COUNTER.next_serial();
        let Some(keyboard) = self.seat.get_keyboard() else {
            return false;
        };

        let exclusive = self.layer_shell_state.layer_surfaces().rev().find(|layer| {
            layer.with_cached_state(|data| {
                data.keyboard_interactivity == KeyboardInteractivity::Exclusive
                    && matches!(data.layer, Layer::Top | Layer::Overlay)
            })
        });
        match exclusive {
            Some(layer) => {
                keyboard.set_focus(self, Some(layer.wl_surface().clone()), serial);
                true
            }
            None => false,
        }
    }

    /// Topmost surface under `pos` (global coordinates) and its origin.
    ///
    /// Stacking order, top to bottom: overlay layer, top layer, windows,
    /// bottom layer, background layer.
    pub fn surface_under(
        &self,
        pos: Point<f64, Logical>,
    ) -> Option<(WlSurface, Point<f64, Logical>)> {
        let output = self.space.outputs().find(|o| {
            self.space
                .output_geometry(o)
                .is_some_and(|g| g.contains(pos.to_i32_round()))
        })?;
        let geo = self.space.output_geometry(output)?;
        let rel = pos - geo.loc.to_f64();
        let map = layer_map_for_output(output);

        let layer_hit = |layers: &[Layer]| {
            layers
                .iter()
                .find_map(|l| map.layer_under(*l, rel))
                .and_then(|layer| {
                    let loc = map.layer_geometry(layer)?.loc;
                    layer
                        .surface_under(rel - loc.to_f64(), WindowSurfaceType::ALL)
                        .map(|(s, p)| (s, (p + loc).to_f64() + geo.loc.to_f64()))
                })
        };

        layer_hit(&[Layer::Overlay, Layer::Top])
            .or_else(|| {
                self.space.element_under(pos).and_then(|(window, loc)| {
                    window
                        .surface_under(pos - loc.to_f64(), WindowSurfaceType::ALL)
                        .map(|(s, p)| (s, (p + loc).to_f64()))
                })
            })
            .or_else(|| layer_hit(&[Layer::Bottom, Layer::Background]))
    }
}
