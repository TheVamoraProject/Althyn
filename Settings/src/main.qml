import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import dev.vamoraos.SysInfo 1.0

ApplicationWindow {
    id: root
    visible: true
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"
    minimumWidth: 360
    minimumHeight: 540
    width: 1020
    height: 700
    title: "Settings"

    readonly property bool isMobile: width < 700
    readonly property int chromeHeight: 46
    readonly property bool windowIsMaximized: visibility === Window.Maximized
    readonly property int resizeMargin: 7
    font.family: "Inter, Segoe UI, system-ui, sans-serif"

    // Path to icon svgs, relative to this file. The overlay recolors the same
    // SVG assets so they remain legible in both light and dark mode.
    property string iconBase: "./assets/icons/"

    // ── Palette ────────────────────────────────────────────────────────────
    // Keep the shell on Vamora's zinc scale: true black/white surfaces, a
    // quiet blue accent, and no competing saturated colors.
    property string appearanceTheme: {
        var value = SysInfo.getAppearanceTheme()
        return value === "light" || value === "dark" ? value : "dark"
    }
    readonly property bool darkTheme: appearanceTheme !== "light"
    readonly property color bgPrimary:    darkTheme ? "#000000" : "#fafafa"
    readonly property color bgSurface:    darkTheme ? "#18181b" : "#ffffff"
    readonly property color bgCard:       darkTheme ? "#27272a" : "#f4f4f5"
    readonly property color bgCardHover:  darkTheme ? "#3f3f46" : "#e4e4e7"
    readonly property color borderColor:  darkTheme ? "#27272a" : "#e4e4e7"
    readonly property color txtPrimary:   darkTheme ? "#f4f4f5" : "#18181b"
    readonly property color txtSecondary: darkTheme ? "#a1a1aa" : "#71717a"
    readonly property color txtMuted:     darkTheme ? "#71717a" : "#a1a1aa"
    readonly property color accentColor:   "#7dd3fc"

    background: Rectangle {
        radius: root.windowIsMaximized ? 0 : 18
        color: root.bgPrimary
        border.color: root.borderColor
        border.width: root.windowIsMaximized ? 0 : 1
    }

    component WindowControl: Rectangle {
        property string symbol: ""
        signal activated()

        width: 28
        height: 28
        radius: 14
        color: hoverArea.containsMouse ? root.bgCardHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.symbol
            color: root.txtPrimary
            font.pixelSize: parent.symbol === "×" ? 17 : 14
            font.weight: Font.Medium
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    Rectangle {
        id: windowChrome
        z: 100
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.chromeHeight
        radius: root.windowIsMaximized ? 0 : 18
        color: root.bgPrimary
        border.color: root.bgPrimary
        border.width: 0

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 18
            color: parent.color
        }

        Text {
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            text: "Settings"
            color: root.txtPrimary
            font { pixelSize: 13; weight: Font.DemiBold }
        }

        Row {
            id: windowControls
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 4

            WindowControl {
                symbol: "−"
                onActivated: root.showMinimized()
            }
            WindowControl {
                symbol: root.windowIsMaximized ? "❐" : "□"
                onActivated: {
                    if (root.windowIsMaximized)
                        root.showNormal()
                    else
                        root.showMaximized()
                }
            }
            WindowControl {
                symbol: "×"
                onActivated: root.close()
            }
        }

        MouseArea {
            anchors { left: parent.left; right: windowControls.left; top: parent.top; bottom: parent.bottom }
            cursorShape: Qt.SizeAllCursor
            onPressed: root.startSystemMove()
            onDoubleClicked: {
                if (root.windowIsMaximized)
                    root.showNormal()
                else
                    root.showMaximized()
            }
        }
    }

    // Frameless windows do not get native resize handles, so provide them
    // around all four sides and corners.
    MouseArea {
        z: 101
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: root.resizeMargin
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.LeftEdge)
    }
    MouseArea {
        z: 101
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: root.resizeMargin
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.RightEdge)
    }
    MouseArea {
        z: 101
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.resizeMargin
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeVerCursor
        onPressed: root.startSystemResize(Qt.TopEdge)
    }
    MouseArea {
        z: 101
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.resizeMargin
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeVerCursor
        onPressed: root.startSystemResize(Qt.BottomEdge)
    }
    MouseArea {
        z: 102
        anchors { left: parent.left; top: parent.top }
        width: root.resizeMargin + 3
        height: root.resizeMargin + 3
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
    }
    MouseArea {
        z: 102
        anchors { right: parent.right; top: parent.top }
        width: root.resizeMargin + 3
        height: root.resizeMargin + 3
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.startSystemResize(Qt.TopEdge | Qt.RightEdge)
    }
    MouseArea {
        z: 102
        anchors { left: parent.left; bottom: parent.bottom }
        width: root.resizeMargin + 3
        height: root.resizeMargin + 3
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
    }
    MouseArea {
        z: 102
        anchors { right: parent.right; bottom: parent.bottom }
        width: root.resizeMargin + 3
        height: root.resizeMargin + 3
        enabled: !root.windowIsMaximized
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }

    // ── State ─────────────────────────────────────────────────────────────
    property string selected: "about-device"
    property bool mobileDetailOpen: false
    property string search: ""

    function refreshAppearanceTheme() {
        var value = SysInfo.getAppearanceTheme()
        if (value === "dark" || value === "light")
            appearanceTheme = value
    }

    function setAppearanceTheme(value) {
        var result = SysInfo.setAppearanceTheme(value)
        if (result === "dark" || result === "light")
            appearanceTheme = result
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: root.refreshAppearanceTheme()
    }

    Component.onCompleted: refreshAppearanceTheme()

    // ── Categories ────────────────────────────────────────────────────────
    // Each maps to a real page under pages/. "About Device" is the only one
    // currently backed by live data (via the Rust SysInfo singleton) — the
    // rest are still working on mock/local state until their own backends
    // land, same as before.
    ListModel {
        id: settingsList
        ListElement { settingId: "about-device";   title: "About Device";       subtitle: "System info, kernel, build";        icon: "info";         page: "pages/AboutPage.qml" }
        ListElement { settingId: "network";        title: "Network & Connections"; subtitle: "Wi-Fi, Bluetooth, VPN";         icon: "wifi";         page: "pages/ConnectionsPage.qml" }
        ListElement { settingId: "devices";        title: "Connected Devices";  subtitle: "Peripherals & Althyn Share";        icon: "usb";          page: "pages/ConnectedDevicesPage.qml" }
        ListElement { settingId: "personalization"; title: "Vamify";   subtitle: "Theme, accent, wallpaper";          icon: "palette";      page: "pages/VamifyPage.qml" }
        ListElement { settingId: "security";       title: "Security & Privacy"; subtitle: "Lock screen, permissions, firewall"; icon: "shield-check"; page: "pages/SecurityPage.qml" }
        ListElement { settingId: "apps";           title: "Apps";               subtitle: "Installed apps & permissions";      icon: "apps";         page: "pages/AppsPage.qml" }
        ListElement { settingId: "accessibility";  title: "Accessibility";      subtitle: "Vision, hearing, dexterity";        icon: "accessibility"; page: "pages/AccessibilityPage.qml" }
        ListElement { settingId: "support";        title: "Help & Support";     subtitle: "Docs, diagnostics, updates";        icon: "help-circle";  page: "pages/HelpPage.qml" }
        ListElement { settingId: "appsettings";           title: "Application settings";               subtitle: "All settings in one place";      icon: "settings";         page: "pages/AppSettingsPage.qml" }
    }

    function pageFor(id) {
        for (var i = 0; i < settingsList.count; i++)
            if (settingsList.get(i).settingId === id)
                return settingsList.get(i).page
        return settingsList.get(0).page
    }

    function openSetting(id) {
        root.selected = id
        root.mobileDetailOpen = true
    }

    // ── Reusable pieces ───────────────────────────────────────────────────

    // Small bare icon (no container), points at assets/icons/<name>.svg
    component AppIcon: Item {
        property string name: ""
        property int iconSize: 16
        width: iconSize; height: iconSize

        Image {
            id: iconSource
            anchors.fill: parent
            source: root.iconBase + name + ".svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: false
            sourceSize: Qt.size(iconSize * 2, iconSize * 2)
        }

        ColorOverlay {
            anchors.fill: iconSource
            source: iconSource
            color: root.darkTheme ? "#e4e4e7" : "#303640"
        }
    }

    // Icon in a rounded card box, used in list rows / empty states
    component IconGlyph: Rectangle {
        property string glyph: ""
        width: 36; height: 36; radius: 10
        color: root.bgCard
        AppIcon { anchors.centerIn: parent; name: glyph; iconSize: Math.round(parent.width * 0.44) }
    }

    component SettingRow: Rectangle {
        id: row
        required property string rowId
        required property string rowTitle
        required property string rowSubtitle
        required property string rowIcon
        property bool isFirst: false
        property bool isLast: false
        property bool active: false
        signal tapped()

        Layout.fillWidth: true
        height: 60
        color: active ? root.bgCard : (mouse.containsMouse ? root.bgCardHover : "transparent")
        Behavior on color { ColorAnimation { duration: 100 } }

        // Match SettingsListPane's radius: 20 so hover/active fill follows
        // the container's rounded top/bottom corners instead of cutting square.
        topLeftRadius:     row.isFirst ? 20 : 0
        topRightRadius:    row.isFirst ? 20 : 0
        bottomLeftRadius:  row.isLast  ? 20 : 0
        bottomRightRadius: row.isLast  ? 20 : 0

        Rectangle {
            visible: !row.isLast
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16 }
            height: 1
            color: root.borderColor
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 12
            IconGlyph { glyph: row.rowIcon }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: row.rowTitle; color: root.txtPrimary; font { pixelSize: 13; weight: Font.Medium } }
                Text { text: row.rowSubtitle; color: root.txtSecondary; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            AppIcon { name: "chevron-right"; iconSize: 16 }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.tapped()
        }
    }

    // ── List pane content (shared between mobile & desktop) ─────────────
    component SettingsListPane: Rectangle {
        radius: 20
        color: root.bgSurface
        border { color: root.borderColor; width: 1 }
        implicitHeight: listCol.implicitHeight

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            spacing: 0

            Repeater {
                model: settingsList
                delegate: SettingRow {
                    required property string settingId
                    required property string title
                    required property string subtitle
                    required property string icon
                    required property int index
                    Layout.fillWidth: true
                    visible: root.search === "" ||
                             title.toLowerCase().indexOf(root.search.toLowerCase()) >= 0 ||
                             subtitle.toLowerCase().indexOf(root.search.toLowerCase()) >= 0
                    rowId: settingId
                    rowTitle: title
                    rowSubtitle: subtitle
                    rowIcon: icon
                    isFirst: index === 0
                    isLast: index === settingsList.count - 1
                    active: root.selected === settingId
                    onTapped: root.openSetting(settingId)
                }
            }
        }
    }

    // ── Detail pane: loads the real page for whatever category is selected.
    // Each page under pages/ is self-contained and self-scrolling (its own
    // ScrollView), so the Loader just needs to fill the available area.
    component DetailPane: Item {
        property alias loadedItem: pageLoader.item
        readonly property bool isNestedPage: pageLoader.item &&
                                             pageLoader.item.activeSection !== undefined &&
                                             pageLoader.item.activeSection !== "overview"

        Loader {
            id: pageLoader
            anchors.fill: parent
            source: root.pageFor(root.selected)
        }
    }

    function categoryTitleFor(id) {
        for (var i = 0; i < settingsList.count; i++)
            if (settingsList.get(i).settingId === id)
                return settingsList.get(i).title
        return "Settings"
    }

    // ── Mobile layout ─────────────────────────────────────────────────────
    ColumnLayout {
        visible: root.isMobile
        anchors { fill: parent; topMargin: root.chromeHeight }
        spacing: 0

        // Single unified header: "‹  Settings › Category › Subpage" — one
        // row, one back step at a time, breadcrumb crumbs jump straight to
        // that level. Replaces the old two-stacked-titles look (this outer
        // bar plus each page's own internal toolbar/title).
        Rectangle {
            visible: root.mobileDetailOpen
            Layout.fillWidth: true
            height: 44
            color: "transparent"

            readonly property bool nested: mobileDetailPane.isNestedPage
            readonly property var loadedItem: mobileDetailPane.loadedItem

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                spacing: 2

                // One step back (nested subpage -> category overview,
                // category -> settings list).
                Item {
                    Layout.preferredWidth: 26
                    Layout.fillHeight: true
                    AppIcon { anchors.centerIn: parent; name: "chevron-left"; iconSize: 16 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (mobileDetailPane.isNestedPage && mobileDetailPane.loadedItem)
                                mobileDetailPane.loadedItem.activeSection = "overview"
                            else
                                root.mobileDetailOpen = false
                        }
                    }
                }

                Text {
                    text: "Settings"
                    color: root.txtSecondary
                    font { pixelSize: 13; weight: Font.Medium }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mobileDetailOpen = false }
                }

                AppIcon { name: "chevron-right"; iconSize: 10 }

                Text {
                    text: root.categoryTitleFor(root.selected)
                    color: mobileDetailPane.isNestedPage ? root.txtSecondary : root.txtPrimary
                    font { pixelSize: 13; weight: mobileDetailPane.isNestedPage ? Font.Medium : Font.DemiBold }
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        enabled: mobileDetailPane.isNestedPage
                        cursorShape: mobileDetailPane.isNestedPage ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (mobileDetailPane.loadedItem) mobileDetailPane.loadedItem.activeSection = "overview"
                    }
                }

                AppIcon { name: "chevron-right"; iconSize: 10; visible: mobileDetailPane.isNestedPage }

                Text {
                    visible: mobileDetailPane.isNestedPage
                    text: (mobileDetailPane.loadedItem && mobileDetailPane.loadedItem.activeSectionTitle !== undefined)
                          ? mobileDetailPane.loadedItem.activeSectionTitle : ""
                    color: root.txtPrimary
                    font { pixelSize: 13; weight: Font.DemiBold }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // List view: scrolls its own content.
        Flickable {
            visible: !root.mobileDetailOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: mobileListContent.implicitHeight + 32
            clip: true

            ColumnLayout {
                id: mobileListContent
                x: 16; y: 16
                width: parent.width - 32
                spacing: 16
                SettingsListPane { Layout.fillWidth: true }
                Item { height: 80 } // room for floating search
            }
        }

        // Detail view: the loaded page owns its own scrolling/margins.
        Item {
            id: mobileDetailContainer
            visible: root.mobileDetailOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            DetailPane {
                id: mobileDetailPane
                anchors.fill: parent
            }
        }
    }

    // Floating mobile search pill
    Rectangle {
        visible: root.isMobile && !root.mobileDetailOpen
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        height: 50
        radius: 25
        color: root.darkTheme ? Qt.rgba(0.09, 0.09, 0.10, 0.94) : Qt.rgba(1, 1, 1, 0.94)
        border { color: root.borderColor; width: 1 }

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 10
                AppIcon { name: "search"; iconSize: 13 }
            TextField {
                id: mobileSearch
                Layout.fillWidth: true
                text: root.search
                onTextChanged: root.search = text
                placeholderText: "Search settings..."
                color: root.txtPrimary
                placeholderTextColor: root.txtMuted
                font.pixelSize: 13
                background: Item {}
                leftPadding: 0
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Desktop layout ────────────────────────────────────────────────────
    Item {
        id: desktopRoot
        visible: !root.isMobile
        anchors { fill: parent; topMargin: root.chromeHeight + 24; leftMargin: 24; rightMargin: 24; bottomMargin: 24 }

        readonly property real sidebarWidth: 320
        readonly property real gap: 24

        // Sidebar (fixed width, anchored — not Layout-managed)
        Item {
            id: sidebarArea
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: desktopRoot.sidebarWidth

            Rectangle {
                id: desktopSearchBox
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 42
                radius: 21
                color: root.bgCard
                border { color: desktopSearch.activeFocus ? root.txtSecondary : root.borderColor; width: 1 }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 8
                    AppIcon { name: "search"; iconSize: 13 }
                    TextField {
                        id: desktopSearch
                        Layout.fillWidth: true
                        text: root.search
                        onTextChanged: root.search = text
                        placeholderText: "Search settings..."
                        color: root.txtPrimary
                        placeholderTextColor: root.txtMuted
                        font.pixelSize: 13
                        background: Item {}
                        leftPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Flickable {
                id: desktopListFlick
                anchors { top: desktopSearchBox.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
                contentWidth: width
                contentHeight: desktopList.implicitHeight
                clip: true

                SettingsListPane {
                    id: desktopList
                    x: 0; y: 0
                    width: desktopListFlick.width
                }
            }
        }

        // Detail pane: the loaded page owns its own scrolling.
        DetailPane {
            anchors { top: parent.top; bottom: parent.bottom; left: sidebarArea.right; leftMargin: desktopRoot.gap; right: parent.right }
        }
    }
}
