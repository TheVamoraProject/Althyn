import QtQuick

// Clock — analog face with digital time and date. Sized 2x2.
Rectangle {
    id: root
    color: "#1c1c21"
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    readonly property real h: now.getHours() % 12 + now.getMinutes() / 60
    readonly property real m: now.getMinutes() + now.getSeconds() / 60

    Item {
        id: face
        width: Math.min(parent.width, parent.height) * 0.82
        height: width
        anchors.centerIn: parent
        Repeater {
            model: 12
            Rectangle {
                width: index % 3 === 0 ? 3 : 2
                height: index % 3 === 0 ? face.height * 0.07 : face.height * 0.04
                radius: 1
                color: index % 3 === 0 ? "#f4f4f5" : "#71717a"
                x: face.width / 2 - width / 2
                y: 0
                transform: Rotation { origin.x: width / 2; origin.y: face.height / 2; angle: index * 30 }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.height * 0.62
            text: Qt.formatDate(root.now, "ddd d").toUpperCase()
            color: "#a1a1aa"; font.pixelSize: face.height * 0.075; font.letterSpacing: 1.5; font.weight: Font.Medium
        }
        Rectangle { // hour hand
            width: 5; height: face.height * 0.26; radius: 2.5; color: "#f4f4f5"
            x: face.width / 2 - 2.5; y: face.height / 2 - height
            transform: Rotation { origin.x: 2.5; origin.y: face.height * 0.26; angle: root.h * 30 }
        }
        Rectangle { // minute hand
            width: 4; height: face.height * 0.38; radius: 2; color: "#f4f4f5"
            x: face.width / 2 - 2; y: face.height / 2 - height
            transform: Rotation { origin.x: 2; origin.y: face.height * 0.38; angle: root.m * 6 }
        }
        Rectangle { // second hand
            width: 2; height: face.height * 0.42; radius: 1; color: "#7dd3fc"
            x: face.width / 2 - 1; y: face.height / 2 - height
            transform: Rotation { origin.x: 1; origin.y: face.height * 0.42; angle: root.now.getSeconds() * 6 }
        }
        Rectangle { width: 10; height: 10; radius: 5; color: "#7dd3fc"; anchors.centerIn: parent }
    }
}
