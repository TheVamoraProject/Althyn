import QtQuick
import QtQuick.Window
import "../components"
import com.vamora

Window {
    id: window
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.NoDropShadowWindowHint
    title: "Vamora Dock"

    // ---- Vamora/AlthynUI palette (dark only, zinc) ----
    readonly property color cBarBg: "#CC09090b"
    readonly property color cBorder: "#26ffffff"

    readonly property int iconSize: 52
    readonly property int iconSpacing: 10
    readonly property int dockPadding: 10
    readonly property int dockMarginBottom: 10
    readonly property int slideDuration: 220
    // Extra space reserved above the bar so DockIcon's hover tooltip has
    // somewhere to render — without this the window is exactly bar-height
    // tall and the tooltip gets clipped by the window's own top edge.
    readonly property int tooltipHeadroom: 40
    // How tall the actual OS window is while "hidden": a thin sliver
    // spanning the full screen width, so the mouse can still be detected
    // anywhere along the bottom edge to re-summon the dock, while the rest
    // of the screen's bottom edge stays free for clicks into whatever's
    // maximized underneath. Kept at 3px rather than a literal 1px — a
    // single device pixel is thinner than normal mouse jitter, so the
    // cursor kept drifting in and out of it on its own and re-triggering
    // the whole show/hide cycle even with the hover debounce below.
    readonly property int hiddenWindowHeight: 3
    readonly property int visibleWindowHeight: iconSize + dockPadding * 2 + dockMarginBottom + tooltipHeadroom

    property var dummyApps: []
    readonly property int dockBarWidth: dummyApps.length > 0
        ? dummyApps.length * iconSize + (dummyApps.length - 1) * iconSpacing + dockPadding * 2
        : iconSize + dockPadding * 2

    width: screen.width
    // No Behavior here on purpose — resizing the actual OS window every
    // animation frame is what caused the lag. The window snaps instantly;
    // only the bar inside it animates. See windowExpanded below.
    height: windowExpanded ? visibleWindowHeight : hiddenWindowHeight
    x: 0
    y: screen.height - height

    DockModel {
        id: dockModel
    }

    DockAutoHide {
        id: autoHide
    }

    Component.onCompleted: dummyApps = JSON.parse(dockModel.getDummyAppsJson())

    property bool systemWantsHide: false
    readonly property bool hoverRaw: revealArea.containsMouse || dockMouseTracker.containsMouse
    // Debounced: hoverRaw can flicker for a moment when the window itself
    // resizes (WMs sometimes emit a spurious enter/leave around a native
    // resize or restack), which without this caused the dock to bounce up
    // and down rapidly while hovering it over a maximized window. Entering
    // reacts instantly; leaving has to hold for a beat before it counts.
    property bool hovered: false
    onHoverRawChanged: {
        if (hoverRaw) {
            hoverLeaveGrace.stop()
            window.hovered = true
        } else {
            hoverLeaveGrace.restart()
        }
    }

    Timer {
        id: hoverLeaveGrace
        interval: 150
        onTriggered: window.hovered = false
    }

    // Whether the dock SHOULD be visible right now.
    readonly property bool wantVisible: !systemWantsHide || hovered
    // Whether the OS window is currently full-sized. Kept separate from
    // wantVisible so the window only shrinks once the bar has finished
    // sliding out of view — never mid-animation.
    property bool windowExpanded: true

    onWantVisibleChanged: {
        if (wantVisible) {
            // Showing: expand the window FIRST, in the same tick — so the
            // slide-up animation that follows has full room and never
            // fights a resizing window. Cancel any pending shrink.
            hideDelayTimer.stop()
            windowExpanded = true
        } else {
            // Hiding: let the bar slide down first, inside the still
            // full-size window. Only shrink the window once that's done.
            hideDelayTimer.restart()
        }
    }

    Timer {
        id: hideDelayTimer
        interval: window.slideDuration
        onTriggered: window.windowExpanded = false
    }

    // Poll rather than push from a background thread — simplest option
    // while the dock only has dummy icons. shouldHide() is true whenever
    // the active window is maximized, except when it's vamora-homescreen.
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: window.systemWantsHide = autoHide.shouldHide()
    }

    // Covers the whole window, whatever its current height is — the 1px
    // hidden strip included — so hovering it re-summons the dock.
    MouseArea {
        id: revealArea
        anchors.fill: parent
        hoverEnabled: true
    }

    Rectangle {
        id: dockBar
        width: window.dockBarWidth
        height: window.iconSize + window.dockPadding * 2
        radius: 18
        color: window.cBarBg
        border.width: 1
        border.color: window.cBorder
        anchors.horizontalCenter: parent.horizontalCenter

        // Slides within the (already full-size, while showing/hiding) window.
        // Visible: hugs the window's bottom edge, dockMarginBottom above it,
        // with tooltipHeadroom left free above for DockIcon's hover label.
        // Hidden: sits fully past the window's bottom edge, clipped away —
        // this is the only thing that animates; the window itself doesn't.
        y: window.wantVisible
            ? window.visibleWindowHeight - height - window.dockMarginBottom
            : window.visibleWindowHeight + 4

        Behavior on y {
            NumberAnimation { duration: window.slideDuration; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: dockMouseTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Row {
            anchors.centerIn: parent
            spacing: window.iconSpacing

            Repeater {
                model: window.dummyApps

                delegate: DockIcon {
                    baseSize: window.iconSize
                    iconSource: modelData.iconPath
                    appName: modelData.appName
                    onClicked: dockModel.launchApp(modelData.appName)
                }
            }
        }
    }
}
