import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import Qt5Compat.GraphicalEffects
import com.vamora

Window {
    id: notificationWindow

    width: 360
    height: 330
    visible: true
    color: "transparent"
    title: "Notifications"
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
    readonly property color cTopBar: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cHover: isDark ? "#3f3f46" : "#e4e4e7"
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"
    readonly property color cMuted: isDark ? "#a1a1aa" : "#52525b"
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"

    property bool isDark: true

    // Real notifications, from the compositor's notification service.
    property var items: []
    property double nowSecs: Date.now() / 1000

    NotificationStore { id: store }

    function refresh() {
        notificationWindow.nowSecs = Date.now() / 1000
        try { notificationWindow.items = JSON.parse(store.json()) } catch (e) { notificationWindow.items = [] }
    }

    function ago(t) {
        var d = Math.max(0, notificationWindow.nowSecs - t)
        if (d < 60) return "now"
        if (d < 3600) return Math.floor(d / 60) + "m"
        if (d < 86400) return Math.floor(d / 3600) + "h"
        return Math.floor(d / 86400) + "d"
    }

    Component.onCompleted: refresh()
    Timer { interval: 1000; repeat: true; running: notificationWindow.visible; onTriggered: notificationWindow.refresh() }

    onActiveChanged: {
        if (!active)
            notificationWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: notificationWindow.cBg
        radius: 24
        border.width: 1
        border.color: notificationWindow.cBorder

        Item {
            anchors.fill: parent
            anchors.margins: 16

            // Header
            Item {
                id: header
                width: parent.width
                height: 30

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: "NOTIFICATIONS"
                        color: notificationWindow.cText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        font.family: "Inter"
                    }
                    Text {
                        text: notificationWindow.items.length === 0
                            ? "You're all caught up"
                            : notificationWindow.items.length + (notificationWindow.items.length === 1 ? " notification" : " notifications")
                        color: notificationWindow.cMuted
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notificationWindow.items.length > 0
                    width: 74
                    height: 28
                    radius: 9
                    color: clearMouse.containsMouse ? notificationWindow.cHover : notificationWindow.cSurface

                    Text {
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: notificationWindow.cText
                        font.pixelSize: 10
                        font.family: "Inter"
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { store.clear(); notificationWindow.refresh() }
                    }
                }
            }

            // Empty state
            Rectangle {
                visible: notificationWindow.items.length === 0
                anchors.top: header.bottom
                anchors.topMargin: 10
                width: parent.width
                height: 74
                radius: 14
                color: notificationWindow.cSurface
                border.width: 1
                border.color: notificationWindow.cBorder

                Text {
                    anchors.centerIn: parent
                    text: "No new notifications"
                    color: notificationWindow.cMuted
                    font.pixelSize: 11
                    font.family: "Inter"
                }
            }

            Flickable {
                id: flick
                visible: notificationWindow.items.length > 0
                anchors.top: header.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: list.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: notificationWindow.items

                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property int hue: { var h = 7; for (var i = 0; i < modelData.app.length; i++) h = (h * 31 + modelData.app.charCodeAt(i)) % 360; return h }
                            width: list.width
                            height: Math.max(66, textCol.implicitHeight + 24)
                            radius: 14
                            color: cardMouse.containsMouse ? notificationWindow.cHover : notificationWindow.cSurface
                            border.width: 1
                            border.color: notificationWindow.cBorder

                            // App icon, or a coloured initial when there is none
                            Item {
                                id: cardIcon
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 13
                                width: 32
                                height: 32

                                Image {
                                    id: iconImg
                                    anchors.fill: parent
                                    visible: card.modelData.icon !== "" && status === Image.Ready
                                    source: card.modelData.icon !== "" ? "file://" + card.modelData.icon : ""
                                    sourceSize.width: 96
                                    sourceSize.height: 96
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle { width: 32; height: 32; radius: 9 }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !iconImg.visible
                                    radius: 16
                                    color: Qt.hsla((card.hue % 360) / 360, notificationWindow.isDark ? 0.45 : 0.55, notificationWindow.isDark ? 0.42 : 0.5, 1)
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.modelData.app.length > 0 ? card.modelData.app.charAt(0).toUpperCase() : "!"
                                        color: "white"
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        font.family: "Inter"
                                    }
                                }
                            }

                            // Picture (avatar / preview), if the app sent one
                            Image {
                                id: pic
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44
                                visible: card.modelData.image !== "" && status === Image.Ready
                                source: card.modelData.image !== "" ? "file://" + card.modelData.image : ""
                                sourceSize.width: 132
                                sourceSize.height: 132
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle { width: 44; height: 44; radius: 9 }
                                }
                            }

                            Column {
                                id: textCol
                                anchors.left: cardIcon.right
                                anchors.leftMargin: 12
                                anchors.right: pic.visible ? pic.left : parent.right
                                anchors.rightMargin: pic.visible ? 10 : 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: card.modelData.app + "  ·  " + notificationWindow.ago(card.modelData.time)
                                    color: notificationWindow.cMuted
                                    font.pixelSize: 9
                                    font.weight: Font.Medium
                                    font.capitalization: Font.AllUppercase
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: card.modelData.summary
                                    color: notificationWindow.cText
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    font.family: "Inter"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: card.modelData.body
                                    color: notificationWindow.cMuted
                                    font.pixelSize: 10
                                    font.family: "Inter"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                // click a notification to dismiss it
                                onClicked: { store.dismiss(card.modelData.id); notificationWindow.refresh() }
                            }
                        }
                    }
                }
            }
        }
    }
}
