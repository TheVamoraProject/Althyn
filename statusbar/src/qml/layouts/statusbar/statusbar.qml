import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import "../components"
import com.vamora

Window {
    id: window
    visible: true
    width: screen.width
    height: 30
    title: "Vamora StatusBar"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Wayland (layer-shell). Top-layer bar spanning the output width that
    // reserves its own height, replacing the X11 strut. Ignored on X11.
    LayerShell.Window.scope: "althyn-bar"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.exclusionZone: height
    color: "transparent"
    x: 0
    y: 0

    // ---- Vamora/AlthynUI palette (zinc, follows appearance.theme) ----
    readonly property color cBarBg: isDark ? "#09090b" : "#fafafa"        // zinc-950/50, solid
    readonly property color cHover: effDark ? "#40272a2e" : "#40d4d4d8"    // zinc-800/300 hover overlay
    readonly property color cDivider: effDark ? "#33ffffff" : "#33000000"
    readonly property color cText: effDark ? "#f4f4f5" : "#18181b"         // zinc-100/900
    readonly property color cTextMuted: effDark ? "#a1a1aa" : "#52525b"    // zinc-400/600
    readonly property color cAccent: "#2563eb"           // Vamora blue-600, same in both themes

    property date currentTime: new Date()
    property int iconSize: 17
    property int trayBtnSize: 28

    // Places a popup window. x/y position it on X11; on Wayland the
    // compositor owns window positions (Qt resets x/y to 0), so the popups
    // take posX/posY as layer-shell margins instead.
    function placePopup(item, px, py) {
        item.x = px
        item.y = py
        item.posX = px
        item.posY = py
    }

    function openQuickSettings() {
        if (quickSettingsLoader.active) {
            quickSettingsLoader.active = false
        } else {
            startMenu.active = false
            calendarLoader.active = false
            notificationLoader.active = false
            trayLoader.active = false
            quickSettingsLoader.active = true
            placePopup(quickSettingsLoader.item,
                window.x + window.width - quickSettingsLoader.item.width - window.sideInset,
                window.y + window.height + 6)
        }
    }

    // Notification centre. On phones/tablets there is no bell button, so it
    // opens at the left edge (swipe down from the top-left half of the bar).
    function openNotifications() {
        if (notificationLoader.active) {
            notificationLoader.active = false
        } else {
            startMenu.active = false
            calendarLoader.active = false
            quickSettingsLoader.active = false
            trayLoader.active = false
            notificationLoader.active = true
            var px = window.phoneOrTablet
                ? window.sideInset : notificationButton.mapToItem(window.contentItem, 0, 0).x
            placePopup(notificationLoader.item, window.x + px, window.y + window.height + 6)
        }
    }

    UserInfo {
        id: userInfo
    }

    ThemeManager {
        id: themeManager
    }

    // Form factor comes from VamoraSys (`vamorasys device get form_factor`).
    DeviceInfo {
        id: deviceInfo
    }

    // Same check the dock uses for auto-hide: is a (non-homescreen) app maximized?
    // With none, the bar is fully transparent (wallpaper shows through).
    BarMaximized {
        id: barMax
    }
    property bool appMaximized: false
    Timer {
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: window.appMaximized = barMax.appMaximized()
    }

    // While transparent, the clock/icons follow the brightness of whatever is
    // under the bar (sampled from the real screen pixels, X11): black on light,
    // white on dark. With a maximized app the themed solid bar + theme colours
    // are used. Hysteresis (0.42 / 0.58) stops flicker near mid-grey and keeps
    // the bar's own glyph pixels from flipping the decision.
    BarLuma {
        id: barLuma
    }
    property bool underDark: false
    readonly property bool effDark: window.appMaximized ? isDark : window.underDark
    Timer {
        interval: 500
        running: !window.appMaximized
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var r = Screen.devicePixelRatio
            var l = barLuma.luminance(0, 0, Math.round(window.width * r),
                                      Math.round(window.height * r))
            if (l < 0) return
            if (window.underDark) { if (l > 0.58) window.underDark = false }
            else if (l < 0.42) window.underDark = true
        }
    }

    // Phones and tablets (incl. foldables): no start-menu button.
    property bool phoneOrTablet: false
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            window.phoneOrTablet = deviceInfo.isPhoneOrTablet()
            window.cornerPadding = deviceInfo.cornerPadding()
        }
    }

    // Side margins: 8 dp on a plain rectangular screen; on rounded screens the
    // larger rounded-corner padding (VamoraSys statusbar.corner_padding, or the
    // per-form-factor default) wins — same rule as Android's status bar.
    property int cornerPadding: 0
    readonly property real sideInset: Math.max(8, window.cornerPadding)

    // Date next to the clock only when there is room: below 600 dp wide
    // (Android's "compact" width class — phones) the clock is just "09:45".
    readonly property bool compactClock: window.width < 600

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
        color: window.appMaximized ? cBarBg : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        radius: 0
        border.width: 0

        // Touch-first devices: swipe down from the top edge — left half opens
        // the notification centre, right half opens the control centre.
        DragHandler {
            id: swipeDown
            target: null
            enabled: window.phoneOrTablet
            property bool fired: false
            onActiveChanged: if (!active) fired = false
            onTranslationChanged: {
                if (!fired && translation.y > 20
                        && translation.y > Math.abs(translation.x)) {
                    fired = true
                    if (centroid.pressPosition.x < window.width / 2) {
                        if (!notificationLoader.active) window.openNotifications()
                    } else {
                        if (!quickSettingsLoader.active) window.openQuickSettings()
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: window.sideInset
            anchors.rightMargin: window.sideInset

            // LEFT SIDE
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Button { // start button (hidden on phones and tablets)
                    visible: !window.phoneOrTablet
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
                        placePopup(startMenu.item, window.x + 8, window.y + window.height + 6)
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
                    visible: !window.phoneOrTablet
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 4
                    color: window.cDivider
                }

                Button { // time
                    width: window.compactClock ? time.implicitWidth + 20 : 118
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
                            placePopup(calendarLoader.item, window.x + 8, window.y + window.height + 6)
                        }
                    }
                    Text {
                        id: time
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(currentTime, window.compactClock ? "hh:mm" : "hh:mm  ddd, d MMM")
                        color: cText
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        font.family: "Inter"
                    }
                }

                Button { // notification (hidden on phones/tablets: swipe down from the top-left instead)
                    id: notificationButton
                    visible: !window.phoneOrTablet
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

                    onClicked: window.openNotifications()
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
                            placePopup(trayLoader.item,
                                window.x + point.x - trayLoader.item.width + trayButton.width,
                                window.y + window.height + 6)
                        }
                    }
                }

                // These indicators remain visible, but form one control-center
                // button. The single hover surface spans all three icons.
                Button {
                    id: controlCenterButton
                    // fit the icons (+4dp each side) so the cluster sits flush with the bar's right margin
                    width: ccIcons.width + 8
                    height: trayBtnSize
                    padding: 0

                    background: Rectangle {
                        radius: 8
                        color: controlCenterMouse.containsMouse
                            ? cHover : "#00000000"
                    }

                    Row {
                        id: ccIcons
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
