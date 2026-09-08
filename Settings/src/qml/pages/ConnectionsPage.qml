import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: connectionsPage
    anchors.fill: parent
    readonly property var settingsWindow: ApplicationWindow.window
    readonly property bool dark: !settingsWindow || settingsWindow.darkTheme
    readonly property color pageCard: dark ? "#18181b" : "#ffffff"
    readonly property color pageHover: dark ? "#27272a" : "#f4f4f5"
    readonly property color pageBorder: dark ? "#27272a" : "#e4e4e7"
    readonly property color pageText: dark ? "#f4f4f5" : "#18181b"
    readonly property color pageMuted: dark ? "#a1a1aa" : "#71717a"
    readonly property color pageAccent: settingsWindow && settingsWindow.accentColor !== undefined
                                        ? settingsWindow.accentColor : "#7dd3fc"

    // ── Mock state ────────────────────────────────────────────────────────────
    property bool wifiOn: true
    property bool btOn:   true
    property bool vpnAdded: false

    ListModel {
        id: wifiModel
        ListElement { ssid: "VamoraNet_5G"; strength: 95; secured: true;  connected: true  }
        ListElement { ssid: "HomeNetwork";  strength: 72; secured: true;  connected: false }
        ListElement { ssid: "GuestWifi";    strength: 48; secured: false; connected: false }
        ListElement { ssid: "Office_5GHz";  strength: 31; secured: true;  connected: false }
        ListElement { ssid: "Neighbor_AP";  strength: 15; secured: true;  connected: false }
    }

    ListModel {
        id: btModel
        ListElement { name: "AirPods Pro"; icon: "volume-1"; paired: true; connected: true }
        ListElement { name: "MX Keys Mini"; icon: "app-window"; paired: true; connected: true }
        ListElement { name: "Logitech MX3"; icon: "mouse-pointer-2"; paired: true; connected: false }
        ListElement { name: "JBL Flip 6"; icon: "volume-2"; paired: false; connected: false }
    }

    // Password dialog
    Dialog {
        id: pwDialog
        property string target: ""
        property int targetIndex: -1
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320; modal: true
        background: Rectangle { color: "#1e1e1e"; radius: 16; border { color: "#2c2c2c"; width: 1 } }

        header: Item {
            height: 54
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "Connect to " + pwDialog.target
                color: "#f5f5f5"; font { pixelSize: 15; weight: Font.Medium }
            }
        }

        ColumnLayout {
            spacing: 10; width: parent.width
            Text { text: "Password"; color: "#666666"; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; height: 42; radius: 10
                color: "#141414"; border { color: pwInput.activeFocus ? "#3b82f6" : "#333"; width: 1 }
                TextInput {
                    id: pwInput
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#f5f5f5"; font.pixelSize: 14
                    echoMode: TextInput.Password
                    placeholderText: "Enter password"; placeholderTextColor: "#444"
                }
            }
        }

        footer: RowLayout {
            padding: 14; spacing: 8
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 80; height: 34; radius: 8; color: "#2a2a2a"
                Text { anchors.centerIn: parent; text: "Cancel"; color: "#888"; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pwDialog.reject() }
            }
            Rectangle {
                width: 90; height: 34; radius: 8; color: "#3b82f6"
                Text { anchors.centerIn: parent; text: "Connect"; color: "#fff"; font.pixelSize: 13; font.weight: Font.Medium }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pwDialog.targetIndex >= 0)
                            wifiModel.setProperty(pwDialog.targetIndex, "connected", true)
                        pwDialog.accept()
                        pwInput.text = ""
                    }
                }
            }
        }
    }

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

                // ── WiFi ──────────────────────────────────────────────────────
                SectionHeader { label: "WiFi" }

                Rectangle {
                    Layout.fillWidth: true; radius: 24; color: connectionsPage.pageCard
                    border.color: connectionsPage.pageBorder; border.width: 1; clip: true
                    implicitHeight: wifiGroup.implicitHeight

                    Column {
                        id: wifiGroup
                        anchors { left: parent.left; right: parent.right }

                        // Toggle
                        ToggleRow {
                            width: parent.width
                            rowLabel: "WiFi"; rowSub: wifiOn ? "Connected to " + wifiModel.get(0).ssid : "Off"
                            on_: wifiOn; isFirst: true
                            onToggled: function(v) { wifiOn = v }
                        }

                        // Scan row
                        Rectangle {
                            width: parent.width; height: 42; color: "transparent"
                            visible: wifiOn

                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                Text { text: "Scan for networks"; color: "#3b82f6"; font.pixelSize: 13; Layout.fillWidth: true }
                                Text { text: wifiModel.count + " found"; color: "#444"; font.pixelSize: 12 }
                            }
                                         MouseArea {
                                             anchors.fill: parent
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: wifiModel.setProperty(index, "connected", false)
                                         }
                        }

                        // Network list
                        Repeater {
                            model: wifiOn ? wifiModel : null
                            delegate: Rectangle {
                                required property string ssid
                                required property int    strength
                                required property bool   secured
                                required property bool   connected
                                required property int    index
                                width: wifiGroup.width; height: 58
                                color: nhov ? "#252525" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                property bool nhov: false

                                Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }; spacing: 12

                                    WifiBar { strength: parent.parent.strength; connected: parent.parent.connected; secured: parent.parent.secured }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text {
                                            text: ssid; color: "#f0f0f0"
                                            font { pixelSize: 13; weight: connected ? Font.Medium : Font.Normal }
                                            elide: Text.ElideRight; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: connected ? "Connected" : (secured ? "Secured · " + strength + "%" : "Open · " + strength + "%")
                                            color: connected ? "#3b82f6" : "#555555"
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle {
                                        visible: connected
                                        width: 68; height: 26; radius: 7; color: "#2a1515"
                                        border { color: "#ef444430"; width: 1 }
                                        Text { anchors.centerIn: parent; text: "Disconnect"; color: "#ef4444"; font.pixelSize: 11 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: !connected; cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.nhov = true; onExited: parent.nhov = false
                                     onClicked: {
                                         pwDialog.target = ssid
                                         pwDialog.targetIndex = index
                                         if (secured) pwDialog.open()
                                         else wifiModel.setProperty(index, "connected", true)
                                     }
                                }
                            }
                        }
                    }
                }

                // ── Bluetooth ─────────────────────────────────────────────────
                SectionHeader { label: "Bluetooth" }

                Rectangle {
                    Layout.fillWidth: true; radius: 24; color: connectionsPage.pageCard
                    border.color: connectionsPage.pageBorder; border.width: 1; clip: true
                    implicitHeight: btGroup.implicitHeight

                    Column {
                        id: btGroup
                        anchors { left: parent.left; right: parent.right }

                        ToggleRow {
                            width: parent.width; rowLabel: "Bluetooth"
                            rowSub: btOn ? "2 devices connected" : "Off"
                            on_: btOn; isFirst: true
                            onToggled: function(v) { btOn = v }
                        }

                        Repeater {
                            model: btOn ? btModel : null
                            delegate: Rectangle {
                                required property string name
                                required property string icon
                                required property bool   paired
                                required property bool   connected
                                required property int    index
                                width: btGroup.width; height: 58
                                color: bhov ? "#252525" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                property bool bhov: false

                                Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }; spacing: 12

                                    Rectangle {
                                        width: 36; height: 36; radius: 18
                                        color: connected ? Qt.rgba(0.49,0.83,0.98,0.16)
                                                         : (connectionsPage.dark ? "#27272a" : "#f4f4f5")
                                        Image {
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            source: "../assets/icons/" + icon + ".svg"
                                            sourceSize: Qt.size(36, 36)
                                            opacity: connected ? 1 : 0.65
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: name; color: "#f0f0f0"; font { pixelSize: 13; weight: connected ? Font.Medium : Font.Normal }; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text {
                                            text: connected ? "Connected" : (paired ? "Paired, not connected" : "Available")
                                            color: connected ? "#3b82f6" : "#555"
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle {
                                        width: connected ? 76 : 58; height: 26; radius: 7
                                        color: connected ? "#1a2a1a" : "#1a1a2a"
                                        border { color: connected ? "#22c55e30" : "#3b82f630"; width: 1 }
                                        Text {
                                            anchors.centerIn: parent
                                            text: connected ? "Disconnect" : (paired ? "Connect" : "Pair")
                                            color: connected ? "#22c55e" : "#3b82f6"
                                            font.pixelSize: 11
                                        }
                                         MouseArea {
                                             anchors.fill: parent
                                             cursorShape: Qt.PointingHandCursor
                                             onClicked: btModel.setProperty(index, "connected", !connected)
                                         }
                                    }
                                }

                                MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: parent.bhov = true; onExited: parent.bhov = false }
                            }
                        }
                    }
                }

                // ── VPN ───────────────────────────────────────────────────────
                SectionHeader { label: "VPN" }

                Rectangle {
                    Layout.fillWidth: true; radius: 24; color: connectionsPage.pageCard
                    border.color: connectionsPage.pageBorder; border.width: 1
                    height: 62

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        Text { text: "No VPN configured"; color: "#444"; font.pixelSize: 13; Layout.fillWidth: true }
                        Rectangle {
                            width: 60; height: 28; radius: 8; color: "#1e2a3a"
                            border { color: "#3b82f620"; width: 1 }
                             Text { anchors.centerIn: parent; text: vpnAdded ? "Added" : "+ Add"; color: "#3b82f6"; font.pixelSize: 12 }
                             MouseArea {
                                 anchors.fill: parent
                                 cursorShape: Qt.PointingHandCursor
                                 onClicked: vpnAdded = !vpnAdded
                             }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
