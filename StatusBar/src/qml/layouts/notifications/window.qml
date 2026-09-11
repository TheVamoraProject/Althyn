import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Qt5Compat.GraphicalEffects

Window {
    id: notificationWindow

    width: 360
    height: 330
    visible: true
    color: "transparent"
    title: "Notifications"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    readonly property color cBg: isDark ? "#18181b" : "#fafafa"
    readonly property color cTopBar: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cHover: isDark ? "#3f3f46" : "#e4e4e7"
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"
    readonly property color cMuted: isDark ? "#a1a1aa" : "#52525b"
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"

    property bool isDark: true

    onActiveChanged: {
        if (!active)
            notificationWindow.close()
    }

    Rectangle {
        anchors.fill: parent
        color: notificationWindow.cBg
        radius: 24
        border.width: 1
        border.color: notificationWindow.cBorder

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                width: parent.width
                height: 30

                Column {
                    width: parent.width - 92
                    spacing: 1

                    Text {
                        text: "NOTIFICATIONS"
                        color: notificationWindow.cText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        font.family: "Inter"
                    }

                    Text {
                        text: "A small sample notification center"
                        color: notificationWindow.cMuted
                        font.pixelSize: 10
                        font.family: "Inter"
                    }
                }

                Rectangle {
                    width: 70
                    height: 28
                    radius: 9
                    color: clearMouse.containsMouse
                        ? notificationWindow.cHover
                        : notificationWindow.cSurface

                    Text {
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: notificationWindow.cText
                        font.pixelSize: 10
                        font.family: "Inter"
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: notificationList.visible = false
                    }
                }
            }

            Column {
                id: notificationList
                width: parent.width
                spacing: 7

                Rectangle {
                    width: parent.width
                    height: 74
                    radius: 14
                    color: notificationOneMouse.containsMouse
                        ? notificationWindow.cHover
                        : notificationWindow.cSurface
                    border.width: 1
                    border.color: notificationWindow.cBorder

                    Image {
                        id: notificationOneIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        source: "../../assets/icons/notification/bell-dot.svg"
                        smooth: false
                        sourceSize.width: 64
                        sourceSize.height: 64
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: notificationWindow.cText
                        }
                    }

                    Column {
                        anchors.left: notificationOneIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            width: parent.width

                            Text {
                                text: "Welcome to Vamora"
                                color: notificationWindow.cText
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                font.family: "Inter"
                            }

                            Item { width: 1; height: 1 }

                            Text {
                                anchors.right: parent.right
                                text: "now"
                                color: notificationWindow.cMuted
                                font.pixelSize: 10
                                font.family: "Inter"
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Your workspace is ready to use."
                            color: notificationWindow.cMuted
                            font.pixelSize: 10
                            font.family: "Inter"
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: notificationOneMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 74
                    radius: 14
                    color: notificationTwoMouse.containsMouse
                        ? notificationWindow.cHover
                        : notificationWindow.cSurface
                    border.width: 1
                    border.color: notificationWindow.cBorder

                    Image {
                        id: notificationTwoIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        source: "../../assets/icons/refresh.svg"
                        smooth: false
                        sourceSize.width: 64
                        sourceSize.height: 64
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: notificationWindow.cText
                        }
                    }

                    Column {
                        anchors.left: notificationTwoIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            width: parent.width

                            Text {
                                text: "System update"
                                color: notificationWindow.cText
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                font.family: "Inter"
                            }

                            Text {
                                anchors.right: parent.right
                                text: "2m"
                                color: notificationWindow.cMuted
                                font.pixelSize: 10
                                font.family: "Inter"
                            }
                        }

                        Text {
                            width: parent.width
                            text: "StatusBar is running normally."
                            color: notificationWindow.cMuted
                            font.pixelSize: 10
                            font.family: "Inter"
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: notificationTwoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }

            Rectangle {
                visible: !notificationList.visible
                width: parent.width
                height: 74
                radius: 14
                color: notificationWindow.cSurface
                border.width: 1
                border.color: notificationWindow.cBorder

                Text {
                    anchors.centerIn: parent
                    text: "No new notifications"
                    color: notificationWindow.cMuted
                    font.pixelSize: 11
                    font.family: "Inter"
                }
            }
        }
    }
}