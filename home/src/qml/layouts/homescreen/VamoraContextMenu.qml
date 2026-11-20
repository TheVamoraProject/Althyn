import QtQuick
import QtQuick.Controls

// VamoraUI-styled right-click context menu — matches statusbar / startmenu style.
//
// Usage:
//   ContextMenu {
//       id: myMenu
//       model: [
//           { label: "Do something", icon: "../../assets/icons/info.svg", action: function() { ... } },
//           { label: "---" },   // separator
//           { label: "Danger",  icon: "...", destructive: true, action: function() { ... } },
//       ]
//   }
//   myMenu.popup(windowX, windowY)

Item {
    id: root

    // The Window this menu belongs to — must be set explicitly by whoever
    // instantiates this component (e.g. `hostWindow: window`), since a
    // bare `window` identifier from the parent file's id scope is not a
    // reliable cross-file lookup across Qt/QML versions.
    property var hostWindow: null

    // Array of { label, icon (qrc path), action (function|null), destructive (bool, opt) }
    // Use label === "---" for a separator row.
    property var model: []

    // Show the menu at the given window-coordinate position.
    function popup(px, py) {
        var mw = menuRect.width
        var mh = col.implicitHeight + 10
        menuRect.height = mh
        var hw = root.hostWindow ? root.hostWindow.width  : mw + 16
        var hh = root.hostWindow ? root.hostWindow.height : mh + 16
        var wx = Math.min(px, hw - mw - 8)
        var wy = Math.min(py, hh - mh - 8)
        menuRect.x = Math.max(8, wx)
        menuRect.y = Math.max(8, wy)
        // entrance animation
        menuRect.scale   = 0.88
        menuRect.opacity = 0
        root.visible     = true
        showAnim.restart()
    }

    function close() {
        hideAnim.restart()
    }

    visible: false
    z: 9999
    // Declared as a direct child of the Window in window.qml, so it's
    // already parented to the window's contentItem automatically —
    // no need (and no safe cross-file way) to set `parent` explicitly here.
    //
    // NOTE: a plain Item has no implicit size, so it must be sized
    // explicitly to the host window — otherwise the full-window dismiss
    // MouseArea below (anchors.fill: parent) covers a 0x0 area and
    // clicking outside the menu silently does nothing.
    width: root.hostWindow ? root.hostWindow.width : 0
    height: root.hostWindow ? root.hostWindow.height : 0

    // ── Full-window dismiss layer ──────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        enabled: root.visible
        // Eat the event and close — don't propagate so the bg menu doesn't re-open
        onPressed: function(mouse) {
            mouse.accepted = true
            root.close()
        }
    }

    // ── Menu card ─────────────────────────────────────────────────────────
    Rectangle {
        id: menuRect

        width: 210
        // height set dynamically in popup()
        radius: 10
        color: "#27272a"          // zinc-800  (cSurface)
        border.color: "#3f3f46"   // zinc-700  (cBorder)
        border.width: 1

        transformOrigin: Item.TopLeft

        ParallelAnimation {
            id: showAnim
            NumberAnimation { target: menuRect; property: "opacity"; to: 1;   duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: menuRect; property: "scale";   to: 1;   duration: 160; easing.type: Easing.OutBack; easing.overshoot: 0.4 }
        }
        ParallelAnimation {
            id: hideAnim
            NumberAnimation { target: menuRect; property: "opacity"; to: 0;   duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: menuRect; property: "scale";   to: 0.9; duration: 100; easing.type: Easing.InQuad }
            onFinished: root.visible = false
        }

        Column {
            id: col
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 5
            spacing: 2

            Repeater {
                model: root.model

                delegate: Loader {
                    width: col.width
                    sourceComponent: modelData.label === "---" ? separatorComp : itemComp
                    property var itemData: modelData
                }
            }
        }
    }

    // ── Menu item ─────────────────────────────────────────────────────────
    Component {
        id: itemComp

        Rectangle {
            id: itemRect
            width: parent.width
            height: 34
            radius: 6
            color: rowHover.containsMouse ? "#3f3f46" : "transparent"   // cSurfaceHover on hover

            Behavior on color { ColorAnimation { duration: 80 } }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 8

                // Icon (plain, no color tint)
                Item {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: itemData.icon !== undefined && itemData.icon !== ""

                    Image {
                        id: itemIcon
                        anchors.fill: parent
                        source: itemData.icon !== undefined ? itemData.icon : ""
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Text {
                    text: itemData.label
                    color: itemData.destructive === true ? "#f87171" : "#f4f4f5"
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.close()
                    if (itemData.action) {
                        itemData.action()
                    }
                }
            }
        }
    }

    // ── Separator ─────────────────────────────────────────────────────────
    Component {
        id: separatorComp

        Item {
            width: parent.width
            height: 9

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                height: 1
                color: "#3f3f46"
                opacity: 0.6
            }
        }
    }
}
