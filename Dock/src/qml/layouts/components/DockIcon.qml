import QtQuick

Item {
    id: dockIcon

    property string iconSource: ""
    property string appName: ""
    property int baseSize: 52
    readonly property bool magnified: mouseArea.containsMouse

    signal clicked()

    width: baseSize
    height: baseSize
    scale: magnified ? 1.35 : 1.0

    Behavior on scale {
        NumberAnimation { duration: 140; easing.type: Easing.OutBack }
    }

    // Tooltip label shown above the icon on hover
    Item {
        id: tooltip
        visible: opacity > 0
        opacity: dockIcon.magnified ? 1.0 : 0.0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: "#CC09090b"
            border.width: 1
            border.color: "#26ffffff"
        }

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: dockIcon.appName
            color: "#f4f4f5"
            font.pixelSize: 12
        }
    }

    Image {
        id: iconImage
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dockIcon.baseSize
        height: dockIcon.baseSize
        source: dockIcon.iconSource
        smooth: true
        mipmap: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            bounceAnim.start()
            dockIcon.clicked()
        }
    }

    SequentialAnimation {
        id: bounceAnim
        NumberAnimation {
            target: dockIcon
            property: "scale"
            to: dockIcon.magnified ? 1.5 : 1.15
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: dockIcon
            property: "scale"
            to: dockIcon.magnified ? 1.35 : 1.0
            duration: 140
            easing.type: Easing.OutBack
        }
    }
}
