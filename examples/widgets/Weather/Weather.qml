import QtQuick

// Weather — static sample card (no network access yet). Sized 2x1.
Rectangle {
    id: root
    gradient: Gradient { orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "#1e3a5f" }
        GradientStop { position: 1; color: "#3b6ea5" } }
    Row {
        anchors.fill: parent; anchors.margins: 14; spacing: 12
        Item { width: parent.height * 0.9; height: width; anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width * 0.55; height: width; radius: width / 2; color: "#fcd34d"; x: parent.width * 0.05; y: parent.height * 0.05 }
            Rectangle { width: parent.width * 0.7; height: parent.height * 0.34; radius: height / 2; color: "#f4f4f5"; x: parent.width * 0.25; y: parent.height * 0.5 }
            Rectangle { width: parent.width * 0.42; height: parent.height * 0.34; radius: height / 2; color: "#f4f4f5"; x: parent.width * 0.18; y: parent.height * 0.4 }
        }
        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Text { text: "21°"; color: "white"; font.pixelSize: root.height * 0.36; font.weight: Font.Light }
            Text { text: "Partly cloudy"; color: "#dbeafe"; font.pixelSize: root.height * 0.13 }
            Text { text: "Algiers  ·  H 24°  L 16°"; color: "#bfdbfe"; font.pixelSize: root.height * 0.11 }
        }
    }
}
