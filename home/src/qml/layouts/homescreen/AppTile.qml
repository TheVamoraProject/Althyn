import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: tile

    property string appName: ""
    property string iconPath: ""
    property string desktopPath: ""
    property color textColor: "#f4f4f5"
    property color hoverColor: "#26f4f4f5"
    // True for Vamora's own icons (unknown.svg fallback) and for apps whose
    // .desktop file declares VamoraPackage=<anything> — a known-good,
    // full-bleed square icon that's safe to round directly. Everything
    // else gets an adaptive-icon-style white backplate instead, since
    // rounding an arbitrary, possibly non-square icon directly can clip it.
    property bool directRound: true
    // BGColor=#RRGGBB from the .desktop file, if any — the backdrop color
    // behind the icon (both the direct-round mask and the adaptive
    // backplate). Empty falls back to white.
    property string bgColor: ""
    readonly property string effectiveBgColor: bgColor !== "" ? bgColor : "#ffffff"
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle).
    property real iconCornerRadiusRaw: 8
    // Grid cells this tile spans (itemData.width/height). A plain 1x1
    // tile keeps the exact fixed 52px icon as always; anything resized
    // wider/taller grows the backplate to actually match its footprint
    // instead of leaving a tiny 52px square stranded in a bigger cell.
    property int tileSpanW: 1
    property int tileSpanH: 1

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

        Item {
            id: iconSlot
            readonly property bool resized: tile.tileSpanW > 1 || tile.tileSpanH > 1
            width: resized ? Math.max(52, tile.width - 12) : 52
            height: resized ? Math.max(52, tile.height - 30) : 52
            anchors.horizontalCenter: parent.horizontalCenter

            function radiusFor(size) {
                return Math.min(tile.iconCornerRadiusRaw, 32) / 32 * (size / 2)
            }

            Rectangle {
                id: adaptiveBg
                anchors.fill: parent
                radius: iconSlot.radiusFor(Math.min(width, height))
                color: tile.effectiveBgColor
                visible: !tile.directRound
            }

            // Same backdrop behind a direct-round icon too — a verified
            // square icon can still have transparent padding/corners, so
            // this keeps it from showing the wallpaper through instead of
            // a solid tile.
            Rectangle {
                id: directRoundBg
                anchors.fill: parent
                radius: iconSlot.radiusFor(Math.min(width, height))
                color: tile.effectiveBgColor
                visible: tile.directRound
            }

            Image {
                id: icon
                anchors.centerIn: parent
                // Fixed to the normal single-cell icon size regardless of
                // how big the backplate above has grown — the backplate
                // grows to fill a resized tile, the icon inside it does
                // not, so it stays a small icon inset on a bigger card
                // rather than stretching to match.
                width: tile.directRound ? iconSlot.width : 52 * 0.66
                height: tile.directRound ? iconSlot.height : 52 * 0.66
                source: tile.iconPath !== "" ? tile.iconPath : "../../assets/icons/unknown.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                // Direct-round icons are drawn through the OpacityMask
                // below instead; non-direct-round ones sit inset on the
                // backplate as-is.
                visible: !tile.directRound
            }

            Rectangle {
                id: iconMask
                anchors.fill: parent
                radius: iconSlot.radiusFor(Math.min(width, height))
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: icon
                maskSource: iconMask
                visible: tile.directRound
            }
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
