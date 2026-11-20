# Vamora Settings refresh

## UI

- Reworked the shell palette to use Vamora's zinc surfaces, true-black dark mode, softer 24px cards, and light-blue accent states.
- Added a clearer settings sidebar header and improved application/device lists.
- Replaced emoji UI icons with the bundled line/icon assets.
- Updated About, Applications, Connections, and Help surfaces to follow the system theme instead of forcing dark-only cards.

## Qt WebView recovery

- Help now loads Qt WebView lazily, so the settings app can still open when the QML module is missing.
- The Help page shows an install dialog when the module is unavailable.
- On Debian-family systems it offers:

  `sudo apt-get install qml6-module-qtwebview`

  The password is sent only to `sudo` over stdin for that install attempt and is not saved or passed as a command-line argument.
- On other systems it identifies the environment as a custom/non-Debian VamoraOS build and directs the user to install the Qt 6 WebView QML module manually.

## Skill

The supplied `vamora-design` skill is installed at `.agents/skills/vamora-design/`, with QML and TSX references.