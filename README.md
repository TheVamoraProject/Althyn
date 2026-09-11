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

## Rust Workspace

The desktop environment components are managed as one Cargo workspace. Build
all components from the repository root:

```bash
cargo build --workspace
```

Build or run one component with its package name:

```bash
cargo build -p vamora-statusbar
cargo run -p vamora-launcher
```

The workspace contains the packages in `Dock`, `HomeScreen`, `Launcher`,
`PowerMenu`, `Settings`, `StatusBar`, and `WelcomeScreen/Live`.
