import QtQuick

// Draws a 4-bar WiFi strength indicator
Item {
    property int  strength:  0    // 0–100
    property bool connected: false
    property bool secured:   false

    width: 18; height: 14

    readonly property color on_:  connected ? "#3b82f6" : "#c0c0c0"
    readonly property color off_: "#383838"

    // bars heights: short → tall
    Repeater {
        model: 4
        Rectangle {
            readonly property int bars: {
                if (strength >= 85) return 4
                if (strength >= 60) return 3
                if (strength >= 35) return 2
                if (strength > 0)   return 1
                return 0
            }
            width: 3; radius: 1.5
            height: [4, 7, 10, 14][index]
            anchors.bottom: parent.bottom
            x: index * 5
            color: (index < bars) ? on_ : off_
        }
    }

    // Lock dot
    Rectangle {
        visible: secured
        width: 5; height: 5; radius: 2.5
        color: "#f59e0b"
        anchors { top: parent.top; right: parent.right }
    }
}
