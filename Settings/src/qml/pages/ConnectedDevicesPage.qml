import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    anchors.fill: parent

    property bool althynShare: true
    property string sharedDevice: ""

    readonly property var peripherals: [
        { name: "27\" 4K Display",    icon: "monitor",        sub: "Connected via HDMI" },
        { name: "USB-C Hub",           icon: "usb",            sub: "4 ports, charging" },
        { name: "Bluetooth Keyboard", icon: "app-window",     sub: "MX Keys Mini · Connected" },
        { name: "Wireless Mouse",      icon: "mouse-pointer-2", sub: "Logitech MX3 · Connected" },
        { name: "USB Printer",         icon: "hard-drive",     sub: "HP LaserJet · Ready" },
        { name: "Webcam",              icon: "image",          sub: "Logitech C920 · Idle" },
    ]

    readonly property var althynDevices: [
        { name: "AlthynPhone 2",   icon: "computer", status: "Nearby · Available" },
        { name: "Vamora Tablet",   icon: "monitor",  status: "Nearby · Available" },
    ]

    ScrollView {

        // Kinetic/touch scrolling: rubber-band overshoot + tuned flick
        // feel so dragging with a finger (VamoraFold, touch panels) works
        // like a native scroller, not just mouse-wheel/scrollbar drag.
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.DragAndOvershootBounds
            contentItem.maximumFlickVelocity = 2500
            contentItem.flickDeceleration = 1500
        }
        anchors.fill: parent; contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width; spacing: 0
            Item { height: 28 }

            ColumnLayout {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; spacing: 14

                SectionHeader { label: "Peripherals" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: periphGroup.implicitHeight

                    Column {
                        id: periphGroup
                        anchors { left: parent.left; right: parent.right }

                        Repeater {
                            model: peripherals
                            delegate: Rectangle {
                                required property var modelData; required property int index
                                width: periphGroup.width; height: 60
                                color: phov ? "#252525" : "transparent"; Behavior on color { ColorAnimation { duration: 100 } }
                                property bool phov: false

                                Rectangle { visible: index > 0; anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }; spacing: 12
                                    Rectangle {
                                        width: 38; height: 38; radius: 10; color: Qt.rgba(1,1,1,0.05)
                                        Image {
                                            anchors.centerIn: parent
                                            width: 20; height: 20
                                            source: "../assets/icons/" + modelData.icon + ".svg"
                                            sourceSize: Qt.size(40, 40)
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: modelData.name; color: "#f0f0f0"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.sub; color: "#555"; font.pixelSize: 11 }
                                    }
                                    Text { text: "›"; color: "#3a3a3a"; font.pixelSize: 18 }
                                }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.phov = true; onExited: parent.phov = false }
                            }
                        }
                    }
                }

                SectionHeader { label: "Althyn Share" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: althynGroup.implicitHeight

                    Column {
                        id: althynGroup
                        anchors { left: parent.left; right: parent.right }

                        ToggleRow {
                            width: parent.width; rowLabel: "Althyn Share"
                            rowSub: "Share files instantly with nearby VamoraOS devices"
                            on_: althynShare; isFirst: true
                            onToggled: function(v) { althynShare = v }
                        }

                        Rectangle {
                            width: parent.width; height: 44; color: "transparent"; visible: althynShare
                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                Text { text: "Nearby Devices"; color: "#888"; font.pixelSize: 12; Layout.fillWidth: true }
                                Rectangle {
                                    width: 20; height: 20; radius: 10; color: "#22c55e"
                                    Text { anchors.centerIn: parent; text: althynDevices.length; color: "#fff"; font { pixelSize: 10; weight: Font.Bold } }
                                }
                            }
                        }

                        Repeater {
                            model: althynShare ? althynDevices : []
                            delegate: Rectangle {
                                required property var modelData; required property int index
                                width: althynGroup.width; height: 56; color: "transparent"
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
                                    height: 1
                                    color: "#252525"
                                }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 32; rightMargin: 16 }
                                    spacing: 12
                                    Rectangle {
                                        width: 34; height: 34; radius: 10
                                        color: Qt.rgba(1,1,1,0.05)
                                        Image {
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            source: "../assets/icons/" + modelData.icon + ".svg"
                                            sourceSize: Qt.size(36, 36)
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: modelData.name; color: "#f0f0f0"; font.pixelSize: 13 }
                                        Text { text: modelData.status; color: "#22c55e"; font.pixelSize: 11 }
                                    }
                                    Rectangle {
                                        width: 56; height: 26; radius: 7; color: "#1a2a1a"; border { color: "#22c55e30"; width: 1 }
                                         Text {
                                             anchors.centerIn: parent
                                             text: sharedDevice === modelData.name ? "Shared" : "Share"
                                             color: "#22c55e"
                                             font.pixelSize: 11
                                         }
                                         MouseArea {
                                             anchors.fill: parent
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: sharedDevice = modelData.name
                                         }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
