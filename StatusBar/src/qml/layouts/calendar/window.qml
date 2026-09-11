import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import "../components"
import com.vamora

Window {
    width: 320
    height: 360
    visible: true
    color: "transparent"
    title: "Vamora Calendar"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // ---- Vamora/AlthynUI palette (zinc, follows appearance.theme) ----
    readonly property color cBg: isDark ? "#18181b" : "#fafafa"        // zinc-900/50, solid
    readonly property color cTopBar: isDark ? "#27272a" : "#f4f4f5"    // zinc-800/100, solid
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"    // zinc-700/300
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"   // zinc-800/100
    readonly property color cSurfaceHover: isDark ? "#3f3f46" : "#e4e4e7" // zinc-700/200
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"      // zinc-100/900
    readonly property color cTextMuted: isDark ? "#a1a1aa" : "#52525b" // zinc-400/600
    readonly property color cTextFaint: "#71717a" // zinc-500, subtle in both themes
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"    // sole accent: white on dark, near-black on light (today marker)
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"  // text on the accent

    ThemeManager {
        id: themeManager
    }

    // Local QML-native mirror of themeManager.darkMode — see statusbar.qml
    // for why we don't bind directly to themeManager.darkMode.
    property bool isDark: true

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            isDark = themeManager.refresh()
        }
    }

    property date viewDate: new Date()
    property date today: new Date()

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate()
    }

    function firstWeekday(y, m) {
        return new Date(y, m, 1).getDay()
    }

    function isToday(y, m, d) {
        return d === today.getDate() && m === today.getMonth() && y === today.getFullYear()
    }

    Rectangle {
        id: calendar
        color: cBg
        width: parent.width
        height: parent.height
        border.color: cBorder
        border.width: 1
        radius: 24

        // TOP BAR
        Rectangle {
            id: topBar
            color: cTopBar
            width: parent.width
            height: 50
            radius: 24

            Rectangle {
                color: parent.color
                width: parent.width
                height: parent.height / 2
                y: parent.height / 2
            }

            Rectangle {
                color: cBorder
                width: parent.width
                height: 1
                y: 49
            }

            Button {
                x: 16
                y: ( parent.height / 2 ) - ( height / 2 )
                width: 28
                height: 28
                padding: 0

                background: Rectangle {
                    radius: width / 2
                    color: cSurface
                    border.width: 1
                    border.color: cBorder
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = cSurfaceHover
                        onExited: parent.color = cSurface
                    }
                }

                onClicked: {
                    viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1)
                }

                Image {
                    source: "../../assets/icons/arrows/arrowleft.svg"
                    width: 14
                    height: 14
                    anchors.centerIn: parent
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: cText
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(viewDate, "MMMM yyyy")
                color: cText
                font.pixelSize: 15
                font.weight: Font.Medium
                font.family: "Inter"
            }

            Button {
                x: parent.width - width - 16
                y: ( parent.height / 2 ) - ( height / 2 )
                width: 28
                height: 28
                padding: 0

                background: Rectangle {
                    radius: width / 2
                    color: cSurface
                    border.width: 1
                    border.color: cBorder
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = cSurfaceHover
                        onExited: parent.color = cSurface
                    }
                }

                onClicked: {
                    viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1)
                }

                Image {
                    source: "../../assets/icons/arrows/arrowright.svg"
                    width: 14
                    height: 14
                    anchors.centerIn: parent
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: cText
                    }
                }
            }
        }

        Row {
            id: weekdayRow
            width: parent.width - 24
            x: 12
            y: 62
            spacing: 0

            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                Item {
                    width: weekdayRow.width / 7
                    height: 20
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: cTextFaint
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Grid {
            id: dayGrid
            columns: 7
            width: parent.width - 24
            x: 12
            y: 90
            rowSpacing: 4
            columnSpacing: 0

            Repeater {
                model: firstWeekday(viewDate.getFullYear(), viewDate.getMonth())
                Item {
                    width: dayGrid.width / 7
                    height: 34
                }
            }

            Repeater {
                model: daysInMonth(viewDate.getFullYear(), viewDate.getMonth())

                Item {
                    width: dayGrid.width / 7
                    height: 34

                    property int dayNum: index + 1
                    property bool todayFlag: isToday(viewDate.getFullYear(), viewDate.getMonth(), dayNum)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: todayFlag ? cAccent : (dayMouse.containsMouse ? cSurfaceHover : "#00000000")
                        border.width: 0

                        Text {
                            anchors.centerIn: parent
                            text: dayNum
                            color: todayFlag ? cOnAccent : cText
                            font.pixelSize: 13
                            font.weight: todayFlag ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
