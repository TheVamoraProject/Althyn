<p align="center">
  <img  height="300" alt="Welcome Screen" src="https://github.com/user-attachments/assets/3bec9ebc-1700-4f3a-b2c2-4684a3b9f122" />
</p>
<h1 align="center">Althyn Welcome Screen</h1>
## Features

- **Fullscreen**, no title bar, no window chrome
- **Background** — soft blurred blobs (orange rounded rect, blue donut, small blue sphere) that gently float with breathing animations
- **Frosted-glass card** — backdrop blur using Qt 6.5 `MultiEffect`
- **Language cycling** — "Hello!" and "Are you ready?" auto-rotate through 16 languages with a smooth fade if the user sits idle
- **Animated button morph** — the single blue `→` pill expands and splits into a `‹  ›` two-button nav pill when clicked, matching the Figma transition
- **Two screens** — Hello screen → Vamora ToS/Welcome screen
- **Keyboard shortcuts**
  - `Ctrl+Shift+Q` — exit (kiosk-safe, always works)
  - `Escape` — exit (dev convenience; remove for production kiosk builds)

## File map

```
vamora_welcome_screen/
├── Cargo.toml                  # Rust crate (cxx-qt 0.7)
├── CMakeLists.txt              # CMake build tying Qt + Rust together
├── build.rs                    # CXX-Qt build script
├── src/
│   ├── main.rs                 # Rust entry — creates QGuiApplication + QQmlApplicationEngine
│   ├── welcome_bridge.rs       # CXX-Qt bridge — WelcomeController QObject (singleton)
│   └── main.cpp                # Thin C++ shim (required by Qt CMake machinery)
└── qml/
    ├── WelcomeScreen.qml       # All UI, animations, state machine
    └── assets/
        ├── background.jpg      # → copy from attached_assets/Background_*.jpg
        └── vamora_logo.png     # → copy from attached_assets/Vamora_*.png
```

## Build

### Prerequisites

| Tool | Version |
|------|---------|
| Rust | 1.77+ (stable) |
| CMake | 3.24+ |
| Qt | 6.5+ (Core, Gui, Qml, Quick, QuickControls2) |
| Ninja | any recent |

### Steps

```bash
cd vamora_welcome_screen

# Copy assets
cp ../attached_assets/Background_*.jpg qml/assets/background.jpg
cp ../attached_assets/Vamora_*.png     qml/assets/vamora_logo.png

# Configure
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Build (downloads Corrosion + CXX-Qt on first run)
cmake --build build

# Run
./build/vamora-welcome
```

## Customising

### Add more languages

Open `qml/WelcomeScreen.qml` and append to the `greetings` array:

```qml
{ hello: "Hola!",  ready: "¿Listo?" },
```

### Adjust the cycling speed

Change `langTimer.interval` (milliseconds). Default: 3200 ms.

### Change the exit shortcut

Find the `Shortcut` blocks at the bottom of `WelcomeScreen.qml` and update the `sequence` string to any [Qt key sequence](https://doc.qt.io/qt-6/qkeysequence.html).

### Connect setup completion to your session manager

In `src/welcome_bridge.rs`, `finish_setup()` currently calls `std::process::exit(0)`.
Replace that with whatever IPC/D-Bus call hands off to your compositor or session manager.

### Remove the Escape shortcut for kiosk builds

Delete or gate the second `Shortcut` block:

```qml
// Remove this for production kiosk builds:
Shortcut {
    sequence: "Escape"
    ...
}
```

## Architecture notes

- All product logic lives in Rust (`welcome_bridge.rs`). The QML side owns visual state only.
- `WelcomeController` is registered as a QML singleton via `#[qml_singleton]` — access it from any QML component with `WelcomeController.finish_setup()`.
- The frosted-glass effect uses `ShaderEffectSource` → `MultiEffect` — requires Qt 6.5+. On older Qt, replace with a plain semi-transparent `Rectangle`.
