import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.vamoraos.SysInfo 1.0
import "../components"

Item {
    id: connectionsPage

    property string activeSection: "overview"

    readonly property var settingsWindow: ApplicationWindow.window

    property string currentTheme: {
        var value = SysInfo.getAppearanceTheme()
        return value === "light" || value === "dark" ? value : "dark"
    }

    property string accentColor: {
        var value = SysInfo.getAccentColor()
        return value.indexOf("error") !== 0 ? value : "#3b82f6"
    }

    readonly property color pageCard:
        currentTheme === "light" ? "#ffffff" : "#1e1e1e"

    readonly property color pageText:
        currentTheme === "light" ? "#1b1d22" : "#f0f0f0"

    readonly property color pageMuted:
        currentTheme === "light" ? "#68717e" : "#777777"

    readonly property color pageBorder:
        currentTheme === "light" ? "#d7dbe2" : "#2c2c2c"

    readonly property color pageHover:
        currentTheme === "light" ? "#eef0f3" : "#252525"

    property bool wifiEnabled: true
    property bool bluetoothEnabled: true
    property bool airplaneMode: false
    property bool ethernetConnected: true

    property bool vpnConnected: false
    property bool privateDnsEnabled: false
    property bool printingEnabled: true

    Timer {
        interval: 1500
        running: true
        repeat: true

        onTriggered: {
            var theme = SysInfo.getAppearanceTheme()

            if (theme === "light" || theme === "dark")
                connectionsPage.currentTheme = theme

            var accent = SysInfo.getAccentColor()

            if (accent.indexOf("error") !== 0)
                connectionsPage.accentColor = accent
        }
    }

    component Card: Rectangle {
        default property alias contentData: cardContent.data

        Layout.fillWidth: true
        radius: 14
        color: connectionsPage.pageCard
        border.color: connectionsPage.pageBorder
        border.width: 1
        clip: true

        implicitHeight: cardContent.implicitHeight

        Column {
            id: cardContent

            anchors.left: parent.left
            anchors.right: parent.right

            spacing: 0
        }
    }

    component ConnectionToggleRow: Item {
        id: connectionRow

        property string rowLabel: ""
        property string rowSub: ""
        property bool rowOn: false
        property string targetSection: ""

        width: parent ? parent.width : 0
        height: toggleRow.height

        ToggleRow {
            id: toggleRow

            width: parent.width

            rowLabel: connectionRow.rowLabel
            rowSub: connectionRow.rowSub
            on_: connectionRow.rowOn
            isFirst: true

            onToggled: function(value) {
                connectionRow.rowOn = value
            }
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: 70

            cursorShape: Qt.PointingHandCursor

            onClicked: {
                connectionsPage.activeSection =
                        connectionRow.targetSection
            }
        }
    }

    function sectionTitle() {
        switch (activeSection) {
        case "wifi":
            return "Wi-Fi"

        case "bluetooth":
            return "Bluetooth"

        case "vpn":
            return "VPN"

        case "privateDns":
            return "Private DNS"

        case "printing":
            return "Printing"

        case "airplane":
            return "Airplane Mode"

        default:
            return "Connections"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        spacing: 18

        // ================================================================
        // HEADER
        // ================================================================

        // The app-level mobile header (in main.qml) already shows this
        // page's title and back button on mobile, so this in-page header
        // would just duplicate it. Only render it in the wide desktop
        // layout — same pattern as AboutPage and VamifyPage.
        RowLayout {
            visible: !connectionsPage.settingsWindow || !connectionsPage.settingsWindow.isMobile
            Layout.fillWidth: true
            spacing: 12

            ToolButton {
                id: backButton

                visible: connectionsPage.activeSection !== "overview"

                text: "‹"

                font.pixelSize: 32
                font.bold: false

                implicitWidth: 42
                implicitHeight: 42

                contentItem: Text {
                    text: backButton.text

                    color: connectionsPage.pageText

                    font: backButton.font

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: backButton.hovered
                           ? connectionsPage.pageHover
                           : "transparent"

                    radius: 10
                }

                onClicked: {
                    connectionsPage.activeSection = "overview"
                }
            }

            Label {
                Layout.fillWidth: true

                text: connectionsPage.sectionTitle()

                color: connectionsPage.pageText

                font.pixelSize: 26
                font.bold: true
            }
        }

        // ================================================================
        // PAGES
        // ================================================================

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            currentIndex: {
                switch (connectionsPage.activeSection) {
                case "wifi":
                    return 1

                case "bluetooth":
                    return 2

                case "vpn":
                    return 3

                case "privateDns":
                    return 4

                case "printing":
                    return 5

                case "airplane":
                    return 6

                default:
                    return 0
                }
            }

            // ============================================================
            // OVERVIEW
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: overviewColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: overviewColumn

                    width: parent.width
                    spacing: 14

                    // ----------------------------------------------------
                    // Main connections
                    // ----------------------------------------------------

                    Card {

                        ConnectionToggleRow {
                            rowLabel: "Wi-Fi"

                            rowSub: connectionsPage.wifiEnabled
                                     ? "On"
                                     : "Off"

                            rowOn: connectionsPage.wifiEnabled

                            targetSection: "wifi"

                            onRowOnChanged: {
                                connectionsPage.wifiEnabled = rowOn
                            }
                        }

                        ConnectionToggleRow {
                            rowLabel: "Bluetooth"

                            rowSub: connectionsPage.bluetoothEnabled
                                     ? "On"
                                     : "Off"

                            rowOn: connectionsPage.bluetoothEnabled

                            targetSection: "bluetooth"

                            onRowOnChanged: {
                                connectionsPage.bluetoothEnabled = rowOn
                            }
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Ethernet"

                            rowValue: connectionsPage.ethernetConnected
                                      ? "Connected"
                                      : "Not connected"

                            rowIcon: ""

                            tappable: false
                        }

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Airplane Mode"

                            rowSub: connectionsPage.airplaneMode
                                     ? "On"
                                     : "Off"

                            on_: connectionsPage.airplaneMode

                            onToggled: function(value) {
                                connectionsPage.airplaneMode = value
                            }
                        }
                    }

                    // ----------------------------------------------------
                    // Other connections
                    // ----------------------------------------------------

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "VPN"

                            rowValue: connectionsPage.vpnConnected
                                      ? "Connected"
                                      : "Not connected"

                            rowIcon: "shield-check"

                            tappable: true

                            onTapped: {
                                connectionsPage.activeSection = "vpn"
                            }
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Private DNS"

                            rowValue: connectionsPage.privateDnsEnabled
                                      ? "Enabled"
                                      : "Automatic"

                            rowIcon: "settings"

                            tappable: true

                            onTapped: {
                                connectionsPage.activeSection =
                                        "privateDns"
                            }
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Printing"

                            rowValue: connectionsPage.printingEnabled
                                      ? "On"
                                      : "Off"

                            rowIcon: "hard-drive"

                            tappable: true

                            onTapped: {
                                connectionsPage.activeSection =
                                        "printing"
                            }
                        }
                    }
                }
            }

            // ============================================================
            // WI-FI
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: wifiColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: wifiColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Wi-Fi"

                            rowSub: connectionsPage.wifiEnabled
                                     ? "Enabled"
                                     : "Disabled"

                            on_: connectionsPage.wifiEnabled

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.wifiEnabled = value
                            }
                        }
                    }

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Available networks"
                            rowValue: "Scan"
                            rowIcon: "search"

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Saved networks"
                            rowValue: ""
                            rowIcon: ""

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Wi-Fi preferences"
                            rowValue: ""
                            rowIcon: "settings"

                            tappable: true
                        }
                    }
                }
            }

            // ============================================================
            // BLUETOOTH
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: bluetoothColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: bluetoothColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Bluetooth"

                            rowSub: connectionsPage.bluetoothEnabled
                                     ? "Enabled"
                                     : "Disabled"

                            on_: connectionsPage.bluetoothEnabled

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.bluetoothEnabled = value
                            }
                        }
                    }

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Pair new device"
                            rowValue: ""
                            rowIcon: ""

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Paired devices"
                            rowValue: ""
                            rowIcon: "computer"

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Bluetooth preferences"
                            rowValue: ""
                            rowIcon: "settings"

                            tappable: true
                        }
                    }
                }
            }

            // ============================================================
            // VPN
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: vpnColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: vpnColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "VPN"

                            rowSub: connectionsPage.vpnConnected
                                     ? "Connected"
                                     : "Not connected"

                            on_: connectionsPage.vpnConnected

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.vpnConnected = value
                            }
                        }
                    }

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Add VPN"
                            rowValue: ""
                            rowIcon: ""

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "VPN preferences"
                            rowValue: ""
                            rowIcon: "settings"

                            tappable: true
                        }
                    }
                }
            }

            // ============================================================
            // PRIVATE DNS
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: privateDnsColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: privateDnsColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Private DNS"

                            rowSub: connectionsPage.privateDnsEnabled
                                     ? "Enabled"
                                     : "Automatic"

                            on_: connectionsPage.privateDnsEnabled

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.privateDnsEnabled = value
                            }
                        }
                    }

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Private DNS mode"

                            rowValue: connectionsPage.privateDnsEnabled
                                      ? "Provider"
                                      : "Automatic"

                            rowIcon: "settings"

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "DNS provider"

                            rowValue: ""
                            rowIcon: ""

                            tappable: true
                        }
                    }
                }
            }

            // ============================================================
            // PRINTING
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: printingColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: printingColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Printing"

                            rowSub: connectionsPage.printingEnabled
                                     ? "Enabled"
                                     : "Disabled"

                            on_: connectionsPage.printingEnabled

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.printingEnabled = value
                            }
                        }
                    }

                    Card {

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Default printer"

                            rowValue: "None"

                            rowIcon: "hard-drive"

                            tappable: true
                        }

                        SettingsRow {
                            width: parent.width

                            rowLabel: "Add printer"

                            rowValue: ""
                            rowIcon: ""

                            tappable: true
                        }
                    }
                }
            }

            // ============================================================
            // AIRPLANE MODE
            // ============================================================

            Flickable {
                contentWidth: width
                contentHeight: airplaneColumn.implicitHeight

                clip: true

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: airplaneColumn

                    width: parent.width
                    spacing: 14

                    Card {

                        ToggleRow {
                            width: parent.width

                            rowLabel: "Airplane Mode"

                            rowSub: connectionsPage.airplaneMode
                                     ? "On"
                                     : "Off"

                            on_: connectionsPage.airplaneMode

                            isFirst: true

                            onToggled: function(value) {
                                connectionsPage.airplaneMode = value
                            }
                        }
                    }

                    Card {

                        Label {
                            Layout.fillWidth: true
                            Layout.margins: 18

                            text: "Airplane Mode disables wireless connections such as Wi-Fi and Bluetooth."

                            wrapMode: Text.WordWrap

                            color: connectionsPage.pageMuted

                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}