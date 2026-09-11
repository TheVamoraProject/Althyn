import QtQuick
import QtQuick.Controls

Button {
    implicitWidth: 80
    implicitHeight: 80

    property string appName: ""
    property string iconPath: ""
    property string execStr: ""
    property color textColor: "#f4f4f5"
    property color hoverColor: "#40272a2e"

    background: Rectangle {
        color: "#00272a2e"
        radius: width / 6

        MouseArea {
            width: parent.width
            height: parent.height
            hoverEnabled: true
            onEntered: parent.color = hoverColor
            onExited: parent.color = "#00272a2e"
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 5

        Image {
            source: iconPath !== "" ? iconPath : "../../assets/icons/unknown.svg"
            width: 44
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            text: appName
            color: textColor
            font.pixelSize: 11
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            elide: Text.ElideRight
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
