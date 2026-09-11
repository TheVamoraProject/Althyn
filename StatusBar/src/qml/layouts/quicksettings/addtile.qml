import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Qt5Compat.GraphicalEffects

Window {
    id: dialog

    width: 252
    height: 484
    visible: false
    color: "transparent"
    title: "Add Control"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property bool isDark: true
    property real hostX: 0
    property real hostY: 0
    property real hostWidth: 0
    property real hostHeight: 0
    property int selectedIndex: 0
    property int previewColumns: 2
    property int previewRows: 2

    readonly property color cBg: isDark ? "#18181b" : "#fafafa"
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cSurfaceHover: isDark ? "#3f3f46" : "#e4e4e7"
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"
    readonly property color cMuted: isDark ? "#a1a1aa" : "#52525b"
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"

    ListModel {
        id: tileOptions
        ListElement {
            label: "Wi-Fi"
            sub: "Network controls"
            icon: "../../assets/icons/wifi/wifi.svg"
            stack: true
        }
        ListElement {
            label: "Weather"
            sub: "Forecast at a glance"
            icon: "../../assets/icons/monitor.svg"
            stack: false
        }
        ListElement {
            label: "Media"
            sub: "Playback controls"
            icon: "../../assets/icons/volume-2.svg"
            stack: false
        }
        ListElement {
            label: "Focus"
            sub: "Quiet workspace"
            icon: "../../assets/icons/cafeine.svg"
            stack: false
        }
    }

    function openAt() {
        x = Math.max(8, hostX - width - 12)
        y = Math.max(8, hostY + 8)
        visible = true
        raise()
        requestActivate()
    }

    Rectangle {
        anchors.fill: parent
        color: dialog.cBg
        radius: 24
        border.width: 1
        border.color: dialog.cBorder

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                width: parent.width
                height: 28

                Column {
                    width: parent.width - 32
                    spacing: 1

                    Text {
                        text: "ADD CONTROL"
                        color: dialog.cText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        font.family: "Inter"
                    }

                    Text {
                        text: "Choose a tile and preview its shape"
                        color: dialog.cMuted
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse
                        ? dialog.cSurfaceHover : dialog.cSurface

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: dialog.cText
                        font.pixelSize: 18
                        font.family: "Inter"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dialog.close()
                    }
                }
            }

            Text {
                text: "TILES"
                color: dialog.cMuted
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                font.family: "Inter"
            }

            ListView {
                id: tileList
                width: parent.width
                height: 116
                clip: true
                spacing: 5
                model: tileOptions

                delegate: Rectangle {
                    width: tileList.width
                    height: 50
                    radius: 12
                    color: index === dialog.selectedIndex
                        ? dialog.cAccent
                        : (optionMouse.containsMouse
                           ? dialog.cSurfaceHover : dialog.cSurface)

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: index === dialog.selectedIndex
                            ? dialog.cOnAccent : dialog.cBg

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: model.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            sourceSize.width: 64
                            sourceSize.height: 64
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                color: index === dialog.selectedIndex
                                    ? dialog.cAccent : dialog.cText
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 52
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: model.label
                            color: index === dialog.selectedIndex
                                ? dialog.cOnAccent : dialog.cText
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.family: "Inter"
                        }

                        Text {
                            text: model.sub
                            color: index === dialog.selectedIndex
                                ? dialog.cOnAccent : dialog.cMuted
                            opacity: index === dialog.selectedIndex ? 0.7 : 1
                            font.pixelSize: 9
                            font.family: "Inter"
                        }
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dialog.selectedIndex = index
                            dialog.previewColumns = model.stack ? 2 : 1
                            dialog.previewRows = model.stack ? 2 : 1
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 25
                spacing: 5

                Text {
                    text: "PREVIEW"
                    color: dialog.cMuted
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    font.family: "Inter"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Repeater {
                    model: ["1×1", "2×1", "2×2"]

                    delegate: Rectangle {
                        width: 42
                        height: 24
                        radius: 8
                        color: ((index === 0 && dialog.previewColumns === 1 &&
                                 dialog.previewRows === 1) ||
                                (index === 1 && dialog.previewColumns === 2 &&
                                 dialog.previewRows === 1) ||
                                (index === 2 && dialog.previewColumns === 2 &&
                                 dialog.previewRows === 2))
                            ? dialog.cAccent : dialog.cSurface

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: ((index === 0 &&
                                     dialog.previewColumns === 1 &&
                                     dialog.previewRows === 1) ||
                                    (index === 1 &&
                                     dialog.previewColumns === 2 &&
                                     dialog.previewRows === 1) ||
                                    (index === 2 &&
                                     dialog.previewColumns === 2 &&
                                     dialog.previewRows === 2))
                                ? dialog.cOnAccent : dialog.cMuted
                            font.pixelSize: 9
                            font.family: "Inter"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (index === 0) {
                                    dialog.previewColumns = 1
                                    dialog.previewRows = 1
                                } else if (index === 1) {
                                    dialog.previewColumns = 2
                                    dialog.previewRows = 1
                                } else {
                                    dialog.previewColumns = 2
                                    dialog.previewRows = 2
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 116

                Rectangle {
                    id: previewTile
                    width: dialog.previewColumns * 54 +
                        (dialog.previewColumns - 1) * 5
                    height: dialog.previewRows * 54 +
                        (dialog.previewRows - 1) * 5
                    anchors.centerIn: parent
                    radius: 15
                    color: dialog.cSurface
                    border.width: 1
                    border.color: dialog.cBorder

                    Grid {
                        visible: dialog.previewRows > 1
                        anchors.fill: parent
                        anchors.margins: 8
                        columns: dialog.previewColumns
                        rows: dialog.previewRows
                        spacing: 5

                        Repeater {
                            model: dialog.previewColumns * dialog.previewRows

                            delegate: Rectangle {
                                width: (previewTile.width - 16 -
                                    (dialog.previewColumns - 1) * 5) /
                                    dialog.previewColumns
                                height: (previewTile.height - 16 -
                                    (dialog.previewRows - 1) * 5) /
                                    dialog.previewRows
                                radius: 8
                                color: index === 0 && dialog.selectedIndex === 0
                                    ? dialog.cAccent : dialog.cSurfaceHover

                                Image {
                                    visible: index === 0
                                    anchors.centerIn: parent
                                    width: 17
                                    height: 17
                                    source: tileOptions.get(
                                        dialog.selectedIndex).icon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        color: index === 0 &&
                                            dialog.selectedIndex === 0
                                            ? dialog.cOnAccent : dialog.cText
                                    }
                                }

                                Text {
                                    visible: index !== 0
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: dialog.cMuted
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }

                    Row {
                        visible: dialog.previewRows === 1
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 9

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: dialog.cBg

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: tileOptions.get(
                                    dialog.selectedIndex).icon
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                sourceSize.width: 64
                                sourceSize.height: 64
                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    color: dialog.cText
                                }
                            }
                        }

                        Text {
                            visible: dialog.previewColumns > 1
                            anchors.verticalCenter: parent.verticalCenter
                            text: tileOptions.get(dialog.selectedIndex).label
                            color: dialog.cText
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.family: "Inter"
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: 11
                color: dialog.cSurface
                border.width: 1
                border.color: dialog.cBorder

                Text {
                    anchors.centerIn: parent
                    text: "Tile catalog coming soon"
                    color: dialog.cMuted
                    font.pixelSize: 10
                    font.family: "Inter"
                }
            }
        }
    }
}