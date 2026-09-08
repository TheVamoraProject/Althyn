import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import dev.vamoraos.SysInfo 1.0

Item {
    id: helpPage
    anchors.fill: parent

    readonly property string helpUrl: "https://vamora.vercel.app/projects/vamoraos/help"
    readonly property var win: ApplicationWindow.window
    readonly property bool dark: !win || win.darkTheme
    readonly property color pageBg: dark ? "#000000" : "#fafafa"
    readonly property color barBg: dark ? "#18181b" : "#ffffff"
    readonly property color borderCol: dark ? "#27272a" : "#e4e4e7"
    readonly property color txtPrimary: dark ? "#f4f4f5" : "#18181b"
    readonly property color txtMuted: dark ? "#a1a1aa" : "#71717a"
    property string installError: ""
    property bool installBusy: false

    function retryWebView() {
        webViewLoader.source = ""
        webViewRetry.start()
    }

    Timer {
        id: webViewRetry
        interval: 250
        onTriggered: webViewLoader.source = "HelpWebView.qml"
    }

    component ToolIcon: Rectangle {
        id: toolIcon
        property string glyph: ""
        property bool enabledLook: true
        signal tapped()
        width: 30; height: 30; radius: 8
        color: hov.containsMouse && toolIcon.enabledLook ? (dark ? "#2a2a2a" : "#eef0f3") : "transparent"

        Image {
            id: iconSrc
            anchors.centerIn: parent
            width: 15; height: 15
            source: "../assets/icons/" + toolIcon.glyph + ".svg"
            sourceSize: Qt.size(30, 30)
            visible: false
        }
        ColorOverlay {
            anchors.fill: iconSrc
            source: iconSrc
            color: toolIcon.enabledLook ? txtPrimary : txtMuted
        }
        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            enabled: toolIcon.enabledLook
            cursorShape: Qt.PointingHandCursor
            onClicked: toolIcon.tapped()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: helpPage.pageBg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Embedded-browser toolbar ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 46
                color: helpPage.barBg
                border.color: helpPage.borderCol
                border.width: 1

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 6

                    ToolIcon {
                        glyph: "chevron-left"
                        enabledLook: webViewLoader.item && webViewLoader.item.canGoBack
                        onTapped: if (webViewLoader.item) webViewLoader.item.goBack()
                    }
                    ToolIcon {
                        glyph: "chevron-right"
                        enabledLook: webViewLoader.item && webViewLoader.item.canGoForward
                        onTapped: if (webViewLoader.item) webViewLoader.item.goForward()
                    }
                    ToolIcon {
                        glyph: "refresh"
                        enabledLook: webViewLoader.status === Loader.Ready
                        onTapped: if (webViewLoader.item) webViewLoader.item.reload()
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 8
                        color: helpPage.dark ? "#141414" : "#eef0f3"

                        Text {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                            text: webViewLoader.item ? webViewLoader.item.url.toString() : helpPage.helpUrl
                            color: helpPage.txtMuted
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                        }
                    }

                    ToolIcon {
                        glyph: "download"
                        onTapped: Qt.openUrlExternally(webViewLoader.item ? webViewLoader.item.url.toString() : helpPage.helpUrl)
                    }
                }

                // Thin loading indicator along the bottom edge of the toolbar
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom }
                    height: 2
                    width: parent.width * (webViewLoader.item ? webViewLoader.item.loadProgress / 100 : 0)
                    color: "#3b82f6"
                    visible: webViewLoader.item && webViewLoader.item.loading
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            // ── The actual embedded page ─────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: webViewLoader
                    anchors.fill: parent
                    source: "HelpWebView.qml"
                    onStatusChanged: {
                        if (status === Loader.Error && !webViewMissingDialog.visible)
                            webViewMissingDialog.open()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: webViewLoader.status !== Loader.Ready
                    color: helpPage.pageBg
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Embedded help is unavailable"
                            color: helpPage.txtPrimary
                            font { pixelSize: 15; weight: Font.DemiBold }
                        }
                        Text {
                            width: Math.min(helpPage.width - 56, 420)
                            text: "Open the help site externally while Qt WebView is being installed."
                            color: helpPage.txtMuted
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 150; height: 34; radius: 17
                            color: helpPage.dark ? "#f4f4f5" : "#18181b"
                            Text {
                                anchors.centerIn: parent
                                text: "Open in browser"
                                color: helpPage.dark ? "#18181b" : "#ffffff"
                                font { pixelSize: 12; weight: Font.DemiBold }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(helpPage.helpUrl)
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: webViewMissingDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(430, helpPage.width - 32)
        modal: true
        title: ""
        padding: 24
        standardButtons: Dialog.NoButton
        background: Rectangle {
            color: helpPage.barBg
            radius: 24
            border { color: helpPage.borderCol; width: 1 }
        }

        ColumnLayout {
            width: parent.width
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: "#7dd3fc"
                    Image {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        source: "../assets/icons/download.svg"
                        sourceSize: Qt.size(40, 40)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Qt WebView is missing"
                        color: helpPage.txtPrimary
                        font { pixelSize: 16; weight: Font.DemiBold }
                    }
                    Text {
                        text: "Help needs the embedded browser module."
                        color: helpPage.txtMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: SysInfo.isDebianBased()
                      ? "This VamoraOS build is Debian-based. Settings can install the Qt 6 WebView package with apt."
                      : "This is a custom VamoraOS build on a non-Debian system. Install the Qt 6 WebView QML module manually, then reopen Settings."
                color: helpPage.txtMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                visible: SysInfo.isDebianBased()
                Layout.fillWidth: true
                height: 38
                radius: 12
                color: helpPage.dark ? "#000000" : "#fafafa"
                border.color: helpPage.borderCol
                Text {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    text: "sudo apt-get install qml6-module-qtwebview"
                    color: helpPage.txtPrimary
                    font.family: "monospace"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            TextField {
                id: sudoPassword
                visible: SysInfo.isDebianBased()
                Layout.fillWidth: true
                placeholderText: "Your administrator password"
                echoMode: TextInput.Password
                color: helpPage.txtPrimary
                placeholderTextColor: helpPage.txtMuted
                font.pixelSize: 13
                background: Rectangle {
                    radius: 12
                    color: helpPage.dark ? "#000000" : "#fafafa"
                    border { color: sudoPassword.activeFocus ? "#7dd3fc" : helpPage.borderCol; width: 1 }
                }
            }

            Text {
                visible: helpPage.installError.length > 0
                Layout.fillWidth: true
                text: helpPage.installError
                color: "#f87171"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 92; height: 36; radius: 18
                    color: helpPage.dark ? "#27272a" : "#f4f4f5"
                    Text { anchors.centerIn: parent; text: "Not now"; color: helpPage.txtPrimary; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: webViewMissingDialog.reject() }
                }
                Rectangle {
                    visible: SysInfo.isDebianBased()
                    width: 150; height: 36; radius: 18
                    color: helpPage.dark ? "#f4f4f5" : "#18181b"
                    opacity: helpPage.installBusy ? 0.5 : 1
                    Text {
                        anchors.centerIn: parent
                        text: helpPage.installBusy ? "Installing…" : "Install WebView"
                        color: helpPage.dark ? "#18181b" : "#ffffff"
                        font { pixelSize: 12; weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !helpPage.installBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            helpPage.installError = ""
                            if (sudoPassword.text.length === 0) {
                                helpPage.installError = "Enter your administrator password to continue."
                            } else {
                                helpPage.installBusy = true
                                var result = SysInfo.installQtWebView(sudoPassword.text)
                                helpPage.installBusy = false
                                sudoPassword.text = ""
                                if (result === "installed") {
                                    webViewMissingDialog.accept()
                                    helpPage.retryWebView()
                                } else {
                                    helpPage.installError = result
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
