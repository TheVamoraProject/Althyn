import QtQuick

// Calendar — current month, today highlighted. Sized 2x2.
Rectangle {
    id: root
    color: "#1c1c21"
    property date now: new Date()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = new Date() }
    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    readonly property int firstDow: (new Date(year, month, 1).getDay() + 6) % 7   // Monday first
    readonly property int days: new Date(year, month + 1, 0).getDate()

    Column {
        anchors.fill: parent
        anchors.margins: Math.max(10, parent.width * 0.06)
        spacing: 6
        Text {
            text: Qt.formatDate(root.now, "MMMM yyyy")
            color: "#f4f4f5"; font.pixelSize: Math.max(13, root.width * 0.075); font.weight: Font.DemiBold
        }
        Grid {
            columns: 7
            width: parent.width
            readonly property real cw: width / 7
            readonly property real ch: (root.height - parent.anchors.margins * 2 - 40) / 7
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Item { width: parent.cw; height: parent.ch
                    Text { anchors.centerIn: parent; text: modelData; color: "#71717a"; font.pixelSize: Math.max(9, parent.height * 0.42); font.weight: Font.Medium } }
            }
            Repeater {
                model: 42
                Item {
                    readonly property int day: index - root.firstDow + 1
                    readonly property bool valid: day >= 1 && day <= root.days
                    readonly property bool today: valid && day === root.now.getDate()
                    width: parent.cw; height: parent.ch
                    Rectangle { anchors.centerIn: parent; width: Math.min(parent.width, parent.height) * 0.9; height: width; radius: width / 2; color: "#7dd3fc"; visible: today }
                    Text { anchors.centerIn: parent; visible: valid; text: day
                        color: today ? "#0c1a22" : (index % 7 > 4 ? "#a1a1aa" : "#e4e4e7")
                        font.pixelSize: Math.max(9, parent.height * 0.44); font.weight: today ? Font.Bold : Font.Normal }
                }
            }
        }
    }
}
