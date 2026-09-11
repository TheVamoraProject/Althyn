import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import "../components"
import com.vamora

Window {
    id: window
    width: 550
    height: 570
    visible: true
    color: "transparent"
    title: "StartMenu"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // ---- VamoraUI palette (zinc, follows appearance.theme) ----
    readonly property color cBg: isDark ? "#18181b" : "#fafafa"        // zinc-900/50, solid
    readonly property color cTopBar: isDark ? "#27272a" : "#f4f4f5"    // zinc-800/100, solid
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"    // zinc-700/300
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"   // zinc-800/100 (pills / inputs)
    readonly property color cSurfaceHover: isDark ? "#3f3f46" : "#e4e4e7" // zinc-700/200
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"      // zinc-100/900
    readonly property color cTextMuted: isDark ? "#a1a1aa" : "#52525b" // zinc-400/600
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"    // sole accent: white on dark, near-black on light
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"  // text/icons on the accent

    ThemeManager {
        id: themeManager
    }

    // Local QML-native mirror of themeManager.darkMode — see statusbar.qml
    // for why we don't bind directly to themeManager.darkMode.
    property bool isDark: true

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            isDark = themeManager.refresh()
        }
    }

    property bool isMaximized: false
    property bool ignoreDeactivate: false
    property real normalX: 0
    property real normalY: 0
    property real normalWidth: width
    property real normalHeight: height
    property int statusBarHeight: 30 // must match your status bar's height

    // Context menu state
    property string ctxDesktopPath: ""

    // Favorites tab data (loaded on demand)
    property var favoritesApps: []

    // click outside ==> close
    onActiveChanged: {
        if (!active && !ignoreDeactivate) {
            window.close()
        }
    }

    Timer {
        id: resizeGuardTimer
        interval: 250
        onTriggered: ignoreDeactivate = false
    }

    function toggleMaximize() {
        ignoreDeactivate = true
        resizeGuardTimer.restart()

        if (!isMaximized) {
            normalX = window.x
            normalY = window.y
            normalWidth = window.width
            normalHeight = window.height

            window.x = 0
            window.y = statusBarHeight
            window.width = Screen.width
            window.height = Screen.height - statusBarHeight
            isMaximized = true
        } else {
            window.x = normalX
            window.y = normalY
            window.width = normalWidth
            window.height = normalHeight
            isMaximized = false
        }
    }

    UserInfo {
        id: userInfo
    }

    AppList {
        id: appList
    }

    // --- App data from rust---
    property var allApps: []
    property var filteredApps: []
    property int cols: isMaximized ? 8 : 5
    property real cellSize: (startmenu.width - 24) / cols

    function applyFilter(text) {
        var q = text.toLowerCase().trim()
        filteredApps = (q === "")
            ? allApps.slice()
            : allApps.filter(function(a) {
                  return a.appName.toLowerCase().indexOf(q) !== -1
              })
    }

    Component.onCompleted: {
        allApps = JSON.parse(appList.getAppsJson())
        filteredApps = allApps.slice()
    }

    Rectangle {
        id: startmenu
        color: cBg
        width: parent.width
        height: parent.height
        border.color: cBorder
        border.width: 1
        radius: isMaximized ? 0 : 24

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                if (ctxMenu.visible) {
                    ctxMenu.visible = false
                } else {
                    window.close()
                }
            }
        }

        Rectangle {
            // top bar
            color: cTopBar
            width: parent.width
            height: 50
            radius: isMaximized ? 0 : 24

            Rectangle {
                color: parent.color
                width: parent.width
                height: parent.height / 2
                y: parent.height / 2
            }

            Rectangle {
                // topbar outline fyi
                color: cBorder
                width: parent.width
                height: 1
                y: 49
            }

            Button {
                id: pfpButton
                x: 16
                y: ( parent.height / 2 ) - ( height / 2 )
                width: 28
                height: 28

                background: Rectangle {
                    radius: width / 2
                    color: cSurface
                    border.width: 1
                    border.color: cBorder
                }

                Image {
                    id: pfpFallback
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    source: "qrc:/assets/icons/account.svg"
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: pfpFallback.width
                            height: pfpFallback.height
                            radius: width / 2
                        }
                    }
                }

                Image {
                    id: pfpImage
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    source: userInfo.pfpPath
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    smooth: false
                    sourceSize.width: 128
                    sourceSize.height: 128
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: pfpImage.width
                            height: pfpImage.height
                            radius: width / 2
                        }
                    }
                }
            }

            // Custom VamoraUI username tooltip
            Rectangle {
                id: usernameTooltip
                visible: pfpButton.hovered
                parent: startmenu
                x: pfpButton.x + pfpButton.width / 2 - width / 2
                y: 50 + 8
                z: 300
                width: usernameText.implicitWidth + 20
                height: 28
                radius: 8
                color: cSurface
                border.color: cBorder
                border.width: 1

                // small triangle pointer
                Canvas {
                    width: 10
                    height: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = cSurface
                        ctx.strokeStyle = cBorder
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(0, height)
                        ctx.lineTo(width / 2, 0)
                        ctx.lineTo(width, height)
                        ctx.closePath()
                        ctx.fill()
                        ctx.stroke()
                    }
                }

                Text {
                    id: usernameText
                    anchors.centerIn: parent
                    text: userInfo.fullName
                    color: cText
                    font.pixelSize: 12
                    font.family: "Inter"
                    font.weight: Font.Medium
                }

                Behavior on visible {
                    // instant show, instant hide — keeps it snappy like the rest of the UI
                }
            }

            TextField {
                // the search bar
                id: searchField
                width: 284
                height: 32
                color: cText
                x: ( parent.width / 2 ) - ( width / 2 )
                y: ( parent.height / 2 ) - ( height / 2 )
                leftPadding: 35
                placeholderText: "Search"
                placeholderTextColor: cTextMuted
                font.pixelSize: 13

                onTextChanged: applyFilter(text)

                background: Rectangle {
                    color: cSurface
                    border.color: searchField.activeFocus ? cAccent : cBorder
                    border.width: 1
                    radius: 25

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
                Image {
                    source: "../../assets/icons/search.svg"
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: cTextMuted
                    }
                }
            }

            Button {
                x: parent.width - width - 16
                y: ( parent.height / 2 ) - ( height / 2 )
                width: 28
                height: 28

                background: Rectangle {
                    radius: width / 2
                    color: cSurface
                    border.width: 1
                    border.color: cBorder
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = cSurfaceHover
                        onExited: parent.color = cSurface
                    }
                }

                onClicked: toggleMaximize()

                Image {
                    source: isMaximized ? "../../assets/icons/minimize.svg" : "../../assets/icons/maximize.svg"
                    width: 14
                    height: 14
                    anchors.centerIn: parent
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: cText
                    }
                }
            }

        }

        // App grid area (scrollable)
        Item {
            id: gridArea
            width: parent.width
            y: 50 + 6
            height: parent.height - 50 - 6 - 36 - 22
            clip: true

            GridView {
                id: appGrid
                anchors.fill: parent
                cellWidth: cellSize
                cellHeight: cellSize
                model: startmenu.selectedCategoryIndex === 1 ? window.favoritesApps : filteredApps
                clip: true

                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                maximumFlickVelocity: 2500

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6

                    background: Rectangle { color: "transparent" }
                    contentItem: Rectangle {
                        radius: 3
                        color: cSurfaceHover
                    }
                }

                delegate: Item {
                    id: iconWrap
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight
                    opacity: 0
                    scale: 0.75

                    Component.onCompleted: entranceAnim.start()

                    SequentialAnimation {
                        id: entranceAnim
                        PauseAnimation { duration: index * 18 }
                        ParallelAnimation {
                            NumberAnimation { target: iconWrap; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                            NumberAnimation { target: iconWrap; property: "scale"; to: 1;   duration: 240; easing.type: Easing.OutBack }
                        }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                    }

                    GridIcon {
                        anchors.fill: parent
                        anchors.margins: 4
                        appName: modelData.appName
                        iconPath: modelData.iconPath
                        execStr: modelData.execStr
                        textColor: cText
                        hoverColor: cSurfaceHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: iconWrap.scale = 1.08
                        onExited:  iconWrap.scale = 1
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                ctxDesktopPath = modelData.desktopPath || ""
                                var pos = mapToItem(startmenu, mouse.x, mouse.y)
                                var mx = Math.min(pos.x, startmenu.width - ctxMenu.width - 6)
                                var my = Math.min(pos.y, startmenu.height - ctxMenu.height - 6)
                                ctxMenu.x = mx
                                ctxMenu.y = my
                                ctxMenu.visible = true
                            } else {
                                if (modelData.execStr !== "") {
                                    appList.launchApp(modelData.execStr)
                                    window.close()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Context menu ──────────────────────────────────────────────────────
        Rectangle {
            id: ctxMenu
            visible: false
            z: 200
            width: 192
            radius: 10
            color: cSurface
            border.color: cBorder
            border.width: 1
            height: ctxMenuItems.height + 10

            // Dismiss layer — transparent, covers the rest of the window
            MouseArea {
                parent: startmenu
                anchors.fill: parent
                z: ctxMenu.z - 1
                enabled: ctxMenu.visible
                onClicked: ctxMenu.visible = false
            }

            Column {
                id: ctxMenuItems
                anchors.top: parent.top
                anchors.topMargin: 5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 2

                // "Add to Homescreen"
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: hsMa.containsMouse ? cSurfaceHover : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        spacing: 8
                        Item {
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: iconHomescreen
                                anchors.fill: parent
                                source: "../../assets/icons/home.svg"
                                smooth: true
                            }
                            ColorOverlay {
                                anchors.fill: iconHomescreen
                                source: iconHomescreen
                                color: cText
                            }
                        }
                        Text {
                            text: "Add to Homescreen"
                            color: cText
                            font.pixelSize: 13
                            font.family: "Inter"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: hsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            appList.copyToDesktop(ctxDesktopPath)
                            ctxMenu.visible = false
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: cBorder
                    opacity: 0.6
                }

                // "Add to Favorite"
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: favMa.containsMouse ? cSurfaceHover : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        spacing: 8
                        Item {
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: iconFavorite
                                anchors.fill: parent
                                source: "../../assets/icons/star.svg"
                                smooth: true
                            }
                            ColorOverlay {
                                anchors.fill: iconFavorite
                                source: iconFavorite
                                color: cText
                            }
                        }
                        Text {
                            text: "Add to Favorite"
                            color: cText
                            font.pixelSize: 13
                            font.family: "Inter"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: favMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            appList.copyToFavorites(ctxDesktopPath)
                            ctxMenu.visible = false
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: cBorder
                    opacity: 0.6
                }

                // "App Info"
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: infoMa.containsMouse ? cSurfaceHover : "transparent"

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        spacing: 8
                        Item {
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: iconInfo
                                anchors.fill: parent
                                source: "../../assets/icons/info.svg"
                                smooth: true
                            }
                            ColorOverlay {
                                anchors.fill: iconInfo
                                source: iconInfo
                                color: cText
                            }
                        }
                        Text {
                            text: "App Info"
                            color: cText
                            font.pixelSize: 13
                            font.family: "Inter"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: infoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            // placeholder — no action yet
                            ctxMenu.visible = false
                        }
                    }
                }
            }
        }
        // ── End context menu ──────────────────────────────────────────────────

        // Always on bottom navbar (https://vamora.vercel.app/blog/vamui)
        property int selectedCategoryIndex: 0

        onSelectedCategoryIndexChanged: {
            if (selectedCategoryIndex === 1) {
                window.favoritesApps = JSON.parse(appList.getFavoritesJson())
            }
        }

        Rectangle {
            id: bottomNav
            width: 168
            height: 38
            color: cSurface
            border.width: 1
            border.color: cBorder
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 14
            radius: 50

            readonly property int btnWidth: 52
            readonly property int btnSpacing: 4

            Rectangle {
                id: selectOverlay
                height: parent.height - 8
                width: bottomNav.btnWidth
                radius: height / 2
                color: cAccent
                anchors.verticalCenter: parent.verticalCenter
                x: navRow.x + startmenu.selectedCategoryIndex * (bottomNav.btnWidth + bottomNav.btnSpacing)

                Behavior on x {
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
                }
            }

            Row {
                id: navRow
                anchors.centerIn: parent
                spacing: bottomNav.btnSpacing
                height: parent.height

                Button {
                    width: bottomNav.btnWidth
                    height: parent.height
                    background: Rectangle { color: "#00000000" }

                    Image {
                        id: appsIcon
                        anchors.centerIn: parent
                        source: "../../assets/icons/apps.svg"
                        width: 16
                        height: 16
                    }
                    ColorOverlay {
                        anchors.fill: appsIcon
                        source: appsIcon
                        color: startmenu.selectedCategoryIndex === 0 ? cOnAccent : cText
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: startmenu.selectedCategoryIndex = 0
                    }
                }
                Button {
                    width: bottomNav.btnWidth
                    height: parent.height
                    background: Rectangle { color: "#00000000" }

                    Image {
                        id: starIcon
                        anchors.centerIn: parent
                        source: "../../assets/icons/star.svg"
                        width: 16
                        height: 16
                    }
                    ColorOverlay {
                        anchors.fill: starIcon
                        source: starIcon
                        color: startmenu.selectedCategoryIndex === 1 ? cOnAccent : cText
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: startmenu.selectedCategoryIndex = 1
                    }
                }
                Button {
                    width: bottomNav.btnWidth
                    height: parent.height
                    background: Rectangle { color: "#00000000" }

                    Image {
                        id: historyIcon
                        anchors.centerIn: parent
                        source: "../../assets/icons/history.svg"
                        width: 16
                        height: 16
                    }
                    ColorOverlay {
                        anchors.fill: historyIcon
                        source: historyIcon
                        color: startmenu.selectedCategoryIndex === 2 ? cOnAccent : cText
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: startmenu.selectedCategoryIndex = 2
                    }
                }
            }
        }
    }
}
