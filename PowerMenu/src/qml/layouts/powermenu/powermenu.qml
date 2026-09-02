import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import com.vamora.powermenu

Window {
    id: window
    visible: false
    x: Screen.virtualX
    y: Screen.virtualY
    width: Screen.width
    height: Screen.height
    title: "vamora-powermenu"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool

    readonly property bool darkMode: isDark
    readonly property color cBg: darkMode ? "#18181b" : "#fafafa"
    readonly property color cTopBar: darkMode ? "#27272a" : "#ffffff"
    readonly property color cBorder: darkMode ? "#3f3f46" : "#d4d4d8"
    readonly property color cSurface: darkMode ? "#27272a" : "#ffffff"
    readonly property color cSurfaceHover: darkMode ? "#3f3f46" : "#e4e4e7"
    readonly property color cText: darkMode ? "#f4f4f5" : "#18181b"
    readonly property color cTextMuted: darkMode ? "#a1a1aa" : "#71717a"
    readonly property color cTextFaint: darkMode ? "#71717a" : "#a1a1aa"
    readonly property color cAccent: darkMode ? "#ffffff" : "#2563eb"
    readonly property color cOnAccent: darkMode ? "#09090b" : "#ffffff"
    readonly property color cBackdrop: darkMode ? "#B309090B" : "#B3F4F4F5"

    property string confirmAction: ""
    property string confirmTitle: ""
    property string confirmDetail: ""
    property string pendingAction: ""
    property bool readyForFocus: false
    property bool isClosing: false

    FontLoader {
        id: interRegular
        source: "../../assets/fonts/inter/Inter-Regular.ttf"
    }
    FontLoader {
        id: interMedium
        source: "../../assets/fonts/inter/Inter-Medium.ttf"
    }
    FontLoader {
        id: interSemibold
        source: "../../assets/fonts/inter/Inter-SemiBold.ttf"
    }

    property bool isDark: true

    ThemeManager { id: themeManager }
    UserInfo { id: userInfo }
    PowerActions { id: powerActions }

    property var powerFeatures: [
        { action: "lock", title: "Lock screen", detail: "Secure this session", icon: "../../assets/icons/lock.svg" },
        { action: "sleep", title: "Sleep", detail: "Suspend the session", icon: "../../assets/icons/moon.svg" },
        { action: "hibernate", title: "Hibernate", detail: "Save state to disk", icon: "../../assets/icons/hibernate.svg" },
        { action: "logout", title: "Log out", detail: "End this session", icon: "../../assets/icons/logout.svg" },
        { action: "restart", title: "Restart", detail: "Reboot the computer", icon: "../../assets/icons/restart.svg" },
        { action: "shutdown", title: "Shut down", detail: "Power off the computer", icon: "../../assets/icons/shutdown.svg" }
    ]

    function beginAction(action, title, detail) {
        confirmAction = action
        confirmTitle = title
        confirmDetail = detail
    }

    function dismiss() {
        if (confirmAction !== "") {
            confirmAction = ""
            confirmTitle = ""
            confirmDetail = ""
        } else {
            closeWithAnimation()
        }
    }

    function runConfirmedAction() {
        pendingAction = confirmAction
        confirmAction = ""
        closeWithAnimation()
    }

    function closeWithAnimation() {
        if (isClosing)
            return

        isClosing = true
        readyForFocus = false
        panel.opacity = 0
        panel.scale = 0.96
        backdropShade.opacity = 0
        closeTimer.restart()
    }

    onActiveChanged: {
        if (readyForFocus && !active && visible)
            closeWithAnimation()
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: {
            if (window.pendingAction !== "") {
                powerActions.executeAction(window.pendingAction)
                window.pendingAction = ""
            }
            window.close()
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: window.dismiss()

        Image {
            id: desktopImage
            anchors.fill: parent
            fillMode: Image.Stretch
            cache: false
            visible: source !== ""
            smooth: true
            layer.enabled: visible
            layer.effect: FastBlur {
                radius: 34
                transparentBorder: false
            }
        }

        Rectangle {
            id: backdropShade
            anchors.fill: parent
            color: window.cBackdrop
            opacity: 0

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        // This is intentionally a single click-catcher: clicking anywhere
        // outside the card cancels the menu (or its pending confirmation).
        MouseArea {
            anchors.fill: parent
            z: 2
            onClicked: window.dismiss()
        }

        Rectangle {
            id: panel
            width: Math.min(470, window.width - 48)
            height: Math.min(590, window.height - 48)
            anchors.centerIn: parent
            z: 3
            radius: 24
            color: window.cBg
            border.width: 1
            border.color: window.cBorder
            opacity: 0
            scale: 0.96

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack }
            }

            // The panel itself sits above the backdrop click-catcher.
            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            Rectangle {
                id: panelHeader
                width: parent.width
                height: 170
                radius: 24
                color: window.cTopBar

                Rectangle {
                    width: parent.width
                    height: parent.height / 2
                    y: parent.height / 2
                    color: parent.color
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    y: parent.height - 1
                    color: window.cBorder
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Item {
                        width: 82
                        height: 82
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: window.cSurface
                            border.width: 1
                            border.color: window.cBorder
                        }

                        // Keep a visible avatar mark even while a local face
                        // is loading or when the desktop path is unavailable.
                        Canvas {
                            id: fallbackAvatar
                            anchors.fill: parent
                            anchors.margins: 14
                            visible: pfpImage.status !== Image.Ready

                            onVisibleChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                var stroke = window.darkMode ? "#e4e4e7" : "#27272a"
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = stroke
                                ctx.lineWidth = 4
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"

                                ctx.beginPath()
                                ctx.arc(width / 2, height * 0.34, width * 0.11, 0, Math.PI * 2)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(width / 2, height * 0.86, width * 0.22, Math.PI, 0)
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: window
                            function onIsDarkChanged() {
                                fallbackAvatar.requestPaint()
                            }
                        }

                        Image {
                            id: pfpImage
                            anchors.fill: parent
                            // The inset keeps even an unmasked square image
                            // fully inside the outer circular frame.
                            anchors.margins: 14
                            source: userInfo.pfpPath
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: pfpImage.width
                                    height: pfpImage.height
                                    radius: width / 2
                                }
                            }
                        }

                        // Keep the frame on top of the image so the face
                        // always reads as contained by the circular avatar.
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: window.cBorder
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: userInfo.username || "Vamora user"
                        color: window.cText
                        font.family: interSemibold.name
                        font.pixelSize: 18
                    }
                }
            }

            Column {
                id: content
                anchors.top: panelHeader.bottom
                anchors.topMargin: 22
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 14

                Text {
                    text: "Power menu"
                    color: window.cText
                    font.family: interSemibold.name
                    font.pixelSize: 16
                }

                Text {
                    text: "Choose what you want to do with this session."
                    color: window.cTextMuted
                    font.family: interRegular.name
                    font.pixelSize: 12
                }

                Grid {
                    id: featureGrid
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10
                    width: parent.width

                    Repeater {
                        model: window.powerFeatures

                        Item {
                            width: (featureGrid.width - featureGrid.columnSpacing) / 2
                            height: 92

                            Rectangle {
                                id: featureCard
                                anchors.fill: parent
                                radius: 14
                                color: cardMouse.containsMouse ? window.cSurfaceHover : window.cSurface
                                border.width: 1
                                border.color: cardMouse.containsMouse ? window.cTextFaint : window.cBorder

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 120 }
                                }

                                Image {
                                    id: featureIcon
                                    x: 16
                                    y: 18
                                    width: 22
                                    height: 22
                                    source: modelData.icon
                                    smooth: true
                                }
                                ColorOverlay {
                                    anchors.fill: featureIcon
                                    source: featureIcon
                                    color: window.darkMode ? "#f4f4f5" : "#27272a"
                                }

                                Column {
                                    x: 16
                                    y: 51
                                    spacing: 2

                                    Text {
                                        text: modelData.title
                                        color: window.cText
                                        font.family: interMedium.name
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: modelData.detail
                                        color: window.cTextMuted
                                        font.family: interRegular.name
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: window.beginAction(
                                        modelData.action,
                                        modelData.title,
                                        modelData.detail
                                    )
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: confirmDialog
                visible: window.confirmAction !== ""
                anchors.fill: parent
                radius: 24
                color: window.cBg
                z: 10

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 76
                    spacing: 16

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Confirm action"
                        color: window.cText
                        font.family: interSemibold.name
                        font.pixelSize: 20
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Run “" + window.confirmTitle + "”?"
                        color: window.cText
                        font.family: interMedium.name
                        font.pixelSize: 15
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: window.confirmDetail
                        color: window.cTextMuted
                        font.family: interRegular.name
                        font.pixelSize: 12
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Rectangle {
                            width: 112
                            height: 40
                            radius: 12
                            color: window.cSurface
                            border.width: 1
                            border.color: window.cBorder

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: window.cText
                                font.family: interMedium.name
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: window.dismiss()
                            }
                        }

                        Rectangle {
                            width: 112
                            height: 40
                            radius: 12
                            color: window.darkMode ? "#f4f4f5" : "#2563eb"

                            Text {
                                anchors.centerIn: parent
                                text: "Continue"
                                color: window.cOnAccent
                                font.family: interMedium.name
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: window.runConfirmedAction()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Capture while this window is still hidden so the overlay is not in
        // its own backdrop. There is no repeating screenshot or theme timer.
        var capturedPath = powerActions.captureScreen()
        window.isDark = themeManager.refresh()
        if (capturedPath !== "")
            desktopImage.source = capturedPath

        window.visible = true
        backdropShade.opacity = 1
        panel.opacity = 1
        panel.scale = 1
        window.readyForFocus = true
        scene.forceActiveFocus()
    }
}