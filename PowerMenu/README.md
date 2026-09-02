# vamora-powermenu

Standalone Qt/QML power overlay for the Vamora desktop.

## Behavior

- Starts full-screen and captures the X11 root window once before showing.
- Uses a blurred desktop capture with a translucent zinc overlay.
- Reads `vamorasys settings get appearance.theme` once at startup; relaunch to pick up changes.
- Shows the current Linux account picture and username.
- Resolves a friendly full name from AccountsService or the passwd profile
  instead of displaying a login principal such as `name@vamoraos`.
- Provides Lock screen, Sleep, Hibernate, Log out, Restart, and Shut down.
- Clicking the backdrop closes the menu, or cancels a pending confirmation.

The statusbar source is not part of this directory and is not modified by this app.

## Build and run

```bash
cargo run --release
```

The session needs an X11 `DISPLAY` for the desktop capture. The power commands
use `systemctl`/`loginctl` first and fall back to common desktop-session tools.