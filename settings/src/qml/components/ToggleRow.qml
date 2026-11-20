import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string rowLabel:    ""
    property string rowSub:      ""
    property bool   on_:         false   // 'on' is reserved in QML
    property bool   isFirst:     false

    signal toggled(bool val)

    readonly property var appWindow: ApplicationWindow.window
    readonly property color divColor: appWindow && !appWindow.darkTheme ? "#d7dbe2" : "#2c2c2c"
    readonly property color primaryText: appWindow && !appWindow.darkTheme ? "#18181b" : "#f4f4f5"
    readonly property color secondaryText: appWindow && !appWindow.darkTheme ? "#71717a" : "#a1a1aa"
    readonly property color accent: appWindow && appWindow.accentColor !== undefined ? appWindow.accentColor : "#7dd3fc"

    height: rowSub.length > 0 ? 66 : 54
    color: "transparent"

    Rectangle {
        visible: !isFirst
        anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
        height: 1; color: root.divColor
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text {
                text: root.rowLabel
                color: root.primaryText; font.pixelSize: 14
                Layout.fillWidth: true
            }
            Text {
                text: root.rowSub; color: root.secondaryText
                font.pixelSize: 12; wrapMode: Text.WordWrap
                visible: text.length > 0
                Layout.fillWidth: true
            }
        }

        // Toggle pill
        Rectangle {
            id: pill
            width: 48; height: 26; radius: 13
            color: root.on_ ? root.accent : (appWindow && !appWindow.darkTheme ? "#d4d4d8" : "#3f3f46")
            Behavior on color { ColorAnimation { duration: 160 } }

            Rectangle {
                id: knob
                width: 20; height: 20; radius: 10; color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: root.on_ ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                layer.enabled: true
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled(!root.on_)
            }
        }
    }
}
