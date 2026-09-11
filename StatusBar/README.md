# Vamora StatusBar (X11)

Part of [**VamoraOS**](https://github.com/TheVamoraProject/VamoraOS/) — a Qt6/QML + Rust ([cxx-qt](https://github.com/KDAB/cxx-qt)) status bar for VamoraOS. This component targets **X11** window managers (developed and tested on Openbox) as a pre-alpha build.

> [!IMPORTANT]
> This X11 build is a compatibility track, not the priority. **[Althyn](https://github.com/TheVamoraProject/Althyn/)
> (Wayland)** is the actively developed, prioritized version, and the upcoming Vamora compositor is
> Wayland-only — it will not run this X11 build at all.

It's built with the **AlthynUI** design language

---

## Table of Contents

- [What this is](#what-this-is)
- [Features](#features)
- [Project Layout](#project-layout)
- [Dependencies](#dependencies)
- [Building](#building)
- [Design System (AlthynUI)](#design-system-vamoraui)
- [Icons](#icons)
- [License](#license)

---

## What this is

`vamora-statusbar-x11` is a single always-on-top, frameless Qt window rendered via QML, backed by a small Rust core using `cxx-qt`. It provides:

- A top status bar (clock, tray icons, wifi/battery/volume indicators, notification bell)
- A start menu (app grid, search, favorites, right-click context actions)
- A calendar popup
- X11 screen-reservation (EWMH struts) so maximized windows don't sit underneath the bar


---

## Features

### Status bar
- Live clock (`hh:mm  ddd, d MMM` format), updates every second
- Start menu toggle button (opens/closes the app grid popup)
- Notification bell icon (UI only, not yet wired to a notification daemon)
- Volume, wifi, and battery tray icons
  - Wifi icon dynamically swaps between 0–4 bar states based on real link quality read from `/proc/net/wireless`
  - Volume and battery icons are currently static placeholders
- Settings shortcut icon
- Mutually-exclusive popups: opening the start menu force-closes the calendar and vice versa

### Start menu
- Full app grid populated by scanning `.desktop` files from:
  - `/usr/share/applications`
  - `/usr/local/share/applications`
  - `~/.local/share/applications`
- Live search/filter box (case-insensitive substring match on app name)
- **Staggered entrance animation** — icons fade + scale in one at a time, sweeping left-to-right, top-to-bottom (row-major order), instead of all popping in simultaneously
- Maximize/restore toggle (expands the start menu to fill the screen below the status bar, changes grid column count from 5 → 8)
- Right-click context menu per app icon:
  - **Add to Homescreen** — copies the `.desktop` file to `~/Desktop/`
  - **Add to Favorite** — copies the `.desktop` file to `~/Desktop/.favorites/`
  - **App Info** — placeholder, not yet implemented
- AlthynUI always on Bottom navbar switching between:
  - All apps
  - Favorites (loaded on demand from `~/Desktop/.favorites/`)
  - History (UI present, not yet wired to real data)
- Click-outside-to-close behavior, with a guard timer so a maximize/restore toggle doesn't immediately trigger a close

### Calendar
- Popup window anchored below the status bar clock button, same open/close exclusivity as the start menu

### System integration
- **X11 EWMH strut reservation**: on startup, a background thread locates the status bar's own window via `_NET_CLIENT_LIST` + `_NET_WM_PID`, then sets `_NET_WM_STRUT` / `_NET_WM_STRUT_PARTIAL` so X11 window managers reserve the top strip of the screen and don't let maximized windows overlap the bar. Retries for a few seconds in case the window manager hasn't registered the window yet. Wayland compositors ignore this entirely and it would stay in the middle instead of the top(X11-only, by design, for now).
- **Profile picture resolution**, checked in priority order:
  1. `/var/lib/AccountsService/icons/<user>` 
  2. `~/.face`
  3. `~/.face.icon`
  4. Falls back to the bundled `account.svg` icon if none exist
- **Wifi strength polling**, refreshed every 5 seconds alongside username/profile picture

---

## Project Layout

```
vamora-statusbar-x11/
├── Cargo.toml              Package manifest (edition 2024)
├── Cargo.lock
├── build.rs                cxx-qt-build wiring — the source of truth for what actually compiles
├── LICENSE
├── .qmlls.ini               QML language server config (editor tooling)
└── src/
    ├── main.rs              Entry point: creates QGuiApplication + QQmlApplicationEngine,
    │                        loads statusbar.qml, spawns the X11 strut reservation
    ├── cxxqt_object.rs       cxx-qt template demo QObject (MyObject)
    ├── userinfo.rs           UserInfo QObject: username / pfp / wifi strength
    ├── applist.rs            AppList QObject: desktop file scanning, launch, favorites
    ├── x11strut.rs           EWMH strut reservation (X11-only, background thread)
    └── qml/
        ├── qml.qrc           Registers all .qml files as Qt resources
        ├── assets.qrc        Registers all icons/images as Qt resources
        ├── assets/
        │   ├── Vamora.svg    App logo (used as the start-menu button icon)
        │   ├── Vamora.png    App logo, raster (bundled resource, e.g. for future window/tray icon use)
        │   └── icons/        All SVG icons — flat structure plus a few legacy subfolders
        │       ├── arrows/       (arrow-left/right/down — no flat equivalents yet)
        │       ├── battery/      (legacy grouped battery icons, kept alongside flat lucide ones)
        │       ├── notification/ (bell, bell-dot)
        │       ├── volume/       (legacy grouped volume icons)
        │       ├── wifi/         (legacy grouped wifi icons, numeric naming)
        │       └── *.svg         (flat, mostly Lucide-sourced icon set)
        └── layouts/
            ├── statusbar/
            │   └── statusbar.qml     The top bar itself
            ├── startmenu/
            │   ├── window.qml        App grid, search, favorites, context menu, navbar
            │   └── GridIcon.qml      Single app tile (icon + label) used by the grid
            ├── calendar/
            │   └── window.qml        Calendar popup
            └── components/
                ├── AppIcon.qml       Reusable icon wrapper with a fallback source
                └── DividerV.qml      Thin vertical divider used between tray sections
```

---

## Dependencies

From `Cargo.toml`:

| Crate | Version | Purpose |
|---|---|---|
| `cxx` | 1.0.197 | Underlying C++ interop used by cxx-qt |
| `cxx-qt` | 0.9.1 | Rust ↔ Qt/QML bridge macros (`#[cxx_qt::bridge]`, `#[qml_element]`, etc.) |
| `cxx-qt-lib` | 0.9.1 (`qt_gui`, `qt_qml` features) | Qt type bindings (`QString`, `QGuiApplication`, `QQmlApplicationEngine`, …) |
| `x11rb` | 0.13 | Raw X11 protocol access, used only by `x11strut.rs` for EWMH struts |
| `cxx-qt-build` | 0.9.1 (build-dependency) | Generates the Qt/QML build glue from `build.rs` |

You'll also need, at the system level:
- **Qt6** (Core, Gui, Qml, Quick, Quick Controls, Network) and its QML modules, including `Qt5Compat.GraphicalEffects` (used for icon color overlays) and `QtQuick.Window`
- A working C++ toolchain (cxx-qt compiles a C++ shim under the hood)
- pkg-config / qmake discoverable on your system so `cxx-qt-build` can locate Qt

---

## Building

```bash
cargo build --release
```

`build.rs` will invoke `cxx-qt-build`, which compiles the Rust bridge files, generates the C++ glue, and bundles the two `.qrc` resource files (`qml.qrc`, `assets.qrc`) into the binary. There is no separate "install icons/fonts" step — everything referenced by the `.qrc` files is embedded directly into the executable at build time.

---


## Design System (AlthynUI)

Consistent across the status bar, start menu, and calendar:

- **Zinc palette**:
  - `zinc-950 @ ~80% opacity` — status bar background
  - `zinc-900` (`#18181b`) — popup window backgrounds
  - `zinc-800` (`#27272a`) — surfaces, top bars, pills
  - `zinc-700` (`#3f3f46`) — borders, hover states
  - `zinc-100` (`#f4f4f5`) — primary text
  - `zinc-400` (`#a1a1aa`) — muted/secondary text
- **White as the sole accent color**, with near-black text/icons drawn on top of it (selected nav pill, etc.)
- **No blur, no glass effects, no gradients** anywhere in the UI chrome
- Large popups (start menu, calendar) use generous corner radii; the bottom category nav is a pill shape
- Icons are recolored via `ColorOverlay` (from `Qt5Compat.GraphicalEffects`) rather than baked-in colors, so the same SVG can be tinted per-context (e.g. white-on-accent vs. zinc-100 default)
- Font family used throughout: **Inter** (`font.family: "Inter"`) — relies on the font being installed system-wide; it is *not* currently bundled/loaded via `FontLoader` inside the app itself

---

## Icons

All icons live under `src/qml/assets/icons/`, registered in `assets.qrc`, and are compiled straight into the binary — nothing is loaded from disk at runtime.

- Most icons are a **flat, Lucide-sourced set** (e.g. `settings.svg`, `star.svg`, `wifi-high.svg`, `battery-full.svg`)
- A handful of **legacy grouped subfolders** remain because they don't have a matching flat/Lucide-named file yet:
  - `arrows/` — `arrowleft.svg`, `arrowright.svg`, `arrowdown.svg`
  - `battery/` — older grouped battery icon variants (kept alongside the flat ones; not currently referenced by any QML)
  - `notification/` — `bell.svg`, `bell-dot.svg`
  - `volume/` — older grouped volume icon variants (kept alongside the flat ones; not currently referenced by any QML)
  - `wifi/` — older grouped wifi icon variants using numeric names (`four.svg`, `three.svg`, …; not currently referenced by any QML)
- `unknown.svg` is the fallback icon used by `AppIcon.qml` and `GridIcon.qml` when an app has no resolvable icon

If you add a new icon that duplicates an existing flat one by filename, the newer file will simply overwrite the old one on disk — there's no automatic conflict resolution beyond "last one copied wins."

---


## License

See [`LICENSE`](./LICENSE) in the project root.
<!-- made by vamora -->
---
<p align="center">
  <sub>
    Made by 
    <a href="https://rb.gy/7jh0i9" target="_blank">
      <img src="https://github.com/user-attachments/assets/efb3ad9b-6b07-4488-9c16-79586297ee5d" alt="Vamora" height="10">
    </a>
  </sub>
</p>
