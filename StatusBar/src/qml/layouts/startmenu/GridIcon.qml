import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Button {
    implicitWidth: 80
    implicitHeight: 80

    property string appName: ""
    property string iconPath: ""
    property string execStr: ""
    property color textColor: "#f4f4f5"
    property color hoverColor: "#40272a2e"
    // True for Vamora's own icons (unknown.svg fallback) and for apps
    // whose .desktop file declares VamoraPackage=<anything> — a known-
    // good, full-bleed square icon that's safe to round directly.
    // Everything else gets an adaptive-icon-style white backplate
    // instead, since rounding an arbitrary, possibly non-square icon
    // directly can clip it.
    property bool directRound: true
    // BGColor=#RRGGBB from the .desktop file, if any — falls back to
    // white, same as the homescreen.
    property string bgColor: ""
    readonly property string effectiveBgColor: bgColor !== "" ? bgColor : "#ffffff"
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle).
    property real iconCornerRadiusRaw: 8

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

        Item {
            id: iconSlot
            width: 44
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter

            function radiusFor(size) {
                return Math.min(iconCornerRadiusRaw, 32) / 32 * (size / 2)
            }

            Rectangle {
                id: adaptiveBg
                anchors.fill: parent
                radius: iconSlot.radiusFor(width)
                color: effectiveBgColor
                visible: !directRound
            }

            // Same backdrop behind a direct-round icon too — a verified
            // square icon can still have transparent padding/corners, so
            // this keeps it from showing the menu background through
            // instead of a solid tile. Same convention as the
            // homescreen's AppTile.
            Rectangle {
                id: directRoundBg
                anchors.fill: parent
                radius: iconSlot.radiusFor(width)
                color: effectiveBgColor
                visible: directRound
            }

            Image {
                id: icon
                anchors.centerIn: parent
                width: directRound ? parent.width : parent.width * 0.66
                height: directRound ? parent.height : parent.height * 0.66
                source: iconPath !== "" ? iconPath : "../../assets/icons/unknown.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                // Direct-round icons are drawn through the OpacityMask
                // below instead; non-direct-round ones sit inset on the
                // backplate as-is.
                visible: !directRound
            }

            Rectangle {
                id: iconMask
                anchors.fill: parent
                radius: iconSlot.radiusFor(width)
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: icon
                maskSource: iconMask
                visible: directRound
            }
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
