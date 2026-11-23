import QtQuick

// Notes — a sticky note you can tick items off on. Sized 2x2.
Rectangle {
    id: root
    color: "#fde68a"
    property var items: [
        { t: "Ship drag & drop", d: true },
        { t: "Pick a wallpaper", d: true },
        { t: "Icon pack support", d: false },
        { t: "Write release notes", d: false }
    ]
    Column {
        anchors.fill: parent; anchors.margins: Math.max(12, parent.width * 0.07); spacing: 6
        Text { text: "To do"; color: "#78350f"; font.pixelSize: Math.max(14, root.width * 0.09); font.weight: Font.Bold }
        Repeater {
            model: root.items.length
            Row {
                spacing: 8
                property bool done: root.items[index].d
                Rectangle { width: 14; height: 14; radius: 4; y: 2; color: parent.done ? "#92400e" : "transparent"; border.width: 2; border.color: "#92400e"
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { var a = root.items.slice(); a[index] = { t: a[index].t, d: !a[index].d }; root.items = a } } }
                Text { text: root.items[index].t; color: "#78350f"; font.pixelSize: Math.max(11, root.width * 0.065); font.strikeout: parent.done; opacity: parent.done ? 0.6 : 1 }
            }
        }
    }
}
