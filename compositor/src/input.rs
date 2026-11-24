//! Input handling shared by every backend (winit and libinput).
//!
//! Adapted from Smithay's smallvil and anvil examples (MIT).

use smithay::{
    backend::input::{
        AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, InputBackend, InputEvent,
        InputTime, KeyState, KeyboardKeyEvent, PointerAxisEvent, PointerButtonEvent,
        PointerMotionEvent, TouchEvent,
    },
    desktop::layer_map_for_output,
    input::{
        keyboard::{FilterResult, xkb::keysyms},
        pointer::{AxisFrame, ButtonEvent, MotionEvent, RelativeMotionEvent},
        touch::{DownEvent, MotionEvent as TouchMotionEvent, UpEvent},
    },
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    utils::{Logical, Point, SERIAL_COUNTER},
    wayland::shell::wlr_layer::Layer,
};

use crate::{config::FocusMode, state::State};

impl State {
    pub fn process_input_event<I: InputBackend>(&mut self, event: InputEvent<I>) {
        match event {
            InputEvent::Keyboard { event } => self.on_keyboard::<I>(event),
            InputEvent::PointerMotion { event } => self.on_pointer_motion::<I>(event),
            InputEvent::PointerMotionAbsolute { event } => {
                self.on_pointer_motion_absolute::<I>(event)
            }
            InputEvent::PointerButton { event } => self.on_pointer_button::<I>(event),
            InputEvent::PointerAxis { event } => self.on_pointer_axis::<I>(event),
            InputEvent::TouchDown { event } => self.on_touch_down::<I>(event),
            InputEvent::TouchMotion { event } => self.on_touch_motion::<I>(event),
            InputEvent::TouchUp { event } => self.on_touch_up::<I>(event),
            InputEvent::TouchFrame { .. } => {
                if let Some(touch) = self.seat.get_touch() {
                    touch.frame(self);
                }
            }
            InputEvent::TouchCancel { .. } => {
                if let Some(touch) = self.seat.get_touch() {
                    touch.cancel(self);
                }
            }
            _ => {}
        }
    }

    //
    // Keyboard
    //

    fn on_keyboard<I: InputBackend>(&mut self, event: I::KeyboardKeyEvent) {
        let serial = SERIAL_COUNTER.next_serial();
        let time = Event::<I>::time(&event);
        let key_state = event.state();
        let Some(keyboard) = self.seat.get_keyboard() else {
            return;
        };

        // The only compositor-level shortcuts in the base are the kernel-style
        // VT switches (Ctrl+Alt+F1..F12), which are meaningless on a nested
        // window but essential on real hardware. Everything else goes to the
        // focused client.
        let vt = keyboard.input::<u32, _>(
            self,
            event.key_code(),
            key_state,
            serial,
            time,
            |_, _, handle| {
                let sym = handle.modified_sym().raw();
                if key_state == KeyState::Pressed
                    && (keysyms::KEY_XF86Switch_VT_1..=keysyms::KEY_XF86Switch_VT_12).contains(&sym)
                {
                    FilterResult::Intercept(sym - keysyms::KEY_XF86Switch_VT_1 + 1)
                } else {
                    FilterResult::Forward
                }
            },
        );
        if let Some(vt) = vt {
            self.backend.switch_vt(vt as i32);
        }
    }

    //
    // Pointer
    //

    /// Keeps a pointer position inside the union of all outputs.
    pub fn clamp_to_outputs(&self, pos: Point<f64, Logical>) -> Point<f64, Logical> {
        let mut best: Option<Point<f64, Logical>> = None;
        let mut best_dist = f64::MAX;
        for output in self.space.outputs() {
            let Some(geo) = self.space.output_geometry(output) else {
                continue;
            };
            let (x0, y0) = (geo.loc.x as f64, geo.loc.y as f64);
            // Stay strictly inside so the pointer can never sit on a seam.
            let (x1, y1) = (
                (geo.loc.x + geo.size.w) as f64 - 1.0,
                (geo.loc.y + geo.size.h) as f64 - 1.0,
            );
            let clamped = Point::from((pos.x.clamp(x0, x1.max(x0)), pos.y.clamp(y0, y1.max(y0))));
            let dist = (clamped.x - pos.x).powi(2) + (clamped.y - pos.y).powi(2);
            if dist < best_dist {
                best_dist = dist;
                best = Some(clamped);
            }
        }
        best.unwrap_or(pos)
    }

    /// Moves the pointer to `pos` and handles focus-follows-mouse.
    fn pointer_moved_to(&mut self, pos: Point<f64, Logical>, time: InputTime) {
        let Some(pointer) = self.seat.get_pointer() else {
            return;
        };
        let serial = SERIAL_COUNTER.next_serial();
        let under = self.surface_under(pos);

        pointer.motion(
            self,
            under.clone(),
            &MotionEvent {
                location: pos,
                serial,
                time,
            },
        );
        pointer.frame(self);

        if self.config.focus_mode == FocusMode::Hover && !pointer.is_grabbed() {
            if let Some((surface, _)) = under {
                self.hover_focus(&surface);
            }
        }
    }

    /// Focus follows the pointer, without raising. Layer surfaces and popups
    /// never take focus this way.
    fn hover_focus(&mut self, surface: &WlSurface) {
        let mut root = surface.clone();
        while let Some(parent) = smithay::wayland::compositor::get_parent(&root) {
            root = parent;
        }
        let Some(window) = self.window_for_surface(&root) else {
            return;
        };
        let Some(keyboard) = self.seat.get_keyboard() else {
            return;
        };
        if keyboard.current_focus().as_ref() == Some(&root) {
            return;
        }
        // Do not pull focus away from an exclusive layer (e.g. the launcher).
        if self.focus_exclusive_layer() {
            return;
        }
        let serial = SERIAL_COUNTER.next_serial();
        for w in self.space.elements() {
            w.set_activated(*w == window);
        }
        keyboard.set_focus(self, Some(root), serial);
        for w in self.space.elements() {
            if let Some(t) = w.toplevel() {
                t.send_pending_configure();
            }
        }
    }

    fn on_pointer_motion<I: InputBackend>(&mut self, event: I::PointerMotionEvent) {
        let Some(pointer) = self.seat.get_pointer() else {
            return;
        };
        let location = pointer.current_location();
        let new = self.clamp_to_outputs(location + event.delta());
        let time = Event::<I>::time(&event);

        let under = self.surface_under(new);
        pointer.relative_motion(
            self,
            under,
            &RelativeMotionEvent {
                delta: event.delta(),
                delta_unaccel: event.delta_unaccel(),
                time: Event::<I>::time(&event),
            },
        );
        self.pointer_moved_to(new, time);
    }

    fn on_pointer_motion_absolute<I: InputBackend>(
        &mut self,
        event: I::PointerMotionAbsoluteEvent,
    ) {
        let Some(output) = self.space.outputs().next().cloned() else {
            return;
        };
        let Some(geo) = self.space.output_geometry(&output) else {
            return;
        };
        let pos = event.position_transformed(geo.size) + geo.loc.to_f64();
        self.pointer_moved_to(pos, Event::<I>::time(&event));
    }

    fn on_pointer_button<I: InputBackend>(&mut self, event: I::PointerButtonEvent) {
        let Some(pointer) = self.seat.get_pointer() else {
            return;
        };
        let serial = SERIAL_COUNTER.next_serial();
        let button_state = event.state();

        // Click on a notification toast dismisses it.
        if button_state == ButtonState::Pressed && !pointer.is_grabbed() && event.button_code() == 0x110 {
            if let Some(zone) = self.active_output().and_then(|o| self.usable_zone(&o))
                && let Some(id) = crate::notify::toast_at(zone, pointer.current_location())
            {
                crate::notify::close(id, crate::notify::REASON_DISMISSED);
                return;
            }
        }

        // Compositor titlebar: buttons, drag to move.
        if button_state == ButtonState::Pressed
            && !pointer.is_grabbed()
            && event.button_code() == 0x110
            && !self.focus_exclusive_layer()
        {
            let pos = pointer.current_location();
            if let crate::shell::WindowHit::Titlebar(window, part) = self.window_hit(pos)
                && self.surface_under(pos).is_none()
            {
                self.titlebar_press(window, part, pos, serial);
                return;
            }
        }

        // Click to focus. While a grab is active (popup menu, drag, move or
        // resize) the grab decides what happens.
        if button_state == ButtonState::Pressed && !pointer.is_grabbed() {
            self.focus_under(pointer.current_location());
        }

        pointer.button(
            self,
            &ButtonEvent {
                button: event.button_code(),
                state: button_state,
                serial,
                time: Event::<I>::time(&event),
            },
        );
        pointer.frame(self);
    }

    fn on_pointer_axis<I: InputBackend>(&mut self, event: I::PointerAxisEvent) {
        let Some(pointer) = self.seat.get_pointer() else {
            return;
        };
        let source = event.source();

        let amount = |axis| {
            event
                .amount(axis)
                .unwrap_or_else(|| event.amount_v120(axis).unwrap_or(0.0) * 15.0 / 120.)
        };
        let (h, v) = (amount(Axis::Horizontal), amount(Axis::Vertical));

        let mut frame = AxisFrame::new(Event::<I>::time(&event)).source(source);
        if h != 0.0 {
            frame = frame.value(Axis::Horizontal, h);
            if let Some(discrete) = event.amount_v120(Axis::Horizontal) {
                frame = frame.v120(Axis::Horizontal, discrete as i32);
            }
        }
        if v != 0.0 {
            frame = frame.value(Axis::Vertical, v);
            if let Some(discrete) = event.amount_v120(Axis::Vertical) {
                frame = frame.v120(Axis::Vertical, discrete as i32);
            }
        }
        if source == AxisSource::Finger {
            if event.amount(Axis::Horizontal) == Some(0.0) {
                frame = frame.stop(Axis::Horizontal);
            }
            if event.amount(Axis::Vertical) == Some(0.0) {
                frame = frame.stop(Axis::Vertical);
            }
        }

        pointer.axis(self, frame);
        pointer.frame(self);
    }

    //
    // Touch
    //

    fn touch_location<E: AbsolutePositionEvent<I>, I: InputBackend>(
        &self,
        event: &E,
    ) -> Option<Point<f64, Logical>> {
        let output = self.space.outputs().next()?;
        let geo = self.space.output_geometry(output)?;
        Some(event.position_transformed(geo.size) + geo.loc.to_f64())
    }

    fn on_touch_down<I: InputBackend>(&mut self, event: I::TouchDownEvent) {
        let Some(touch) = self.seat.get_touch() else {
            return;
        };
        let Some(location) = self.touch_location::<_, I>(&event) else {
            return;
        };

        let serial = SERIAL_COUNTER.next_serial();
        self.focus_under(location);
        let under = self.surface_under(location);
        touch.down(
            self,
            under,
            &DownEvent {
                slot: event.slot(),
                location,
                serial,
                time: Event::<I>::time(&event),
            },
        );
    }

    fn on_touch_motion<I: InputBackend>(&mut self, event: I::TouchMotionEvent) {
        let Some(touch) = self.seat.get_touch() else {
            return;
        };
        let Some(location) = self.touch_location::<_, I>(&event) else {
            return;
        };
        let under = self.surface_under(location);
        touch.motion(
            self,
            under,
            &TouchMotionEvent {
                slot: event.slot(),
                location,
                time: Event::<I>::time(&event),
            },
        );
    }

    fn on_touch_up<I: InputBackend>(&mut self, event: I::TouchUpEvent) {
        let Some(touch) = self.seat.get_touch() else {
            return;
        };
        let serial = SERIAL_COUNTER.next_serial();
        touch.up(
            self,
            &UpEvent {
                slot: event.slot(),
                serial,
                time: Event::<I>::time(&event),
            },
        );
    }

    //
    // Click / tap focus
    //

    /// Gives keyboard focus to whatever is at `pos`: overlay / top layer
    /// surfaces first, then windows (raised), then bottom / background layers.
    fn focus_under(&mut self, pos: Point<f64, Logical>) {
        // An exclusive layer surface (launcher, lock screen) keeps the keyboard.
        if self.focus_exclusive_layer() {
            return;
        }
        let Some(output) = self.space.output_under(pos).next().cloned() else {
            return;
        };
        let Some(geo) = self.space.output_geometry(&output) else {
            return;
        };
        let rel = pos - geo.loc.to_f64();
        let Some(keyboard) = self.seat.get_keyboard() else {
            return;
        };
        let serial = SERIAL_COUNTER.next_serial();

        let layer_focus = |layers: &[Layer]| -> Option<WlSurface> {
            let map = layer_map_for_output(&output);
            layers
                .iter()
                .find_map(|l| map.layer_under(*l, rel))
                .filter(|layer| layer.can_receive_keyboard_focus())
                .map(|layer| layer.wl_surface().clone())
        };

        if let Some(surface) = layer_focus(&[Layer::Overlay, Layer::Top]) {
            keyboard.set_focus(self, Some(surface), serial);
            return;
        }

        if let Some(window) = self.space.element_under(pos).map(|(w, _)| w.clone()) {
            self.focus_window(Some(&window));
            return;
        }

        if let Some(surface) = layer_focus(&[Layer::Bottom, Layer::Background]) {
            // Clicking the home screen / desktop: windows lose focus.
            self.space.elements().for_each(|w| {
                w.set_activated(false);
            });
            keyboard.set_focus(self, Some(surface), serial);
            for w in self.space.elements() {
                if let Some(t) = w.toplevel() {
                    t.send_pending_configure();
                }
            }
            return;
        }

        self.focus_window(None);
    }
}
