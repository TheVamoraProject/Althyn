import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    property string rowLabel:    ""
    property string rowValue:    ""
    property string rowIcon:     ""
    property bool   tappable:    false
    property bool   isFirst:     false
    property bool   isLast:      false
    property real   groupRadius: 14
    property alias  trailing:    trailSlot.data

    signal tapped

    readonly property var appWindow: ApplicationWindow.window
    readonly property color surfaceHover: appWindow && !appWindow.darkTheme ? "#f4f4f5" : "#27272a"
    readonly property color dividerColor: appWindow && !appWindow.darkTheme ? "#e4e4e7" : "#27272a"
    readonly property color primaryText: appWindow && !appWindow.darkTheme ? "#18181b" : "#f4f4f5"
    readonly property color secondaryText: appWindow && !appWindow.darkTheme ? "#71717a" : "#a1a1aa"
    readonly property color chevronColor: appWindow && !appWindow.darkTheme ? "#a1a1aa" : "#71717a"

    height: 52
    color: hov && tappable ? root.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    // Match the rounded corners of the parent card group so the hover
    // fill doesn't show square corners poking out of a rounded container.
    topLeftRadius:     isFirst ? groupRadius : 0
    topRightRadius:    isFirst ? groupRadius : 0
    bottomLeftRadius:  isLast  ? groupRadius : 0
    bottomRightRadius: isLast  ? groupRadius : 0

    property bool hov: false

    Rectangle {
        visible: !isFirst
        anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
        height: 1; color: root.dividerColor
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 14 }
        spacing: 8

        Item {
            Layout.preferredWidth: root.rowIcon.length > 0 ? 24 : 0
            Layout.preferredHeight: 24
            visible: root.rowIcon.length > 0

            Image {
                id: rowIconSource
                anchors.fill: parent
                source: "../assets/icons/" + root.rowIcon + ".svg"
                sourceSize: Qt.size(48, 48)
                visible: false
            }

            ColorOverlay {
                anchors.fill: rowIconSource
                source: rowIconSource
                color: root.appWindow && !root.appWindow.darkTheme ? "#303640" : "#e4e4e7"
            }
        }

        Text {
            text: root.rowLabel
            color: root.primaryText; font.pixelSize: 14
            Layout.fillWidth: true
        }

        Text {
            text: root.rowValue
            color: root.secondaryText; font.pixelSize: 14
            visible: text.length > 0
            elide: Text.ElideRight; Layout.maximumWidth: 200
        }

        Item { id: trailSlot; visible: children.length > 0 }

        Text {
            text: "›"; font.pixelSize: 18; color: root.chevronColor
            visible: root.tappable
        }
    }

    MouseArea {
        anchors.fill: parent; enabled: tappable; hoverEnabled: true
        cursorShape: tappable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.hov = true
        onExited:  root.hov = false
        onClicked: root.tapped()
    }
}
