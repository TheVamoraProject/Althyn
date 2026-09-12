import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    anchors.fill: parent

    property bool screenLock:  true
    property bool biometric:   false
    property bool location:    false
    property bool camera:      false
    property bool microphone:  false
    property bool firewall:    true
    property bool sudoNotify:  true
    property string lockTimeout: "5 minutes"
    property string passwordStatus: "Change"
    property string permissionsStatus: "Manage per-app"
    property string firewallMode: "Standard"
    property string rulesStatus: "Manage"
    property string auditStatus: "View"

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

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                text: "Security & Privacy"
                color: "#f0f0f0"
                font.pixelSize: 26
                font.bold: true
            }

            Item { height: 14 }

            ColumnLayout {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; spacing: 14

                SectionHeader { label: "Screen Security" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: screenGroup.implicitHeight
                    Column {
                        id: screenGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Screen Lock"; rowSub: "Require authentication to unlock"; on_: screenLock; isFirst: true; onToggled: function(v) { screenLock = v } }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Auto-Lock Timeout"
                            rowValue: lockTimeout
                            tappable: true
                            onTapped: lockTimeout = lockTimeout === "5 minutes" ? "15 minutes" : "5 minutes"
                        }
                        ToggleRow { width: parent.width; rowLabel: "Biometric Unlock"; rowSub: "Fingerprint or face recognition"; on_: biometric; onToggled: function(v) { biometric = v } }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Change Password"
                            rowValue: passwordStatus
                            tappable: true
                            isLast: true
                            onTapped: passwordStatus = "Updated"
                        }
                    }
                }

                SectionHeader { label: "Privacy" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: privacyGroup.implicitHeight
                    Column {
                        id: privacyGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Location Services"; rowSub: "Allow apps to access your location"; on_: location; isFirst: true; onToggled: function(v) { location = v } }
                        ToggleRow { width: parent.width; rowLabel: "Camera Access"; rowSub: "Allow apps to use the camera"; on_: camera; onToggled: function(v) { camera = v } }
                        ToggleRow { width: parent.width; rowLabel: "Microphone Access"; rowSub: "Allow apps to record audio"; on_: microphone; onToggled: function(v) { microphone = v } }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Permission Manager"
                            rowValue: permissionsStatus
                            tappable: true
                            isLast: true
                            onTapped: permissionsStatus = "Opened"
                        }
                    }
                }

                SectionHeader { label: "Firewall" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: fwGroup.implicitHeight
                    Column {
                        id: fwGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Firewall"; rowSub: "Block unauthorised incoming connections"; on_: firewall; isFirst: true; onToggled: function(v) { firewall = v } }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Mode"
                            rowValue: firewallMode
                            tappable: true
                            onTapped: firewallMode = firewallMode === "Standard" ? "Strict" : "Standard"
                        }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Manage Rules"
                            rowValue: rulesStatus
                            tappable: true
                            isLast: true
                            onTapped: rulesStatus = "Opened"
                        }
                    }
                }

                SectionHeader { label: "System" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: sysSecGroup.implicitHeight
                    Column {
                        id: sysSecGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Sudo Notifications"; rowSub: "Alert when elevated permissions are used"; on_: sudoNotify; isFirst: true; onToggled: function(v) { sudoNotify = v } }
                        SettingsRow { width: parent.width; rowLabel: "App Permissions"; rowValue: "34 apps"; tappable: true; onTapped: permissionsStatus = "Opened" }
                        SettingsRow {
                            width: parent.width
                            rowLabel: "Security Audit Log"
                            rowValue: auditStatus
                            tappable: true
                            isLast: true
                            onTapped: auditStatus = "Opened"
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
