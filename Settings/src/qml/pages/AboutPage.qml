import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.vamoraos.SysInfo 1.0

Item {
    id: aboutPage
    anchors.fill: parent
    readonly property var settingsWindow: ApplicationWindow.window
    readonly property bool dark: !settingsWindow || settingsWindow.darkTheme
    readonly property color pageCard: dark ? "#18181b" : "#ffffff"
    readonly property color pageBorder: dark ? "#27272a" : "#e4e4e7"
    readonly property color pageText: dark ? "#f4f4f5" : "#18181b"
    readonly property color pageMuted: dark ? "#a1a1aa" : "#71717a"

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

    readonly property var infoRows: {
        // Device, versions, OS and Environment lead the table; Name and the
        // plain "version" line are skipped here since the banner above
        // already shows them, and there's no Logo row anymore.
        var rows = [
            ["Device",           str(SysInfo.device)],
            ["OS",               str(SysInfo.prettyName)],
            ["VamoraSys Version", str(SysInfo.vamorasysVersion)],
            ["VMF Version",      str(SysInfo.vmfVersion)],
            ["Environment",      str(SysInfo.environment)],
            ["OS ID",            str(SysInfo.osId)],
            ["ID Like",          str(SysInfo.idLike)],
            ["Version ID",       str(SysInfo.versionId)],
            ["Codename",         str(SysInfo.codename)],
            ["Architecture",     str(SysInfo.arch)],
            ["Kernel",           str(SysInfo.kernel)],
        ]
        if (str(SysInfo.buildId).length > 0) rows.push(["Build ID", str(SysInfo.buildId)])
        if (str(SysInfo.channel).length > 0) rows.push(["Channel", str(SysInfo.channel)])
        if (str(SysInfo.ansiColor).length > 0) rows.push(["ANSI Color", str(SysInfo.ansiColor)])
        return rows.filter(function (row) { return row[1].length > 0 })
    }

    readonly property var linkRows: {
        var links = []
        if (str(SysInfo.homeUrl).length > 0)   links.push({ label: "Website",       url: str(SysInfo.homeUrl) })
        if (str(SysInfo.docsUrl).length > 0)   links.push({ label: "Documentation", url: str(SysInfo.docsUrl) })
        if (str(SysInfo.bugUrl).length > 0)    links.push({ label: "Report a Bug",  url: str(SysInfo.bugUrl) })
        if (str(SysInfo.sourceUrl).length > 0) links.push({ label: "Source Code",   url: str(SysInfo.sourceUrl) })
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
                        GradientStop { position: 0.0; color: "#7dd3fc" }
                        GradientStop { position: 0.5; color: "#38bdf8" }
                        GradientStop { position: 1.0; color: "#2563eb" }
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
                             color: "#07111f"
                            font { pixelSize: 42; weight: Font.Bold; letterSpacing: -1.5 }
                            layer.enabled: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: SysInfo.version
                             color: Qt.rgba(7/255, 17/255, 31/255, 0.68)
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

                // ── Links ─────────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    radius: 24; color: aboutPage.pageCard
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
        }
    }
}
