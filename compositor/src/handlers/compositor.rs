use smithay::{
    backend::renderer::utils::on_commit_buffer_handler,
    reexports::wayland_server::{
        Client,
        protocol::{wl_buffer, wl_surface::WlSurface},
    },
    wayland::{
        buffer::BufferHandler,
        compositor::{
            CompositorClientState, CompositorHandler, CompositorState, get_parent,
            is_sync_subsurface,
        },
        shm::{ShmHandler, ShmState},
    },
};

use super::xdg_shell;
use crate::{
    grabs::resize_grab,
    shell::window_data,
    state::{ClientState, State},
};

impl CompositorHandler for State {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }

    fn commit(&mut self, surface: &WlSurface) {
        on_commit_buffer_handler::<Self>(surface);
        self.backend.early_import(surface);

        if !is_sync_subsurface(surface) {
            let mut root = surface.clone();
            while let Some(parent) = get_parent(&root) {
                root = parent;
            }
            if let Some(window) = self.window_for_surface(&root) {
                window.on_commit();
            }
        }

        // xdg toplevels / popups: initial configure and first placement.
        xdg_shell::handle_commit(self, surface);
        resize_grab::handle_commit(&mut self.space, surface);

        // layer-shell surfaces: arrange, initial configure, exclusive focus.
        self.handle_layer_commit(surface);

        // First commit with a real size: put the window where it belongs.
        if let Some(window) = self.window_for_surface(surface) {
            let (placed, sized) = {
                let data = window_data(&window).borrow();
                (
                    data.placed,
                    window.geometry().size.w > 0 && window.geometry().size.h > 0,
                )
            };
            if !placed && sized {
                self.place_window(&window);
                // A launcher holding exclusive keyboard focus keeps it.
                if !self.focus_exclusive_layer() {
                    self.focus_window(Some(&window));
                }
            }
        }
    }
}

impl BufferHandler for State {
    fn buffer_destroyed(&mut self, _buffer: &wl_buffer::WlBuffer) {}
}

impl ShmHandler for State {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}
