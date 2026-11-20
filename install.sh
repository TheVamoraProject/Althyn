#!/usr/bin/env bash
# Althyn installer/updater.
#
# Default (no flags): builds the workspace and installs onto the running
# system (needs root for the system paths, so it uses sudo for just the
# install/copy steps below — never for the cargo build itself, so you're
# not building as root).
# Running it again later (after a `git pull`) re-builds and re-installs
# over the top — that's the "updater" half, same command either way.
#
#   ./install.sh                 build + install onto this machine
#   ./install.sh --skip-build    reinstall using whatever's already in
#                                 target/release (no rebuild)
#   ./install.sh --chroot DIR    stage into DIR/config/includes.chroot
#                                 instead (for a live-build ISO project —
#                                 see below), no sudo used at all
#   ./install.sh --no-compositor skip Althyn's Wayland compositor
#                                 (compositor/); the X11 session
#                                 (althyn --run-x11) still works without it,
#                                 the Wayland session does not
#   ./install.sh --with-layer-shell-qt
#                                 also build + install LayerShellQt from
#                                 source (see scripts/) if it is missing
#
# Binaries -> /usr/local/bin/ (althyn-dock, althyn-home, althyn-launcher,
#             althyn-power, vamora-settings, althyn-bar, althyn-setup,
#             althyn-core (the compositor), althyn (the session runner))
# Anything installed under the previous names (vamora-dock, vamora-homescreen,
# vamora-statusbar, ...) is removed so nothing stale is left on PATH.
# Sessions -> /usr/share/xsessions/vamora.desktop
#             /usr/share/wayland-sessions/com.vamora.althyn.desktop
# Wallpapers -> /etc/VamoraSys/wallpapers/
#
# `vamorasys` itself is a separate component and is expected to already
# be on PATH — this script only checks for it and warns, it doesn't try
# to install it.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$REPO_ROOT"

BINARIES=(althyn-dock althyn-home althyn-launcher althyn-power vamora-settings althyn-bar althyn-setup)
# Names used before the rename; removed from the install destination.
LEGACY_BINARIES=(vamora-dock vamora-homescreen vamora-launcher vamora-powermenu vamora-statusbar vamora-welcome vamora-compositor)

COMPOSITOR_BIN=althyn-core
COMPOSITOR_DIR="$REPO_ROOT/compositor"

CHROOT_DIR=""
SKIP_BUILD=0
WITH_COMPOSITOR=1
WITH_LAYER_SHELL_QT=0

usage() {
  sed -n '2,36p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --chroot)
      [ $# -ge 2 ] || { echo "install.sh: --chroot needs a path" >&2; exit 1; }
      CHROOT_DIR="$2"
      shift 2
      ;;
    --chroot=*)
      CHROOT_DIR="${1#--chroot=}"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --no-compositor)
      WITH_COMPOSITOR=0
      shift
      ;;
    --with-layer-shell-qt)
      WITH_LAYER_SHELL_QT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "install.sh: unknown argument '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -f "$REPO_ROOT/Cargo.toml" ] || [ ! -d "$REPO_ROOT/runner" ]; then
  echo "install.sh: expected to sit at the repo root (next to Cargo.toml and runner/) — run it from there." >&2
  exit 1
fi

# ---- destination root ----
# Real system: DESTROOT is "" (paths below are absolute, e.g. /usr/local/bin).
# --chroot DIR: DESTROOT is DIR/config/includes.chroot — live-build copies
# that tree verbatim into the ISO's chroot filesystem at the same relative
# paths, so staging into it is identical to a real install, just without
# ever touching the host machine or needing root.
if [ -n "$CHROOT_DIR" ]; then
  DESTROOT="$CHROOT_DIR/config/includes.chroot"
  if [ ! -d "$CHROOT_DIR/config" ]; then
    echo "install.sh: '$CHROOT_DIR/config' doesn't exist — is this a live-build project (has 'lb config' been run there)?" >&2
    exit 1
  fi
  mkdir -p "$DESTROOT"
  SUDO=""
  echo "install.sh: staging into $DESTROOT"
else
  DESTROOT=""
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  else
    SUDO="sudo"
    echo "install.sh: installing onto the running system, using sudo for system paths"
  fi
fi

# ---- build ----
if [ "$SKIP_BUILD" -eq 0 ]; then
  command -v cargo >/dev/null 2>&1 || { echo "install.sh: cargo not found on PATH — can't build. Use --skip-build if target/release is already built." >&2; exit 1; }
  echo "install.sh: building (cargo build --release --workspace)..."
  cargo build --release --workspace
fi

# ---- compositor ----
# Althyn's Wayland compositor (Rust + Smithay) is its own cargo project in
# compositor/ (it is not part of the workspace). It is built with the `udev`
# feature, i.e. the real DRM/KMS + libinput + libseat backend, which needs a
# few system development libraries; check for them first so a missing one
# produces a clear message instead of a linker error.
if [ "$WITH_COMPOSITOR" -eq 1 ]; then
  if [ ! -f "$COMPOSITOR_DIR/Cargo.toml" ]; then
    echo "install.sh: compositor/ is missing — use --no-compositor to skip it." >&2
    exit 1
  fi
  if [ "$SKIP_BUILD" -eq 0 ]; then
    missing=""
    if command -v pkg-config >/dev/null 2>&1; then
      for pc in wayland-server xkbcommon libinput libudev libseat gbm libdrm egl; do
        pkg-config --exists "$pc" 2>/dev/null || missing="$missing $pc"
      done
    else
      missing=" pkg-config"
    fi
    if [ -n "$missing" ]; then
      echo "install.sh: the compositor needs these development libraries, not found:$missing" >&2
      echo "  Debian/Ubuntu: sudo apt install pkg-config libwayland-dev libxkbcommon-dev libinput-dev libudev-dev libseat-dev libgbm-dev libdrm-dev libegl-dev libgles-dev" >&2
      echo "  (or run with --no-compositor to skip it; only the X11 session will work then)" >&2
      exit 1
    fi
    echo "install.sh: building the compositor (cargo build --release --features udev)..."
    ( cd "$COMPOSITOR_DIR" && cargo build --release --features udev )
  fi
  if [ ! -x "$COMPOSITOR_DIR/target/release/$COMPOSITOR_BIN" ]; then
    echo "install.sh: compositor/target/release/$COMPOSITOR_BIN is missing — build it first (drop --skip-build)." >&2
    exit 1
  fi
fi

# ---- LayerShellQt ----
# StatusBar, Dock and HomeScreen import `org.kde.layershell` (KDE's
# LayerShellQt) in QML to become Wayland layer-shell surfaces, in both the
# Wayland and X11 sessions, so the QML module must be installed. It must be
# built against the same Qt the apps use.
layer_shell_qt_present() {
  local d
  for d in $(qmake6 -query QT_INSTALL_QML 2>/dev/null) \
           /usr/lib/*/qt6/qml /usr/lib/qt6/qml /usr/local/lib/qt6/qml /usr/local/lib/*/qt6/qml; do
    [ -f "$d/org/kde/layershell/qmldir" ] && return 0
  done
  return 1
}
if ! layer_shell_qt_present; then
  if [ "$WITH_LAYER_SHELL_QT" -eq 1 ] && [ -z "$CHROOT_DIR" ]; then
    echo "install.sh: building LayerShellQt (scripts/build-layer-shell-qt.sh)..."
    ( cd "$(mktemp -d)" && $SUDO env PREFIX=/usr/local "$REPO_ROOT/scripts/build-layer-shell-qt.sh" )
  else
    echo "install.sh: warning — LayerShellQt (QML module org.kde.layershell) was not found." >&2
    echo "  The status bar, dock and home screen will not start without it." >&2
    echo "  Install your distro's Qt6 package of it, or re-run with --with-layer-shell-qt" >&2
    echo "  (or run scripts/build-layer-shell-qt.sh)." >&2
  fi
fi

for bin in "${BINARIES[@]}"; do
  if [ ! -x "target/release/$bin" ]; then
    echo "install.sh: target/release/$bin is missing — build it first (drop --skip-build, or build just this crate)." >&2
    exit 1
  fi
done

command -v vamorasys >/dev/null 2>&1 || echo "install.sh: warning — 'vamorasys' isn't on PATH. Althyn needs it at runtime; this script doesn't install it." >&2

# ---- install ----
put() { # put SRC DEST-RELATIVE-TO-DESTROOT MODE
  local src="$1" rel="$2" mode="$3"
  $SUDO install -Dm"$mode" "$src" "$DESTROOT$rel"
}

for old in "${LEGACY_BINARIES[@]}"; do
  if [ -e "$DESTROOT/usr/local/bin/$old" ] || [ -L "$DESTROOT/usr/local/bin/$old" ]; then
    echo "install.sh: removing old binary name $DESTROOT/usr/local/bin/$old"
    $SUDO rm -f "$DESTROOT/usr/local/bin/$old"
  fi
done

echo "install.sh: installing binaries -> ${DESTROOT}/usr/local/bin/"
for bin in "${BINARIES[@]}"; do
  put "target/release/$bin" "/usr/local/bin/$bin" 755
done
if [ "$WITH_COMPOSITOR" -eq 1 ]; then
  put "$COMPOSITOR_DIR/target/release/$COMPOSITOR_BIN" "/usr/local/bin/$COMPOSITOR_BIN" 755
fi
put "runner/althyn" "/usr/local/bin/althyn" 755

echo "install.sh: installing session files"
put "runner/x11/vamora.desktop" "/usr/share/xsessions/vamora.desktop" 644
put "runner/wayland/com.vamora.althyn.desktop" "/usr/share/wayland-sessions/com.vamora.althyn.desktop" 644

echo "install.sh: installing wallpapers"
for f in branding/wallpapers/*; do
  put "$f" "/etc/VamoraSys/wallpapers/$(basename "$f")" 644
done

# Small breadcrumb for "did this get updated, and when" — not required to
# run Althyn, just handy when something's not matching what you expect.
VERSION_FILE="/usr/local/share/althyn/installed"
GIT_REF="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
$SUDO mkdir -p "$DESTROOT/usr/local/share/althyn"
printf 'commit: %s\ninstalled: %s\n' "$GIT_REF" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" | $SUDO tee "$DESTROOT$VERSION_FILE" >/dev/null

if [ -n "$CHROOT_DIR" ]; then
  echo "install.sh: done — staged into $DESTROOT (build the ISO with lb build as usual)."
else
  echo "install.sh: done — log out and pick 'Vamora Althyn' from the session menu."
  if [ "$WITH_COMPOSITOR" -eq 1 ]; then
    echo "install.sh: the Wayland session uses althyn-core (it needs seat access: systemd-logind or seatd)."
  fi
fi
