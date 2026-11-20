#!/bin/bash
# Builds and installs LayerShellQt (KDE) so Qt apps can be Wayland layer-shell
# surfaces. Althyn's StatusBar, Dock and HomeScreen import `org.kde.layershell`
# in QML (they need it in the X11 session too; there it simply does nothing).
#
#   PREFIX=/usr/local     install prefix (default /usr/local)
#   LSQ_TAG=v6.8.2        which LayerShellQt release to build
#
# IMPORTANT: it must be built against the Qt the Althyn apps run on, and each
# LayerShellQt release has a minimum Qt version (v6.8.2 needs Qt >= 6.11). If
# your Qt is older, pick an older tag that matches it (LSQ_TAG=...); the build
# will stop at the Qt version check rather than produce a broken plugin.
#
# Needs: cmake, a C++ compiler, extra-cmake-modules, wayland + wayland-protocols,
# and Qt6 Gui/Qml/WaylandClient with the private WaylandClient headers.
set -euo pipefail
PREFIX=${PREFIX:-/usr/local}
LSQ_TAG=${LSQ_TAG:-v6.8.2}

git clone --depth 1 --branch "$LSQ_TAG" https://github.com/KDE/layer-shell-qt.git lsq
cd lsq
# The release asks for a very new extra-cmake-modules; it only needs older
# features, so relax that one requirement (not the Qt one).
sed -i 's/set(KF6_MIN_VERSION "[0-9.]*")/set(KF6_MIN_VERSION "6.0.0")/' CMakeLists.txt
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_TESTING=OFF
cmake --build build -j"$(nproc)" --target LayerShellQtInterface layer-shell LayerShellQtQml
cmake --install build
