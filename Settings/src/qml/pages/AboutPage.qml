import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.vamoraos.SysInfo 1.0
import "../components"

Item {
    id: aboutPage
    anchors.fill: parent
    property string activeSection: "overview"
    readonly property var settingsWindow: ApplicationWindow.window
    readonly property bool dark: !settingsWindow || settingsWindow.darkTheme
    readonly property color pageCard: dark ? "#18181b" : "#ffffff"
    readonly property color pageBorder: dark ? "#27272a" : "#e4e4e7"
    readonly property color pageText: dark ? "#f4f4f5" : "#18181b"
    readonly property color pageMuted: dark ? "#a1a1aa" : "#71717a"
    readonly property color pageHover: dark ? "#27272a" : "#f4f4f5"

    // ── Banner colors, derived from the accent color ────────────────────────
    // The banner used to be a hardcoded sky-blue gradient with dark navy
    // text baked in for that specific blue. Now it tracks whatever accent
    // color is set, and the text flips between dark and light depending on
    // the accent's luminance so it stays readable on any color.
    readonly property color bannerAccent: settingsWindow ? settingsWindow.accentColor : "#2563eb"
    readonly property real bannerLuminance: 0.2126 * bannerAccent.r + 0.7152 * bannerAccent.g + 0.0722 * bannerAccent.b
    readonly property color bannerText: bannerLuminance > 0.55 ? "#07111f" : "#ffffff"
    readonly property color bannerTextMuted: bannerLuminance > 0.55 ? Qt.rgba(7/255, 17/255, 31/255, 0.68) : Qt.rgba(1, 1, 1, 0.72)
    property var hardwareRows: []
    property string hardwareError: ""
    readonly property bool isVamoraDesktop: {
        var environment = str(SysInfo.environment).trim().toLowerCase()
        return environment === "vamora" || environment === "althyn"
    }
    readonly property var deviceChildRows: {
        var rows = [
            {
                label: "Hardware Info",
                value: "CPU, GPU, memory, storage",
                icon: "hard-drive",
                section: "hardware"
            },
            {
                label: "About Vamora",
                value: "VamoraOS system information",
                icon: "info",
                section: "about-vamora"
            }
        ]
        if (isVamoraDesktop) {
            rows.push({
                label: "About Althyn",
                value: "Vamora desktop environment",
                icon: "monitor",
                section: "about-althyn"
            })
        }
        return rows
    }
    readonly property string activeSectionTitle: {
        var titles = {
            "overview": "About Device",
            "hardware": "Hardware Info",
            "about-vamora": "About Vamora",
            "about-althyn": "About Althyn"
        }
        return titles[activeSection] || "About Device"
    }

    // System identity comes from /etc/VamoraSys/vamora-release (or
    // /etc/VamoraSys/vamora-release.vmf on older builds), read at runtime
    // by the Rust bridge. There is no bundled/compiled-in fallback file.
    // str() guards every SysInfo read: if the running vamora-settings binary
    // is older than this QML (e.g. it hasn't been rebuilt yet after new
    // qproperty fields were added to SysInfo), the newer property names come
    // back as `undefined` instead of an empty QString, and calling .length
    // on undefined threw on every one of these rows. Coercing to "" first
    // makes a stale bridge degrade to "row just doesn't show up" instead of
    // crashing the whole page.
    function str(value) {
        return typeof value === "string" ? value : ""
    }

    function textOr(value, fallback) {
        var text = str(value).trim()
        return text.length > 0 ? text : fallback
    }

    function refreshHardwareInfo() {
        hardwareError = ""
        try {
            var raw = SysInfo.getHardwareInfo()
            var parsed = JSON.parse(raw)
            hardwareRows = parsed.filter(function (row) {
                return row && str(row.label).length > 0 && str(row.value).length > 0
            })
        } catch (error) {
            hardwareRows = []
            hardwareError = "Hardware information is unavailable."
        }
    }

    function refreshHardwareUsage() {
        if (activeSection !== "hardware")
            return

        try {
            var updates = JSON.parse(SysInfo.getHardwareUsage())
            var nextRows = hardwareRows.slice()
            updates.forEach(function (update) {
                if (!update || str(update.value).length === 0)
                    return
                for (var i = 0; i < nextRows.length; i++) {
                    if (nextRows[i].label === update.label) {
                        nextRows[i] = { label: update.label, value: update.value }
                        break
                    }
                }
            })
            hardwareRows = nextRows
        } catch (error) {
            // Keep the last successful readings visible if a later refresh fails.
        }
    }

    function goBack() {
        activeSection = "overview"
    }

    onActiveSectionChanged: {
        if (activeSection === "hardware")
            refreshHardwareInfo()
    }

    Timer {
        interval: 2000
        repeat: true
        running: aboutPage.activeSection === "hardware"
        onTriggered: aboutPage.refreshHardwareUsage()
    }

    readonly property var infoRows: {
        // Keep the required rows visible even when a release file does not
        // provide one of the optional fields. Previously the final filter
        // removed those rows entirely, making the UI disagree with this
        // list and hiding OS/version metadata.
        var rows = [
            ["Device",           textOr(SysInfo.device, "Unknown Device")],
            ["OS",               textOr(SysInfo.pretty_name, textOr(SysInfo.name, "VamoraOS"))],
            ["VamoraSys Version", textOr(SysInfo.vamorasys_version, "Not reported")],
            ["VMF Version",      textOr(SysInfo.vmf_version, "Not reported")],
            ["Environment",      textOr(SysInfo.environment, "Unknown")],
            ["Codename",         textOr(SysInfo.codename, "Unknown")],
            ["Architecture",     textOr(SysInfo.arch, "Unknown")],
            ["Kernel",           textOr(SysInfo.kernel, "Unknown")],
        ]
        if (str(SysInfo.build_id).length > 0) rows.push(["Build ID", str(SysInfo.build_id)])
        if (str(SysInfo.channel).length > 0) rows.push(["Channel", str(SysInfo.channel)])
        return rows
    }

    readonly property var linkRows: {
        var links = []
        if (str(SysInfo.home_url).length > 0)   links.push({ label: "Website",       url: str(SysInfo.home_url) })
        if (str(SysInfo.docs_url).length > 0)   links.push({ label: "Documentation", url: str(SysInfo.docs_url) })
        if (str(SysInfo.bug_url).length > 0)    links.push({ label: "Report a Bug",  url: str(SysInfo.bug_url) })
        if (str(SysInfo.source_url).length > 0) links.push({ label: "Source Code",   url: str(SysInfo.source_url) })
        return links
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

            Item { height: 28 }

            ColumnLayout {
                visible: aboutPage.activeSection === "overview"
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 14

                // ── Banner ────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 168
                    radius: 24
                    clip: true

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.lighter(aboutPage.bannerAccent, 1.55) }
                        GradientStop { position: 0.5; color: aboutPage.bannerAccent }
                        GradientStop { position: 1.0; color: Qt.darker(aboutPage.bannerAccent, 1.35) }
                    }

                    Rectangle {
                        width: 180; height: 180; radius: 90
                        color: Qt.rgba(1,1,1,0.05)
                        anchors { right: parent.right; rightMargin: -40; top: parent.top; topMargin: -40 }
                    }
                    Rectangle {
                        width: 120; height: 120; radius: 60
                        color: Qt.rgba(1,1,1,0.05)
                        anchors { left: parent.left; leftMargin: -30; bottom: parent.bottom; bottomMargin: -30 }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                             Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "VamoraOS"
                             color: aboutPage.bannerText
                            font { pixelSize: 42; weight: Font.Bold; letterSpacing: -1.5 }
                            layer.enabled: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: SysInfo.version
                             color: aboutPage.bannerTextMuted
                            font { pixelSize: 15; italic: true; letterSpacing: 0.3 }
                        }
                    }
                }

                // ── Info table ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    clip: true
                    implicitHeight: infoRows.length * 50

                    Column {
                        id: infoCol
                        anchors { left: parent.left; right: parent.right }
                        height: infoRows.length * 50

                        Repeater {
                            model: infoRows
                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: infoCol.width
                                height: 50

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
                                     height: 1; color: aboutPage.pageBorder
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                    spacing: 8

                                    Text {
                                        text: modelData[0]
                                         color: aboutPage.pageMuted
                                        font { pixelSize: 13 }
                                        Layout.preferredWidth: 120
                                    }
                                    Text {
                                        text: modelData[1]
                                         color: aboutPage.pageText
                                        font { pixelSize: 13 }
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Top-level navigation entries on the main About Device page:
                // Hardware Info, About Vamora, and (when applicable) About Althyn,
                // all grouped together in one card.
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    clip: true
                    implicitHeight: aboutPage.deviceChildRows.length * 52

                    Column {
                        anchors { left: parent.left; right: parent.right }

                        Repeater {
                            model: aboutPage.deviceChildRows
                            delegate: SettingsRow {
                                required property var modelData
                                required property int index
                                width: parent.width
                                rowLabel: aboutPage.str(modelData.label)
                                rowValue: aboutPage.str(modelData.value)
                                rowIcon: aboutPage.str(modelData.icon)
                                tappable: true
                                isFirst: index === 0
                                isLast: index === aboutPage.deviceChildRows.length - 1
                                onTapped: aboutPage.activeSection = modelData.section
                            }
                        }
                    }
                }

                Item { height: 28 }
            }

            // The app-level mobile header supplies its own back+title row.
            // On desktop, keep the subpage's back affordance inside this
            // page instead.
            RowLayout {
                visible: aboutPage.activeSection !== "overview" &&
                         (!aboutPage.settingsWindow || !aboutPage.settingsWindow.isMobile)
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                height: 48
                spacing: 12

                ToolButton {
                    id: aboutBackButton
                    text: "‹"
                    font.pixelSize: 32
                    font.bold: false
                    implicitWidth: 42
                    implicitHeight: 42

                    contentItem: Text {
                        text: aboutBackButton.text
                        color: aboutPage.pageText
                        font: aboutBackButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: aboutBackButton.hovered ? aboutPage.pageHover : "transparent"
                        radius: 10
                    }

                    onClicked: aboutPage.goBack()
                }

                Text {
                    text: aboutPage.activeSectionTitle
                    color: aboutPage.pageText
                    font.pixelSize: 26
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                visible: aboutPage.activeSection === "hardware"
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 14

                Text {
                    text: "Hardware"
                    color: aboutPage.pageText
                    font { pixelSize: 18; weight: Font.DemiBold }
                    Layout.fillWidth: true
                }

                Text {
                    text: "Live information collected from this device."
                    color: aboutPage.pageMuted
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: aboutPage.hardwareRows.length > 0
                    Layout.fillWidth: true
                    radius: 14
                    color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    clip: true
                    implicitHeight: aboutPage.hardwareRows.length * 52

                    Column {
                        anchors { left: parent.left; right: parent.right }
                        Repeater {
                            model: aboutPage.hardwareRows
                            delegate: SettingsRow {
                                required property var modelData
                                required property int index
                                width: parent.width
                                rowLabel: aboutPage.str(modelData.label)
                                rowValue: aboutPage.str(modelData.value)
                                isFirst: index === 0
                                isLast: index === aboutPage.hardwareRows.length - 1
                            }
                        }
                    }
                }

                Rectangle {
                    visible: aboutPage.hardwareRows.length === 0
                    Layout.fillWidth: true
                    radius: 14
                    color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    implicitHeight: emptyHardwareText.implicitHeight + 32

                    Text {
                        id: emptyHardwareText
                        anchors {
                            left: parent.left
                            right: parent.right
                            margins: 16
                        }
                        text: aboutPage.hardwareError.length > 0
                              ? aboutPage.hardwareError
                              : "No hardware information was detected."
                        color: aboutPage.pageMuted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }

                Item { height: 28 }
            }

            ColumnLayout {
                visible: aboutPage.activeSection === "about-vamora"
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 14

                // ── Identity ──────────────────────────────────────────────────
                // A plain Column with anchored children centers reliably
                // regardless of the outer ColumnLayout's actual width, unlike
                // Layout.alignment on fillWidth items which can end up
                // stretched edge-to-edge instead of centered.
                Column {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 4
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 88; height: 88
                        source: "../assets/Vamora.svg"
                        sourceSize: Qt.size(88, 88)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Vamora"
                        color: aboutPage.pageText
                        font { pixelSize: 22; weight: Font.Bold }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(440, parent.width)
                        horizontalAlignment: Text.AlignHCenter
                        text: "Vamora is an open project building a connected ecosystem of software \u2014 from operating systems and apps to AI-powered tools \u2014 designed to feel unique and work together across every device."
                        color: aboutPage.pageMuted
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Open, beautiful software for every screen \ud83c\udf1f"
                        color: aboutPage.pageMuted
                        font { pixelSize: 12; italic: true }
                    }
                }

                // ── Links ─────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14; color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    clip: true
                    visible: linkRows.length > 0
                    implicitHeight: linkRows.length * 50

                    Column {
                        id: linksCol
                        anchors { left: parent.left; right: parent.right }
                        height: linkRows.length * 50

                        Repeater {
                            model: linkRows
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: linksCol.width; height: 50
                                color: lhov ? "#252525" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                property bool lhov: false

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
                                     height: 1; color: aboutPage.pageBorder
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                    Text {
                                         text: modelData.label; color: aboutPage.pageText
                                        font.pixelSize: 13; Layout.fillWidth: true
                                    }
                                    Text { text: "↗"; color: "#3b82f6"; font.pixelSize: 14 }
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.lhov = true; onExited: parent.lhov = false
                                    onClicked: Qt.openUrlExternally(modelData.url)
                                }
                            }
                        }
                    }
                }

                Item { height: 28 }
            }

            ColumnLayout {
                visible: aboutPage.activeSection === "about-althyn"
                Layout.fillWidth: true
                Layout.leftMargin: 28
                Layout.rightMargin: 28
                spacing: 14

                // ── Identity ──────────────────────────────────────────────────
                Column {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 4
                    spacing: 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 88; height: 88
                        source: "../assets/Vamora.svg"
                        sourceSize: Qt.size(88, 88)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Althyn"
                        color: aboutPage.pageText
                        font { pixelSize: 22; weight: Font.Bold }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(440, parent.width)
                        horizontalAlignment: Text.AlignHCenter
                        text: "Althyn is the desktop shell that powers VamoraOS \u2014 the statusbar, homescreen, dock, and system UI you use every day."
                        color: aboutPage.pageMuted
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Part of the Vamora ecosystem"
                        color: aboutPage.pageMuted
                        font { pixelSize: 12; italic: true }
                    }
                }

                // ── Links ─────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    radius: 14; color: aboutPage.pageCard
                    border.color: aboutPage.pageBorder
                    border.width: 1
                    clip: true
                    visible: linkRows.length > 0
                    implicitHeight: linkRows.length * 50

                    Column {
                        id: althynLinksCol
                        anchors { left: parent.left; right: parent.right }
                        height: linkRows.length * 50

                        Repeater {
                            model: linkRows
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: althynLinksCol.width; height: 50
                                color: alhov ? "#252525" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                property bool alhov: false

                                Rectangle {
                                    visible: index > 0
                                    anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }
                                    height: 1; color: aboutPage.pageBorder
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                    Text {
                                        text: modelData.label; color: aboutPage.pageText
                                        font.pixelSize: 13; Layout.fillWidth: true
                                    }
                                    Text { text: "\u2197"; color: "#3b82f6"; font.pixelSize: 14 }
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.alhov = true; onExited: parent.alhov = false
                                    onClicked: Qt.openUrlExternally(modelData.url)
                                }
                            }
                        }
                    }
                }

                Item { height: 28 }
            }
        }
    }
}
