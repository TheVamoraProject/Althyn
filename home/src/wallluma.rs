//! Brightness of the wallpaper behind a screen rectangle, so home-screen labels
//! can switch between light and dark text without any outline.
//!
//! Clients cannot read the screen on Wayland, but the home screen sits right
//! above the wallpaper, so what is behind a label is the wallpaper itself,
//! drawn the way `swaybg -m fill` does (scaled to cover the output, centred).

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type WallLuma = super::WallLumaRust;

        /// Average brightness 0.0 (black) .. 1.0 (white) of the rectangle
        /// (x, y, w, h) on an output of `screen_w` x `screen_h`, or -1.0 when
        /// the wallpaper could not be read.
        #[qinvokable]
        fn luminance(self: &WallLuma, x: i32, y: i32, w: i32, h: i32, screen_w: i32, screen_h: i32) -> f64;
    }
}

use std::sync::OnceLock;

const DEFAULT_WALLPAPER: &str = "/etc/VamoraSys/wallpapers/background.jpg";

#[derive(Default)]
pub struct WallLumaRust;

impl qobject::WallLuma {
    pub fn luminance(&self, x: i32, y: i32, w: i32, h: i32, screen_w: i32, screen_h: i32) -> f64 {
        sample(x, y, w, h, screen_w, screen_h).unwrap_or(-1.0)
    }
}

struct Thumb {
    w: u32,
    h: u32,
    /// Rec. 709 luma per pixel, 0..1.
    luma: Vec<f32>,
}

fn thumb() -> Option<&'static Thumb> {
    static THUMB: OnceLock<Option<Thumb>> = OnceLock::new();
    THUMB
        .get_or_init(|| {
            let path = std::env::var("VAMORA_WALLPAPER").unwrap_or_else(|_| DEFAULT_WALLPAPER.into());
            let img = image::open(path).ok()?.thumbnail(512, 512).to_rgb8();
            let luma = img
                .pixels()
                .map(|p| (0.2126 * p[0] as f32 + 0.7152 * p[1] as f32 + 0.0722 * p[2] as f32) / 255.0)
                .collect();
            Some(Thumb { w: img.width(), h: img.height(), luma })
        })
        .as_ref()
}

fn sample(x: i32, y: i32, w: i32, h: i32, sw: i32, sh: i32) -> Option<f64> {
    let t = thumb()?;
    if sw <= 0 || sh <= 0 || w <= 0 || h <= 0 {
        return None;
    }
    let (iw, ih) = (t.w as f64, t.h as f64);
    let scale = (sw as f64 / iw).max(sh as f64 / ih);
    let off_x = (sw as f64 - iw * scale) / 2.0;
    let off_y = (sh as f64 - ih * scale) / 2.0;

    let (cols, rows) = (24.min(w).max(1), 6.min(h).max(1));
    let (mut sum, mut n) = (0.0f64, 0u32);
    for r in 0..rows {
        for c in 0..cols {
            let px = x as f64 + (c as f64 + 0.5) * w as f64 / cols as f64;
            let py = y as f64 + (r as f64 + 0.5) * h as f64 / rows as f64;
            let ix = (((px - off_x) / scale) as i64).clamp(0, t.w as i64 - 1) as usize;
            let iy = (((py - off_y) / scale) as i64).clamp(0, t.h as i64 - 1) as usize;
            sum += t.luma[iy * t.w as usize + ix] as f64;
            n += 1;
        }
    }
    (n > 0).then(|| sum / n as f64)
}

#[cfg(test)]
mod tests {
    #[test]
    fn rejects_empty_rect() {
        assert!(super::sample(0, 0, 0, 10, 100, 100).is_none());
    }
}
