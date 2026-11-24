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

    // Same trick for the network indicators: mirror the Rust values into
    // plain QML properties on every refresh so the icons always update.
    property bool netWifiOn: false
    property int netWifiBars: 0
    property bool netBluetoothOn: false
    property bool batPresent: false
    property int batPercent: 100
    property bool batCharging: false
    property int batType: 1   // statusbar.battery_type: 1 % beside, 2 % inside, 3 no %
    function syncNetwork() {
        userInfo.refresh()
        netWifiOn = userInfo.wifi_enabled
        netWifiBars = userInfo.wifi_strength
        netBluetoothOn = userInfo.bluetooth_on
        batPresent = userInfo.battery_present
        batPercent = userInfo.battery_percent
        batCharging = userInfo.battery_charging
        batType = userInfo.battery_type
    }

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
        onTriggered: syncNetwork()
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
                    property int unread: 0
                    NotificationStore { id: barNotifications }
                    Timer {
                        interval: 3000; repeat: true; running: true; triggeredOnStart: true
                        onTriggered: {
                            try { notificationButton.unread = JSON.parse(barNotifications.json()).length } catch (e) { notificationButton.unread = 0 }
                        }
                    }
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
                        source: notificationButton.unread > 0 ? "../../assets/icons/notification/bell-dot.svg" : "../../assets/icons/notification/bell.svg"
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

                        // Only while Bluetooth is powered on.
                        Image {
                            width: iconSize
                            height: iconSize
                            visible: netBluetoothOn
                            source: "../../assets/icons/bluetooth.svg"
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: cText }
                        }

                        // Hidden entirely while Wi-Fi is off or there is no Wi-Fi device.
                        Image {
                            width: iconSize
                            height: iconSize
                            visible: netWifiOn
                            source: {
                                switch (netWifiBars) {
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

                        // Battery: "74%" next to a plain level icon; a bolt over the icon while
                        // charging. Hidden on machines without a battery.
                        Row {
                            id: battery
                            visible: batPresent
                            spacing: 4
                            height: iconSize
                            readonly property color levelColor: batCharging ? "#34d399"
                                : (batPercent <= 20 ? "#ef4444" : cText)

                            Text {
                                visible: batType === 1
                                height: iconSize
                                verticalAlignment: Text.AlignVCenter
                                text: batPercent + "%"
                                color: cText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: batType === 2 ? 32 : 28
                                height: iconSize

                                Rectangle {
                                    id: batBody
                                    readonly property bool inside: batType === 2
                                    y: (parent.height - height) / 2
                                    width: inside ? 28 : 24
                                    height: inside ? 15 : 12
                                    radius: inside ? 5 : 4
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Qt.rgba(cText.r, cText.g, cText.b, 0.6)

                                    Rectangle {
                                        x: 2; y: 2
                                        height: parent.height - 4
                                        width: Math.max(batPercent > 0 ? 3 : 0, (parent.width - 4) * batPercent / 100)
                                        radius: 2
                                        color: battery.levelColor
                                        opacity: batBody.inside ? 0.4 : 1
                                    }

                                    // Style 2: percentage inside, with a small bolt while charging.
                                    Row {
                                        visible: batBody.inside
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Image {
                                            visible: batCharging
                                            width: 7; height: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: "../../assets/icons/battery/bolt.svg"
                                            layer.enabled: true
                                            layer.effect: ColorOverlay { color: cText }
                                        }
                                        Text {
                                            text: batPercent
                                            color: cText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }
                                }
                                Rectangle {
                                    x: batBody.width + 1; width: 2; height: 4
                                    anchors.verticalCenter: batBody.verticalCenter
                                    radius: 1
                                    color: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
                                }

                                // Charging bolt: a little taller than the battery, with a
                                // contrasting rim so it reads on top of the fill.
                                Item {
                                    visible: batCharging && !batBody.inside
                                    width: 16; height: 18
                                    x: batBody.x + (batBody.width - width) / 2
                                    y: (parent.height - height) / 2
                                    Image {
                                        anchors.centerIn: parent
                                        width: 18; height: 20
                                        source: "../../assets/icons/battery/bolt.svg"
                                        layer.enabled: true
                                        layer.effect: ColorOverlay { color: effDark ? "#18181b" : "#fafafa" }
                                    }
                                    Image {
                                        anchors.centerIn: parent
                                        width: 15; height: 17
                                        source: "../../assets/icons/battery/bolt.svg"
                                        layer.enabled: true
                                        layer.effect: ColorOverlay { color: effDark ? "#f4f4f5" : "#18181b" }
                                    }
                                }
                            }
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
