import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    anchors.fill: parent

    // Mock state
    property bool   highContrast:    false
    property bool   largeText:       false
    property real   textScale:       1.0
    property bool   reduceMotion:    false
    property bool   magnifier:       false
    property string colorBlindMode:  "None"
    property bool   screenReader:    false
    property real   readerSpeed:     1.0
    property bool   visualAlerts:    false
    property bool   monoAudio:       false
    property bool   stickyKeys:      false
    property bool   slowKeys:        false
    property bool   bounceKeys:      false
    property bool   onscreenKb:      false
    property bool   mouseKeys:       false
    property real   pointerSpeed:    0.5

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
                text: "Accessibility"
                color: "#f0f0f0"
                font.pixelSize: 26
                font.bold: true
            }

            Item { height: 14 }

            ColumnLayout {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; spacing: 14

                SectionHeader { label: "Vision" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: visionGroup.implicitHeight
                    Column {
                        id: visionGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "High Contrast"; rowSub: "Increase colour contrast for readability"; on_: highContrast; isFirst: true; onToggled: function(v){ highContrast=v } }
                        ToggleRow { width: parent.width; rowLabel: "Large Text"; on_: largeText; onToggled: function(v){ largeText=v } }
                        ToggleRow { width: parent.width; rowLabel: "Reduce Motion"; rowSub: "Limit interface animations"; on_: reduceMotion; onToggled: function(v){ reduceMotion=v } }
                        ToggleRow { width: parent.width; rowLabel: "Screen Magnifier"; rowSub: "Zoom in with keyboard shortcut"; on_: magnifier; onToggled: function(v){ magnifier=v } }

                        // Text scale slider
                        Rectangle {
                            width: parent.width; height: 76; color: "transparent"
                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }
                            ColumnLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 10 }; spacing: 6
                                RowLayout {
                                    Text { text: "Text Scale"; color: "#f0f0f0"; font.pixelSize: 14; Layout.fillWidth: true }
                                    Text { text: Math.round(textScale*100)+"%"; color: ApplicationWindow.window.accentColor; font { pixelSize: 13; weight: Font.Medium } }
                                }
                                StyledSlider { Layout.fillWidth: true; from: 0.75; to: 2.0; stepSize: 0.05; value: textScale; onMoved: textScale=value }
                            }
                        }

                        // Colour blindness
                        Rectangle {
                            width: parent.width; height: 52; color: "transparent"
                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }
                            RowLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                Text { text: "Colour Blindness Filter"; color: "#f0f0f0"; font.pixelSize: 14; Layout.fillWidth: true }
                                ComboBox {
                                    model: ["None","Deuteranopia","Protanopia","Tritanopia"]
                                    currentIndex: 0
                                    background: Rectangle { color: "#2a2a2a"; radius: 8 }
                                    contentItem: Text { text: parent.displayText; color: "#f0f0f0"; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
                                    onActivated: colorBlindMode = currentText
                                }
                            }
                        }
                    }
                }

                SectionHeader { label: "Screen Reader" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: srGroup.implicitHeight
                    Column {
                        id: srGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Screen Reader"; rowSub: "Read aloud interface elements"; on_: screenReader; isFirst: true; onToggled: function(v){ screenReader=v } }
                        Rectangle {
                            width: parent.width; height: 76; color: "transparent"
                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }
                            ColumnLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 10 }; spacing: 6
                                RowLayout {
                                    Text { text: "Reading Speed"; color: "#f0f0f0"; font.pixelSize: 14; Layout.fillWidth: true }
                                    Text { text: Math.round(readerSpeed*100)+"%"; color: ApplicationWindow.window.accentColor; font { pixelSize: 13; weight: Font.Medium } }
                                }
                                StyledSlider { Layout.fillWidth: true; from: 0.5; to: 2.0; stepSize: 0.1; value: readerSpeed; onMoved: readerSpeed=value }
                            }
                        }
                    }
                }

                SectionHeader { label: "Hearing" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: hearGroup.implicitHeight
                    Column {
                        id: hearGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Visual Alerts"; rowSub: "Flash screen for audio notifications"; on_: visualAlerts; isFirst: true; onToggled: function(v){ visualAlerts=v } }
                        ToggleRow { width: parent.width; rowLabel: "Mono Audio"; rowSub: "Mix stereo audio into a single channel"; on_: monoAudio; onToggled: function(v){ monoAudio=v } }
                    }
                }

                SectionHeader { label: "Dexterity" }

                Rectangle {
                    Layout.fillWidth: true; radius: 14; color: "#1e1e1e"; clip: true
                    implicitHeight: dexGroup.implicitHeight
                    Column {
                        id: dexGroup; anchors { left: parent.left; right: parent.right }
                        ToggleRow { width: parent.width; rowLabel: "Sticky Keys"; rowSub: "Press modifier keys one at a time"; on_: stickyKeys; isFirst: true; onToggled: function(v){ stickyKeys=v } }
                        ToggleRow { width: parent.width; rowLabel: "Slow Keys"; rowSub: "Delay before a key press is accepted"; on_: slowKeys; onToggled: function(v){ slowKeys=v } }
                        ToggleRow { width: parent.width; rowLabel: "Bounce Keys"; rowSub: "Ignore rapid repeated key presses"; on_: bounceKeys; onToggled: function(v){ bounceKeys=v } }
                        ToggleRow { width: parent.width; rowLabel: "On-Screen Keyboard"; on_: onscreenKb; onToggled: function(v){ onscreenKb=v } }
                        ToggleRow { width: parent.width; rowLabel: "Mouse Keys"; rowSub: "Control pointer with keyboard numpad"; on_: mouseKeys; onToggled: function(v){ mouseKeys=v } }
                        Rectangle {
                            width: parent.width; height: 76; color: "transparent"
                            Rectangle { anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: "#252525" }
                            ColumnLayout { anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 10 }; spacing: 6
                                RowLayout {
                                    Text { text: "Pointer Speed"; color: "#f0f0f0"; font.pixelSize: 14; Layout.fillWidth: true }
                                    Text { text: Math.round(pointerSpeed*100)+"%"; color: ApplicationWindow.window.accentColor; font { pixelSize: 13; weight: Font.Medium } }
                                }
                                StyledSlider { Layout.fillWidth: true; from: 0; to: 1; stepSize: 0.05; value: pointerSpeed; onMoved: pointerSpeed=value }
                            }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
