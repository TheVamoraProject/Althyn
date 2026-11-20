import QtQuick
import QtQuick.Controls

// A Slider re-skinned to match the ToggleRow switch: same track height,
// same fully-rounded pill shape, same plain white knob — just wider,
// and with the filled portion tracking the accent color instead of a
// hardcoded blue. Drop-in replacement for the default Slider everywhere
// in the app so every slider and every switch reads as one control family.
Slider {
    id: control

    readonly property var appWindow: ApplicationWindow.window
    readonly property bool dark: !(appWindow && appWindow.darkTheme === false)
    readonly property color trackOff: dark ? "#3f3f46" : "#d4d4d8"
    readonly property color accent: appWindow && appWindow.accentColor !== undefined ? appWindow.accentColor : "#7dd3fc"

    implicitHeight: 26

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 26
        radius: height / 2
        color: control.trackOff

        Rectangle {
            // Extend the fill under the knob rather than stopping at its
            // centre, then square off the right edge so no rounded corner
            // ever peeks out from behind the knob. The knob itself (same
            // height as the track, with an accent-colored stroke) sits on
            // top and creates the illusion of a smaller knob inset in the
            // fill with even spacing all around.
            x: 0
            width: control.visualPosition * (parent.width - height) + height
            height: parent.height
            topLeftRadius: parent.radius
            bottomLeftRadius: parent.radius
            topRightRadius: parent.radius
            bottomRightRadius: parent.radius
            color: control.accent
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 26; height: 26; radius: 13
        color: "#ffffff"
        border.width: 3
        border.color: control.accent
    }
}
