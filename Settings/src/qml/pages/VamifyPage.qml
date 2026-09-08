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
    property string accentColor: "#3b82f6"
    property string iconColor: "rainbow"
    property real iconSizePct: 1.0
    property real iconCornerPx: 20
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

    readonly property var iconPreviewApps: [
        { name: "Contacts", icon: "appicons/contacts" },
        { name: "Files",    icon: "appicons/files" },
        { name: "Gallery",  icon: "appicons/gallery" },
        { name: "Camera",   icon: "appicons/camera" }
    ]
    readonly property var accentOptions: [
        { name: "Blue",   value: "#3b82f6" },
        { name: "Purple", value: "#8b5cf6" },
        { name: "Pink",   value: "#ec4899" },
        { name: "Red",    value: "#ef4444" },
        { name: "Orange", value: "#f97316" },
        { name: "Yellow", value: "#eab308" },
        { name: "Green",  value: "#22c55e" },
        { name: "Teal",   value: "#14b8a6" }
    ]
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
            dock: "Dock"
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
            if (vamifyPage.activeSection === "homescreen")
                vamifyPage.refreshGrid()
        }
    }

    Component.onCompleted: {
        refreshTheme()
        refreshGrid()
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
        border.color: previewWindow.selected ? "#3b82f6" : "transparent"
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
            color: "#3b82f6"
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
        // On narrow/mobile windows the app-level breadcrumb in main.qml
        // ("Settings › Vamify › Icons") already shows this page's title
        // and handles back navigation, so this in-page toolbar would just
        // duplicate it. Only render it in the wide desktop layout.
        readonly property bool showHere: !vamifyPage.settingsWindow || !vamifyPage.settingsWindow.isMobile
        Layout.fillWidth: true
        height: showHere ? 48 : 0
        visible: showHere
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Item {
                Layout.preferredWidth: 26
                Layout.fillHeight: true
                visible: vamifyPage.activeSection !== "overview"

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: pageText
                    font.pixelSize: 30
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: vamifyPage.activeSection = "overview"
                }
            }

            Text {
                text: vamifyPage.activeSection === "overview" ? "Vamify" : vamifyPage.activeSection.charAt(0).toUpperCase() + vamifyPage.activeSection.slice(1)
                color: pageText
                font { pixelSize: 22; weight: Font.DemiBold }
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
        Slider {
            Layout.fillWidth: true
            from: ls.fromVal; to: ls.toVal; stepSize: ls.stepVal
            value: ls.value
            onMoved: ls.moved(value)
            background: Rectangle {
                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 4
                width: parent.availableWidth; height: 8; radius: 4; color: "#2c2c2c"
                Rectangle { width: parent.parent.visualPosition * parent.width; height: 8; radius: 4; color: "#3b82f6" }
            }
            handle: Rectangle {
                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - 22)
                y: parent.topPadding + parent.availableHeight / 2 - 11
                width: 22; height: 22; radius: 11; color: "#ffffff"
                border { color: "#3b82f6"; width: 2 }
            }
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
            spacing: 0

            Item { height: 20 }
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

                    SectionHeader { label: "Preview" }
                    Text {
                        text: "The blue outline and check mark show which mode is active right now."
                        color: pageMuted
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

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

                    SectionHeader { label: "Customize" }

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
                                rowValue: "Dummy settings"
                                rowIcon: "palette"
                                tappable: true
                                isFirst: true
                                onTapped: vamifyPage.activeSection = "appearance"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Wallpaper"
                                rowValue: "Dummy settings"
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
                                rowValue: "Dummy settings"
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
                                rowLabel: "Windows"
                                rowValue: "Dummy settings"
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
                                rowLabel: "AOD / Screensaver"
                                rowValue: "Dummy settings"
                                rowIcon: "moon"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "aod"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Bootloader"
                                rowValue: "Dummy settings"
                                rowIcon: "power"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "bootloader"
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Desktops"
                                rowValue: "Dummy settings"
                                rowIcon: "layout-dashboard"
                                tappable: true
                                onTapped: vamifyPage.activeSection = "desktops"
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

                            Text {
                                width: parent.width - 28
                                leftPadding: 14
                                rightPadding: 14
                                topPadding: 12
                                bottomPadding: 12
                                text: "Vamify only works with compatible Vamora apps and Althyn, the Vamora Mobile / Tablet / Desktop environment."
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

                    Text { text: "General appearance"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Pick the accent color used across VamoraOS."; color: pageMuted; font.pixelSize: 12 }

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
                                            onClicked: vamifyPage.accentColor = swatch.modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        implicitHeight: appearanceExtras.implicitHeight
                        content: Column {
                            id: appearanceExtras
                            Layout.fillWidth: true
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Enable customization"
                                rowValue: "On"
                                rowIcon: "check"
                                tappable: true
                                isFirst: true
                            }
                            SettingsRow {
                                width: parent.width
                                rowLabel: "Style"
                                rowValue: "Default"
                                rowIcon: "sliders-horizontal"
                                tappable: true
                                isLast: true
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
                    Text { text: "Dummy window appearance settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

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
                    Text { text: "Dummy bootloader settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                    Card {
                        implicitHeight: bootToggles.implicitHeight
                        content: Column {
                            id: bootToggles
                            Layout.fillWidth: true
                            ToggleRow { width: parent.width; rowLabel: "Show boot menu"; on_: vamifyPage.bootMenuEnabled; isFirst: true; onToggled: function(v) { vamifyPage.bootMenuEnabled = v } }
                            ToggleRow { width: parent.width; rowLabel: "Boot animation"; on_: vamifyPage.bootAnimEnabled; onToggled: function(v) { vamifyPage.bootAnimEnabled = v } }
                        }
                    }

                    LabeledSlider {
                        visible: vamifyPage.bootMenuEnabled
                        label: "Menu timeout"; valueText: Math.round(vamifyPage.bootTimeoutSec) + " s"
                        value: vamifyPage.bootTimeoutSec; fromVal: 0; toVal: 30; stepVal: 1
                        onMoved: function(v) { vamifyPage.bootTimeoutSec = v }
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
                                isLast: true
                                onTapped: {
                                    if (homescreenGrid === "13x6") setGrid("12x6")
                                    else if (homescreenGrid === "12x6") setGrid("10x5")
                                    else setGrid("13x6")
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "lockscreen"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Lockscreen"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy lockscreen customization settings."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: lockscreenColumn.implicitHeight
                        content: Column {
                            id: lockscreenColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Clock style"; rowValue: "Digital"; rowIcon: "clock"; tappable: true; isFirst: true; onTapped: rowValue = rowValue === "Digital" ? "Analog" : "Digital" }
                            SettingsRow { width: parent.width; rowLabel: "Wallpaper"; rowValue: "System default"; rowIcon: "image"; tappable: true; isLast: true }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "icons"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Icons"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy icon appearance settings — not wired up to VamoraSys yet."; color: pageMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

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
                                                    radius: Math.min(vamifyPage.iconCornerPx, width / 2)
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
                        Slider {
                            Layout.fillWidth: true
                            from: 0.5; to: 1.5; stepSize: 0.05
                            value: vamifyPage.iconSizePct
                            onMoved: vamifyPage.iconSizePct = value
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 4
                                width: parent.availableWidth; height: 8; radius: 4; color: "#2c2c2c"
                                Rectangle { width: parent.parent.visualPosition * parent.width; height: 8; radius: 4; color: "#3b82f6" }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - 22)
                                y: parent.topPadding + parent.availableHeight / 2 - 11
                                width: 22; height: 22; radius: 11; color: "#ffffff"
                                border { color: "#3b82f6"; width: 2 }
                            }
                        }
                    }

                    // Corner radius
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Corner radius"; color: pageText; font.pixelSize: 13; Layout.fillWidth: true }
                            Text { text: Math.round(vamifyPage.iconCornerPx) + "px"; color: pageMuted; font.pixelSize: 12 }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 0; to: 36; stepSize: 1
                            value: vamifyPage.iconCornerPx
                            onMoved: vamifyPage.iconCornerPx = value
                            background: Rectangle {
                                x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 4
                                width: parent.availableWidth; height: 8; radius: 4; color: "#2c2c2c"
                                Rectangle { width: parent.parent.visualPosition * parent.width; height: 8; radius: 4; color: "#3b82f6" }
                            }
                            handle: Rectangle {
                                x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - 22)
                                y: parent.topPadding + parent.availableHeight / 2 - 11
                                width: 22; height: 22; radius: 11; color: "#ffffff"
                                border { color: "#3b82f6"; width: 2 }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "statusbar"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Statusbar"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy statusbar appearance settings."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: statusbarColumn.implicitHeight
                        content: Column {
                            id: statusbarColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Show status icons"; rowValue: "On"; rowIcon: "bell"; tappable: true; isFirst: true }
                            SettingsRow { width: parent.width; rowLabel: "Battery style"; rowValue: "Icon"; rowIcon: "battery-full"; tappable: true; isLast: true }
                        }
                    }
                }

                ColumnLayout {
                    visible: vamifyPage.activeSection === "dock"
                    Layout.fillWidth: true
                    spacing: 14
                    Text { text: "Dock"; color: pageText; font { pixelSize: 15; weight: Font.DemiBold } }
                    Text { text: "Dummy dock appearance settings."; color: pageMuted; font.pixelSize: 12 }
                    Card {
                        implicitHeight: dockColumn.implicitHeight
                        content: Column {
                            id: dockColumn
                            Layout.fillWidth: true
                            SettingsRow { width: parent.width; rowLabel: "Show dock"; rowValue: "On"; rowIcon: "panel-bottom"; tappable: true; isFirst: true }
                            SettingsRow { width: parent.width; rowLabel: "Dock size"; rowValue: "Medium"; rowIcon: "sliders-horizontal"; tappable: true; isLast: true }
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