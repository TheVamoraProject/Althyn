<p align="center">
  <img  height="300" alt="Welcome Screen" src="https://github.com/user-attachments/assets/3bec9ebc-1700-4f3a-b2c2-4684a3b9f122" />
</p>
<h1 align="center">Althyn Welcome Screen</h1>
<p align="center">
QML + CXX-Qt + Rust implementation of the VamoraOS first-boot welcome flow.
</p>

## Features

- **Language Select** : Select the language and it would change using `localetcl`
- **Frosted-glass card** : backdrop blur using Qt 6.5 `MultiEffect`
- **Language cycling** : "Hello!" and "Are you ready?" auto-rotate through 16 languages with a smooth fade if the user sits idle
- **Animated button morph** : the single blue `>` pill expands and splits into a `‹  ›` two-button nav pill when clicked.
- **Two screens** : Hello screen → Vamora ToS/Welcome screen
- **Keyboard shortcut just in case**
  - `Ctrl+Shift+Q` — exit (kiosk-safe, always works)

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
cd Live
cargo build --release
```

## Customising

### Add more languages

Open `qml/WelcomeScreen.qml` and append to the `greetings` array:

```qml
{ hello: "Hola!",  ready: "¿Listo?" },
```

### Change the exit shortcut

Find the `Shortcut` blocks at the bottom of `WelcomeScreen.qml` and update the `sequence` string to any [Qt key sequence](https://doc.qt.io/qt-6/qkeysequence.html).

### Connect setup completion to your session manager

In `src/welcome_bridge.rs`, `finish_setup()` currently calls `std::process::exit(0)`.
Replace that with whatever IPC/D-Bus call hands off to your compositor or session manager.
