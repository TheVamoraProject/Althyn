import QtQuick

Item {
    id: tile

    property string appName: ""
    property string iconPath: ""
    property string desktopPath: ""
    property color textColor: "#f4f4f5"
    property color hoverColor: "#26f4f4f5"

    signal clicked()
    signal rightClicked(real x, real y)

    readonly property bool hasApp: appName !== ""

    Rectangle {
        id: hoverBg
        anchors.fill: parent
        anchors.margins: -6
        radius: 14
        color: mouseArea.pressed && mouseArea.pressedButtons === Qt.LeftButton
               ? Qt.darker(tile.hoverColor, 1.3)
               : (mouseArea.containsMouse ? tile.hoverColor : "transparent")
        visible: tile.hasApp

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: tile.hasApp

        Image {
            id: icon
            source: tile.iconPath !== "" ? tile.iconPath : "../../assets/icons/unknown.svg"
            width: 52
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            text: tile.appName
            color: tile.textColor
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Medium
            width: tile.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: hoverBg
        hoverEnabled: true
        enabled: tile.hasApp
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Set true once a press-and-hold has already opened the context
        // menu for the current press, so the release that follows doesn't
        // also fire a normal tap (which would launch the app).
        property bool longPressHandled: false

        onPressed: function(mouse) {
            longPressHandled = false
            if (mouse.button === Qt.RightButton) {
                // Map tile-local position to window coordinates
                var pt = tile.mapToItem(null, mouse.x, mouse.y)
                tile.rightClicked(pt.x, pt.y)
            }
        }

        // Touch/mobile users have no right-click, so a long press on the
        // tile does the same job: open the same context menu.
        onPressAndHold: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                longPressHandled = true
                var pt = tile.mapToItem(null, mouse.x, mouse.y)
                tile.rightClicked(pt.x, pt.y)
            }
        }

        onClicked: function(mouse) {
            if (longPressHandled) {
                longPressHandled = false
                return
            }
            if (mouse.button === Qt.LeftButton) {
                tile.clicked()
            }
        }
    }
}
