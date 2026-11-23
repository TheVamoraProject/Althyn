//! Window look: rounded corners for windows that do not draw their own, and
//! the open animation. Shared by the nested (winit) and the real (udev) backend.
//!
//! Smithay's `Space` helper cannot be told to treat one window differently, so
//! the scene is assembled here: layer surfaces and windows in the same order
//! `Space` uses (overlay, top, windows, bottom, background), with every window's
//! toplevel surface drawn through a small rounded-corner shader.

use std::time::{Duration, Instant};

use smithay::{
    backend::{
        allocator::Fourcc,
        renderer::{
        element::{
            AsRenderElements, Element, Id, Kind, RenderElement, UnderlyingStorage,
            memory::{MemoryRenderBuffer, MemoryRenderBufferRenderElement},
            surface::WaylandSurfaceRenderElement,
            utils::RescaleRenderElement,
        },
        gles::{
            element::PixelShaderElement, GlesPixelProgram,
            GlesError, GlesFrame, GlesRenderer, GlesTexProgram, Uniform, UniformName, UniformType,
        },
        utils::{CommitCounter, DamageSet, OpaqueRegions},
        },
    },
    desktop::{Space, Window, layer_map_for_output},
    output::Output,
    reexports::wayland_protocols::xdg::shell::server::xdg_toplevel,
    utils::{Buffer as BufferCoords, Logical, Physical, Point, Rectangle, Scale, Transform},
    wayland::{
        compositor::with_states,
        shell::{wlr_layer::Layer, xdg::XdgToplevelSurfaceData},
    },
};

use crate::shell::window_data;
use crate::titlebar;

const SHADER: &str = r#"#version 100

//_DEFINES_

#if defined(EXTERNAL)
#extension GL_OES_EGL_image_external : require
#endif

precision highp float;
#if defined(EXTERNAL)
uniform samplerExternalOES tex;
#else
uniform sampler2D tex;
#endif

uniform float alpha;
uniform vec2 size;   // whole window, px
uniform vec2 off;    // this surface's top-left inside the window, px
uniform vec2 esize;  // this surface's size, px
uniform float radius;      // bottom corners
uniform float top_radius;  // top corners
varying vec2 v_coords;

#if defined(DEBUG_FLAGS)
uniform float tint;
#endif

void main() {
    vec4 color = texture2D(tex, v_coords);
#if defined(NO_ALPHA)
    color = vec4(color.rgb, 1.0);
#endif

    // Signed distance to a rounded rectangle, in pixels; 1 px anti-aliased edge.
    vec2 p = off + v_coords * esize - size * 0.5;
    float r = p.y < 0.0 ? top_radius : radius;
    vec2 q = abs(p) - (size * 0.5 - vec2(r));
    float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
    float coverage = clamp(0.5 - d, 0.0, 1.0);

    color = color * alpha * coverage;

#if defined(DEBUG_FLAGS)
    if (tint == 1.0)
        color = vec4(0.0, 0.2, 0.0, 0.2) + color * 0.8;
#endif

    gl_FragColor = color;
}
"#;

const FRAME_SHADER: &str = r#"
precision mediump float;
uniform float alpha;
uniform vec2 size;
uniform float radius;
uniform vec3 tint_rgb;
varying vec2 v_coords;
void main() {
    vec2 p = (v_coords - vec2(0.5)) * size;
    vec2 q = abs(p) - (size * 0.5 - vec2(radius));
    float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
    float coverage = clamp(0.5 - d, 0.0, 1.0);
    gl_FragColor = vec4(tint_rgb, 1.0) * alpha * coverage;
}
"#;

struct FrameCell(Option<GlesPixelProgram>);

/// The white frame program, compiled once per GL context.
fn frame_program(renderer: &mut GlesRenderer) -> Option<GlesPixelProgram> {
    if let Some(cell) = renderer.egl_context().user_data().get::<FrameCell>() {
        return cell.0.clone();
    }
    let program = renderer
        .compile_custom_pixel_shader(FRAME_SHADER, &[UniformName::new("radius", UniformType::_1f), UniformName::new("tint_rgb", UniformType::_3f)])
        .map_err(|err| tracing::warn!("frame shader failed to compile: {err}"))
        .ok();
    renderer
        .egl_context()
        .user_data()
        .insert_if_missing(|| FrameCell(program.clone()));
    program
}

/// Margin (white, or dark with `appearance.theme=dark`) drawn left, right and below a rounded window (logical px).
pub use titlebar::MARGIN as FRAME_MARGIN;

struct ShaderCell(Option<GlesTexProgram>);

/// The rounding program, compiled once per GL context.
fn rounded_program(renderer: &mut GlesRenderer) -> Option<GlesTexProgram> {
    if let Some(cell) = renderer.egl_context().user_data().get::<ShaderCell>() {
        return cell.0.clone();
    }
    let program = renderer
        .compile_custom_texture_shader(
            SHADER,
            &[
                UniformName::new("size", UniformType::_2f),
                UniformName::new("top_radius", UniformType::_1f),
                UniformName::new("off", UniformType::_2f),
                UniformName::new("esize", UniformType::_2f),
                UniformName::new("radius", UniformType::_1f),
            ],
        )
        .map_err(|err| tracing::warn!("rounded-corner shader failed to compile: {err}"))
        .ok();
    renderer
        .egl_context()
        .user_data()
        .insert_if_missing(|| ShaderCell(program.clone()));
    program
}

/// A window surface drawn with rounded corners (radius 0 draws it unchanged).
pub struct RoundedSurfaceElement {
    inner: WaylandSurfaceRenderElement<GlesRenderer>,
    program: Option<GlesTexProgram>,
    /// Physical pixels.
    radius: f32,
    /// Top corners, physical pixels (0 under a compositor-drawn titlebar).
    top_radius: f32,
    /// The whole window (its geometry, unscaled), so every surface of it
    /// (CSD titlebar, subsurfaces) is cut by the same rounded outline.
    win: Rectangle<i32, Physical>,
    /// Open-animation scale about `center`; 1.0 when idle.
    anim: f32,
    center: Point<i32, Physical>,
}

impl Element for RoundedSurfaceElement {
    fn id(&self) -> &Id {
        self.inner.id()
    }
    fn current_commit(&self) -> CommitCounter {
        self.inner.current_commit()
    }
    fn location(&self, scale: Scale<f64>) -> Point<i32, Physical> {
        self.inner.location(scale)
    }
    fn src(&self) -> Rectangle<f64, BufferCoords> {
        self.inner.src()
    }
    fn transform(&self) -> smithay::utils::Transform {
        self.inner.transform()
    }
    fn geometry(&self, scale: Scale<f64>) -> Rectangle<i32, Physical> {
        self.inner.geometry(scale)
    }
    fn damage_since(&self, scale: Scale<f64>, commit: Option<CommitCounter>) -> DamageSet<i32, Physical> {
        self.inner.damage_since(scale, commit)
    }
    fn opaque_regions(&self, scale: Scale<f64>) -> OpaqueRegions<i32, Physical> {
        if self.radius > 0.0 || self.top_radius > 0.0 {
            OpaqueRegions::default() // the corners are transparent
        } else {
            self.inner.opaque_regions(scale)
        }
    }
    fn alpha(&self) -> f32 {
        self.inner.alpha()
    }
    fn kind(&self) -> Kind {
        self.inner.kind()
    }
}

impl RenderElement<GlesRenderer> for RoundedSurfaceElement {
    fn draw(
        &self,
        frame: &mut GlesFrame<'_, '_>,
        src: Rectangle<f64, BufferCoords>,
        dst: Rectangle<i32, Physical>,
        damage: &[Rectangle<i32, Physical>],
        opaque_regions: &[Rectangle<i32, Physical>],
        cache: Option<&smithay::utils::user_data::UserDataMap>,
    ) -> Result<(), GlesError> {
        let Some(program) = self.program.clone().filter(|_| self.radius > 0.0 || self.top_radius > 0.0) else {
            return RenderElement::<GlesRenderer>::draw(&self.inner, frame, src, dst, damage, opaque_regions, cache);
        };
        let a = self.anim;
        let (cx, cy) = (self.center.x as f32, self.center.y as f32);
        let wx = cx + (self.win.loc.x as f32 - cx) * a;
        let wy = cy + (self.win.loc.y as f32 - cy) * a;
        let (ww, wh) = (self.win.size.w as f32 * a, self.win.size.h as f32 * a);
        let radius = (self.radius * a).min(ww.min(wh) / 2.0);
        let top_radius = (self.top_radius * a).min(ww.min(wh) / 2.0);
        frame.override_default_tex_program(
            program,
            vec![
                Uniform::new("size", (ww, wh)),
                Uniform::new("off", (dst.loc.x as f32 - wx, dst.loc.y as f32 - wy)),
                Uniform::new("esize", (dst.size.w as f32, dst.size.h as f32)),
                Uniform::new("radius", radius),
                Uniform::new("top_radius", top_radius),
            ],
        );
        let result =
            RenderElement::<GlesRenderer>::draw(&self.inner, frame, src, dst, damage, opaque_regions, cache);
        frame.clear_tex_program_override();
        result
    }

    fn underlying_storage(&self, _renderer: &mut GlesRenderer) -> Option<UnderlyingStorage<'_>> {
        // Never scan a rounded window out directly: the corners need the shader.
        if self.radius > 0.0 || self.top_radius > 0.0 { None } else { self.inner.underlying_storage(_renderer) }
    }
}

smithay::backend::renderer::element::render_elements! {
    /// Everything that can appear in a frame, front to back.
    pub SceneElement<=GlesRenderer>;
    Surface=WaylandSurfaceRenderElement<GlesRenderer>,
    Window=RoundedSurfaceElement,
    Animated=RescaleRenderElement<RoundedSurfaceElement>,
    Title=MemoryRenderBufferRenderElement<GlesRenderer>,
    AnimatedTitle=RescaleRenderElement<MemoryRenderBufferRenderElement<GlesRenderer>>,
    Frame=PixelShaderElement,
    AnimatedFrame=RescaleRenderElement<PixelShaderElement>,
}

/// Apps that draw their own rounded frame (Althyn's own, e.g. Settings): the
/// compositor leaves their corners alone.
pub fn is_self_decorated(app_id: &str) -> bool {
    let id = app_id.to_ascii_lowercase();
    id.starts_with("vamora-") || id.starts_with("althyn-") || id.starts_with("org.vamora.")
        || id.starts_with("com.vamora.") || id.starts_with("app.vamora.")
}

pub const OPEN_ANIMATION: Duration = Duration::from_millis(220);

/// 0 → 1 over [`OPEN_ANIMATION`], ease-out.
pub fn open_progress(opened_at: Option<Instant>, now: Instant) -> f32 {
    let Some(start) = opened_at else { return 1.0 };
    let t = now.saturating_duration_since(start).as_secs_f32() / OPEN_ANIMATION.as_secs_f32();
    if t >= 1.0 { 1.0 } else { 1.0 - (1.0 - t.max(0.0)).powi(3) }
}

/// Clients lay out their own titlebar buttons/text for square corners; past
/// this radius the rounding starts eating them, so it is capped for them.
const MAX_CLIENT_RADIUS: u32 = 18;

/// Window starts at this fraction of its size and grows to 1.
const OPEN_FROM_SCALE: f64 = 0.94;

pub(crate) fn app_id(window: &Window) -> String {
    window
        .toplevel()
        .and_then(|t| {
            with_states(t.wl_surface(), |states| {
                states
                    .data_map
                    .get::<XdgToplevelSurfaceData>()
                    .and_then(|d| d.lock().unwrap().app_id.clone())
            })
        })
        .unwrap_or_default()
}

fn is_expanded(window: &Window) -> bool {
    window.toplevel().is_some_and(|t| {
        t.with_pending_state(|s| {
            s.states.contains(xdg_toplevel::State::Maximized) || s.states.contains(xdg_toplevel::State::Fullscreen)
        })
    })
}

/// Layer surfaces and windows of one output, front to back.
pub fn scene_elements(
    renderer: &mut GlesRenderer,
    space: &Space<Window>,
    output: &Output,
    corner_radius: u32,
    animations: bool,
    dark: bool,
) -> Vec<SceneElement> {
    let Some(output_geo) = space.output_geometry(output) else {
        return Vec::new();
    };
    let scale = Scale::from(output.current_scale().fractional_scale());
    let program = rounded_program(renderer);
    let frame_prog = frame_program(renderer);
    let now = Instant::now();
    let mut out: Vec<SceneElement> = Vec::new();

    let layer_map = layer_map_for_output(output);
    let layers = |renderer: &mut GlesRenderer, which: Layer, out: &mut Vec<SceneElement>| {
        for layer in layer_map.layers_on(which).rev() {
            let Some(geo) = layer_map.layer_geometry(layer) else { continue };
            out.extend(
                layer
                    .render_elements::<WaylandSurfaceRenderElement<GlesRenderer>>(
                        renderer,
                        geo.loc.to_physical_precise_round(scale),
                        scale,
                        1.0,
                    )
                    .into_iter()
                    .map(SceneElement::Surface),
            );
        }
    };

    layers(renderer, Layer::Overlay, &mut out);
    layers(renderer, Layer::Top, &mut out);

    for window in space.elements().rev() {
        let Some(loc) = space.element_location(window) else { continue };
        let mut bbox = window.bbox();
        bbox.loc += loc - window.geometry().loc;
        if !output_geo.overlaps(bbox) {
            continue;
        }
        let render_loc: Point<i32, Logical> = loc - window.geometry().loc - output_geo.loc;

        let opened_at = window_data(window).borrow().opened_at;
        let progress = if animations { open_progress(opened_at, now) } else { 1.0 };
        let ssd = titlebar::is_ssd(window);
        let maximized = titlebar::is_maximized(window);
        let rounded = corner_radius > 0 && !is_expanded(window) && !is_self_decorated(&app_id(window));
        let outer_logical = corner_radius.min(MAX_CLIENT_RADIUS) as f32;
        let px = scale.x as f32;
        // Under a compositor titlebar the client is flat on top and concentric
        // with the frame at the bottom; otherwise it is rounded all around.
        let (radius, top_radius) = if ssd && !maximized {
            (if rounded { (outer_logical - FRAME_MARGIN as f32).max(0.0) * px } else { 0.0 }, 0.0)
        } else if ssd {
            (0.0, 0.0)
        } else if rounded {
            (outer_logical * px, outer_logical * px)
        } else {
            (0.0, 0.0)
        };

        let elements = window.render_elements::<WaylandSurfaceRenderElement<GlesRenderer>>(
            renderer,
            render_loc.to_physical_precise_round(scale),
            scale,
            if progress < 1.0 { progress } else { 1.0 },
        );
        let origin: Point<i32, Physical> = (loc - output_geo.loc).to_physical_precise_round(scale);
        let size: smithay::utils::Size<i32, Physical> = window.geometry().size.to_physical_precise_round(scale);
        let center = Point::<i32, Physical>::from((origin.x + size.w / 2, origin.y + size.h / 2));
        let s = OPEN_FROM_SCALE + (1.0 - OPEN_FROM_SCALE) * progress as f64;
        let window_start = out.len();
        for inner in elements {
            let element = RoundedSurfaceElement {
                inner,
                program: program.clone(),
                radius,
                top_radius,
                win: Rectangle::new(origin, size),
                anim: if progress < 1.0 { s as f32 } else { 1.0 },
                center,
            };
            if progress < 1.0 {
                out.push(SceneElement::Animated(RescaleRenderElement::from_element(element, center, s)));
            } else {
                out.push(SceneElement::Window(element));
            }
        }
        if ssd {
            let strip = titlebar::strip_rect(window, loc);
            let rel = strip.loc - output_geo.loc;
            // text + buttons
            let key = titlebar::Key {
                title: titlebar::title_of(window),
                width: strip.size.w,
                scale: scale.x.ceil().max(1.0) as i32,
                dark,
                active: titlebar::is_active(window),
                maximized,
            };
            {
                let mut data = window_data(window).borrow_mut();
                if data.title.as_ref().is_none_or(|(k, _)| *k != key) {
                    let bytes = titlebar::rasterize(&key);
                    let buf = MemoryRenderBuffer::from_slice(
                        &bytes,
                        Fourcc::Argb8888,
                        (key.width * key.scale, titlebar::HEIGHT * key.scale),
                        key.scale,
                        Transform::Normal,
                        None,
                    );
                    data.title = Some((key, buf));
                }
                if let Some((_, buf)) = data.title.as_ref()
                    && let Ok(el) = MemoryRenderBufferRenderElement::from_buffer(
                        renderer,
                        rel.to_f64().to_physical(scale),
                        buf,
                        Some(progress),
                        None,
                        None,
                        Kind::Unspecified,
                    )
                {
                    if progress < 1.0 {
                        // inserted before this window's surfaces: front to back
                        out.insert(window_start, SceneElement::AnimatedTitle(RescaleRenderElement::from_element(el, center, s)));
                    } else {
                        out.insert(window_start, SceneElement::Title(el));
                    }
                }
            }
            // the colour behind it: titlebar, and the margin around the client
            if let Some(fp) = frame_prog.clone() {
                let gs = window.geometry().size;
                let (area, r): (Rectangle<i32, Logical>, f32) = if maximized {
                    (Rectangle::new(rel, (gs.w, titlebar::HEIGHT).into()), 0.0)
                } else {
                    (
                        Rectangle::new(rel, (gs.w + 2 * FRAME_MARGIN, gs.h + titlebar::HEIGHT + FRAME_MARGIN).into()),
                        if rounded { outer_logical } else { 0.0 },
                    )
                };
                let el = PixelShaderElement::new(
                    fp,
                    area,
                    None,
                    progress,
                    vec![
                        Uniform::new("radius", r * px),
                        Uniform::new("tint_rgb", if dark { (0.12f32, 0.12f32, 0.135f32) } else { (1.0f32, 1.0f32, 1.0f32) }),
                    ],
                    Kind::Unspecified,
                );
                if progress < 1.0 {
                    out.push(SceneElement::AnimatedFrame(RescaleRenderElement::from_element(el, center, s)));
                } else {
                    out.push(SceneElement::Frame(el));
                }
            }
        }
    }

    layers(renderer, Layer::Bottom, &mut out);
    layers(renderer, Layer::Background, &mut out);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn own_apps_are_self_decorated() {
        assert!(is_self_decorated("vamora-settings"));
        assert!(is_self_decorated("Althyn-Setup"));
        assert!(is_self_decorated("app.vamora.music"));
        assert!(!is_self_decorated("org.gnome.Calculator"));
        assert!(!is_self_decorated(""));
    }

    #[test]
    fn open_animation_runs_from_0_to_1() {
        let t0 = Instant::now();
        assert_eq!(open_progress(None, t0), 1.0);
        assert!(open_progress(Some(t0), t0) < 0.01);
        let mid = open_progress(Some(t0), t0 + OPEN_ANIMATION / 2);
        assert!(mid > 0.5 && mid < 1.0); // ease-out: more than half done at half time
        assert_eq!(open_progress(Some(t0), t0 + OPEN_ANIMATION * 2), 1.0);
    }
}
