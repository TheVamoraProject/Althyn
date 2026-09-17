import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: dockIcon

    property string iconSource: ""
    property string appName: ""
    property int baseSize: 52
    property int openWindowCount: 0
    property int focusedWindowIndex: -1
    readonly property bool magnified: mouseArea.containsMouse

    // True for Vamora's own icons (no iconPath resolved) and for apps
    // whose .desktop file declares VamoraPackage=<anything> — a known-
    // good, full-bleed square icon that's safe to round directly.
    // Everything else gets an adaptive-icon-style backplate instead,
    // since rounding an arbitrary, possibly non-square icon directly
    // can clip it. Same convention as the homescreen, start menu and
    // launcher.
    property bool directRound: true
    // BGColor=#RRGGBB from the .desktop file, if any. Empty falls back
    // to white, same as the homescreen.
    property string bgColor: ""
    readonly property string effectiveBgColor: bgColor !== "" ? bgColor : "#ffffff"
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle at any
    // pixel size, since the fraction below is always relative to 32).
    property real iconCornerRadiusRaw: 8
    function radiusFor(size) {
        return Math.min(dockIcon.iconCornerRadiusRaw, 32) / 32 * (size / 2)
    }

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

    Item {
        id: iconSlot
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: dockIcon.baseSize
        height: dockIcon.baseSize

        Rectangle {
            id: adaptiveBg
            anchors.fill: parent
            radius: dockIcon.radiusFor(width)
            color: dockIcon.effectiveBgColor
            visible: !dockIcon.directRound
        }

        // Same backdrop behind a direct-round icon too — a verified
        // square icon can still have transparent padding/corners, so
        // this keeps it from showing whatever's behind the dock
        // through instead of a solid tile. Same convention as the
        // homescreen's AppTile.
        Rectangle {
            id: directRoundBg
            anchors.fill: parent
            radius: dockIcon.radiusFor(width)
            color: dockIcon.effectiveBgColor
            visible: dockIcon.directRound
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: dockIcon.directRound ? parent.width : parent.width * 0.66
            height: dockIcon.directRound ? parent.height : parent.height * 0.66
            source: dockIcon.iconSource !== "" ? dockIcon.iconSource : "qrc:/assets/icons/unknown.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            // Direct-round icons are drawn through the OpacityMask
            // below instead; non-direct-round ones sit inset on the
            // backplate as-is.
            visible: !dockIcon.directRound
        }

        Rectangle {
            id: iconMask
            anchors.fill: parent
            radius: dockIcon.radiusFor(width)
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: iconImage
            maskSource: iconMask
            visible: dockIcon.directRound
        }

        // EWMH taskbar-style indicators. There is one dot per managed window;
        // the dot for the active window is longer so focus is visible without
        // changing the icon itself.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -2
            spacing: 2
            z: 3

            Repeater {
                model: Math.max(0, dockIcon.openWindowCount)

                delegate: Rectangle {
                    readonly property bool isFocused: index === dockIcon.focusedWindowIndex
                    width: isFocused ? 11 : 5
                    height: 4
                    radius: 2
                    color: "#f4f4f5"
                    border.width: 1
                    border.color: "#66000000"
                }
            }
        }
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
