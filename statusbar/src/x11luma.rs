//! Samples the real screen pixels under the status bar (X11 only) and reports
//! their average brightness, so the bar can switch its clock/icons between
//! black (light background) and white (dark background) while it is
//! transparent. Like the Dock's x11maximize.rs this does nothing without an
//! X11 display (Wayland forbids reading other surfaces' pixels).

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type BarLuma = super::BarLumaRust;

        /// Average brightness 0.0 (black) .. 1.0 (white) of the given screen
        /// rectangle in device pixels, or -1.0 if it could not be sampled.
        #[qinvokable]
        fn luminance(self: &BarLuma, x: i32, y: i32, w: i32, h: i32) -> f64;
    }
}

use x11rb::connection::Connection;
use x11rb::protocol::xproto::{ConnectionExt, ImageFormat, ImageOrder};

#[derive(Default)]
pub struct BarLumaRust;

impl qobject::BarLuma {
    pub fn luminance(&self, x: i32, y: i32, w: i32, h: i32) -> f64 {
        sample(x, y, w, h).unwrap_or(-1.0)
    }
}

fn sample(x: i32, y: i32, w: i32, h: i32) -> Option<f64> {
    if !crate::x11maximize::should_use_x11() {
        return sample_wallpaper(x, y, w, h);
    }
    if std::env::var_os("DISPLAY").is_none() {
        return None;
    }
    let (conn, screen_num) = x11rb::connect(None).ok()?;
    let setup = conn.setup();
    let screen = &setup.roots[screen_num];
    let sw = screen.width_in_pixels as i32;
    let sh = screen.height_in_pixels as i32;

    let x = x.clamp(0, sw - 1);
    let y = y.clamp(0, sh - 1);
    let w = w.clamp(1, sw - x);
    let h = h.clamp(1, sh - y);

    let reply = conn
        .get_image(ImageFormat::Z_PIXMAP, screen.root, x as i16, y as i16, w as u16, h as u16, !0)
        .ok()?
        .reply()
        .ok()?;
    if reply.depth < 24 {
        return None; // only 24/32-bit TrueColor supported
    }

    let (w, h) = (w as usize, h as usize);
    let stride = reply.data.len() / h; // bytes per scanline (32-bit padded)
    if stride < w * 4 {
        return None;
    }
    let lsb = setup.image_byte_order == ImageOrder::LSB_FIRST;
    let step_x = (w / 160).max(1);
    let step_y = (h / 8).max(1);

    let (mut sum, mut n) = (0.0f64, 0u32);
    let mut row = 0;
    while row < h {
        let mut col = 0;
        while col < w {
            let i = row * stride + col * 4;
            let (r, g, b) = if lsb {
                (reply.data[i + 2], reply.data[i + 1], reply.data[i])
            } else {
                (reply.data[i + 1], reply.data[i + 2], reply.data[i + 3])
            };
            // Rec. 709 luma on the gamma-encoded values (good enough for a light/dark decision)
            sum += (0.2126 * r as f64 + 0.7152 * g as f64 + 0.0722 * b as f64) / 255.0;
            n += 1;
            col += step_x;
        }
        row += step_y;
    }
    if n == 0 { None } else { Some(sum / n as f64) }
}

// ---------------------------------------------------------------------------
// Wayland. Clients cannot read the screen, but the bar is laid out in its own
// reserved strip, so what shows through its transparent background is the
// wallpaper. Estimate the brightness from the wallpaper image the same way the
// session draws it (`swaybg -m fill`: scaled to cover the output, centered).

use std::sync::OnceLock;

const DEFAULT_WALLPAPER: &str = "/etc/VamoraSys/wallpapers/background.jpg";

struct Thumb {
    w: u32,
    h: u32,
    /// Rec. 709 luma per pixel, 0..1.
    luma: Vec<f32>,
}

fn wallpaper_thumb() -> Option<&'static Thumb> {
    static THUMB: OnceLock<Option<Thumb>> = OnceLock::new();
    THUMB
        .get_or_init(|| {
            let path = std::env::var("VAMORA_WALLPAPER").unwrap_or_else(|_| DEFAULT_WALLPAPER.into());
            let img = image::open(path).ok()?;
            let img = img.thumbnail(256, 256).to_rgb8();
            let luma = img
                .pixels()
                .map(|p| {
                    (0.2126 * p[0] as f32 + 0.7152 * p[1] as f32 + 0.0722 * p[2] as f32) / 255.0
                })
                .collect();
            Some(Thumb { w: img.width(), h: img.height(), luma })
        })
        .as_ref()
}

fn sample_wallpaper(x: i32, y: i32, w: i32, h: i32) -> Option<f64> {
    let thumb = wallpaper_thumb()?;
    let (sw, sh) = crate::wltoplevel::output_size()?;
    if sw <= 0 || sh <= 0 || w <= 0 || h <= 0 {
        return None;
    }
    // Cover-fit: scale so the image fills the output, centered.
    let (iw, ih) = (thumb.w as f64, thumb.h as f64);
    let scale = (sw as f64 / iw).max(sh as f64 / ih);
    let off_x = (sw as f64 - iw * scale) / 2.0;
    let off_y = (sh as f64 - ih * scale) / 2.0;

    let (mut sum, mut n) = (0.0f64, 0u32);
    let cols = 160.min(w).max(1);
    let rows = 8.min(h).max(1);
    for r in 0..rows {
        for c in 0..cols {
            let px = x as f64 + (c as f64 + 0.5) * w as f64 / cols as f64;
            let py = y as f64 + (r as f64 + 0.5) * h as f64 / rows as f64;
            let ix = (((px - off_x) / scale) as i64).clamp(0, thumb.w as i64 - 1) as usize;
            let iy = (((py - off_y) / scale) as i64).clamp(0, thumb.h as i64 - 1) as usize;
            sum += thumb.luma[iy * thumb.w as usize + ix] as f64;
            n += 1;
        }
    }
    if n == 0 { None } else { Some(sum / n as f64) }
}
