import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string itemLabel: ""
    property string itemSub:   ""
    property string itemIcon:  "•"
    property bool   active:    false

    signal tapped

    height: 60
    radius: 10
    color: active ? Qt.rgba(0.23, 0.51, 0.96, 0.12) : (hov ? Qt.rgba(1,1,1,0.04) : "transparent")

    Behavior on color { ColorAnimation { duration: 120 } }

    property bool hov: false

    // Active left accent bar
    Rectangle {
        width: 3; height: 26; radius: 1.5
        anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
        color: "#3b82f6"
        visible: root.active
        opacity: 1
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 13; rightMargin: 12 }
        spacing: 11

        // Icon pill
        Rectangle {
            width: 34; height: 34; radius: 9
            color: root.active ? Qt.rgba(0.23, 0.51, 0.96, 0.22) : Qt.rgba(1,1,1,0.05)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: root.itemIcon
                font.pixelSize: 15
                color: root.active ? "#3b82f6" : "#666666"
            }
        }

        // Text
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text {
                text: root.itemLabel
                color: root.active ? "#f5f5f5" : "#d0d0d0"
                font { pixelSize: 13; weight: root.active ? Font.Medium : Font.Normal }
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text {
                text: root.itemSub
                color: "#555555"
                font.pixelSize: 11
                Layout.fillWidth: true; elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        Text {
            text: "›"; font.pixelSize: 17
            color: root.active ? "#3b82f6" : "#3a3a3a"
        }
    }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hov = true
        onExited:  root.hov = false
        onClicked: root.tapped()
    }
}
