import QtQuick
import QtQuick.Controls
import QtQuick.Window
import com.vamora

Window {
    id: launcher

    visible: true
    visibility: Window.FullScreen
    color: "transparent"
    title: "Vamora Launcher"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool

    property bool darkTheme: true
    property var allApps: []
    property var results: []
    property int selectedIndex: -1
    property bool errorVisible: false
    property string failedCommand: ""

    readonly property color panelColor: darkTheme ? "#18181b" : "#fafafa"
    readonly property color surfaceColor: darkTheme ? "#27272a" : "#ffffff"
    readonly property color borderColor: darkTheme ? "#3f3f46" : "#d4d4d8"
    readonly property color textColor: darkTheme ? "#f4f4f5" : "#18181b"
    readonly property color mutedTextColor: darkTheme ? "#a1a1aa" : "#71717a"
    readonly property color hoverColor: darkTheme ? "#3f3f46" : "#f0f0f2"
    readonly property color accentColor: darkTheme ? "#ffffff" : "#18181b"
    readonly property color accentTextColor: darkTheme ? "#18181b" : "#ffffff"

    FontLoader { id: interRegular; source: "qrc:/assets/fonts/inter/Inter-Regular.ttf" }
    FontLoader { id: interMedium; source: "qrc:/assets/fonts/inter/Inter-Medium.ttf" }
    FontLoader { id: interSemiBold; source: "qrc:/assets/fonts/inter/Inter-SemiBold.ttf" }

    AppList { id: appList }

    function updateResults() {
        var query = searchField.text.trim().toLowerCase()
        var appResults = allApps
        if (query.length > 0) {
            appResults = allApps.filter(function(app) {
                return app.appName.toLowerCase().indexOf(query) !== -1
            })
        }

        var commandResults = query.length > 0
            ? JSON.parse(appList.getCommandJson(searchField.text.trim()))
            : []
        results = appResults.concat(commandResults)
        selectedIndex = results.length > 0 ? 0 : -1
    }

    function moveSelection(delta) {
        if (results.length === 0)
            return
        selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + delta))
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function launchResult(result) {
        if (!result || !result.execStr)
            return
        appList.launchApp(result.execStr, !!result.terminal)
        launcher.close()
    }

    function submitSearch() {
        if (selectedIndex >= 0 && selectedIndex < results.length) {
            launchResult(results[selectedIndex])
            return
        }

        var command = searchField.text.trim()
        if (command.length > 0 && appList.commandExists(command)) {
            appList.launchApp(command, true)
            launcher.close()
            return
        }

        failedCommand = command
        errorVisible = true
    }

    Component.onCompleted: {
        // Theme detection is intentionally a single startup read.
        darkTheme = appList.getTheme() !== "light"
        allApps = JSON.parse(appList.getAppsJson())
        updateResults()
        searchField.forceActiveFocus()
    }

    Keys.onEscapePressed: launcher.close()
    onActiveChanged: {
        if (!active && visible && !errorVisible)
            launcher.close()
    }

    MouseArea {
        id: outsideArea
        anchors.fill: parent
        z: 0
        onClicked: launcher.close()
    }

    Rectangle {
        id: panel
        z: 1
        width: Math.min(640, launcher.width - 64)
        height: 250
        anchors.centerIn: parent
        radius: 24
        color: panelColor
        border.color: borderColor
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        TextField {
            id: searchField
            x: 20
            y: 20
            width: parent.width - 40
            height: 54
            leftPadding: 52
            rightPadding: 18
            color: textColor
            placeholderText: "Search applications or commands..."
            placeholderTextColor: mutedTextColor
            font.family: interRegular.name
            font.pixelSize: 16
            selectByMouse: true

            background: Rectangle {
                radius: 16
                color: surfaceColor
                border.color: searchField.activeFocus ? accentColor : borderColor
                border.width: searchField.activeFocus ? 2 : 1
            }

            Image {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                source: "qrc:/assets/search.svg"
                opacity: launcher.darkTheme ? 0.9 : 0.65
            }

            onTextChanged: launcher.updateResults()
            Keys.onReturnPressed: launcher.submitSearch()
            Keys.onEnterPressed: launcher.submitSearch()
            Keys.onLeftPressed: function(event) {
                launcher.moveSelection(-1)
                event.accepted = true
            }
            Keys.onRightPressed: function(event) {
                launcher.moveSelection(1)
                event.accepted = true
            }
            Keys.onUpPressed: function(event) {
                launcher.moveSelection(-1)
                event.accepted = true
            }
            Keys.onDownPressed: function(event) {
                launcher.moveSelection(1)
                event.accepted = true
            }
        }

        Item {
            id: resultsArea
            x: 20
            y: 92
            width: parent.width - 40
            height: 128
            clip: true

            ListView {
                id: resultList
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 10
                model: launcher.results
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 1800
                flickDeceleration: 2400

                delegate: Rectangle {
                    id: resultDelegate
                    width: 112
                    height: resultList.height
                    readonly property bool selected: index === launcher.selectedIndex
                    radius: 16
                    color: selected || cardMouse.containsMouse ? hoverColor : surfaceColor
                    border.color: selected || cardMouse.containsMouse ? accentColor : borderColor
                    border.width: selected || cardMouse.containsMouse ? 2 : 0

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Image {
                        id: resultIcon
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 58
                        height: 58
                        source: modelData.isCommand
                                ? "qrc:/assets/terminal.png"
                                : (modelData.iconPath !== "" ? modelData.iconPath : "qrc:/assets/unknown.png")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 13
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.appName
                        color: textColor
                        font.family: interMedium.name
                        font.pixelSize: 12
                        maximumLineCount: 1
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: launcher.selectedIndex = index
                        onClicked: launcher.launchResult(modelData)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onWheel: function(wheel) {
                        var delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y
                        // Shift + wheel is the conventional horizontal-scroll
                        // gesture. Vertical wheel is also mapped horizontally
                        // when no horizontal delta is supplied.
                        resultList.contentX = Math.max(0, Math.min(
                            resultList.contentWidth - resultList.width,
                            resultList.contentX - delta
                        ))
                        wheel.accepted = true
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: launcher.results.length === 0
                text: searchField.text.length === 0 ? "No applications found" : "No matching applications or commands"
                color: mutedTextColor
                font.family: interRegular.name
                font.pixelSize: 13
            }
        }
    }

    Rectangle {
        id: errorPopup
        z: 3
        visible: launcher.errorVisible
        width: 360
        height: 156
        anchors.centerIn: parent
        radius: 18
        color: panelColor
        border.color: borderColor
        border.width: 1

        Text {
            anchors.top: parent.top
            anchors.topMargin: 25
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            text: "Command does not exist"
            color: textColor
            font.family: interSemiBold.name
            font.pixelSize: 16
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 55
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: launcher.failedCommand.length > 0 ? "“" + launcher.failedCommand + "”" : "Enter a command to run"
            color: mutedTextColor
            font.family: interRegular.name
            font.pixelSize: 13
        }

        Button {
            width: 76
            height: 32
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: "OK"
            onClicked: {
                launcher.errorVisible = false
                searchField.forceActiveFocus()
            }

            contentItem: Text {
                text: parent.text
                color: accentTextColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: interMedium.name
                font.pixelSize: 13
            }

            background: Rectangle {
                radius: 10
                color: parent.down ? mutedTextColor : accentColor
            }
        }
    }
}