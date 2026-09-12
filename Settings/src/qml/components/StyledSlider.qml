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
            // Keep the fill endpoint under the knob's centre.  Using the
            // complete track width here leaves a visible unfilled gap beside
            // the knob at every value except the two endpoints.
            x: 3
            width: control.visualPosition * (parent.width - 26) + 10
            height: parent.height
            radius: parent.radius
            color: control.accent
        }
    }

    handle: Rectangle {
        x: control.leftPadding + 3 + control.visualPosition * (control.availableWidth - width - 6)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 20; height: 20; radius: 10
        color: "#ffffff"
        layer.enabled: true
    }
}
