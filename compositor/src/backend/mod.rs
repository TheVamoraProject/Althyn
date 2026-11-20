//! Backends: where frames go and where input comes from.
//!
//! * [`winit`]: runs as a window inside another compositor / X11 session.
//!   Used for development and testing, and works on every architecture.
//! * `udev` (feature `udev`): runs on real hardware through DRM/KMS, GBM,
//!   libinput and libseat. Added in its own module.

use smithay::{
    backend::allocator::dmabuf::Dmabuf, reexports::wayland_server::protocol::wl_surface::WlSurface,
    wayland::dmabuf::DmabufGlobal,
};

#[cfg(feature = "udev")]
pub mod udev;
pub mod winit;

pub enum Backend {
    Winit(Box<winit::WinitData>),
    #[cfg(feature = "udev")]
    Udev(Box<udev::UdevData>),
}

impl Backend {
    pub fn name(&self) -> &'static str {
        match self {
            Backend::Winit(_) => "winit",
            #[cfg(feature = "udev")]
            Backend::Udev(_) => "udev",
        }
    }

    /// Imports a client dmabuf to check that the GPU can use it.
    #[cfg_attr(not(feature = "udev"), allow(unused_variables))]
    pub fn import_dmabuf(&mut self, global: &DmabufGlobal, dmabuf: Dmabuf) -> bool {
        match self {
            Backend::Winit(data) => data.import_dmabuf(&dmabuf),
            #[cfg(feature = "udev")]
            Backend::Udev(data) => data.import_dmabuf(global, dmabuf),
        }
    }

    /// Called on every surface commit, before the compositor looks at it.
    #[cfg_attr(not(feature = "udev"), allow(unused_variables))]
    pub fn early_import(&mut self, surface: &WlSurface) {
        match self {
            Backend::Winit(_) => {}
            #[cfg(feature = "udev")]
            Backend::Udev(data) => data.early_import(surface),
        }
    }

    /// Ctrl+Alt+F<n>. Only meaningful on real hardware.
    #[cfg_attr(not(feature = "udev"), allow(unused_variables))]
    pub fn switch_vt(&mut self, vt: i32) {
        match self {
            Backend::Winit(_) => {}
            #[cfg(feature = "udev")]
            Backend::Udev(data) => data.switch_vt(vt),
        }
    }
}
