<p align="center">
<img height="300" alt="HomeScreen" src="https://github.com/user-attachments/assets/9a21879b-c1e9-45ba-af32-6fb0f6d283fb" />
</p>

# Vamora HomeScreen (X11)
Part of [**VamoraOS**](https://github.com/TheVamoraProject/VamoraOS/) — a Qt6/QML + Rust ([cxx-qt](https://github.com/KDAB/cxx-qt)) desktop/home layer for VamoraOS. This component targets **X11** window managers (developed and tested on Openbox) as a pre-alpha build.

> [!IMPORTANT]
> This X11 build is a compatibility track, not the priority. **[Althyn](https://github.com/TheVamoraProject/Althyn/)
> (Wayland)** is the actively developed, prioritized version, and the upcoming Vamora compositor is
> Wayland-only — it will not run this X11 build at all.

It's built with the **AlthynUI** design language.

---

## What this is

`vamora-homescreen` is a Qt window rendered via QML, backed by a small Rust core using `cxx-qt`. It
renders the desktop app grid ("home screen") and pins itself below other windows in the X11 stacking
order so it stays under the status bar and other panels regardless of launch order.

---

## Features

- App grid (6 columns × 4 rows) populated from `~/Desktop/*.desktop`
- Click to launch an app via its cleaned `Exec` string
- Right-click an app tile for a context menu:
  - **Remove from Homescreen** — deletes the `.desktop` file from `~/Desktop`
  - **App Info** — placeholder, not yet implemented
- Right-click empty background for:
  - **Add Widget** — placeholder, not yet implemented
  - **Add App** — placeholder, not yet implemented
  - **Shut Down** — calls `systemctl poweroff`, falling back to `shutdown -h now`
- **X11 window pinning**: on startup, a background thread marks the homescreen window
  `_NET_WM_WINDOW_TYPE_DESKTOP` and sends a `_NET_WM_STATE` `BELOW` request via EWMH, so it stays
  under the statusbar/other panels even if it maps before the window manager is ready. This is
  X11-only and does nothing on Wayland.

---

## Project Layout

```
HomeScreen/
├── Cargo.toml              Package manifest (edition 2024)
├── Cargo.lock
├── build.rs                 cxx-qt-build wiring
└── src/
    ├── main.rs               Entry point: creates QGuiApplication + QQmlApplicationEngine,
    │                         loads window.qml, spawns the X11 "keep below" thread
    ├── applist.rs            AppList QObject: scans ~/Desktop/*.desktop, launches apps,
    │                         removes apps, shuts the system down
    ├── x11below.rs           EWMH "stay below" pinning (X11-only, background thread)
    └── qml/
        ├── qml.qrc            Registers all .qml files as Qt resources
        ├── assets.qrc         Registers all icons/images as Qt resources
        ├── assets/
        │   ├── Vamora.svg     App logo
        │   └── icons/         Flat, mostly Lucide-sourced icon set
        └── layouts/
            └── homescreen/
                ├── window.qml       Top-level window, wires up context menus and shutdown
                ├── HomePage.qml     The app grid itself (GridView)
                ├── AppTile.qml      Single app icon + label tile
                └── ContextMenu.qml  Reusable VamoraUI-styled right-click context menu
```

---

## Dependencies

From `Cargo.toml`:

| Crate | Version | Purpose |
|---|---|---|
| `cxx` | 1.0.197 | Underlying C++ interop used by cxx-qt |
| `cxx-qt` | 0.9.1 | Rust ↔ Qt/QML bridge macros (`#[cxx_qt::bridge]`, `#[qml_element]`, etc.) |
| `cxx-qt-lib` | 0.9.1 (`qt_gui`, `qt_qml` features) | Qt type bindings (`QString`, `QGuiApplication`, `QQmlApplicationEngine`, …) |
| `x11rb` | 0.13 | Raw X11 protocol access, used only by `x11below.rs` for EWMH window state |
| `cxx-qt-build` | 0.9.1 (build-dependency) | Generates the Qt/QML build glue from `build.rs` |

You'll also need, at the system level:
- **Qt6** (Core, Gui, Qml, Quick) and its QML modules
- A working C++ toolchain (cxx-qt compiles a C++ shim under the hood)
- pkg-config / qmake discoverable on your system so `cxx-qt-build` can locate Qt

---

## Building

```bash
cargo build --release
```

`build.rs` invokes `cxx-qt-build`, which compiles the Rust bridge files, generates the C++ glue, and
bundles the two `.qrc` resource files (`qml.qrc`, `assets.qrc`) into the binary. There is no separate
"install icons/fonts" step — everything referenced by the `.qrc` files is embedded directly into the
executable at build time.

---

## License

See [`LICENSE`](../LICENSE) in the project root.

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
