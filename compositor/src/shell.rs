//! Window management policy: placement, focus, hit testing.
//!
//! Althyn's base is a plain floating window manager. Layer-shell surfaces
//! (wallpaper, status bar, dock, launcher, ...) are laid out by Smithay's
//! `LayerMap`; normal windows live in the `Space` and are kept inside the
//! "non-exclusive zone", i.e. the output minus whatever the layer surfaces
//! reserved with their exclusive zones.

use std::cell::RefCell;
use std::time::{Duration, Instant};

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
    /// When the window first appeared (drives the open animation).
    pub opened_at: Option<std::time::Instant>,
    /// Geometry to return to when leaving maximized / fullscreen.
    pub restore: Option<Rectangle<i32, Logical>>,
    /// Handle announced through ext-foreign-toplevel-list.
    pub foreign: Option<ForeignToplevelHandle>,
    /// Cached titlebar raster (compositor-drawn decorations).
    pub title: Option<(crate::titlebar::Key, smithay::backend::renderer::element::memory::MemoryRenderBuffer)>,
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
        // A compositor-drawn titlebar sits above the client: keep it in the zone.
        let tb = if crate::titlebar::is_ssd(window) { crate::titlebar::HEIGHT } else { 0 };
        let free: Size<i32, Logical> =
            Size::from(((zone.size.w - size.w).max(0), (zone.size.h - size.h - tb).max(0)));
        let step = (self.cascade % CASCADE_STEPS) * CASCADE_STEP;
        self.cascade += 1;
        let x = (free.w / 2 + step).min(free.w);
        let y = (free.h / 2 + step).min(free.h);

        self.space
            .map_element(window.clone(), zone.loc + Point::from((x, y + tb)), false);
        {
            let mut data = window_data(window).borrow_mut();
            data.placed = true;
            data.opened_at = Some(std::time::Instant::now());
        }
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

        if let Some(hit) = layer_hit(&[Layer::Overlay, Layer::Top]) {
            return Some(hit);
        }
        match self.window_hit(pos) {
            WindowHit::Surface(s, p) => return Some((s, p)),
            // A compositor titlebar is not a client surface, and it hides
            // whatever is behind it.
            WindowHit::Titlebar(..) => return None,
            WindowHit::None => {}
        }
        layer_hit(&[Layer::Bottom, Layer::Background])
    }

    /// Topmost window part under `pos`: client surface, or compositor titlebar.
    pub fn window_hit(&self, pos: Point<f64, Logical>) -> WindowHit {
        for window in self.space.elements().rev() {
            let Some(loc) = self.space.element_location(window) else { continue };
            if crate::titlebar::is_ssd(window)
                && let Some(part) = crate::titlebar::part_at(window, loc, pos)
            {
                return WindowHit::Titlebar(window.clone(), part);
            }
            if let Some((s, p)) = window.surface_under(pos - loc.to_f64(), WindowSurfaceType::ALL) {
                return WindowHit::Surface(s, (p + loc).to_f64());
            }
        }
        WindowHit::None
    }

    /// A press on a compositor titlebar: buttons, move, double-click maximize.
    pub fn titlebar_press(
        &mut self,
        window: Window,
        part: crate::titlebar::Part,
        pos: Point<f64, Logical>,
        serial: smithay::utils::Serial,
    ) {
        use crate::titlebar::Part;
        use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;

        self.focus_window(Some(&window));
        let Some(toplevel) = window.toplevel().cloned() else { return };
        let toggle_max = |state: &mut State| {
            if crate::titlebar::is_maximized(&window) {
                state.restore_window(&toplevel, xdg_toplevel::State::Maximized);
            } else {
                state.set_window_expanded(&toplevel, xdg_toplevel::State::Maximized, None);
            }
        };
        match part {
            Part::Close => toplevel.send_close(),
            Part::Maximize => toggle_max(self),
            Part::Bar => {
                let now = Instant::now();
                let double = self
                    .last_title_click
                    .take()
                    .is_some_and(|(t, w)| w == window && now.duration_since(t) < Duration::from_millis(400));
                if double {
                    toggle_max(self);
                    return;
                }
                self.last_title_click = Some((now, window.clone()));
                if crate::titlebar::is_maximized(&window) {
                    return;
                }
                let (Some(pointer), Some(initial)) =
                    (self.seat.get_pointer(), self.space.element_location(&window))
                else {
                    return;
                };
                let grab = crate::grabs::move_grab::MoveSurfaceGrab {
                    start_data: smithay::input::pointer::GrabStartData {
                        focus: None,
                        button: 0x110,
                        location: pos,
                    },
                    window,
                    initial_window_location: initial,
                };
                pointer.set_grab(self, grab, serial, smithay::input::pointer::Focus::Clear);
            }
        }
    }
}

pub enum WindowHit {
    Surface(WlSurface, Point<f64, Logical>),
    Titlebar(Window, crate::titlebar::Part),
    None,
}
