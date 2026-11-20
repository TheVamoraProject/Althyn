# Althyn Compositor

Althyn's Wayland compositor, written in Rust on [Smithay](https://github.com/Smithay/smithay).
Its structure follows Smithay's `smallvil` and `anvil` examples (MIT).
It is a plain floating window manager: a base that works, to build features on.

## What it does

- **Backends** (no architecture-specific code, so x86_64 and aarch64 alike)
  - `winit`: runs as a window inside another session (development, testing).
  - `udev`: the real thing on a bare VT: DRM/KMS (GBM + EGL + GLES), libinput,
    libseat, VT switching (Ctrl+Alt+F<n>), output hot-plug. Build with
    `--features udev`.
  - Chosen automatically: `winit` when `WAYLAND_DISPLAY`/`DISPLAY` is set, else `udev`
    (override with `--backend winit|udev`).
- **Protocols**: wl_compositor, xdg-shell, xdg-decoration, wlr-layer-shell, xdg-activation,
  ext-foreign-toplevel-list, **wlr-foreign-toplevel-management** (Dock and StatusBar use
  it to hide / change colour for maximized windows), viewporter, fractional-scale,
  cursor-shape, data-device + primary-selection, linux-dmabuf, shm, xdg-output.
- **Layer shell** is what places the status bar (top, reserves its height), the dock,
  the home screen (bottom layer), the wallpaper (`swaybg`) and the menu popups
  (overlay). Windows are kept inside the area the layers leave free.
- **VamoraSys settings**: `wm.focus_mode`, `wm.animations`, `wm.transparency`,
  `wm.window_effects` and `keyboard.*` are read with `vamorasys settings get` and
  followed live (the same keys the Settings app's Vamify page writes). Without
  `vamorasys` the defaults apply.

## Build

```sh
sudo apt install pkg-config libwayland-dev libxkbcommon-dev libinput-dev libudev-dev \
                 libseat-dev libgbm-dev libdrm-dev libegl-dev libgles-dev
cargo build --release --features udev      # hardware backend
cargo build --release                      # nested (winit) only
```

`install.sh` at the repository root does this and installs `althyn-core`;
the Runner (`althyn`) starts it for the Wayland session. It is the only compositor
the Wayland session uses; no external compositor is required.

## Run

```sh
althyn-core -s ./startup.sh     # -s: command to run once the compositor is ready
```

Inside another desktop it opens a window; `RUST_LOG=debug` for more logging.
On a bare VT it needs seat access (systemd-logind or seatd). `VAMORA_DRM_DEVICE`
picks a GPU, `XCURSOR_THEME` / `XCURSOR_SIZE` the cursor (a built-in arrow is used
without a theme).

## Not done yet

Multi-GPU, presentation-time / explicit sync, per-shape cursors, display make / model,
mode and scale selection (preferred mode at scale 1), a real minimize.
