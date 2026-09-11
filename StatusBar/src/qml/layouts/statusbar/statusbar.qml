import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import "../components"
import com.vamora

Window {
    id: window
    visible: true
    width: screen.width
    height: 30
    title: "Vamora StatusBar"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    x: 0
    y: 0

    // ---- Vamora/AlthynUI palette (zinc, follows appearance.theme) ----
    readonly property color cBarBg: isDark ? "#09090b" : "#fafafa"        // zinc-950/50, solid
    readonly property color cHover: isDark ? "#40272a2e" : "#40d4d4d8"    // zinc-800/300 hover overlay
    readonly property color cDivider: isDark ? "#33ffffff" : "#33000000"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"         // zinc-100/900
    readonly property color cTextMuted: isDark ? "#a1a1aa" : "#52525b"    // zinc-400/600
    readonly property color cAccent: "#2563eb"           // Vamora blue-600, same in both themes

    property date currentTime: new Date()
    property int iconSize: 17
    property int trayBtnSize: 28

    function openQuickSettings() {
        if (quickSettingsLoader.active) {
            quickSettingsLoader.active = false
        } else {
            startMenu.active = false
            calendarLoader.active = false
            notificationLoader.active = false
            trayLoader.active = false
            quickSettingsLoader.active = true
            quickSettingsLoader.item.x =
                window.x + window.width - quickSettingsLoader.item.width - 8
            quickSettingsLoader.item.y = window.y + window.height + 6
        }
    }

    UserInfo {
        id: userInfo
    }

    ThemeManager {
        id: themeManager
    }

    // Local QML-native mirror of themeManager.darkMode. Reading the C++/Rust
    // property directly in bindings depends on cxx-qt correctly registering
    // a NOTIFY signal for it — assigning it into a plain QML property here
    // sidesteps that entirely, since QML's own property system always
    // notifies dependents on assignment, regardless of what's happening on
    // the Rust side.
    property bool isDark: true

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentTime = new Date()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: userInfo.refresh()
    }

    // Statusbar never closes, so it can't pick up appearance.theme changes
    // on relaunch like other apps do — poll instead.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            isDark = themeManager.refresh()
        }
    }

    Rectangle {
        id: dock
        anchors.fill: parent
        color: cBarBg
        radius: 0
        border.width: 0

        Item {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            // LEFT SIDE
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Button { // start button
                    width: trayBtnSize
                    height: trayBtnSize
                    padding: 0

                    background: Rectangle {
                        color: "#00000000"
                        radius: 8
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = cHover
                            onExited: parent.color = "#00000000"
                        }
                    }

                    onClicked: { 
                        if ( startMenu.active ) {
                        startMenu.active = false;
                        } else {
                        calendarLoader.active = false;   // force the other one shut first
                        quickSettingsLoader.active = false;
                        notificationLoader.active = false;
                        trayLoader.active = false;
                        startMenu.active = true;
                        startMenu.item.x = window.x + 8
                        startMenu.item.y = window.y + window.height + 6
                        }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: parent.height - 8
                        source: "../../assets/Vamora.svg"
                    }
                }

                DividerV {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 4
                    color: window.cDivider
                }

                Button { // time
                    width: 118
                    height: trayBtnSize
                    padding: 0

                    background: Rectangle {
                        color: "#00000000"
                        radius: 8
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = cHover
                            onExited: parent.color = "#00000000"
                        }
                    }

                    onClicked: { // time / clock button
                        if ( calendarLoader.active ) {
                            calendarLoader.active = false;
                        } else {
                            startMenu.active = false;   // force the other one shut first
                            quickSettingsLoader.active = false;
                            notificationLoader.active = false;
                            trayLoader.active = false;
                            calendarLoader.active = true;
                            calendarLoader.item.x = window.x + 8
                            calendarLoader.item.y = window.y + window.height + 6
                        }
                    }
                    Text {
                        id: time
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(currentTime, "hh:mm  ddd, d MMM")
                        color: cText
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        font.family: "Inter"
                    }
                }

                Button { // notification
                    id: notificationButton
                    width: trayBtnSize
                    height: trayBtnSize
                    padding: 0

                    background: Rectangle {
                        color: "#00000000"
                        radius: 8
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = cHover
                            onExited: parent.color = "#00000000"
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: iconSize
                        height: iconSize
                        source: "../../assets/icons/notification/bell.svg"
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: cText
                        }
                    }

                    onClicked: {
                        if (notificationLoader.active) {
                            notificationLoader.active = false
                        } else {
                            startMenu.active = false
                            calendarLoader.active = false
                            quickSettingsLoader.active = false
                            trayLoader.active = false
                            notificationLoader.active = true
                            var point = notificationButton.mapToItem(
                                window.contentItem, 0, 0)
                            notificationLoader.item.x = window.x + point.x
                            notificationLoader.item.y =
                                window.y + window.height + 6
                        }
                    }
                }
            }

            // RIGHT SIDE
            Row {
                id: rightRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Button {
                    id: trayButton
                    width: trayBtnSize
                    height: trayBtnSize
                    padding: 0
                    background: Rectangle {
                        color: "#00000000"
                        radius: 8
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = cHover
                            onExited: parent.color = "#00000000"
                        }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: iconSize
                        height: iconSize
                        source: "../../assets/icons/arrows/arrowdown.svg"
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: cText
                        }
                    }

                    onClicked: {
                        if (trayLoader.active) {
                            trayLoader.active = false
                        } else {
                            startMenu.active = false
                            calendarLoader.active = false
                            quickSettingsLoader.active = false
                            notificationLoader.active = false
                            trayLoader.active = true
                            var point = trayButton.mapToItem(
                                window.contentItem, 0, 0)
                            trayLoader.item.x = window.x + point.x -
                                trayLoader.item.width + trayButton.width
                            trayLoader.item.y = window.y + window.height + 6
                        }
                    }
                }

                // These indicators remain visible, but form one control-center
                // button. The single hover surface spans all three icons.
                Button {
                    id: controlCenterButton
                    width: trayBtnSize * 3 + 4
                    height: trayBtnSize
                    padding: 0

                    background: Rectangle {
                        radius: 8
                        color: controlCenterMouse.containsMouse
                            ? cHover : "#00000000"
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        Image {
                            width: iconSize
                            height: iconSize
                            source: "../../assets/icons/volume-2.svg"
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: cText }
                        }

                        Image {
                            width: iconSize
                            height: iconSize
                            source: {
                                switch (userInfo.wifiStrength) {
                                    case 4: return "../../assets/icons/wifi/wifi.svg"
                                    case 3: return "../../assets/icons/wifi/wifi-high.svg"
                                    case 2: return "../../assets/icons/wifi/wifi-low.svg"
                                    case 1: return "../../assets/icons/wifi/wifi-low.svg"
                                    default: return "../../assets/icons/wifi/wifi-zero.svg"
                                }
                            }
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: cText }
                        }

                        Image {
                            width: iconSize
                            height: iconSize
                            source: "../../assets/icons/battery/battery-full.svg"
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: cText }
                        }
                    }

                    MouseArea {
                        id: controlCenterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: window.openQuickSettings()
                    }
                }
            }
        }
    }

    Loader {
        id: startMenu
        source: "../startmenu/window.qml"
        active: false
    }

    Loader {
        id: calendarLoader
        source: "../calendar/window.qml"
        active: false
    }

    Loader {
        id: quickSettingsLoader
        source: "../quicksettings/window.qml"
        active: false
    }

    Loader {
        id: notificationLoader
        source: "../notifications/window.qml"
        active: false
    }

    Loader {
        id: trayLoader
        source: "../tray/window.qml"
        active: false
    }
}
