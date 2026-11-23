//! Compositor-drawn window titlebar (server-side decoration).
//!
//! Clients that ask for server-side decorations (foot, Qt apps, ...) get a
//! titlebar drawn here, in the colours of `appearance.theme`. Clients that draw
//! their own (GTK, Althyn's own apps) are left alone: they follow VamoraSys
//! themselves.
//!
//! The strip is rasterised on the CPU into a small ARGB buffer (title text and
//! the maximize / close glyphs) and cached per window until something it shows
//! changes.

use std::sync::{OnceLock, atomic::{AtomicBool, Ordering}};

use ab_glyph::{Font, FontVec, PxScale, ScaleFont};
use smithay::{
    desktop::Window,
    reexports::wayland_protocols::xdg::shell::server::xdg_toplevel,
    utils::{Logical, Point, Rectangle},
    wayland::{compositor::with_states, shell::xdg::XdgToplevelSurfaceData},
};

/// Titlebar height, logical px.
pub const HEIGHT: i32 = 38;
/// White / dark margin left, right and below a framed window, logical px.
pub const MARGIN: i32 = 6;

/// Set on a toplevel's surface once the client negotiated decorations with us.
/// `true` means the compositor draws the titlebar.
#[derive(Default)]
pub struct ServerDecorated(pub AtomicBool);

pub fn set_server_decorated(surface: &smithay::reexports::wayland_server::protocol::wl_surface::WlSurface, on: bool) {
    with_states(surface, |states| {
        states
            .data_map
            .get_or_insert_threadsafe(ServerDecorated::default)
            .0
            .store(on, Ordering::Relaxed);
    });
}

fn toplevel_state(window: &Window) -> (bool, bool, bool) {
    // (server decorated, maximized, fullscreen)
    let Some(t) = window.toplevel() else { return (false, false, false) };
    let decorated = with_states(t.wl_surface(), |states| {
        states
            .data_map
            .get::<ServerDecorated>()
            .is_some_and(|d| d.0.load(Ordering::Relaxed))
    });
    let (max, full) = t.with_pending_state(|s| {
        (
            s.states.contains(xdg_toplevel::State::Maximized),
            s.states.contains(xdg_toplevel::State::Fullscreen),
        )
    });
    (decorated, max, full)
}

/// The compositor draws this window's titlebar.
pub fn is_ssd(window: &Window) -> bool {
    let (decorated, _, full) = toplevel_state(window);
    decorated && !full && !crate::render::is_self_decorated(&crate::render::app_id(window))
}

pub fn is_maximized(window: &Window) -> bool {
    toplevel_state(window).1
}

pub fn title_of(window: &Window) -> String {
    window
        .toplevel()
        .and_then(|t| {
            with_states(t.wl_surface(), |states| {
                states.data_map.get::<XdgToplevelSurfaceData>().and_then(|d| {
                    let d = d.lock().unwrap();
                    d.title.clone().filter(|s| !s.is_empty()).or_else(|| d.app_id.clone())
                })
            })
        })
        .unwrap_or_default()
}

pub fn is_active(window: &Window) -> bool {
    window
        .toplevel()
        .is_some_and(|t| t.with_pending_state(|s| s.states.contains(xdg_toplevel::State::Activated)))
}

/// Side margin of the frame around this window (none when maximized).
pub fn side_margin(window: &Window) -> i32 {
    if is_maximized(window) { 0 } else { MARGIN }
}

/// The titlebar strip in global coordinates, given the client's location.
pub fn strip_rect(window: &Window, loc: Point<i32, Logical>) -> Rectangle<i32, Logical> {
    let m = side_margin(window);
    let size = window.geometry().size;
    Rectangle::new((loc.x - m, loc.y - HEIGHT).into(), (size.w + 2 * m, HEIGHT).into())
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Part {
    Bar,
    Maximize,
    Close,
}

const BUTTON_W: i32 = 34;
const RIGHT_PAD: i32 = 10;

/// Centres of the (maximize, close) buttons, relative to the strip.
fn button_centers(strip_w: i32) -> (i32, i32) {
    let close = strip_w - RIGHT_PAD - BUTTON_W / 2;
    (close - BUTTON_W, close)
}

pub fn part_at(window: &Window, loc: Point<i32, Logical>, pos: Point<f64, Logical>) -> Option<Part> {
    let strip = strip_rect(window, loc);
    let p = pos.to_i32_floor();
    if !strip.contains(p) {
        return None;
    }
    let x = p.x - strip.loc.x;
    let (max_c, close_c) = button_centers(strip.size.w);
    Some(if (x - close_c).abs() <= BUTTON_W / 2 {
        Part::Close
    } else if (x - max_c).abs() <= BUTTON_W / 2 {
        Part::Maximize
    } else {
        Part::Bar
    })
}

//
// Rasterising
//

#[derive(Clone, PartialEq)]
pub struct Key {
    pub title: String,
    pub width: i32,
    pub scale: i32,
    pub dark: bool,
    pub active: bool,
    pub maximized: bool,
}

fn font() -> Option<&'static FontVec> {
    static FONT: OnceLock<Option<FontVec>> = OnceLock::new();
    FONT.get_or_init(|| {
        let mut paths: Vec<String> = Vec::new();
        if let Ok(out) = std::process::Command::new("fc-match")
            .args(["-f", "%{file}", "Inter:weight=500"])
            .output()
            && out.status.success()
        {
            paths.push(String::from_utf8_lossy(&out.stdout).trim().to_string());
        }
        for p in [
            "/usr/share/fonts/opentype/inter/Inter-Medium.otf",
            "/usr/share/fonts/truetype/inter/Inter-Medium.ttf",
            "/usr/share/fonts/truetype/noto/NotoSans-Medium.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/TTF/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ] {
            paths.push(p.to_string());
        }
        paths
            .into_iter()
            .filter_map(|p| std::fs::read(p).ok())
            .find_map(|data| FontVec::try_from_vec(data).ok())
    })
    .as_ref()
}

struct Canvas {
    w: i32,
    h: i32,
    /// Premultiplied RGBA (converted to BGRA bytes at the end).
    px: Vec<[f32; 4]>,
}

impl Canvas {
    fn blend(&mut self, x: i32, y: i32, rgb: [f32; 3], a: f32) {
        if x < 0 || y < 0 || x >= self.w || y >= self.h || a <= 0.0 {
            return;
        }
        let p = &mut self.px[(y * self.w + x) as usize];
        let inv = 1.0 - a;
        p[0] = rgb[0] * a + p[0] * inv;
        p[1] = rgb[1] * a + p[1] * inv;
        p[2] = rgb[2] * a + p[2] * inv;
        p[3] = a + p[3] * inv;
    }

    /// Anti-aliased line segment of the given thickness.
    fn line(&mut self, a: (f32, f32), b: (f32, f32), thick: f32, rgb: [f32; 3], alpha: f32) {
        let pad = thick + 1.0;
        let (x0, x1) = ((a.0.min(b.0) - pad).floor() as i32, (a.0.max(b.0) + pad).ceil() as i32);
        let (y0, y1) = ((a.1.min(b.1) - pad).floor() as i32, (a.1.max(b.1) + pad).ceil() as i32);
        let (dx, dy) = (b.0 - a.0, b.1 - a.1);
        let len2 = (dx * dx + dy * dy).max(1e-6);
        for y in y0..=y1 {
            for x in x0..=x1 {
                let (px, py) = (x as f32 + 0.5, y as f32 + 0.5);
                let t = (((px - a.0) * dx + (py - a.1) * dy) / len2).clamp(0.0, 1.0);
                let (cx, cy) = (a.0 + t * dx, a.1 + t * dy);
                let d = ((px - cx).powi(2) + (py - cy).powi(2)).sqrt();
                let cov = (thick * 0.5 + 0.5 - d).clamp(0.0, 1.0);
                self.blend(x, y, rgb, cov * alpha);
            }
        }
    }
}

/// Renders the strip: ARGB8888 (little-endian: B, G, R, A), premultiplied.
/// Fully transparent except text and glyphs; the colour behind is drawn by the
/// frame shader.
pub fn rasterize(key: &Key) -> Vec<u8> {
    let s = key.scale as f32;
    let (w, h) = (key.width * key.scale, HEIGHT * key.scale);
    let mut c = Canvas { w, h, px: vec![[0.0; 4]; (w * h) as usize] };
    let fg: [f32; 3] = if key.dark { [0.894, 0.894, 0.906] } else { [0.094, 0.094, 0.106] };
    let alpha = if key.active { 1.0 } else { 0.55 };

    // Title
    if let Some(font) = font() {
        let px = 13.5 * s;
        let scaled = font.as_scaled(PxScale::from(px));
        let (max_c, _) = button_centers(key.width);
        let limit = ((max_c - BUTTON_W / 2 - 12) as f32) * s;
        let mut x = 16.0 * s + if key.maximized { 0.0 } else { 0.0 };
        let baseline = (h as f32) / 2.0 + (scaled.ascent() + scaled.descent()) / 2.0;
        let ellipsis = scaled.glyph_id('…');
        let ell_w = scaled.h_advance(ellipsis);
        let chars: Vec<char> = key.title.chars().collect();
        let total: f32 = chars.iter().map(|ch| scaled.h_advance(scaled.glyph_id(*ch))).sum();
        let truncate = x + total > limit;
        for ch in chars {
            let id = scaled.glyph_id(ch);
            let adv = scaled.h_advance(id);
            if truncate && x + adv + ell_w > limit {
                let g = id_glyph(ellipsis, px, x, baseline);
                draw_glyph(&mut c, font, g, fg, alpha);
                break;
            }
            let g = id_glyph(id, px, x, baseline);
            draw_glyph(&mut c, font, g, fg, alpha);
            x += adv;
        }
    }

    // Buttons
    let (max_c, close_c) = button_centers(key.width);
    let cy = h as f32 / 2.0;
    let t = 1.6 * s;
    let r = 5.0 * s;
    let cx = close_c as f32 * s;
    c.line((cx - r, cy - r), (cx + r, cy + r), t, fg, alpha);
    c.line((cx - r, cy + r), (cx + r, cy - r), t, fg, alpha);
    let mx = max_c as f32 * s;
    if key.maximized {
        // restore: two overlapping squares
        let q = 4.0 * s;
        let o = 1.8 * s;
        rect_outline(&mut c, mx - q - o * 0.0, cy - q + o, mx + q - o * 2.0 + o, cy + q + o, t, fg, alpha);
        c.line((mx - q + o, cy - q + o), (mx - q + o, cy - q - o * 0.2), t, fg, alpha);
        c.line((mx - q + o, cy - q - o * 0.2), (mx + q + o, cy - q - o * 0.2), t, fg, alpha);
        c.line((mx + q + o, cy - q - o * 0.2), (mx + q + o, cy + q - o), t, fg, alpha);
    } else {
        rect_outline(&mut c, mx - r, cy - r, mx + r, cy + r, t, fg, alpha);
    }

    let mut out = Vec::with_capacity(c.px.len() * 4);
    for p in &c.px {
        out.extend_from_slice(&[
            (p[2] * 255.0).round() as u8,
            (p[1] * 255.0).round() as u8,
            (p[0] * 255.0).round() as u8,
            (p[3] * 255.0).round() as u8,
        ]);
    }
    out
}

fn rect_outline(c: &mut Canvas, x0: f32, y0: f32, x1: f32, y1: f32, t: f32, rgb: [f32; 3], a: f32) {
    c.line((x0, y0), (x1, y0), t, rgb, a);
    c.line((x1, y0), (x1, y1), t, rgb, a);
    c.line((x1, y1), (x0, y1), t, rgb, a);
    c.line((x0, y1), (x0, y0), t, rgb, a);
}

fn id_glyph(id: ab_glyph::GlyphId, px: f32, x: f32, baseline: f32) -> ab_glyph::Glyph {
    id.with_scale_and_position(PxScale::from(px), ab_glyph::point(x, baseline))
}

fn draw_glyph(c: &mut Canvas, font: &FontVec, glyph: ab_glyph::Glyph, rgb: [f32; 3], alpha: f32) {
    if let Some(og) = font.outline_glyph(glyph) {
        let b = og.px_bounds();
        og.draw(|gx, gy, cov| {
            c.blend(b.min.x as i32 + gx as i32, b.min.y as i32 + gy as i32, rgb, cov * alpha);
        });
    }
}
