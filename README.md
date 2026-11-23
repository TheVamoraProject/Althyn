<p align="center">
<img height="80" alt="Althyn" src="https://github.com/user-attachments/assets/675f447b-dbf2-42cc-8a31-f7851afa1087" />
</p>
<p align="center">
  Adaptive user interface for desktop, mobile, and more.
</p>

## One Interface, Every Screen

<a href="https://vamora.vercel.app/blog/vamui">VamoraUI</a> is a single set of rules for color, shape, and spacing — not a per-platform redesign. The same components and code paths adapt density automatically across phone, tablet, and desktop, so every surface stays recognizably Vamora.

- **Phone:** single column, bottom navigation, minimal controls
- **Tablet:** two-column density, navigation grows with the width
- **Desktop:** full grid density, side navigation, room for everything

## Build

The desktop environment components are managed as one Cargo workspace. Build
all components from the repository root:

```bash
cargo build --workspace --release
```

Build or run one component with its package name:

```bash
cargo build -p althyn-bar
cargo run -p althyn-launcher
```

The workspace contains the packages in `dock`, `home`, `launcher`, `power`,
`settings`, `statusbar`, and `setup/live`. The compositor (`compositor/`) is
its own Cargo project with a separate lockfile; `install.sh` builds it too.

## Layout and executables

| Directory | Package / executable |
|---|---|
| `compositor/` | `althyn-core` |
| `dock/` | `althyn-dock` |
| `home/` | `althyn-home` |
| `launcher/` | `althyn-launcher` |
| `power/` | `althyn-power` |
| `runner/` | `althyn` (session launcher script) |
| `settings/` | `vamora-settings` |
| `statusbar/` | `althyn-bar` |
| `setup/live/` | `althyn-setup` |
| `branding/` | wallpapers and other branding assets |
| `scripts/` | helper scripts (`build-layer-shell-qt.sh`) |

## Install

```bash
./install.sh            # build + install to /usr/local/bin (uses sudo)
./install.sh --chroot DIR   # stage into a live-build project instead
```

Then pick "Vamora Althyn" (Wayland, runs `althyn-core`) or
"Vamora Althyn (X11)" in the session menu. Runtime needs: `vamorasys`,
`swaybg` (Wayland wallpaper), and `openbox`, `feh`, `picom` (X11 session).
