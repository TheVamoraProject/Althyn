import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import Qt5Compat.GraphicalEffects

Window {
    id: trayWindow

    width: 290
    height: 244
    visible: true
    color: "transparent"
    title: "System Tray"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Wayland (layer-shell). Popups are overlay surfaces pinned to the
    // top-left corner; the posX/posY that the status bar assigns (next to x/y,
    // which only work on X11) become margins: same absolute screen coordinates. Ignored on X11.
    LayerShell.Window.scope: "vamora-popup"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.exclusionZone: -1
    property int posX: 0
    property int posY: 0
    LayerShell.Window.margins.left: Math.max(0, posX)
    LayerShell.Window.margins.top: Math.max(0, posY)

    readonly property color cBg: isDark ? "#18181b" : "#fafafa"
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cHover: isDark ? "#3f3f46" : "#e4e4e7"
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"
    readonly property color cMuted: isDark ? "#a1a1aa" : "#52525b"

    property bool isDark: true

    onActiveChanged: {
        if (!active)
            trayWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: trayWindow.cBg
        radius: 22
        border.width: 1
        border.color: trayWindow.cBorder

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "SYSTEM TRAY"
                color: trayWindow.cText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                font.family: "Inter"
            }

            Text {
                text: "Quick access to background tools"
                color: trayWindow.cMuted
                font.pixelSize: 10
                font.family: "Inter"
            }

            Repeater {
                model: [
                    { label: "Clipboard", icon: "../../assets/icons/folder.svg" },
                    { label: "Downloads", icon: "../../assets/icons/download.svg" },
                    { label: "Night light", icon: "../../assets/icons/crescent moon.svg" }
                ]

                delegate: Rectangle {
                    width: parent.width
                    height: 34
                    radius: 9
                    color: trayMouse.containsMouse
                        ? trayWindow.cHover : trayWindow.cSurface

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: modelData.icon
                        smooth: false
                        sourceSize.width: 64
                        sourceSize.height: 64
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: trayWindow.cText
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: trayWindow.cText
                        font.pixelSize: 11
                        font.family: "Inter"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: trayWindow.cMuted
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}