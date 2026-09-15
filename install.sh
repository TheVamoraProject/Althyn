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
#
# Binaries -> /usr/local/bin/ (vamora-dock, vamora-homescreen,
#             vamora-launcher, vamora-powermenu, vamora-settings,
#             vamora-statusbar, vamora-welcome, althyn)
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

BINARIES=(vamora-dock vamora-homescreen vamora-launcher vamora-powermenu vamora-settings vamora-statusbar vamora-welcome)

CHROOT_DIR=""
SKIP_BUILD=0

usage() {
  sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

if [ ! -f "$REPO_ROOT/Cargo.toml" ] || [ ! -d "$REPO_ROOT/Runner" ]; then
  echo "install.sh: expected to sit at the repo root (next to Cargo.toml and Runner/) — run it from there." >&2
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

echo "install.sh: installing binaries -> ${DESTROOT}/usr/local/bin/"
for bin in "${BINARIES[@]}"; do
  put "target/release/$bin" "/usr/local/bin/$bin" 755
done
put "Runner/althyn" "/usr/local/bin/althyn" 755

echo "install.sh: installing session files"
put "Runner/x11/vamora.desktop" "/usr/share/xsessions/vamora.desktop" 644
put "Runner/wayland/com.vamora.althyn.desktop" "/usr/share/wayland-sessions/com.vamora.althyn.desktop" 644

echo "install.sh: installing wallpapers"
for f in Branding/wallpapers/*; do
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
fi
