# Icon packs

Set `icons.theme` in VamoraSys (e.g. `Papirus-Dark`, `Tela-circle`). The dock, homescreen,
launcher and start menu look icons up in that pack first, then in `hicolor`.

## Vamora packs

A pack whose icons are full-bleed (e.g. circle packs) can opt in by adding
`VamoraPackage=true` under `[Icon Theme]` in its `index.theme`. Icons resolved from it are
drawn like Vamora icons: no backing tile, rounded by `icons.corner_radius`
(set it to 32 for a circle pack). Icons that fall back to another pack keep the tile.
A single app can also opt in with `VamoraPackage=<anything>` in its `.desktop` file.

`examples/widgets/` holds sample widgets (Clock, Calendar, Weather, Notes);
`examples/showcase/` builds the demo desktops.
