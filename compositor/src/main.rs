//! Althyn's Wayland compositor.
//!
//! Built on Smithay. The structure follows Smithay's `smallvil` and `anvil`
//! examples (MIT): a single `State` owning every protocol global, backends
//! that feed it input and consume its frames, and a calloop event loop.

mod backend;
mod config;
mod foreign_toplevel;
mod grabs;
mod handlers;
mod input;
mod render;
mod titlebar;
mod notify;
mod notify_icons;
mod shell;
mod state;

use std::process::{Command, Stdio};

use smithay::reexports::{calloop::EventLoop, wayland_server::Display};
use tracing::{error, info, warn};

pub use state::State;

const USAGE: &str = "\
althyn-core — Althyn's Wayland compositor

USAGE:
    althyn-core [OPTIONS]

OPTIONS:
    -s, --startup <CMD>     Run CMD (through `sh -c`) once the compositor is ready
        --size <WxH>        Window size when running nested (winit), default 1280x800
        --backend <NAME>    winit | udev (default: winit when a display server is
                            already running, udev otherwise)
    -h, --help              Print this help

Settings are read from VamoraSys (`vamorasys settings get <key>`).
Set RUST_LOG (e.g. RUST_LOG=debug) for more logging.";

#[derive(Clone, Copy, PartialEq, Eq)]
enum BackendKind {
    Winit,
    Udev,
}

struct Args {
    startup: Option<String>,
    size: Option<(f64, f64)>,
    backend: Option<BackendKind>,
}

fn parse_args() -> Result<Args, String> {
    let mut args = Args {
        startup: None,
        size: None,
        backend: None,
    };
    let mut it = std::env::args().skip(1);
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "-s" | "--startup" => {
                args.startup = Some(it.next().ok_or("--startup needs a command")?);
            }
            "--size" => {
                let value = it.next().ok_or("--size needs WxH, e.g. 412x892")?;
                let parsed = value.split_once('x').and_then(|(w, h)| {
                    Some((w.parse::<f64>().ok()?, h.parse::<f64>().ok()?))
                });
                args.size = Some(
                    parsed
                        .filter(|(w, h)| *w >= 100.0 && *h >= 100.0)
                        .ok_or_else(|| format!("bad --size {value:?} (expected WxH, e.g. 412x892)"))?,
                );
            }
            "--backend" => {
                args.backend = Some(match it.next().as_deref() {
                    Some("winit") => BackendKind::Winit,
                    Some("udev") => BackendKind::Udev,
                    other => {
                        return Err(format!(
                            "unknown backend {other:?} (expected winit or udev)"
                        ));
                    }
                });
            }
            "-h" | "--help" => {
                println!("{USAGE}");
                std::process::exit(0);
            }
            other => return Err(format!("unknown argument {other:?}\n\n{USAGE}")),
        }
    }
    Ok(args)
}

fn main() {
    init_logging();

    let args = match parse_args() {
        Ok(args) => args,
        Err(err) => {
            eprintln!("{err}");
            std::process::exit(2);
        }
    };

    if let Err(err) = run(args) {
        error!("{err}");
        std::process::exit(1);
    }
}

fn run(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    let mut event_loop: EventLoop<'static, State> = EventLoop::try_new()?;
    let display: Display<State> = Display::new()?;

    // Inside another session we run as a window; on a bare VT we own the GPU.
    let nested =
        std::env::var_os("WAYLAND_DISPLAY").is_some() || std::env::var_os("DISPLAY").is_some();
    let kind = args.backend.unwrap_or(if nested {
        BackendKind::Winit
    } else {
        BackendKind::Udev
    });

    let mut state = match kind {
        BackendKind::Winit => backend::winit::init(&mut event_loop, display, args.size)?,
        BackendKind::Udev => {
            #[cfg(feature = "udev")]
            {
                backend::udev::init(&mut event_loop, display)?
            }
            #[cfg(not(feature = "udev"))]
            {
                return Err("this build has no udev backend (rebuild with --features udev)".into());
            }
        }
    };

    // Children (wallpaper, status bar, dock, ...) must talk to *us*.
    // Safety: still single threaded here apart from the settings watcher,
    // which never touches the environment.
    unsafe {
        std::env::set_var("WAYLAND_DISPLAY", &state.socket_name);
        std::env::set_var("XDG_SESSION_TYPE", "wayland");
        std::env::set_var("XDG_CURRENT_DESKTOP", "Vamora");
    }
    info!(
        socket = ?state.socket_name,
        backend = state.backend.name(),
        "compositor ready"
    );

    if let Some(cmd) = args.startup {
        match Command::new("sh")
            .arg("-c")
            .arg(&cmd)
            .stdin(Stdio::null())
            .spawn()
        {
            Ok(_) => info!(%cmd, "startup command launched"),
            Err(err) => warn!(%cmd, "could not launch the startup command: {err}"),
        }
    }

    event_loop.run(None, &mut state, |_| {})?;
    info!("compositor stopped");
    Ok(())
}

fn init_logging() {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));
    tracing_subscriber::fmt().with_env_filter(filter).init();
}
