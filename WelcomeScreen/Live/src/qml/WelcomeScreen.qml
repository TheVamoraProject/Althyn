// VamoraOS — Welcome Screen
//
// Exit: Ctrl+Shift+Q

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import com.vamora.welcome

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    title: "VamoraOS"
    color: "transparent"

    // Fonts
    FontLoader { id: interRegular;  source: "assets/fonts/inter/Inter-Regular.ttf"  }
    FontLoader { id: interMedium;   source: "assets/fonts/inter/Inter-Medium.ttf"   }
    FontLoader { id: interSemiBold; source: "assets/fonts/inter/Inter-SemiBold.ttf" }
    FontLoader { id: interBold;     source: "assets/fonts/inter/Inter-Bold.ttf"     }

    // Rust stuff
    WelcomeController { id: controller }
    Component.onCompleted: root.osName = controller.os_name()

    // State
    property int  langIndex:   0
    property bool hasStarted:  false   // flips when user first clicks →
    // 0=Hello  1=Welcome/ToS  2=Install/Try  3=ToS text  4=All set
    property int  currentPage: 0
    readonly property bool onDetailPage:   currentPage === 3
    readonly property bool onChooserPage:  currentPage === 2
    readonly property bool onAllSetPage:   currentPage === 4
    // true on any page that shows a single back-arrow pill
    readonly property bool pillSingleBack: onDetailPage

    property string osName: ""          // populated from /etc/os-release on startup

    // "" = nothing picked yet, "install" or "try" once a card is tapped.
    // Picking a card only highlights it — the forward arrow is what
    // actually commits to it (and stays disabled until something's picked).
    property string selectedChoice: ""
    readonly property bool fwdEnabled: !onChooserPage || selectedChoice !== ""

    // ── Animation state ────────────────────────────────────────────────────
    property int  helloCharCount: 0     // typewriter character counter
    property bool introAnimDone:  false // flips true when typewriter finishes
    property int  _prevPage:      0     // previous page (for slide direction)
    property bool _pagesReady:    false // guards against cold-start transition

    // Match whatever corner radius the window manager gives the window.
    // A true fullscreen window covers the whole (rectangular) display, so
    // no rounding is needed there — but when running windowed (e.g. GNOME's
    // client-side-decoration rounding during dev), the content needs to be
    // clipped to the same radius or the square background pokes out past
    // the window's rounded edges.
    property real cornerRadius: root.visibility === Window.FullScreen ? 0 : 20

    // the languages
    readonly property var greetings: [
        { hello: "Hello!",        ready: "Are you ready?"        },
        { hello: "¡Hola!",        ready: "¿Estás listo?"         },
        { hello: "Bonjour !",     ready: "Êtes-vous prêt ?"      },
        { hello: "你好！",         ready: "你准备好了吗？"         },
        { hello: "مرحباً!",       ready: "هل أنت مستعد؟"        },
        { hello: "こんにちは！",  ready: "準備はいいですか？"     },
        { hello: "Hallo!",        ready: "Bist du bereit?"       },
        { hello: "Ciao!",         ready: "Sei pronto?"           },
        { hello: "Olá!",          ready: "Você está pronto?"     },
        { hello: "Привет!",       ready: "Готов?"                },
        { hello: "Merhaba!",      ready: "Hazır mısın?"          },
        { hello: "नमस्ते!",       ready: "क्या आप तैयार हैं?"    },
        { hello: "Hej!",          ready: "Är du redo?"           },
        { hello: "سلام!",         ready: "آماده‌ای؟"             },
        { hello: "Γεια σου!",     ready: "Είσαι έτοιμος;"        },
        { hello: "Hello!",        ready: "C'mon start the setup already"        },
    ]

    // timer for switching
    Timer {
        id: langTimer
        interval: 3200
        running: !root.hasStarted
        repeat: true
        onTriggered: langFadeOut.start()
    }

    SequentialAnimation {
        id: langFadeOut
        NumberAnimation {
            target: greetGroup; property: "opacity"
            to: 0; duration: 280; easing.type: Easing.InQuad
        }
        ScriptAction {
            script: root.langIndex = (root.langIndex + 1) % root.greetings.length
        }
        NumberAnimation {
            target: greetGroup; property: "opacity"
            to: 1; duration: 280; easing.type: Easing.OutQuad
        }
    }

    // ── Typewriter: bouncy character-reveal for "Hello!" (intro only) ──────
    Timer {
        id: typewriterTimer
        interval: 85
        running: true
        repeat: true
        onTriggered: {
            if (root.helloCharCount < root.greetings[0].hello.length) {
                root.helloCharCount++
                charBounce.restart()
            } else {
                root.introAnimDone = true
                typewriterTimer.stop()
            }
        }
    }


    // ── Battery status ─────────────────────────────────────────────────────
    property int  batteryPercent:  controller.battery_percent()
    property bool batteryCharging: controller.battery_charging()

    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: {
            root.batteryPercent  = controller.battery_percent()
            root.batteryCharging = controller.battery_charging()
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // SCENE ROOT — everything gets clipped to cornerRadius as one unit
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: sceneRoot
        anchors.fill: parent
        layer.enabled: root.cornerRadius > 0
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

    // ══════════════════════════════════════════════════════════════════════
    // BACKGROUND  — light-blue base + blurred floating blobs
    // ══════════════════════════════════════════════════════════════════════

    // Base layer (also used as ShaderEffectSource for the card blur)
    Item {
        id: bgScene
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: "assets/background.jpg"
            fillMode: Image.PreserveAspectCrop
        }


    // ══════════════════════════════════════════════════════════════════════
    // FROSTED-GLASS CARD
    // ══════════════════════════════════════════════════════════════════════

    // Capture the background under the card for backdrop blur
    ShaderEffectSource {
        id: cardBgCapture
        sourceItem: bgScene
        anchors.fill: frostedCard
        sourceRect: Qt.rect(frostedCard.x, frostedCard.y, frostedCard.width, frostedCard.height)
        visible: false
        live: true
    }

    // The card — clip: true rounds the blur + content together
    Rectangle {
        id: frostedCard
        width:  Math.min(root.width  * 0.70, 810)
        height: Math.min(root.height * 0.81, 550)
        anchors.centerIn: parent
        radius: 24
        clip: true
        color: "transparent"

        // Layer 1: blurred background
        FastBlur {
            anchors.fill: parent
            source: cardBgCapture
            radius: 48
        }

        // Layer 2: frosted white overlay
        Rectangle {
            anchors.fill: parent
            radius: frostedCard.radius
            color: Qt.rgba(1, 1, 1, 0.40)
        }

        // Layer 3: 1 px border (sits on top so radius matches)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: frostedCard.radius
            border.color: Qt.rgba(1, 1, 1, 0.68)
            border.width: 1
        }

        // ── PAGE 0 : Hello ─────────────────────────────────────────────────
        Item {
            id: helloPage
            anchors.fill: parent
            opacity: 1                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: helloPage.pageSlide }

            Column {
                id: greetGroup
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -24
                spacing: 10

                Text {
                    id: helloText
                    // Intro: show only typed portion of the first greeting.
                    // After intro: follow the cycling language index normally.
                    text: root.introAnimDone
                          ? root.greetings[root.langIndex].hello
                          : root.greetings[0].hello.substring(0, root.helloCharCount)
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.105, 64)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: readyText
                    text: root.greetings[root.langIndex].ready
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.037, 22)
                    font.weight: Font.Normal
                    color: "#555555"
                    // Hidden until typewriter completes, then fades in once.
                    // greetGroup's opacity handles the cycling animation after that.
                    opacity: root.introAnimDone ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutQuad } }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── PAGE 1 : Welcome / ToS ─────────────────────────────────────────
        Item {
            id: tosPage
            anchors.fill: parent
            opacity: 0                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: tosPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -24
                spacing: 10

                // Vamora logo
                Image {
                    id: vamoraLogo
                    source: "assets/Vamora.svg"
                    width: 88;  height: 88
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Vamora"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.078, 48)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "WELCOME TO YOUR NEW HOME"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.026, 16)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.6
                    color: "#333333"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ToS line with clickable link
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        text: "by continuing you are accepting our "
                        font.family: "Inter"
                        font.pixelSize: Math.min(frostedCard.width * 0.024, 14)
                        color: "#555555"
                    }

                    Text {
                        text: "Terms of Service"
                        font.family: "Inter"
                        font.pixelSize: Math.min(frostedCard.width * 0.024, 14)
                        color: "#4477DD"
                        font.underline: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // No internet during setup — show the ToS in-app
                            // instead of trying to open a browser.
                            onClicked: root.currentPage = 3
                        }
                    }
                }
            }
        }

        // ── PAGE 2 : Terms of Service (full text, shown in-app) ────────────
        Item {
            id: tosDetailPage
            anchors.fill: parent
            opacity: 0                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: tosDetailPage.pageSlide }

            Text {
                id: tosDetailTitle
                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Terms of Service"
                font.family: "Inter"
                font.pixelSize: Math.min(frostedCard.width * 0.045, 24)
                font.weight: Font.Bold
                color: "#111111"
            }

            Flickable {
                id: tosFlick
                anchors.top: tosDetailTitle.bottom
                anchors.topMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 78
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 34
                anchors.rightMargin: 34
                contentHeight: tosBody.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                Text {
                    id: tosBody
                    width: tosFlick.width
                    wrapMode: Text.WordWrap
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.0215, 13)
                    lineHeight: 1.4
                    color: "#333333"
                    text:
                        "This is placeholder Terms of Service text for VamoraOS. Replace it " +
                        "with your real terms before shipping.\n\n" +
                        "1. Acceptance of Terms\n" +
                        "By setting up and using VamoraOS, you agree to be bound by these terms. " +
                        "If you do not agree, please discontinue setup.\n\n" +
                        "2. Use of the Software\n" +
                        "VamoraOS is provided to help you manage your device. You agree to use it " +
                        "only for lawful purposes and in accordance with any additional policies " +
                        "provided with your device.\n\n" +
                        "3. Data and Privacy\n" +
                        "Details on what data VamoraOS collects, how it is stored, and how it is " +
                        "used will be described here. Replace this section with your actual " +
                        "privacy practices.\n\n" +
                        "4. Updates\n" +
                        "VamoraOS may receive updates that add, change, or remove functionality. " +
                        "Continued use of the software after an update constitutes acceptance of " +
                        "any revised terms.\n\n" +
                        "5. Limitation of Liability\n" +
                        "VamoraOS is provided \"as is\" without warranties of any kind, express or " +
                        "implied, to the fullest extent permitted by law.\n\n" +
                        "6. Contact\n" +
                        "Questions about these terms can be directed to your device's support " +
                        "channel."
                }
            }
        }

        // ── PAGE 2 : Install or Try ────────────────────────────────────────
        Item {
            id: chooserPage
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: chooserPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -16
                spacing: 20

                Text {
                    text: "Choose your path"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.050, 30)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ── Install card ────────────────────────────────────────
                    Rectangle {
                        id: installCard
                        readonly property bool selected: root.selectedChoice === "install"

                        width:  Math.min(frostedCard.width * 0.34, 172)
                        height: Math.min(frostedCard.height * 0.40, 158)
                        radius: 18
                        scale: selected ? 1.045 : 1.0
                        color:  selected
                                ? Qt.rgba(0.22, 0.53, 1.0, 0.22)
                                : installHover.containsMouse
                                  ? Qt.rgba(0.22, 0.53, 1.0, 0.18)
                                  : Qt.rgba(1, 1, 1, 0.52)
                        border.color: selected
                                      ? "#2C6FEA"
                                      : installHover.containsMouse
                                        ? Qt.rgba(0.22, 0.53, 1.0, 0.55)
                                        : Qt.rgba(1, 1, 1, 0.72)
                        border.width: selected ? 2.5 : 1.5
                        Behavior on scale        { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 4 } }
                        Behavior on color        { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on border.width { NumberAnimation { duration: 160 } }

                        HoverHandler { id: installHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Tapping only selects the card — the forward
                            // arrow on the nav pill is what commits to it.
                            onClicked: root.selectedChoice = "install"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                id: installIconSrc
                                width: 32;  height: 32
                                sourceSize: Qt.size(width, height)
                                source: "assets/icons/download.svg"
                                visible: false
                            }
                            ColorOverlay {
                                width: installIconSrc.width;  height: installIconSrc.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: installIconSrc
                                color: installCard.selected ? "#2C6FEA" : "#333333"
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            Text {
                                text: "Install"
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.030, 17)
                                font.weight: Font.SemiBold
                                color: "#111111"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.osName
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.023, 13)
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // ── Try card ────────────────────────────────────────────
                    Rectangle {
                        id: tryCard
                        readonly property bool selected: root.selectedChoice === "try"

                        width:  Math.min(frostedCard.width * 0.34, 172)
                        height: Math.min(frostedCard.height * 0.40, 158)
                        radius: 18
                        scale: selected ? 1.045 : 1.0
                        color:  selected
                                ? Qt.rgba(0.22, 0.53, 1.0, 0.22)
                                : tryHover.containsMouse
                                  ? Qt.rgba(0.22, 0.53, 1.0, 0.18)
                                  : Qt.rgba(1, 1, 1, 0.52)
                        border.color: selected
                                      ? "#2C6FEA"
                                      : tryHover.containsMouse
                                        ? Qt.rgba(0.22, 0.53, 1.0, 0.55)
                                        : Qt.rgba(1, 1, 1, 0.72)
                        border.width: selected ? 2.5 : 1.5
                        Behavior on scale        { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 4 } }
                        Behavior on color        { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on border.width { NumberAnimation { duration: 160 } }

                        HoverHandler { id: tryHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Tapping only selects the card — the forward
                            // arrow on the nav pill is what commits to it.
                            onClicked: root.selectedChoice = "try"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                id: tryIconSrc
                                width: 32;  height: 32
                                sourceSize: Qt.size(width, height)
                                source: "assets/icons/play.svg"
                                visible: false
                            }
                            ColorOverlay {
                                width: tryIconSrc.width;  height: tryIconSrc.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: tryIconSrc
                                color: tryCard.selected ? "#2C6FEA" : "#333333"
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            Text {
                                text: "Try"
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.030, 17)
                                font.weight: Font.SemiBold
                                color: "#111111"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.osName
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.023, 13)
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }

        // ── PAGE 4 : All set (Try mode confirmed) ──────────────────────────
        Item {
            id: allSetPage
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: allSetPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -28
                spacing: 10

                Image {
                    id: checkIconSrc
                    width: Math.min(frostedCard.width * 0.11, 60)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/check.svg"
                    visible: false
                }
                ColorOverlay {
                    width: checkIconSrc.width;  height: checkIconSrc.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: checkIconSrc
                    color: "#2DBD6E"
                    scale: root.onAllSetPage ? 1.0 : 0.4
                    transformOrigin: Item.Center
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 6 } }
                }

                Text {
                    text: "You're all set!"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.075, 44)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.osName + " is ready to try"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.032, 19)
                    font.weight: Font.Normal
                    color: "#555555"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── NAVIGATION PILL ────────────────────────────────────────────────
        //
        //  Page 0 (not started):  [  →  ]  blue pill, single right arrow
        //  Page 1 (Welcome/ToS):  [  ←  →  ]  frosted, both arrows
        //  Page 2 (Install/Try):  [  ←  →  ]  frosted, both arrows — → is
        //                          grayed out/disabled until a card is picked
        //  Page 3 (ToS text):     [  ←  ]  frosted, single back arrow
        //  Page 4 (All set):      [  →  ]  blue pill again, single right arrow (exits)
        //
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            width:  navPill.width
            height: navPill.height

            Rectangle {
                id: navPill
                width: {
                    if (!root.hasStarted)    return 125   // initial blue → pill
                    if (root.pillSingleBack) return 125   // frosted ← only
                    if (root.onAllSetPage)   return 125   // frosted → only (exits)
                    return 150                            // frosted ← | →
                }
                height: 45
                radius: height / 2
                // All-set page matches the very first pill's blue, not the
                // frosted look used everywhere in between.
                readonly property bool isBluePill: !root.hasStarted || root.onAllSetPage
                color:  isBluePill ? "#4DA8FF" : Qt.rgba(1, 1, 1, 0.60)
                border.color: isBluePill ? "transparent" : Qt.rgba(0, 0, 0, 0.10)
                border.width: 1

                Behavior on width {
                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                }
                Behavior on color   { ColorAnimation { duration: 240 } }
                Behavior on border.color { ColorAnimation { duration: 240 } }

                // ── Back button (dual-arrow state: page 1 only) ─────────────
                Item {
                    id: backBtn
                    visible: !root.pillSingleBack && !root.onAllSetPage
                    width: 84;  height: parent.height
                    anchors.left: parent.left
                    opacity: root.hasStarted ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.currentPage > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.hasStarted && root.currentPage > 1
                        onClicked: if (root.currentPage > 1) root.currentPage--
                    }

                    Image {
                        id: backArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-left.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: backArrow
                        source: backArrow
                        color: "#000000"
                        opacity: (root.hasStarted && root.currentPage > 1) ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }

                // ── Forward button ──────────────────────────────────────────
                Item {
                    id: fwdBtn
                    visible: !root.pillSingleBack
                    // Takes full pill width on all-set page (no back button there)
                    width: (root.hasStarted && !root.onAllSetPage) ? 84 : parent.width
                    height: parent.height
                    anchors.right: parent.right
                    opacity: root.fwdEnabled ? 1.0 : 0.4
                    Behavior on width   { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.fwdEnabled
                        cursorShape: root.fwdEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!root.hasStarted) {
                                // First press: morph pill, go to Welcome/ToS
                                root.hasStarted  = true
                                root.currentPage = 1
                            } else if (root.onAllSetPage) {
                                // All-set page → exit to live session
                                controller.finish_setup()
                            } else if (root.onChooserPage) {
                                // Commit whichever card was picked
                                if (root.selectedChoice === "install") {
                                    controller.launch_installer()
                                } else if (root.selectedChoice === "try") {
                                    root.currentPage = 4
                                }
                            } else if (root.currentPage < 2) {
                                // Page 1 → page 2 (Install/Try chooser)
                                root.currentPage++
                            }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-right.svg"
                        // Tint: white on blue pill, black on frosted pill
                        // Qt SVG colorization via ColorOverlay
                    }

                    ColorOverlay {
                        anchors.fill: fwdArrow
                        source: fwdArrow
                        color: navPill.isBluePill ? "#ffffff" : "#000000"
                        Behavior on color { ColorAnimation { duration: 240 } }
                    }

                    Image {
                        id: fwdArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-right.svg"
                        visible: false   // rendered only by the ColorOverlay above
                    }
                }

                // ── Back-only button (ToS detail page 3) ────────────────────
                Item {
                    id: backOnlyBtn
                    visible: root.pillSingleBack
                    anchors.fill: parent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = 1
                    }

                    Image {
                        id: backOnlyArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-left.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: backOnlyArrow
                        source: backOnlyArrow
                        color: "#000000"
                    }
                }
            }
        }
    }
    } // end bgScene

    // ══════════════════════════════════════════════════════════════════════
    // TOP BAR  ——  VAMORAOS  (left)   battery (right)
    // ══════════════════════════════════════════════════════════════════════

    Item {
        id: topBar
        x: 0;  y: 14
        width: parent.width;  height: 32

        Text {
            text: "VamoraOS Setup"
            anchors.left: parent.left;  anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 2.0
            color: "#1a1a1a"
        }

        // Battery indicator — hidden entirely if no battery is detected
        // (e.g. running on a desktop dev box with no /sys/class/power_supply
        // BAT* entry).
        Row {
            anchors.right: parent.right;  anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.batteryPercent >= 0

            // ── Battery icon: outline + proportional fill + charging bolt ──
            Item {
                id: batteryIcon
                width: 22;  height: 13
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: batteryOutlineSrc
                    anchors.fill: parent
                    fillMode: Image.Stretch
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/battery.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: batteryOutlineSrc
                    source: batteryOutlineSrc
                    color: "#1a1a1a"
                }

                // Charge-level fill, inset inside the battery body
                Rectangle {
                    anchors.left: parent.left;   anchors.leftMargin: 3
                    anchors.top: parent.top;     anchors.topMargin: 3
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    radius: 1
                    color: "#1a1a1a"
                    width: Math.max(0, (parent.width - 8) * (root.batteryPercent / 100))
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                }
            }

            // Charging bolt — sits beside the icon rather than on top of it,
            // so it stays visible black-on-light-background at any charge level.
            Item {
                width: 11;  height: 11
                anchors.verticalCenter: parent.verticalCenter
                visible: root.batteryCharging

                Image {
                    id: zapSrc
                    anchors.fill: parent
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/zap.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: zapSrc
                    source: zapSrc
                    color: "#1a1a1a"
                }
            }

            Text {
                text: root.batteryPercent + "%"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#1a1a1a"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    } // end sceneRoot

    // Mask used by sceneRoot's OpacityMask — invisible, just defines the shape
    Rectangle {
        id: cornerMask
        anchors.fill: sceneRoot
        radius: root.cornerRadius
        visible: false
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE TRANSITIONS  — slide + fade in/out on every page change
    // ══════════════════════════════════════════════════════════════════════

    // Wait one event-loop tick after startup so the initial state doesn't
    // trigger a spurious transition.
    Timer {
        id: pagesReadyTimer
        interval: 0; running: true; repeat: false
        onTriggered: root._pagesReady = true
    }

    onCurrentPageChanged: {
        if (!root._pagesReady) return

        var dir      = currentPage > _prevPage ? 1 : -1
        var allPages = [helloPage, tosPage, chooserPage, tosDetailPage, allSetPage]
        var leaving  = allPages[_prevPage]
        var entering = allPages[currentPage]
        _prevPage    = currentPage

        // Slide + fade the leaving page out
        leavingOpacity.target = leaving
        leavingOpacity.start()
        leavingSlide.target = leaving
        leavingSlide.to = -28 * dir
        leavingSlide.start()

        // Prime the entering page just off-screen, then bring it in
        entering.pageSlide = 28 * dir
        entering.opacity   = 0
        enterDelay.pendingPage = entering
        enterDelay.restart()
    }

    // ── Leaving page ───────────────────────────────────────────────────────
    NumberAnimation {
        id: leavingOpacity
        property: "opacity"; to: 0
        duration: 200; easing.type: Easing.InQuad
    }
    NumberAnimation {
        id: leavingSlide
        property: "pageSlide"
        duration: 220; easing.type: Easing.InQuad
    }

    // ── Entering page (starts slightly after leaving begins) ──────────────
    NumberAnimation {
        id: enteringOpacity
        property: "opacity"; to: 1
        duration: 310; easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: enteringSlide
        property: "pageSlide"; to: 0
        duration: 390; easing.type: Easing.OutBack
        easing.overshoot: 0.7
    }

    Timer {
        id: enterDelay
        interval: 55; repeat: false
        property var pendingPage: null
        onTriggered: {
            if (pendingPage === null) return
            enteringOpacity.target = pendingPage
            enteringOpacity.start()
            enteringSlide.target = pendingPage
            enteringSlide.start()
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // KEYBOARD SHORTCUTS
    // ══════════════════════════════════════════════════════════════════════

    // Left/Right pick a card (Install is on the left, Try is on the right);
    // Enter/Return commits whichever one is currently selected — same as
    // tapping the forward arrow.
    Shortcut {
        sequence: "Left"
        enabled: root.onChooserPage
        onActivated: root.selectedChoice = "install"
    }
    Shortcut {
        sequence: "Right"
        enabled: root.onChooserPage
        onActivated: root.selectedChoice = "try"
    }
    Shortcut {
        sequence: "Return"
        enabled: root.onChooserPage && root.selectedChoice !== ""
        onActivated: {
            if (root.selectedChoice === "install") {
                controller.launch_installer()
            } else if (root.selectedChoice === "try") {
                root.currentPage = 4
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Q"
        context: Qt.ApplicationShortcut
        onActivated: controller.request_exit()
    }

}
