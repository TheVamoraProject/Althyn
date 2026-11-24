//! Icons and pictures for notifications: finding the app icon by name (the
//! same lookup order the home screen uses), reading `image-path` /
//! `image-data` hints, and loading png / jpeg / svg at a given size.

use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::Mutex,
};

use image::RgbaImage;

/// App icon by absolute path, `file://` URL or theme name.
pub fn resolve_icon(icon: &str) -> Option<PathBuf> {
    let icon = icon.trim();
    if icon.is_empty() {
        return None;
    }
    let icon = icon.strip_prefix("file://").unwrap_or(icon);
    if icon.starts_with('/') {
        return Path::new(icon).exists().then(|| PathBuf::from(icon));
    }
    if icon.contains('/') || icon.contains("..") {
        return None;
    }
    let theme = crate::config::get_setting("icons.theme")
        .filter(|s| !s.is_empty() && !s.contains('/') && !s.contains(".."))
        .unwrap_or_else(|| "hicolor".to_string());
    let mut themes = vec![theme.clone()];
    if theme != "hicolor" {
        themes.push("hicolor".into());
    }
    let home = std::env::var("HOME").unwrap_or_default();
    for t in &themes {
        for base in [format!("/usr/share/icons/{t}"), format!("{home}/.local/share/icons/{t}")] {
            for sub in [
                "scalable/apps", "64x64/apps", "48x48/apps", "128x128/apps", "256x256/apps",
                "apps/scalable", "apps/64", "apps/48", "32/apps", "32x32/apps", "24/apps",
            ] {
                for ext in ["svg", "png"] {
                    let p = PathBuf::from(format!("{base}/{sub}/{icon}.{ext}"));
                    if p.exists() {
                        return Some(p);
                    }
                }
            }
        }
    }
    ["png", "svg"]
        .iter()
        .map(|e| PathBuf::from(format!("/usr/share/pixmaps/{icon}.{e}")))
        .find(|p| p.exists())
}

/// The notification's picture: `image-path`, or `image-data` saved as a png in
/// the runtime dir (so the status bar can show it too).
pub fn hint_image(
    hints: &HashMap<String, zbus::zvariant::OwnedValue>,
    id: u32,
) -> Option<PathBuf> {
    for key in ["image-path", "image_path"] {
        if let Some(v) = hints.get(key)
            && let Ok(s) = <String>::try_from(v.clone())
            && let Some(p) = resolve_icon(&s)
        {
            return Some(p);
        }
    }
    for key in ["image-data", "image_data", "icon_data"] {
        let Some(v) = hints.get(key) else { continue };
        let Ok((w, h, stride, has_alpha, bits, channels, data)) =
            <(i32, i32, i32, bool, i32, i32, Vec<u8>)>::try_from(v.clone())
        else {
            continue;
        };
        if bits != 8 || w <= 0 || h <= 0 || !(3..=4).contains(&channels) || stride < w * channels {
            continue;
        }
        let mut img = RgbaImage::new(w as u32, h as u32);
        for y in 0..h as usize {
            for x in 0..w as usize {
                let i = y * stride as usize + x * channels as usize;
                let Some(px) = data.get(i..i + channels as usize) else { return None };
                let a = if has_alpha && channels == 4 { px[3] } else { 255 };
                img.put_pixel(x as u32, y as u32, image::Rgba([px[0], px[1], px[2], a]));
            }
        }
        let dir = PathBuf::from(std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into()))
            .join("vamora-notifications");
        std::fs::create_dir_all(&dir).ok()?;
        let path = dir.join(format!("{id}-{}.png", std::process::id()));
        img.save(&path).ok()?;
        return Some(path);
    }
    None
}

static CACHE: Mutex<Option<HashMap<(PathBuf, u32), Option<RgbaImage>>>> = Mutex::new(None);

/// Loads `path` as a `size` x `size` square, cover-fit, straight RGBA.
pub fn load_square(path: &Path, size: u32) -> Option<RgbaImage> {
    let mut guard = CACHE.lock().ok()?;
    let cache = guard.get_or_insert_with(HashMap::new);
    cache
        .entry((path.to_path_buf(), size))
        .or_insert_with(|| decode(path, size))
        .clone()
}

fn decode(path: &Path, size: u32) -> Option<RgbaImage> {
    let is_svg = path.extension().is_some_and(|e| e.eq_ignore_ascii_case("svg"));
    let img = if is_svg {
        let data = std::fs::read(path).ok()?;
        let tree = resvg::usvg::Tree::from_data(&data, &resvg::usvg::Options::default()).ok()?;
        let mut pixmap = resvg::tiny_skia::Pixmap::new(size, size)?;
        let s = tree.size();
        let scale = (size as f32 / s.width()).min(size as f32 / s.height());
        let tx = (size as f32 - s.width() * scale) / 2.0;
        let ty = (size as f32 - s.height() * scale) / 2.0;
        resvg::render(
            &tree,
            resvg::tiny_skia::Transform::from_row(scale, 0.0, 0.0, scale, tx, ty),
            &mut pixmap.as_mut(),
        );
        // tiny-skia is premultiplied; we want straight alpha
        let mut out = RgbaImage::new(size, size);
        for (i, p) in pixmap.pixels().iter().enumerate() {
            let c = p.demultiply();
            out.put_pixel(
                (i as u32) % size,
                (i as u32) / size,
                image::Rgba([c.red(), c.green(), c.blue(), c.alpha()]),
            );
        }
        out
    } else {
        let img = image::open(path).ok()?.to_rgba8();
        let (w, h) = img.dimensions();
        // centre-crop to a square, then resize
        let side = w.min(h);
        let cropped = image::imageops::crop_imm(&img, (w - side) / 2, (h - side) / 2, side, side).to_image();
        image::imageops::resize(&cropped, size, size, image::imageops::FilterType::Lanczos3)
    };
    Some(img)
}
