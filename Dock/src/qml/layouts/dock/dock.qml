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

    property var apps: []
    property var windowStates: ({})
    readonly property int dockBarWidth: apps.length > 0
        ? apps.length * iconSize + (apps.length - 1) * iconSpacing + dockPadding * 2
        : iconSize + dockPadding * 2
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle), same
    // convention as the launcher, homescreen and start menu.
    property real iconCornerRadiusRaw: 8
    // Dock bar background follows the same corner-radius setting as the
    // icons inside it, scaled against its own height (32 = full pill,
    // same "32 at any size" convention as the icons).
    readonly property real dockBarRadius: Math.min(iconCornerRadiusRaw, 32) / 32 * ((iconSize + dockPadding * 2) / 2)

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

    function load() {
        apps = JSON.parse(dockModel.getAppsJson())
        refreshWindowStates()
        iconCornerRadiusRaw = parseFloat(dockModel.getIconCornerRadius()) || iconCornerRadiusRaw
    }

    function refreshWindowStates() {
        var parsed = JSON.parse(dockModel.getWindowStatesJson())
        var next = ({})
        for (var i = 0; i < parsed.length; ++i) {
            next[parsed[i].execStr] = parsed[i]
        }
        windowStates = next
    }

    function windowStateFor(execStr) {
        return windowStates[execStr] || { windowCount: 0, focusedIndex: -1 }
    }

    Component.onCompleted: load()

    // Dock contents (~/.VamoraSys/althyn/dock/contents/*.desktop) and
    // icons.corner_radius can both change while the dock is running —
    // the dock never closes, so it re-scans periodically rather than
    // only reading once at startup like the launcher does.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            apps = JSON.parse(dockModel.getAppsJson())
            var freshRadius = parseFloat(dockModel.getIconCornerRadius())
            if (!isNaN(freshRadius) && freshRadius !== window.iconCornerRadiusRaw) {
                window.iconCornerRadiusRaw = freshRadius
            }
        }
    }

    // Window state changes are much more frequent than dock-content changes.
    // Keep this poll cheap and separate so a focused window never rebuilds
    // the Repeater or interrupts its hover animation.
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: window.refreshWindowStates()
    }

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

    // Keep the reveal target fixed to the bottom edge instead of covering the
    // whole resizable window. When the dock expands, the cursor stays over
    // this same 3px strip instead of leaving a MouseArea that just moved
    // underneath it; that was the source of the up/down hover oscillation over
    // maximized X11 windows.
    MouseArea {
        id: revealArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: window.hiddenWindowHeight
        hoverEnabled: true
    }

    Rectangle {
        id: dockBar
        width: window.dockBarWidth
        height: window.iconSize + window.dockPadding * 2
        radius: window.dockBarRadius
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
                model: window.apps

                delegate: DockIcon {
                    baseSize: window.iconSize
                    iconSource: modelData.iconPath
                    appName: modelData.appName
                    directRound: !!modelData.directRound || modelData.iconPath === ""
                    bgColor: modelData.bgColor || ""
                    iconCornerRadiusRaw: window.iconCornerRadiusRaw
                    openWindowCount: window.windowStateFor(modelData.execStr).windowCount
                    focusedWindowIndex: window.windowStateFor(modelData.execStr).focusedIndex
                    onClicked: dockModel.launchApp(modelData.execStr)
                }
            }
        }
    }
}
