import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import dev.vamoraos.SysInfo 1.0
import "../components"

Item {
    id: vamifyPage
    anchors.fill: parent

    property string activeSection: "overview"
    property string currentTheme: {
        var value = SysInfo.getAppearanceTheme()
        return value === "light" || value === "dark" ? value : "dark"
    }
    property string themeStatus: ""
    property string homescreenGrid: "13x6"
    property string homescreenIconSize: "48"
    property string accentColor: {
        var value = SysInfo.getAccentColor()
        return value.indexOf("error") !== 0 ? value : "#3b82f6"
    }
    property string iconColor: "rainbow"
    property real iconSizePct: 1.0
    readonly property var iconColorOptions: [
        { name: "Default", value: "rainbow" },
        { name: "Red",     value: "#b1585c" },
        { name: "Orange",  value: "#f2924a" },
        { name: "Yellow",  value: "#f0d64a" },
        { name: "Green",   value: "#8ac351" },
        { name: "Cyan",    value: "#3fd1d6" },
        { name: "Blue",    value: "#2f6fed" }
    ]
    // Dummy state for the generic Vamify subpages (Windows/Cursor/AOD/
    // Bootloader/Desktops) — not wired to VamoraSys, just enough to make
    // the sliders/toggles feel real instead of static placeholder rows.
    property bool windowsRounded: true
    property bool windowsShadows: true
    property bool windowsSnap: true
    property real windowsCornerPx: 10
    property real windowsGapPx: 8

    property bool cursorTrail: false
    property bool cursorLargeClick: false
    property real cursorSizePct: 1.0
    property string cursorTheme: "Vamora Default"
    readonly property var cursorThemeOptions: ["Vamora Default", "Classic", "High Contrast", "Neon"]
    function cycleCursorTheme() {
        var i = cursorThemeOptions.indexOf(cursorTheme)
        cursorTheme = cursorThemeOptions[(i + 1) % cursorThemeOptions.length]
    }

    property bool aodEnabled: true
    property bool screensaverEnabled: true
    property real aodBrightnessPct: 0.4
    property real idleTimeoutMin: 5

    property bool bootMenuEnabled: true
    property bool bootAnimEnabled: true
    property real bootTimeoutSec: 5

    property bool desktopsWrap: true
    property bool desktopsIndicator: true
    property real desktopsCount: 4

    // ── Generic VamoraSys setting bridge ──────────────────────────────────
    // Thin wrapper around SysInfo.getSetting/setSetting so every setting
    // from `vamorasys settings dump vamify` can be wired up without a
    // dedicated Rust getter/setter for each one (see get_appearance_theme
    // etc. above for the ones that already had bespoke methods).
    function readSetting(key, fallback) {
        var value = SysInfo.getSetting(key)
        return value.indexOf("error:") === 0 ? fallback : value
    }
    function writeSetting(key, value) {
        if (!vamoraSysAvailable) {
            warningAttention = true
            return false
        }
        return SysInfo.setSetting(key, value).indexOf("error:") !== 0
    }
    function toBool(value, fallback) {
        if (value === "true") return true
        if (value === "false") return false
        return fallback
    }
    function setStringSetting(key, propName, value) {
        if (writeSetting(key, value))
            vamifyPage[propName] = value
    }
    function setBoolSetting(key, propName, value) {
        if (writeSetting(key, value ? "true" : "false"))
            vamifyPage[propName] = value
    }
    function setNumberSetting(key, propName, value) {
        if (writeSetting(key, value.toString()))
            vamifyPage[propName] = value
    }

    // appearance.* (accent_color and theme already have dedicated methods)
    property string fontSize: "16"
    property string iconThemeName: "default"
    property string primaryColor: "#2563eb"
    property string secondaryColor: "#0ea5e9"
    property string successColor: "#16a34a"
    property string warningColor: "#f59e0b"
    property string errorColor: "#dc2626"
    property string surfaceColor: "#eff6ff"
    property string textColor: "#0f172a"

    // homescreen.* (grid and icon_size already have dedicated methods)
    property string homescreenLayout: "default"
    property string homescreenWallpaper: "default"
    property string homescreenWidgets: "clock"

    // lockscreen.*
    property string lockClockStyle: "digital"
    property bool lockShowDate: true
    property bool lockShowNotifications: true
    property string lockWallpaper: "default"

    // icons.*
    property string iconsBgColor: "#2563eb"
    property real iconsCornerRadius: 8
    property bool iconsStroke: false
    property string iconsStrokeColor: "#0f172a"
    property string iconsStyle: "normal"

    // statusbar.*
    property real statusbarSize: 32
    property bool statusbarTransparency: false

    // dock.* (position — dock.qml elsewhere in Settings covers show/size)
    property string dockPosition: "bottom"

    // wm.*
    property bool wmAnimations: true
    property string wmFocusMode: "click"
    property bool wmTransparency: false
    property bool wmWindowEffects: true

    // bootloader.* (bootTimeoutSec above is now the real bootloader.timeout)
    property string bootDefaultEntry: "vamora"

    // keyboard.* — new section, not represented anywhere yet
    property string keyboardLayout: "us"
    property string keyboardLayouts: "us"
    property string keyboardModel: "pc105"
    property string keyboardOptions: ""
    property string keyboardVariant: ""

    // Pulls fresh values for whichever section is open, mirroring
    // refreshGrid/refreshIconSize's per-section pattern above.
    function refreshVamifySettings(section) {
        switch (section) {
        case "appearance":
            fontSize = readSetting("appearance.font_size", fontSize)
            iconThemeName = readSetting("appearance.icon_theme", iconThemeName)
            primaryColor = readSetting("appearance.primary_color", primaryColor)
            secondaryColor = readSetting("appearance.secondary_color", secondaryColor)
            successColor = readSetting("appearance.success_color", successColor)
            warningColor = readSetting("appearance.warning_color", warningColor)
            errorColor = readSetting("appearance.error_color", errorColor)
            surfaceColor = readSetting("appearance.surface_color", surfaceColor)
            textColor = readSetting("appearance.text_color", textColor)
            break
        case "homescreen":
            homescreenLayout = readSetting("homescreen.layout", homescreenLayout)
            homescreenWallpaper = readSetting("homescreen.wallpaper", homescreenWallpaper)
            homescreenWidgets = readSetting("homescreen.widgets", homescreenWidgets)
            break
        case "lockscreen":
            lockClockStyle = readSetting("lockscreen.clock_style", lockClockStyle)
            lockShowDate = toBool(readSetting("lockscreen.show_date", ""), lockShowDate)
            lockShowNotifications = toBool(readSetting("lockscreen.show_notifications", ""), lockShowNotifications)
            lockWallpaper = readSetting("lockscreen.wallpaper", lockWallpaper)
            break
        case "icons":
            iconsBgColor = readSetting("icons.bg_color", iconsBgColor)
            iconsCornerRadius = parseFloat(readSetting("icons.corner_radius", iconsCornerRadius.toString())) || iconsCornerRadius
            iconsStroke = toBool(readSetting("icons.stroke", ""), iconsStroke)
            iconsStrokeColor = readSetting("icons.stroke_color", iconsStrokeColor)
            iconsStyle = readSetting("icons.style", iconsStyle)
            break
        case "statusbar":
            statusbarSize = parseFloat(readSetting("statusbar.size", statusbarSize.toString())) || statusbarSize
            statusbarTransparency = toBool(readSetting("statusbar.transparency", ""), statusbarTransparency)
            break
        case "dock":
            dockPosition = readSetting("dock.position", dockPosition)
            break
        case "windows":
            wmAnimations = toBool(readSetting("wm.animations", ""), wmAnimations)
            wmFocusMode = readSetting("wm.focus_mode", wmFocusMode)
            wmTransparency = toBool(readSetting("wm.transparency", ""), wmTransparency)
            wmWindowEffects = toBool(readSetting("wm.window_effects", ""), wmWindowEffects)
            break
        case "bootloader":
            bootDefaultEntry = readSetting("bootloader.default_entry", bootDefaultEntry)
            var timeout = parseFloat(readSetting("bootloader.timeout", bootTimeoutSec.toString()))
            if (!isNaN(timeout)) bootTimeoutSec = timeout
            break
        case "keyboard":
            keyboardLayout = readSetting("keyboard.layout", keyboardLayout)
            keyboardLayouts = readSetting("keyboard.layouts", keyboardLayouts)
            keyboardModel = readSetting("keyboard.model", keyboardModel)
            keyboardOptions = readSetting("keyboard.options", keyboardOptions)
            keyboardVariant = readSetting("keyboard.variant", keyboardVariant)
            break
        }
    }

    readonly property var iconPreviewApps: [
        { name: "Contacts", icon: "appicons/contacts" },
        { name: "Files",    icon: "appicons/files" },
        { name: "Gallery",  icon: "appicons/gallery" },
        { name: "Camera",   icon: "appicons/camera" }
    ]
    readonly property var accentOptions: [
        { name: "Blue",    value: "#3b82f6" },
        { name: "Indigo",  value: "#6366f1" },
        { name: "Purple",  value: "#8b5cf6" },
        { name: "Fuchsia", value: "#d946ef" },
        { name: "Pink",    value: "#ec4899" },
        { name: "Rose",    value: "#f43f5e" },
        { name: "Red",     value: "#ef4444" },
        { name: "Orange",  value: "#f97316" },
        { name: "Amber",   value: "#f59e0b" },
        { name: "Yellow",  value: "#eab308" },
        { name: "Lime",    value: "#84cc16" },
        { name: "Green",   value: "#22c55e" },
        { name: "Emerald", value: "#10b981" },
        { name: "Teal",    value: "#14b8a6" },
        { name: "Sky",     value: "#0ea5e9" },
        { name: "Slate",   value: "#64748b" }
    ]
    // Shared swatch set for the role-based color rows below (primary,
    // secondary, success, warning, error, surface, text) — includes each
    // row's current default so it always shows as selected on first open,
    // plus a few neutrals for the surface/text roles.
    readonly property var roleColorPalette: [
        { name: "Blue",   value: "#2563eb" },
        { name: "Sky",    value: "#0ea5e9" },
        { name: "Green",  value: "#16a34a" },
        { name: "Amber",  value: "#f59e0b" },
        { name: "Red",    value: "#dc2626" },
        { name: "Indigo", value: "#4f46e5" },
        { name: "Purple", value: "#7c3aed" },
        { name: "Pink",   value: "#db2777" },
        { name: "Orange", value: "#ea580c" },
        { name: "Teal",   value: "#0d9488" },
        { name: "Cyan",   value: "#0891b2" },
        { name: "Slate",  value: "#64748b" },
        { name: "Light",  value: "#eff6ff" },
        { name: "White",  value: "#ffffff" },
        { name: "Navy",   value: "#0f172a" },
        { name: "Black",  value: "#0f0f10" }
    ]
    function hexLuminance(hex) {
        var c = hex.indexOf("#") === 0 ? hex.substring(1) : hex
        if (c.length === 3) c = c[0]+c[0]+c[1]+c[1]+c[2]+c[2]
        var r = parseInt(c.substring(0, 2), 16) / 255
        var g = parseInt(c.substring(2, 4), 16) / 255
        var b = parseInt(c.substring(4, 6), 16) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    function contrastOn(hex) {
        return hexLuminance(hex) > 0.62 ? "#18202b" : "#ffffff"
    }
    property bool vamoraSysAvailable: SysInfo.isVamoraSysInstalled()
    property bool warningAttention: false
    property var settingsWindow: ApplicationWindow.window

    readonly property color pageCard: currentTheme === "light" ? "#ffffff" : "#1e1e1e"
    readonly property color pageText: currentTheme === "light" ? "#1b1d22" : "#f0f0f0"
    readonly property color pageMuted: currentTheme === "light" ? "#68717e" : "#777777"
    readonly property color pageBorder: currentTheme === "light" ? "#d7dbe2" : "#2c2c2c"
    readonly property color pageHover: currentTheme === "light" ? "#eef0f3" : "#252525"

    function refreshTheme() {
        vamoraSysAvailable = SysInfo.isVamoraSysInstalled()
        var value = SysInfo.getAppearanceTheme()
        if (value === "dark" || value === "light") {
            currentTheme = value
            if (settingsWindow)
                settingsWindow.appearanceTheme = value
        }
    }

    function setTheme(value) {
        if (!vamoraSysAvailable) {
            warningAttention = true
            return
        }
        var result = SysInfo.setAppearanceTheme(value)
        if (result === "dark" || result === "light") {
            currentTheme = result
            if (settingsWindow)
                settingsWindow.appearanceTheme = result
            themeStatus = "Theme saved"
        } else {
            themeStatus = result
        }
    }

    function setAccent(value) {
        if (!vamoraSysAvailable) {
            warningAttention = true
            return
        }
        var result = SysInfo.setAccentColor(value)
        if (result.indexOf("error:") !== 0) {
            accentColor = result
            if (settingsWindow)
                settingsWindow.accentColor = result
        }
    }

    function refreshGrid() {
        var value = SysInfo.getHomescreenGrid()
        if (value.indexOf("error:") !== 0)
            homescreenGrid = value
    }

    function setGrid(value) {
        if (!vamoraSysAvailable) {
            warningAttention = true
            return
        }
        var result = SysInfo.setHomescreenGrid(value)
        if (result.indexOf("error:") !== 0)
            homescreenGrid = result
    }

    function refreshIconSize() {
        var value = SysInfo.getHomescreenIconSize()
        if (value.indexOf("error:") !== 0)
            homescreenIconSize = value
    }

    function setIconSize(value) {
        if (!vamoraSysAvailable) {
            warningAttention = true
            return
        }
        var result = SysInfo.setHomescreenIconSize(value)
        if (result.indexOf("error:") !== 0)
            homescreenIconSize = result
    }

    function sectionTitle() {
        var titles = {
            appearance: "General appearance",
            windows: "Windows",
            cursor: "Cursor",
            wallpaper: "Wallpaper",
            homescreen: "Homescreen",
            lockscreen: "Lockscreen",
            icons: "Icons",
            aod: "AOD / Screensaver",
            bootloader: "Bootloader",
            desktops: "Desktops",
            statusbar: "Statusbar",
            dock: "Dock",
            keyboard: "Keyboard"
        }
        return titles[vamifyPage.activeSection] || "Vamify"
    }

    // Exposed so the app-level breadcrumb (main.qml) can show
    // "Settings › Vamify › <this>" without duplicating the title map.
    readonly property string activeSectionTitle: vamifyPage.activeSection === "overview" ? "Vamify" : vamifyPage.sectionTitle()

    Timer {
        interval: 1500
        repeat: true
        running: vamifyPage.visible
        onTriggered: {
            vamifyPage.refreshTheme()
            vamifyPage.refreshVamifySettings(vamifyPage.activeSection)
            if (vamifyPage.activeSection === "homescreen") {
                vamifyPage.refreshGrid()
                vamifyPage.refreshIconSize()
            }
        }
    }

    Component.onCompleted: {
        refreshTheme()
        refreshGrid()
        refreshIconSize()
    }

    component GnomeToolbarWindow: Rectangle {
        id: previewWindow
        property string mode: "light"
        property bool windowClosed: false
        property bool windowMinimized: false
        property bool windowMaximized: false
        property real savedWindowWidth: 172
        property real savedWindowHeight: 116
        property real minWindowWidth: 96
        property real minWindowHeight: 72
        property real resizeStartWidth: 0
        property real resizeStartHeight: 0
        property real resizeStartMouse: 0
        property bool selected: vamifyPage.currentTheme === mode

        Layout.fillWidth: true
        Layout.preferredHeight: 220
        radius: 12
        color: "#111111"
        border.color: previewWindow.selected ? vamifyPage.accentColor : "transparent"
        border.width: previewWindow.selected ? 3 : 0
        Behavior on border.width { NumberAnimation { duration: 120 } }
        clip: true
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: previewMask
        }

        Rectangle {
            id: previewMask
            anchors.fill: parent
            radius: 12
            color: "#ffffff"
            visible: false
        }

        Image {
            anchors.fill: parent
            source: "qrc:/assets/vamify-wallpaper.svg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            color: previewWindow.mode === "light" ? "#c7d2df" : "#171a22"
            opacity: 0.76
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            cursorShape: Qt.PointingHandCursor
            onClicked: vamifyPage.setTheme(previewWindow.mode)
        }

        Rectangle {
            id: innerWindow
            visible: !previewWindow.windowClosed
            width: previewWindow.windowMaximized
                   ? previewWindow.width - 20
                   : Math.min(previewWindow.savedWindowWidth, previewWindow.width - 28)
            height: previewWindow.windowMinimized
                    ? 34
                    : (previewWindow.windowMaximized
                       ? previewWindow.height - 20
                       : Math.min(previewWindow.savedWindowHeight, previewWindow.height - 28))
            anchors.centerIn: parent
            radius: 10
            color: previewWindow.mode === "light" ? "#f7f7f8" : "#24262d"
            border.color: previewWindow.mode === "light" ? "#d7d8dc" : "#3d414c"
            border.width: 1

            Rectangle {
                id: gnomeToolbar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 30
                topLeftRadius: 10
                topRightRadius: 10
                bottomLeftRadius: 0
                bottomRightRadius: 0
                color: previewWindow.mode === "light" ? "#ececef" : "#2e3139"

                Row {
                    anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter }
                    spacing: 5

                    Repeater {
                        model: [
                            { fill: "#ff5f57", glyph: "×" },
                            { fill: "#febc2e", glyph: "−" },
                            { fill: "#28c840", glyph: "□" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 11
                            height: 11
                            radius: 6
                            color: modelData.fill

                            Text {
                                anchors.centerIn: parent
                                text: modelData.glyph
                                color: "#303030"
                                font.pixelSize: 8
                                visible: toolbarButton.containsMouse
                            }

                            MouseArea {
                                id: toolbarButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (index === 0) previewWindow.windowClosed = true
                                    else if (index === 1) previewWindow.windowMinimized = !previewWindow.windowMinimized
                                    else previewWindow.windowMaximized = !previewWindow.windowMaximized
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors { top: gnomeToolbar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                color: previewWindow.mode === "light" ? "#ffffff" : "#1d1f25"
                radius: 8
            }
        }

        MouseArea {
            anchors { left: innerWindow.left; top: innerWindow.top; bottom: innerWindow.bottom }
            width: 6
            enabled: !previewWindow.windowClosed && !previewWindow.windowMaximized
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => {
                previewWindow.resizeStartWidth = previewWindow.savedWindowWidth
                previewWindow.resizeStartMouse = mouse.x
            }
            onPositionChanged: (mouse) => { if (pressed)
                previewWindow.savedWindowWidth = Math.max(
                    previewWindow.minWindowWidth,
                    previewWindow.resizeStartWidth - (mouse.x - previewWindow.resizeStartMouse))
            }
        }

        MouseArea {
            anchors { right: innerWindow.right; top: innerWindow.top; bottom: innerWindow.bottom }
            width: 6
            enabled: !previewWindow.windowClosed && !previewWindow.windowMaximized
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => {
                previewWindow.resizeStartWidth = previewWindow.savedWindowWidth
                previewWindow.resizeStartMouse = mouse.x
            }
            onPositionChanged: (mouse) => { if (pressed)
                previewWindow.savedWindowWidth = Math.max(
                    previewWindow.minWindowWidth,
                    previewWindow.resizeStartWidth + (mouse.x - previewWindow.resizeStartMouse))
            }
        }

        MouseArea {
            anchors { left: innerWindow.left; right: innerWindow.right; top: innerWindow.top }
            height: 6
            enabled: !previewWindow.windowClosed && !previewWindow.windowMaximized
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => {
                previewWindow.resizeStartHeight = previewWindow.savedWindowHeight
                previewWindow.resizeStartMouse = mouse.y
            }
            onPositionChanged: (mouse) => { if (pressed)
                previewWindow.savedWindowHeight = Math.max(
                    previewWindow.minWindowHeight,
                    previewWindow.resizeStartHeight - (mouse.y - previewWindow.resizeStartMouse))
            }
        }

        MouseArea {
            anchors { left: innerWindow.left; right: innerWindow.right; bottom: innerWindow.bottom }
            height: 6
            enabled: !previewWindow.windowClosed && !previewWindow.windowMaximized
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => {
                previewWindow.resizeStartHeight = previewWindow.savedWindowHeight
                previewWindow.resizeStartMouse = mouse.y
            }
            onPositionChanged: (mouse) => { if (pressed)
                previewWindow.savedWindowHeight = Math.max(
                    previewWindow.minWindowHeight,
                    previewWindow.resizeStartHeight + (mouse.y - previewWindow.resizeStartMouse))
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: previewWindow.windowClosed
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                previewWindow.windowClosed = false
                previewWindow.windowMinimized = false
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 30
            color: Qt.rgba(0, 0, 0, 0.38)
            bottomLeftRadius: 12
            bottomRightRadius: 12

            Text {
                anchors.centerIn: parent
                text: previewWindow.mode === "light" ? "Light" : "Dark"
                color: "#ffffff"
                font { pixelSize: 12; weight: previewWindow.selected ? Font.DemiBold : Font.Normal }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: vamifyPage.setTheme(previewWindow.mode)
            }
        }

        // Active-mode badge: the border alone is easy to miss, so pair it
        // with an explicit check mark in the corner of whichever card
        // matches the mode VamoraOS is actually running in.
        Rectangle {
            visible: previewWindow.selected
            width: 22; height: 22; radius: 11
            color: vamifyPage.accentColor
            border.color: "#ffffff"
            border.width: 2
            anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "#ffffff"
                font { pixelSize: 12; weight: Font.Bold }
            }
        }
    }

    component VamifyToolbar: Rectangle {
        // On narrow/mobile windows the app-level header in main.qml already
        // shows this page's title and handles back navigation, so this
        // in-page toolbar would just duplicate it. Only render it in the
        // wide desktop layout.
        readonly property bool showHere: !vamifyPage.settingsWindow || !vamifyPage.settingsWindow.isMobile
        Layout.fillWidth: true
        Layout.topMargin: showHere ? 24 : 0
        Layout.leftMargin: 28
        Layout.rightMargin: 28
        height: showHere ? 42 : 0
        visible: showHere
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 12

            ToolButton {
                id: vamifyBackButton
                visible: vamifyPage.activeSection !== "overview"
                text: "‹"
                font.pixelSize: 32
                font.bold: false
                implicitWidth: 42
                implicitHeight: 42

                contentItem: Text {
                    text: vamifyBackButton.text
                    color: pageText
                    font: vamifyBackButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: vamifyBackButton.hovered ? pageHover : "transparent"
                    radius: 10
                }

                onClicked: vamifyPage.activeSection = "overview"
            }

            Text {
                text: vamifyPage.activeSection === "overview" ? "Vamify" : vamifyPage.activeSection.charAt(0).toUpperCase() + vamifyPage.activeSection.slice(1)
                color: pageText
                font.pixelSize: 26
                font.bold: true
                Layout.fillWidth: true
            }
        }
    }

    // Shared label+value+slider row used across the generic Vamify
    // subpages and the Icons page, so every "dummy" slider actually moves
    // and reports a value instead of sitting there as static UI.
    component LabeledSlider: ColumnLayout {
        id: ls
        property string label: ""
        property string valueText: ""
        property real value: 0
        property real fromVal: 0
        property real toVal: 1
        property real stepVal: 0.01
        signal moved(real v)

        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { text: ls.label; color: vamifyPage.pageText; font.pixelSize: 13; Layout.fillWidth: true }
            Text { text: ls.valueText; color: vamifyPage.pageMuted; font.pixelSize: 12 }
        }
        StyledSlider {
            Layout.fillWidth: true
            from: ls.fromVal; to: ls.toVal; stepSize: ls.stepVal
            value: ls.value
            onMoved: ls.moved(value)
        }
    }

    component Card: Rectangle {
        property alias content: cardContent.data
        Layout.fillWidth: true
        radius: 14
        color: vamifyPage.pageCard
        border.color: vamifyPage.pageBorder
        border.width: 1
        clip: true
        implicitHeight: cardContent.implicitHeight

        ColumnLayout {
            id: cardContent
            anchors { left: parent.left; right: parent.right }
            spacing: 0
        }
    }

    // Generic "type a custom value" dialog — reused for any VamoraSys
    // setting that's just a raw string (homescreen.grid, homescreen.icon_size,
    // and future ones), instead of a bespoke dialog per setting.
    Dialog {
        id: valueDialog
        property string dialogTitle: ""
        property var onSave: null   // function(value)

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320; modal: true
        background: Rectangle {
            color: vamifyPage.pageCard; radius: 16
            border { color: vamifyPage.pageBorder; width: 1 }
        }

        header: Item {
            height: 54
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: valueDialog.dialogTitle
                color: vamifyPage.pageText; font { pixelSize: 15; weight: Font.Medium }
            }
        }

        ColumnLayout {
            spacing: 10; width: parent.width
            Rectangle {
                Layout.fillWidth: true; height: 42; radius: 10
                color: vamifyPage.currentTheme === "light" ? "#f4f4f5" : "#141414"
                border { color: valueInput.activeFocus ? vamifyPage.accentColor : vamifyPage.pageBorder; width: 1 }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: valueInput
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: vamifyPage.pageText; font.pixelSize: 14
                    selectByMouse: true

                    Keys.onReturnPressed: valueDialog.save()
                    Keys.onEnterPressed: valueDialog.save()
                }
            }
        }

        footer: Item {
            implicitHeight: dialogFooterRow.implicitHeight + 28
            implicitWidth: valueDialog.width

            RowLayout {
                id: dialogFooterRow
                anchors { fill: parent; margins: 14 }
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 80; height: 34; radius: 8; color: "#2a2a2a"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#888"; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: valueDialog.reject() }
                }
                Rectangle {
                    width: 90; height: 34; radius: 8; color: vamifyPage.accentColor
                    Text { anchors.centerIn: parent; text: "Save"; color: "#fff"; font.pixelSize: 13; font.weight: Font.Medium }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: valueDialog.save()
                    }
                }
            }
        }

        function save() {
            var value = valueInput.text.trim()
            if (value.length > 0 && onSave)
                onSave(value)
            accept()
        }

        function openFor(title, current, callback) {
            dialogTitle = title
            onSave = callback
            valueInput.text = current
            open()
            valueInput.forceActiveFocus()
            valueInput.selectAll()
        }
    }

    // Swatch-based picker for the role colors (primary/secondary/success/
    // warning/error/surface/text) — same pattern as the accent color
    // palette, so people pick a color instead of typing a hex code.
    Dialog {
        id: colorPickerDialog
        property string dialogTitle: ""
        property string currentValue: ""
        property var onSave: null   // function(value)

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320; modal: true
        background: Rectangle {
            color: vamifyPage.pageCard; radius: 16
            border { color: vamifyPage.pageBorder; width: 1 }
        }

        header: Item {
            height: 54
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: colorPickerDialog.dialogTitle
                color: vamifyPage.pageText; font { pixelSize: 15; weight: Font.Medium }
            }
        }

        Flow {
            width: parent.width
            leftPadding: 20; rightPadding: 20; bottomPadding: 4
            spacing: 12

            Repeater {
                model: vamifyPage.roleColorPalette
                delegate: Rectangle {
                    id: roleSwatch
                    required property var modelData
                    readonly property bool isSelected:
                        roleSwatch.modelData.value.toLowerCase() === colorPickerDialog.currentValue.toLowerCase()
                    width: 36; height: 36; radius: 18
                    color: modelData.value
                    border.color: vamifyPage.pageBorder
                    border.width: isSelected ? 3 : 1

                    Text {
                        visible: roleSwatch.isSelected
                        anchors.centerIn: parent
                        text: "✓"
                        color: vamifyPage.contrastOn(roleSwatch.modelData.value)
                        font { pixelSize: 13; weight: Font.Bold }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorPickerDialog.choose(roleSwatch.modelData.value)
                    }
                }
            }
        }

        footer: Item {
            implicitHeight: colorDialogFooterRow.implicitHeight + 28
            implicitWidth: colorPickerDialog.width

            RowLayout {
                id: colorDialogFooterRow
                anchors { fill: parent; margins: 14 }
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 80; height: 34; radius: 17; color: "#2a2a2a"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#888"; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: colorPickerDialog.reject() }
                }
            }
        }

        function choose(value) {
            if (onSave) onSave(value)
            accept()
        }

        function openFor(title, current, callback) {
            dialogTitle = title
            currentValue = current
            onSave = callback
            open()
        }
    }

    ScrollView {

        // Kinetic/touch scrolling: rubber-band overshoot + tuned flick
        // feel so dragging with a finger (VamoraFold, touch panels) works
        // like a native scroller, not just mouse-wheel/scrollbar drag.
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.DragAndOvershootBounds
            contentItem.maximumFlickVelocity = 2500
            contentItem.flickDeceleration = 1500
        }
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 18

            VamifyToolbar {}

            ColumnLayout {
                id: pageContent
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 14

                // Main Vamify page: the previews are rendered here, not hidden
                // behind a button or a fake preview row.
                ColumnLayout {
                    visible: vamifyPage.activeSection === "overview"
                    Layout.fillWidth: true
                    spacing: 14

                    SectionHeader { label: "Theme" }

                    Card {
                        implicitHeight: previewContent.implicitHeight + 24
                        content: RowLayout {
                            id: previewContent
                            Layout.margins: 12
                            spacing: 12
                            GnomeToolbarWindow { mode: "light" }
                            GnomeToolbarWindow { mode: "dark" }
                        }
                    }

                    SectionHeader { label: "Other Customizations" }

                    Card {
                        implicitHeight: customizeContent.implicitHeight
                        content: Column {
                            id: customizeContent
                            Layout.fillWidth: true

                            // Order follows what people actually reach for: everyone
                            // touches wallpaper/homescreen/lockscreen/icons; the rest
                            // is opened far less often, so it trails behind.
                            SettingsRow {
                                width: parent.width
                                rowLabel: "General appearance"
                                rowValue: vamifyPage.currentTheme === "light" ? "Light" : "Dark"
                                rowIcon: "palette"
                                tappable: true
                                isFirst: true
                                onTapped: vamifyPage.activeSection = "appearance"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Wallpaper"
                                rowValue: ""
                                rowIcon: "image"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "wallpaper"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Homescreen"
                                rowValue: homescreenGrid
                                rowIcon: "home"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "homescreen"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Lockscreen"
                                rowValue: vamifyPage.lockClockStyle
                                rowIcon: "lock"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "lockscreen"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Icons"
                                rowValue: "Default"
                                rowIcon: "shapes"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "icons"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "AOD / Screensaver"
                                rowValue: "Dummy settings"
                                rowIcon: "moon"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "aod"
                            }
                                                        SettingsRow {
                                width: parent.width
                                rowLabel: "Statusbar"
                                rowValue: "Default"
                                rowIcon: "bell"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "statusbar"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Dock"
                                rowValue: "Default"
                                rowIcon: "panel-bottom"
                                tappable: true
                                isLast: true
                                onTapped: vamifyPage.activeSection = "dock"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Desktops"
                                rowValue: " "
                                rowIcon: "layout-dashboard"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "desktops"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Keyboard"
                                rowValue: vamifyPage.keyboardLayout
                                rowIcon: "settings"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "keyboard"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Windows"
                                rowValue: vamifyPage.wmFocusMode
                                rowIcon: "app-window"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "windows"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Cursor"
                                rowValue: "Dummy settings"
                                rowIcon: "mouse-pointer-2"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "cursor"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Bootloader"
                                rowValue: vamifyPage.bootDefaultEntry
                                rowIcon: "power"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "bootloader"
                            }
                            Text {
                                width: parent.width - 28
                                leftPadding: 14
                                rightPadding: 14
                                topPadding: 12
                                bottomPadding: 12
                                text: "Vamify only works with compatible Vamora apps and Althyn (the Vamora Mobile / Tablet / Desktop environment)."
                                color: pageMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // General appearance: the section people open most, so it gets
                // an actual color palette instead of the generic placeholder.
                ColumnLayout {
                    visible: vamifyPage.activeSection === "appearance"
                    Layout.fillWidth: true
                    spacing: 14

                    SectionHeader { label: "Preview" }

                    // Small live UI preview so theme and accent changes are
                    // immediately visible before choosing a swatch.
                    Card {
                        implicitHeight: appearancePreview.implicitHeight + 24
                        content: Item {
                            id: appearancePreview
                            Layout.fillWidth: true
                            Layout.margins: 12
                            implicitHeight: 190

                            readonly property bool light: vamifyPage.currentTheme === "light"
                            readonly property color previewBg: light ? "#f5f7fb" : "#11141a"
                            readonly property color previewSurface: light ? "#ffffff" : "#1c2028"
                            readonly property color previewSurfaceAlt: light ? "#eef1f6" : "#252a35"
                            readonly property color previewText: light ? "#18202b" : "#f4f6fb"
                            readonly property color previewMuted: light ? "#7b8494" : "#98a1b2"
                            readonly property color accentText: {
                                var luminance = 0.2126 * vamifyPage.accentColor.r
                                               + 0.7152 * vamifyPage.accentColor.g
                                               + 0.0722 * vamifyPage.accentColor.b
                                return luminance > 0.62 ? "#18202b" : "#ffffff"
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 11
                                color: appearancePreview.previewBg
                                border.color: vamifyPage.pageBorder
                                border.width: 1
                                clip: true

                                Rectangle {
                                    id: previewRail
                                    width: 58
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    color: appearancePreview.previewSurface

                                    Rectangle {
                                        anchors { left: parent.left; top: parent.top; topMargin: 16 }
                                        width: 4
                                        height: 34
                                        radius: 2
                                        color: vamifyPage.accentColor
                                    }

                                    Column {
                                        anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                                        spacing: 12

                                        Rectangle {
                                            width: 32; height: 32; radius: 10
                                            color: vamifyPage.accentColor
                                            Text {
                                                anchors.centerIn: parent
                                                text: "V"
                                                color: appearancePreview.accentText
                                                font { pixelSize: 15; weight: Font.Bold }
                                            }
                                        }
                                        Repeater {
                                            model: 3
                                            delegate: Rectangle {
                                                required property int index
                                                width: 30; height: 8; radius: 4
                                                color: index === 0
                                                       ? vamifyPage.accentColor
                                                       : appearancePreview.previewSurfaceAlt
                                                opacity: index === 0 ? 0.9 : 1
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: previewTopBar
                                    anchors {
                                        left: previewRail.right
                                        right: parent.right
                                        top: parent.top
                                        leftMargin: 10
                                        rightMargin: 12
                                        topMargin: 12
                                    }
                                    height: 28
                                    radius: 7
                                    color: appearancePreview.previewSurface

                                    Text {
                                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                        text: "Vamora workspace"
                                        color: appearancePreview.previewMuted
                                        font.pixelSize: 9
                                    }

                                    Row {
                                        anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter }
                                        spacing: 5
                                        Repeater {
                                            model: 3
                                            delegate: Rectangle {
                                                required property int index
                                                width: index === 0 ? 14 : 6
                                                height: 6
                                                radius: height / 2
                                                color: index === 0 ? vamifyPage.accentColor : appearancePreview.previewSurfaceAlt
                                                Behavior on width { NumberAnimation { duration: 150 } }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    anchors {
                                        left: previewRail.right
                                        right: parent.right
                                        top: previewTopBar.bottom
                                        bottom: parent.bottom
                                        leftMargin: 18
                                        rightMargin: 12
                                        topMargin: 10
                                        bottomMargin: 12
                                    }
                                    spacing: 8

                                    Text {
                                        text: "Good evening"
                                        color: appearancePreview.previewText
                                        font { pixelSize: 13; weight: Font.DemiBold }
                                    }

                                    Row {
                                        width: parent.width
                                        height: 54
                                        spacing: 8

                                        Rectangle {
                                            width: Math.max(92, (parent.width - 8) * 0.56)
                                            height: parent.height
                                            radius: 8
                                            color: appearancePreview.previewSurface

                                            Rectangle {
                                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                                width: 4
                                                radius: 2
                                                color: vamifyPage.accentColor
                                            }
                                            Text {
                                                anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 10 }
                                                text: "Focus mode"
                                                color: appearancePreview.previewText
                                                font.pixelSize: 10
                                            }
                                            Text {
                                                anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 9 }
                                                text: "Active now"
                                                color: appearancePreview.previewMuted
                                                font.pixelSize: 8
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width - Math.max(92, (parent.width - 8) * 0.56) - 8
                                            height: parent.height
                                            radius: 8
                                            color: appearancePreview.previewSurface

                                            Text {
                                                anchors { left: parent.left; leftMargin: 10; top: parent.top; topMargin: 10 }
                                                text: "Updates"
                                                color: appearancePreview.previewText
                                                font.pixelSize: 10
                                            }
                                            Rectangle {
                                                anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 10 }
                                                width: 22; height: 12; radius: 6
                                                color: vamifyPage.accentColor
                                                Rectangle {
                                                    width: 8; height: 8; radius: 4
                                                    anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                                                    color: "#ffffff"
                                                }
                                            }
                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                                                height: 4; radius: 2
                                                color: appearancePreview.previewSurfaceAlt
                                                Rectangle {
                                                    width: parent.width * 0.68
                                                    height: parent.height
                                                    radius: 2
                                                    color: vamifyPage.accentColor
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        height: 30
                                        spacing: 8

                                        Rectangle {
                                            width: 76; height: parent.height; radius: height / 2
                                            color: vamifyPage.accentColor
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Apply"
                                                color: appearancePreview.accentText
                                                font { pixelSize: 9; weight: Font.Medium }
                                            }
                                        }
                                        Rectangle {
                                            width: 76; height: parent.height; radius: height / 2
                                            color: appearancePreview.previewSurfaceAlt
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Preview"
                                                color: appearancePreview.previewText
                                                font.pixelSize: 9
                                            }
                                        }
                                        Item { width: 1; height: 1 }
                                    }
                                }
                            }
                        }
                    }
                    SectionHeader { label: "Customize" }
                    Card {
                        implicitHeight: paletteContent.implicitHeight + 24
                        content: Column {
                            id: paletteContent
                            Layout.fillWidth: true
                            Layout.margins: 16
                            spacing: 12

                            Text {
                                text: "Accent color"
                                color: pageMuted
                                font { pixelSize: 11; weight: Font.Medium }
                            }

                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: vamifyPage.accentOptions
                                    delegate: Rectangle {
                                        id: swatch
                                        required property var modelData
                                        readonly property bool isSelected: vamifyPage.accentColor === modelData.value
                                        width: 40; height: 40; radius: 20
                                        color: modelData.value
                                        border.color: "#3b82f6"
                                        border.width: isSelected ? 3 : 0

                                        // A colored ring alone can be lost against a
                                        // similarly colored swatch (e.g. the blue one),
                                        // so a white check mark always shows through.
                                        Text {
                                            visible: swatch.isSelected
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: "#ffffff"
                                            font { pixelSize: 14; weight: Font.Bold }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: vamifyPage.setAccent(swatch.modelData.value)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Card {
                        implicitHeight: appearanceMore.implicitHeight
                        content: Column {
                            id: appearanceMore
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width; rowLabel: "Primary color"; rowValue: vamifyPage.primaryColor; rowIcon: "palette"
                                tappable: true; isFirst: true
                                onTapped: colorPickerDialog.openFor("Primary color", vamifyPage.primaryColor, function(v) { vamifyPage.setStringSetting("appearance.primary_color", "primaryColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Secondary color"; rowValue: vamifyPage.secondaryColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Secondary color", vamifyPage.secondaryColor, function(v) { vamifyPage.setStringSetting("appearance.secondary_color", "secondaryColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Success color"; rowValue: vamifyPage.successColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Success color", vamifyPage.successColor, function(v) { vamifyPage.setStringSetting("appearance.success_color", "successColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Warning color"; rowValue: vamifyPage.warningColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Warning color", vamifyPage.warningColor, function(v) { vamifyPage.setStringSetting("appearance.warning_color", "warningColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Error color"; rowValue: vamifyPage.errorColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Error color", vamifyPage.errorColor, function(v) { vamifyPage.setStringSetting("appearance.error_color", "errorColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Surface color"; rowValue: vamifyPage.surfaceColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Surface color", vamifyPage.surfaceColor, function(v) { vamifyPage.setStringSetting("appearance.surface_color", "surfaceColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Text color"; rowValue: vamifyPage.textColor; rowIcon: "palette"
                                tappable: true
                                onTapped: colorPickerDialog.openFor("Text color", vamifyPage.textColor, function(v) { vamifyPage.setStringSetting("appearance.text_color", "textColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Font size"; rowValue: vamifyPage.fontSize; rowIcon: "sliders-horizontal"
                                tappable: true
                                onTapped: valueDialog.openFor("Font size", vamifyPage.fontSize, function(v) { vamifyPage.setStringSetting("appearance.font_size", "fontSize", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Icon theme"; rowValue: vamifyPage.iconThemeName; rowIcon: "shapes"
                                tappable: true; isLast: true
                                onTapped: valueDialog.openFor("Icon theme", vamifyPage.iconThemeName, function(v) { vamifyPage.setStringSetting("appearance.icon_theme", "iconThemeName", v) })
                            }
                        }
                    }
                }

                // Wallpaper: second-most-touched section, gets a real thumbnail
                // preview instead of the generic placeholder card.
                ColumnLayout {
                    visible: vamifyPage.activeSection === "wallpaper"
                    Layout.fillWidth: true
                    spacing: 14

                    Text { text: "Wallpaper"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy wallpaper customization settings."; color: pageMuted; font.pixelSize: 12 }

                    Card {
                        implicitHeight: 150
                        content: Item {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            implicitHeight: 138
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                clip: true
                                color: "#111111"
                                Image {
                                    anchors.fill: parent
                                    source: "qrc:/assets/vamify-wallpaper.svg"
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                        }
                    }

                    Card {
                        implicitHeight: wallpaperColumn.implicitHeight
                        content: Column {
                            id: wallpaperColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Change wallpaper"; rowValue: ""; rowIcon: "image"; tappable: true; isFirst: true }
                            SettingsRow { width: parent.width; rowLabel: "Fit"; rowValue: "Fill"; rowIcon: "maximize"; tappable: true; isLast: true }
                        }
                    }
                }

                // Windows
                ColumnLayout {
                    visible: vamifyPage.activeSection === "windows"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Windows"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure window behavior. \"Rounded corners\", \"Window shadows\", \"Snap assist\", and the corner radius/gap sliders aren't real VamoraSys settings yet, so they stay local to this page."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: windowsToggles.implicitHeight
                        content: Column {
                            id: windowsToggles
                            Layout.fillWidth: true
                            ToggleRow { width: parent.width; rowLabel: "Rounded corners"; on_: vamifyPage.windowsRounded; isFirst: true; onToggled: function(v) { vamifyPage.windowsRounded = v } }
                            ToggleRow { width: parent.width; rowLabel: "Window shadows"; on_: vamifyPage.windowsShadows; onToggled: function(v) { vamifyPage.windowsShadows = v } }
                            ToggleRow { width: parent.width; rowLabel: "Snap assist"; rowSub: "Drag windows to screen edges to tile"; on_: vamifyPage.windowsSnap; onToggled: function(v) { vamifyPage.windowsSnap = v } }
                        }
                    }

                    LabeledSlider {
                        label: "Corner radius"; valueText: Math.round(vamifyPage.windowsCornerPx) + "px"
                        value: vamifyPage.windowsCornerPx; fromVal: 0; toVal: 24; stepVal: 1
                        enabled: vamifyPage.windowsRounded; opacity: vamifyPage.windowsRounded ? 1 : 0.4
                        onMoved: function(v) { vamifyPage.windowsCornerPx = v }
                    }
                    LabeledSlider {
                        label: "Gap size"; valueText: Math.round(vamifyPage.windowsGapPx) + "px"
                        value: vamifyPage.windowsGapPx; fromVal: 0; toVal: 32; stepVal: 1
                        onMoved: function(v) { vamifyPage.windowsGapPx = v }
                    }

                    Card {
                        implicitHeight: wmMore.implicitHeight
                        content: Column {
                            id: wmMore
                            Layout.fillWidth: true
                            ToggleRow {
                                width: parent.width; rowLabel: "Animations"; on_: vamifyPage.wmAnimations; isFirst: true
                                onToggled: function(v) { vamifyPage.setBoolSetting("wm.animations", "wmAnimations", v) }
                            }
                            ToggleRow {
                                width: parent.width; rowLabel: "Transparency"; on_: vamifyPage.wmTransparency
                                onToggled: function(v) { vamifyPage.setBoolSetting("wm.transparency", "wmTransparency", v) }
                            }
                            ToggleRow {
                                width: parent.width; rowLabel: "Window effects"; on_: vamifyPage.wmWindowEffects
                                onToggled: function(v) { vamifyPage.setBoolSetting("wm.window_effects", "wmWindowEffects", v) }
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Focus mode"; rowValue: vamifyPage.wmFocusMode; rowIcon: "app-window"
                                tappable: true; isLast: true
                                onTapped: {
                                    var next = vamifyPage.wmFocusMode === "click" ? "hover" : "click"
                                    vamifyPage.setStringSetting("wm.focus_mode", "wmFocusMode", next)
                                }
                            }
                        }
                    }
                }

                // Cursor
                ColumnLayout {
                    visible: vamifyPage.activeSection === "cursor"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Cursor"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy cursor settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: cursorColumn.implicitHeight
                        content: Column {
                            id: cursorColumn
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Cursor theme"; rowValue: vamifyPage.cursorTheme; rowIcon: "mouse-pointer-2"
                                tappable: true; isFirst: true
                                onTapped: vamifyPage.cycleCursorTheme()
                            }
                            ToggleRow { width: parent.width; rowLabel: "Cursor trail"; rowSub: "Show a fading trail while moving"; on_: vamifyPage.cursorTrail; onToggled: function(v) { vamifyPage.cursorTrail = v } }
                            ToggleRow { width: parent.width; rowLabel: "Larger click target"; on_: vamifyPage.cursorLargeClick; onToggled: function(v) { vamifyPage.cursorLargeClick = v } }
                        }
                    }

                    LabeledSlider {
                        label: "Cursor size"; valueText: Math.round(vamifyPage.cursorSizePct * 100) + "%"
                        value: vamifyPage.cursorSizePct; fromVal: 0.5; toVal: 2.0; stepVal: 0.05
                        onMoved: function(v) { vamifyPage.cursorSizePct = v }
                    }
                }

                // AOD / Screensaver
                ColumnLayout {
                    visible: vamifyPage.activeSection === "aod"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "AOD / Screensaver"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy AOD and screensaver settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: aodToggles.implicitHeight
                        content: Column {
                            id: aodToggles
                            Layout.fillWidth: true
                            ToggleRow { width: parent.width; rowLabel: "Always-on display"; rowSub: "Show clock and status while locked"; on_: vamifyPage.aodEnabled; isFirst: true; onToggled: function(v) { vamifyPage.aodEnabled = v } }
                            ToggleRow { width: parent.width; rowLabel: "Screensaver on idle"; on_: vamifyPage.screensaverEnabled; onToggled: function(v) { vamifyPage.screensaverEnabled = v } }
                        }
                    }

                    LabeledSlider {
                        visible: vamifyPage.aodEnabled
                        label: "AOD brightness"; valueText: Math.round(vamifyPage.aodBrightnessPct * 100) + "%"
                        value: vamifyPage.aodBrightnessPct; fromVal: 0; toVal: 1; stepVal: 0.05
                        onMoved: function(v) { vamifyPage.aodBrightnessPct = v }
                    }
                    LabeledSlider {
                        visible: vamifyPage.screensaverEnabled
                        label: "Idle timeout"; valueText: Math.round(vamifyPage.idleTimeoutMin) + " min"
                        value: vamifyPage.idleTimeoutMin; fromVal: 1; toVal: 30; stepVal: 1
                        onMoved: function(v) { vamifyPage.idleTimeoutMin = v }
                    }
                }

                // Bootloader
                ColumnLayout {
                    visible: vamifyPage.activeSection === "bootloader"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Bootloader"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure the bootloader. \"Show boot menu\" and \"Boot animation\" aren't real VamoraSys settings yet, so they stay local to this page."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: bootToggles.implicitHeight
                        content: Column {
                            id: bootToggles
                            Layout.fillWidth: true
                            ToggleRow { width: parent.width; rowLabel: "Show boot menu"; on_: vamifyPage.bootMenuEnabled; isFirst: true; onToggled: function(v) { vamifyPage.bootMenuEnabled = v } }
                            ToggleRow { width: parent.width; rowLabel: "Boot animation"; on_: vamifyPage.bootAnimEnabled; onToggled: function(v) { vamifyPage.bootAnimEnabled = v } }
                            SettingsRow {
                                width: parent.width; rowLabel: "Default entry"; rowValue: vamifyPage.bootDefaultEntry; rowIcon: "power"
                                tappable: true; isLast: true
                                onTapped: valueDialog.openFor("Default boot entry", vamifyPage.bootDefaultEntry, function(v) { vamifyPage.setStringSetting("bootloader.default_entry", "bootDefaultEntry", v) })
                            }
                        }
                    }

                    LabeledSlider {
                        visible: vamifyPage.bootMenuEnabled
                        label: "Menu timeout"; valueText: Math.round(vamifyPage.bootTimeoutSec) + " s"
                        value: vamifyPage.bootTimeoutSec; fromVal: 0; toVal: 30; stepVal: 1
                        onMoved: function(v) { vamifyPage.setNumberSetting("bootloader.timeout", "bootTimeoutSec", v) }
                    }
                }

                // Desktops
                ColumnLayout {
                    visible: vamifyPage.activeSection === "desktops"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Desktops"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy virtual desktop settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: desktopsToggles.implicitHeight
                        content: Column {
                            id: desktopsToggles
                            Layout.fillWidth: true
                            ToggleRow { width: parent.width; rowLabel: "Wrap around"; rowSub: "Looping from last desktop back to first"; on_: vamifyPage.desktopsWrap; isFirst: true; onToggled: function(v) { vamifyPage.desktopsWrap = v } }
                            ToggleRow { width: parent.width; rowLabel: "Show indicator in dock"; on_: vamifyPage.desktopsIndicator; onToggled: function(v) { vamifyPage.desktopsIndicator = v } }
                        }
                    }

                    LabeledSlider {
                        label: "Number of desktops"; valueText: Math.round(vamifyPage.desktopsCount).toString()
                        value: vamifyPage.desktopsCount; fromVal: 1; toVal: 8; stepVal: 1
                        onMoved: function(v) { vamifyPage.desktopsCount = v }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "homescreen"
                    Layout.fillWidth: true
                    spacing: 14

                    Text { text: "Homescreen"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure the homescreen layout."; color: pageMuted; font.pixelSize: 12 }

                    Card {
                        implicitHeight: gridColumn.implicitHeight
                        content: ColumnLayout {
                            id: gridColumn
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Grid size"
                                rowValue: homescreenGrid
                                rowIcon: "home"
                                tappable: true
                                isFirst: true
                                onTapped: valueDialog.openFor("Grid size", homescreenGrid, function(value) { setGrid(value) })
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Icon size"
                                rowValue: homescreenIconSize
                                rowIcon: "shapes"
                                tappable: true
                                onTapped: valueDialog.openFor("Icon size", homescreenIconSize, function(value) { setIconSize(value) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Layout"; rowValue: vamifyPage.homescreenLayout; rowIcon: "layout-dashboard"
                                tappable: true
                                onTapped: valueDialog.openFor("Layout", vamifyPage.homescreenLayout, function(v) { vamifyPage.setStringSetting("homescreen.layout", "homescreenLayout", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Wallpaper"; rowValue: vamifyPage.homescreenWallpaper; rowIcon: "image"
                                tappable: true
                                onTapped: valueDialog.openFor("Wallpaper", vamifyPage.homescreenWallpaper, function(v) { vamifyPage.setStringSetting("homescreen.wallpaper", "homescreenWallpaper", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Widgets"; rowValue: vamifyPage.homescreenWidgets; rowIcon: "layout-dashboard"
                                tappable: true; isLast: true
                                onTapped: valueDialog.openFor("Widgets", vamifyPage.homescreenWidgets, function(v) { vamifyPage.setStringSetting("homescreen.widgets", "homescreenWidgets", v) })
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "lockscreen"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Lockscreen"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure the lockscreen."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: lockscreenColumn.implicitHeight
                        content: Column {
                            id: lockscreenColumn
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width; rowLabel: "Clock style"; rowValue: vamifyPage.lockClockStyle; rowIcon: "clock"
                                tappable: true; isFirst: true
                                onTapped: {
                                    var next = vamifyPage.lockClockStyle === "digital" ? "analog" : "digital"
                                    vamifyPage.setStringSetting("lockscreen.clock_style", "lockClockStyle", next)
                                }
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Wallpaper"; rowValue: vamifyPage.lockWallpaper; rowIcon: "image"
                                tappable: true
                                onTapped: valueDialog.openFor("Lockscreen wallpaper", vamifyPage.lockWallpaper, function(v) { vamifyPage.setStringSetting("lockscreen.wallpaper", "lockWallpaper", v) })
                            }
                        }
                    }
                    Card {
                        implicitHeight: lockscreenToggles.implicitHeight
                        content: Column {
                            id: lockscreenToggles
                            Layout.fillWidth: true
                            ToggleRow {
                                width: parent.width; rowLabel: "Show date"; on_: vamifyPage.lockShowDate; isFirst: true
                                onToggled: function(v) { vamifyPage.setBoolSetting("lockscreen.show_date", "lockShowDate", v) }
                            }
                            ToggleRow {
                                width: parent.width; rowLabel: "Show notifications"; on_: vamifyPage.lockShowNotifications
                                onToggled: function(v) { vamifyPage.setBoolSetting("lockscreen.show_notifications", "lockShowNotifications", v) }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "icons"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Configure icon appearance. The preview above and its size/color swatches stay local to this page; \"Background color\", \"Style\", \"Stroke color\", \"Stroke\" and \"Corner radius\" below are the real VamoraSys settings."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    // Live preview: same wallpaper crop used elsewhere in Vamify,
                    // with a row of real icons reacting to the size/radius controls
                    // below so the sliders feel connected to something.
                    Card {
                        implicitHeight: 210
                        content: Item {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            implicitHeight: 186

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                clip: true
                                color: "#111111"

                                Image {
                                    anchors.fill: parent
                                    source: "qrc:/assets/vamify-wallpaper.svg"
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 26

                                    Repeater {
                                        model: vamifyPage.iconPreviewApps
                                        delegate: Column {
                                            required property var modelData
                                            spacing: 8

                                            Item {
                                                width: 72 * vamifyPage.iconSizePct
                                                height: 72 * vamifyPage.iconSizePct
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Image {
                                                    id: previewIconImg
                                                    anchors.fill: parent
                                                    source: "../assets/icons/" + modelData.icon + ".png"
                                                    sourceSize: Qt.size(144, 144)
                                                    smooth: true
                                                    visible: false
                                                }
                                                Rectangle {
                                                    id: previewIconMask
                                                    anchors.fill: parent
                                                    radius: Math.min(vamifyPage.iconsCornerRadius, width / 2)
                                                    visible: false
                                                }
                                                OpacityMask {
                                                    anchors.fill: parent
                                                    source: previewIconImg
                                                    maskSource: previewIconMask
                                                }
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.name
                                                color: "#ffffff"
                                                font { pixelSize: 11; weight: Font.Medium }
                                                style: Text.Outline
                                                styleColor: Qt.rgba(0, 0, 0, 0.45)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Color
                    Text { text: "Color"; color: pageText; font { pixelSize: 13; weight: Font.Medium } }
                    Row {
                        spacing: 12
                        Repeater {
                            model: vamifyPage.iconColorOptions
                            delegate: Rectangle {
                                id: iconSwatch
                                required property var modelData
                                readonly property bool isSelected: vamifyPage.iconColor === modelData.value
                                width: 38; height: 38; radius: 19
                                border.color: "#ffffff"
                                border.width: isSelected ? 3 : 0

                                gradient: modelData.value === "rainbow" ? rainbowGradient : null
                                color: modelData.value === "rainbow" ? "transparent" : modelData.value

                                Gradient {
                                    id: rainbowGradient
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0;  color: "#ef4444" }
                                    GradientStop { position: 0.17; color: "#f97316" }
                                    GradientStop { position: 0.34; color: "#eab308" }
                                    GradientStop { position: 0.5;  color: "#22c55e" }
                                    GradientStop { position: 0.67; color: "#06b6d4" }
                                    GradientStop { position: 0.84; color: "#3b82f6" }
                                    GradientStop { position: 1.0;  color: "#a855f7" }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: vamifyPage.iconColor = iconSwatch.modelData.value
                                }
                            }
                        }
                    }

                    // Icon size
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Icon Size"; color: pageText; font.pixelSize: 13; Layout.fillWidth: true }
                            Text { text: Math.round(vamifyPage.iconSizePct * 100) + "%"; color: pageMuted; font.pixelSize: 12 }
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0.5; to: 1.5; stepSize: 0.05
                            value: vamifyPage.iconSizePct
                            onMoved: vamifyPage.iconSizePct = value
                        }
                    }

                    // Corner radius
                    LabeledSlider {
                        label: "Corner radius"
                        valueText: Math.round(vamifyPage.iconsCornerRadius) + "px"
                        value: vamifyPage.iconsCornerRadius
                        fromVal: 0
                        toVal: 36
                        stepVal: 1
                        onMoved: function(v) {
                            vamifyPage.setNumberSetting(
                                "icons.corner_radius",
                                "iconsCornerRadius",
                                v
                            )
                        }
                    }

                    Card {
                        implicitHeight: iconsMore.implicitHeight
                        content: Column {
                            id: iconsMore
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width; rowLabel: "Background color"; rowValue: vamifyPage.iconsBgColor; rowIcon: "palette"
                                tappable: true; isFirst: true
                                onTapped: valueDialog.openFor("Icon background color", vamifyPage.iconsBgColor, function(v) { vamifyPage.setStringSetting("icons.bg_color", "iconsBgColor", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Style"; rowValue: vamifyPage.iconsStyle; rowIcon: "shapes"
                                tappable: true
                                onTapped: valueDialog.openFor("Icon style", vamifyPage.iconsStyle, function(v) { vamifyPage.setStringSetting("icons.style", "iconsStyle", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Stroke color"; rowValue: vamifyPage.iconsStrokeColor; rowIcon: "palette"
                                tappable: true
                                onTapped: valueDialog.openFor("Icon stroke color", vamifyPage.iconsStrokeColor, function(v) { vamifyPage.setStringSetting("icons.stroke_color", "iconsStrokeColor", v) })
                            }
                            ToggleRow {
                                width: parent.width; rowLabel: "Stroke"; rowSub: "Outline icons instead of filling them"; on_: vamifyPage.iconsStroke
                                onToggled: function(v) { vamifyPage.setBoolSetting("icons.stroke", "iconsStroke", v) }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "statusbar"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Statusbar"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure the statusbar."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: statusbarColumn.implicitHeight
                        content: Column {
                            id: statusbarColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Show status icons"; rowValue: "On"; rowIcon: "bell"; tappable: true; isFirst: true }
                            SettingsRow { width: parent.width; rowLabel: "Battery style"; rowValue: "Icon"; rowIcon: "battery-full"; tappable: true }
                            ToggleRow {
                                width: parent.width; rowLabel: "Transparency"; on_: vamifyPage.statusbarTransparency
                                onToggled: function(v) { vamifyPage.setBoolSetting("statusbar.transparency", "statusbarTransparency", v) }
                            }
                        }
                    }
                    LabeledSlider {
                        label: "Statusbar size"; valueText: Math.round(vamifyPage.statusbarSize) + "px"
                        value: vamifyPage.statusbarSize; fromVal: 20; toVal: 48; stepVal: 1
                        onMoved: function(v) { vamifyPage.setNumberSetting("statusbar.size", "statusbarSize", v) }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "dock"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Dock"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure the dock."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: dockColumn.implicitHeight
                        content: Column {
                            id: dockColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Show dock"; rowValue: "On"; rowIcon: "panel-bottom"; tappable: true; isFirst: true }
                            SettingsRow { width: parent.width; rowLabel: "Dock size"; rowValue: "Medium"; rowIcon: "sliders-horizontal"; tappable: true }
                            SettingsRow {
                                width: parent.width; rowLabel: "Position"; rowValue: vamifyPage.dockPosition; rowIcon: "panel-bottom"
                                tappable: true; isLast: true
                                onTapped: {
                                    var order = ["bottom", "left", "right"]
                                    var next = order[(order.indexOf(vamifyPage.dockPosition) + 1) % order.length]
                                    vamifyPage.setStringSetting("dock.position", "dockPosition", next)
                                }
                            }
                        }
                    }
                }

                // Keyboard — layout, model and options, not represented
                // anywhere else in Settings.
                ColumnLayout {
                    visible: vamifyPage.activeSection === "keyboard"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Keyboard"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Configure keyboard layout and model."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: keyboardColumn.implicitHeight
                        content: Column {
                            id: keyboardColumn
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width; rowLabel: "Layout"; rowValue: vamifyPage.keyboardLayout; rowIcon: "settings"
                                tappable: true; isFirst: true
                                onTapped: valueDialog.openFor("Keyboard layout", vamifyPage.keyboardLayout, function(v) { vamifyPage.setStringSetting("keyboard.layout", "keyboardLayout", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Layouts"; rowValue: vamifyPage.keyboardLayouts; rowIcon: "settings"
                                tappable: true
                                onTapped: valueDialog.openFor("Keyboard layouts (comma-separated)", vamifyPage.keyboardLayouts, function(v) { vamifyPage.setStringSetting("keyboard.layouts", "keyboardLayouts", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Model"; rowValue: vamifyPage.keyboardModel; rowIcon: "settings"
                                tappable: true
                                onTapped: valueDialog.openFor("Keyboard model", vamifyPage.keyboardModel, function(v) { vamifyPage.setStringSetting("keyboard.model", "keyboardModel", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Variant"; rowValue: vamifyPage.keyboardVariant; rowIcon: "settings"
                                tappable: true
                                onTapped: valueDialog.openFor("Keyboard variant", vamifyPage.keyboardVariant, function(v) { vamifyPage.setStringSetting("keyboard.variant", "keyboardVariant", v) })
                            }
                            SettingsRow {
                                width: parent.width; rowLabel: "Options"; rowValue: vamifyPage.keyboardOptions; rowIcon: "settings"
                                tappable: true; isLast: true
                                onTapped: valueDialog.openFor("Keyboard options", vamifyPage.keyboardOptions, function(v) { vamifyPage.setStringSetting("keyboard.options", "keyboardOptions", v) })
                            }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }

    Rectangle {
        id: unavailableOverlay
        z: 50
        anchors.fill: parent
        visible: !vamifyPage.vamoraSysAvailable
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ForbiddenCursor
            onClicked: vamifyPage.warningAttention = true
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 86
                leftMargin: 28
                rightMargin: 28
            }
            radius: 12
            color: vamifyPage.warningAttention ? "#ffd8d8" : "#fff0f0"
            border.color: "#d63636"
            border.width: vamifyPage.warningAttention ? 2 : 1
            implicitHeight: warningText.implicitHeight + 28

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.width { NumberAnimation { duration: 120 } }

            Text {
                id: warningText
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                text: "VamoraSys is not installed and Vamify wouldn't work. Vamify settings are unavailable until VamoraSys is installed."
                color: "#a51d2d"
                font { pixelSize: 13; weight: Font.DemiBold }
                wrapMode: Text.WordWrap
            }
        }
    }
}