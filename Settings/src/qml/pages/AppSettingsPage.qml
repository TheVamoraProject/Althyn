import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: appSettingsPage
    anchors.fill: parent
    readonly property var settingsWindow: ApplicationWindow.window
    readonly property bool dark: !settingsWindow || settingsWindow.darkTheme
    readonly property color pageCard: dark ? "#18181b" : "#ffffff"
    readonly property color pageHover: dark ? "#27272a" : "#f4f4f5"
    readonly property color pageBorder: dark ? "#27272a" : "#e4e4e7"
    readonly property color pageText: dark ? "#f4f4f5" : "#18181b"
    readonly property color pageMuted: dark ? "#a1a1aa" : "#71717a"
    readonly property color pageAccent: settingsWindow && settingsWindow.accentColor !== undefined
                                        ? settingsWindow.accentColor : "#7dd3fc"

    property string filterText: ""
    property string selectedApp: ""

    readonly property var apps: [
        { name: "Files",        icon: "files",       pkg: "vamora-files",    perms: "Storage" },
        { name: "Browser",      icon: "compass",     pkg: "vamora-browser",  perms: "Network, Storage" },
        { name: "Camera",       icon: "camera",      pkg: "vamora-camera",   perms: "Camera, Storage" },
        { name: "Gallery",      icon: "gallery",     pkg: "vamora-gallery",  perms: "Storage" },
        { name: "Calendar",     icon: "calendar",    pkg: "vamora-cal",      perms: "Calendar" },
        { name: "Calculator",   icon: "calculator",  pkg: "vamora-calc",     perms: "None" },
        { name: "Contacts",     icon: "contacts",    pkg: "vamora-contacts",  perms: "Contacts" },
        { name: "Clock",        icon: "clock",       pkg: "vamora-clock",     perms: "Notifications" },
    ]

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Item { height: 28 }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            text: "Application settings"
            color: appSettingsPage.pageText
            font { pixelSize: 22; weight: Font.DemiBold }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            text: "Manage app access and the defaults used by VamoraOS."
            color: appSettingsPage.pageMuted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Item { height: 4 }

        // Search
        Rectangle {
            Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28
            height: 44; radius: 22; color: appSettingsPage.pageCard
            border { color: appSettingsPage.pageBorder; width: 1 }

            RowLayout { anchors { fill: parent; leftMargin: 14; rightMargin: 10 }; spacing: 8
                Image {
                    source: "../assets/icons/search.svg"
                    sourceSize: Qt.size(28, 28)
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    opacity: 0.65
                }
                TextInput {
                    Layout.fillWidth: true; color: appSettingsPage.pageText; font.pixelSize: 13
                    placeholderText: "Search applications"; placeholderTextColor: appSettingsPage.pageMuted
                    onTextChanged: filterText = text
                }
            }
        }

        Item { height: 14 }

        ScrollView {

        // Kinetic/touch scrolling: rubber-band overshoot + tuned flick
        // feel so dragging with a finger (VamoraFold, touch panels) works
        // like a native scroller, not just mouse-wheel/scrollbar drag.
        Component.onCompleted: {
            contentItem.boundsBehavior = Flickable.DragAndOvershootBounds
            contentItem.maximumFlickVelocity = 2500
            contentItem.flickDeceleration = 1500
        }
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth; ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Rectangle {
                x: 28; width: parent.width - 56; radius: 24; color: appSettingsPage.pageCard
                border.color: appSettingsPage.pageBorder
                border.width: 1
                clip: true
                implicitHeight: appList.implicitHeight

                Column {
                    id: appList; anchors { left: parent.left; right: parent.right }

                    Repeater {
                        model: apps.filter(function(a) {
                            if (filterText === "") return true
                            return a.name.toLowerCase().indexOf(filterText.toLowerCase()) >= 0 ||
                                   a.pkg.toLowerCase().indexOf(filterText.toLowerCase()) >= 0
                        })

                        delegate: Rectangle {
                            required property var modelData; required property int index
                            width: appList.width; height: 58
                            color: ahov ? appSettingsPage.pageHover : "transparent"; Behavior on color { ColorAnimation { duration: 160 } }
                            property bool ahov: false

                            Rectangle { visible: index > 0; anchors { left: parent.left; right: parent.right; leftMargin: 16; top: parent.top }; height: 1; color: appSettingsPage.pageBorder }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }; spacing: 12

                                Rectangle {
                                    width: 40; height: 40; radius: 14
                                    color: appSettingsPage.dark ? "#27272a" : "#f4f4f5"
                                    Image {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        source: "../assets/icons/appicons/" + modelData.icon + ".png"
                                        sourceSize: Qt.size(48, 48)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: modelData.name; color: appSettingsPage.pageText; font { pixelSize: 13; weight: Font.Medium } }
                                         Text {
                                             text: selectedApp === modelData.name
                                                   ? "Selected · " + modelData.perms
                                                   : modelData.perms
                                              color: selectedApp === modelData.name ? appSettingsPage.pageAccent : appSettingsPage.pageMuted
                                             font.pixelSize: 11
                                         }
                                }

                                Text { text: "›"; color: appSettingsPage.pageMuted; font.pixelSize: 18 }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: parent.ahov = true; onExited: parent.ahov = false
                                 onClicked: selectedApp = modelData.name
                            }
                        }
                    }
                }
            }
        }

        Item { height: 28 }
    }
}
