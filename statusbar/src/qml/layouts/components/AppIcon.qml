//the icon only
import QtQuick
import QtQuick.Controls

Button {
    id: appicon
    width: window.height
    height: window.height

    background: Rectangle {
        color: "#00000000"
        radius: 8
        MouseArea {
            width: window.height
            height: window.height
            hoverEnabled: true
            onEntered: parent.color = "#40272a2e" // zinc-800 hover
            onExited: parent.color = "#00000000"
        }
    }
    
    property string iconSource: "../assets/icons/unknown.svg"

    Image {
        anchors.centerIn: parent
        width: parent.width - 20
        height: parent.height - 20
        source: "../" + appicon.iconSource
    }
}