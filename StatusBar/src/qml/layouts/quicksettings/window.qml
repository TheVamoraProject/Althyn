import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "../components"
import com.vamora

Window {
    id: window
    width: 348
    height: 548
    visible: true
    color: "transparent"
    title: "Vamora Quick Settings"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // The control center uses the same zinc palette and rounded tile language
    // as the homescreen.
    readonly property color cBg: isDark ? "#18181b" : "#fafafa"
    readonly property color cTopBar: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cBorder: isDark ? "#3f3f46" : "#d4d4d8"
    readonly property color cSurface: isDark ? "#27272a" : "#f4f4f5"
    readonly property color cSurfaceHover: isDark ? "#3f3f46" : "#e4e4e7"
    readonly property color cText: isDark ? "#f4f4f5" : "#18181b"
    readonly property color cTextMuted: isDark ? "#a1a1aa" : "#52525b"
    readonly property color cTextFaint: "#71717a"
    readonly property color cAccent: isDark ? "#ffffff" : "#18181b"
    readonly property color cOnAccent: isDark ? "#09090b" : "#fafafa"

    readonly property int gridColumns: 4
    readonly property int gridGap: 10
    // Use the computed column width for both axes so a 1x1 tile is exactly
    // square on every panel width.
    readonly property real gridUnitHeight: gridUnitWidth()

    property bool isDark: true
    property bool editMode: false
    property var addTileDialog: null

    AppList {
        id: appList
    }

    ThemeManager {
        id: themeManager
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: isDark = themeManager.refresh()
    }

    onActiveChanged: {
        if (!active && (!addTileDialog || !addTileDialog.visible)) {
            if (addTileDialog)
                addTileDialog.close()
            window.close()
        }
    }

    onClosing: {
        if (addTileDialog)
            addTileDialog.close()
    }

    function gridUnitWidth() {
        return (toggleGrid.width - gridGap * (gridColumns - 1)) / gridColumns
    }

    function openAddTileMenu() {
        if (!addTileDialog) {
            var component = Qt.createComponent(
                "qrc:/layouts/quicksettings/addtile.qml",
                Component.PreferSynchronous)
            if (component.status === Component.Ready)
                addTileDialog = component.createObject(null)
        }
        if (!addTileDialog)
            return

        addTileDialog.isDark = isDark
        addTileDialog.hostX = x
        addTileDialog.hostY = y
        addTileDialog.hostWidth = width
        addTileDialog.hostHeight = height
        addTileDialog.openAt()
    }

    function bumpGrid() {
        // ListModel role changes do not invalidate a function that scans the
        // model, so use a revision property to make the grid height reactive.
        toggleGrid.layoutRevision += 1
    }

    function modelIndex(key) {
        for (var i = 0; i < toggleModel.count; ++i) {
            if (toggleModel.get(i).key === key)
                return i
        }
        return -1
    }

    function canPlace(key, column, row, columns, rows) {
        if (column < 0 || row < 0 ||
            column + columns > gridColumns || row > 99)
            return false

        for (var i = 0; i < toggleModel.count; ++i) {
            var other = toggleModel.get(i)
            if (other.key === key)
                continue
            if (column < other.gridX + other.colSpan &&
                column + columns > other.gridX &&
                row < other.gridY + other.rowSpan &&
                row + rows > other.gridY)
                return false
        }
        return true
    }

    function findAvailablePosition(key, columns, rows, startRow) {
        var firstRow = Math.max(0, Math.min(99, Math.round(startRow)))
        for (var row = firstRow; row <= 99 - rows; ++row) {
            for (var column = 0; column <= gridColumns - columns; ++column) {
                if (canPlace(key, column, row, columns, rows))
                    return { column: column, row: row }
            }
        }

        // If the preferred line is full, wrap around and use any free space.
        for (var earlierRow = 0; earlierRow < firstRow; ++earlierRow) {
            for (var earlierColumn = 0;
                 earlierColumn <= gridColumns - columns;
                 ++earlierColumn) {
                if (canPlace(key, earlierColumn, earlierRow,
                             columns, rows))
                    return { column: earlierColumn, row: earlierRow }
            }
        }
        return null
    }

    function moveTile(key, column, row) {
        var index = modelIndex(key)
        if (index < 0)
            return

        var item = toggleModel.get(index)
        var nextColumn = Math.max(0, Math.min(gridColumns - item.colSpan,
            Math.round(column)))
        var nextRow = Math.max(0, Math.min(99, Math.round(row)))
        if (!canPlace(key, nextColumn, nextRow, item.colSpan, item.rowSpan))
            return

        toggleModel.setProperty(index, "gridX", nextColumn)
        toggleModel.setProperty(index, "gridY", nextRow)
        bumpGrid()
    }

    function resizeTile(key, columns, rows) {
        var index = modelIndex(key)
        if (index < 0)
            return

        var item = toggleModel.get(index)
        var oldColumns = item.colSpan
        var oldRows = item.rowSpan
        var nextColumns = Math.max(1, Math.min(gridColumns,
            Math.round(columns)))
        var nextRows = Math.max(1, Math.min(4, Math.round(rows)))

        var position
        if (canPlace(key, item.gridX, item.gridY,
                     nextColumns, nextRows)) {
            position = { column: item.gridX, row: item.gridY }
        } else {
            // Keep the tile being resized anchored. Move the tiles that
            // block its new footprint down to the next free line instead.
            var blockers = []
            for (var blockerIndex = 0;
                 blockerIndex < toggleModel.count; ++blockerIndex) {
                var blocker = toggleModel.get(blockerIndex)
                if (blocker.key === key)
                    continue
                if (item.gridX < blocker.gridX + blocker.colSpan &&
                    item.gridX + nextColumns > blocker.gridX &&
                    item.gridY < blocker.gridY + blocker.rowSpan &&
                    item.gridY + nextRows > blocker.gridY)
                    blockers.push({
                        key: blocker.key,
                        colSpan: blocker.colSpan,
                        rowSpan: blocker.rowSpan
                    })
            }

            // Reserve the requested footprint while finding homes for the
            // blockers. canPlace() will then treat the resized tile as the
            // immovable obstacle.
            toggleModel.setProperty(index, "colSpan", nextColumns)
            toggleModel.setProperty(index, "rowSpan", nextRows)

            for (var movedIndex = 0; movedIndex < blockers.length;
                 ++movedIndex) {
                var moved = blockers[movedIndex]
                var movedPosition = findAvailablePosition(
                    moved.key, moved.colSpan, moved.rowSpan, item.gridY + 1)
                if (!movedPosition) {
                    toggleModel.setProperty(index, "colSpan", oldColumns)
                    toggleModel.setProperty(index, "rowSpan", oldRows)
                    return
                }
                var movedModelIndex = modelIndex(moved.key)
                toggleModel.setProperty(movedModelIndex, "gridX",
                    movedPosition.column)
                toggleModel.setProperty(movedModelIndex, "gridY",
                    movedPosition.row)
            }

            bumpGrid()
            return
        }

        if (!position)
            return

        if (item.gridX !== position.column)
            toggleModel.setProperty(index, "gridX", position.column)
        if (item.gridY !== position.row)
            toggleModel.setProperty(index, "gridY", position.row)
        toggleModel.setProperty(index, "colSpan", nextColumns)
        toggleModel.setProperty(index, "rowSpan", nextRows)
        bumpGrid()
    }

    function saveLayout() {
        var saved = []
        for (var i = 0; i < toggleModel.count; ++i) {
            var item = toggleModel.get(i)
            saved.push({
                key: item.key,
                colSpan: item.colSpan,
                rowSpan: item.rowSpan,
                gridX: item.gridX,
                gridY: item.gridY,
                value: item.value
            })
        }
        appList.saveQuickSettingsLayout(JSON.stringify(saved))
    }

    function loadLayout() {
        var raw = String(appList.getQuickSettingsLayout())
        if (!raw)
            return

        try {
            var saved = JSON.parse(raw)
            if (!Array.isArray(saved))
                return

            for (var i = 0; i < saved.length; ++i) {
                var savedItem = saved[i]
                var index = modelIndex(savedItem.key)
                if (index < 0)
                    continue

                var current = toggleModel.get(index)
                var columns = Math.max(1, Math.min(gridColumns,
                    Number(savedItem.colSpan) || current.colSpan))
                var rows = Math.max(1, Math.min(4,
                    Number(savedItem.rowSpan) || current.rowSpan))
                var column = Math.max(0, Math.min(gridColumns - columns,
                    Number(savedItem.gridX) || 0))
                var row = Math.max(0, Math.min(99,
                    Number(savedItem.gridY) || 0))

                toggleModel.setProperty(index, "colSpan", columns)
                toggleModel.setProperty(index, "rowSpan", rows)
                toggleModel.setProperty(index, "gridX", column)
                toggleModel.setProperty(index, "gridY", row)
                if (current.kind === "slider" &&
                    Number(savedItem.value) >= 0)
                    toggleModel.setProperty(index, "value",
                        Math.max(0, Math.min(1, Number(savedItem.value))))
            }
            bumpGrid()
        } catch (error) {
            // Malformed preferences must never prevent the panel opening.
        }
    }

    Component.onCompleted: {
        loadLayout()
        entranceAnimation.start()
    }

    ListModel {
        id: toggleModel

        // gridX/gridY are the top-left cell. colSpan is horizontal and
        // rowSpan is vertical. The default 2x1 form is the requested
        // horizontal "1x2" control.
        ListElement {
            key: "wifi"
            label: "Wi-Fi"
            sub: "Vamora-5G"
            icon: "../../assets/icons/wifi/wifi.svg"
            kind: "toggle"
            on: true
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 0
            gridY: 0
        }
        ListElement {
            key: "notifications"
            label: "Notifications"
            sub: "Do Not Disturb"
            icon: "../../assets/icons/notification/bell.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 2
            gridY: 0
        }
        ListElement {
            key: "awake"
            label: "Keep Awake"
            sub: "Prevent sleep"
            icon: "../../assets/icons/cafeine.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 0
            gridY: 1
        }
        ListElement {
            key: "top"
            label: "Always on Top"
            sub: "Pin windows"
            icon: "../../assets/icons/pin.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 2
            gridY: 1
        }
        ListElement {
            key: "usb"
            label: "USB Devices"
            sub: "Manage devices"
            icon: "../../assets/icons/usb.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 0
            gridY: 2
        }
        ListElement {
            key: "workspaces"
            label: "Workspaces"
            sub: "Overview"
            icon: "../../assets/icons/computer.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 2
            gridY: 2
        }
        ListElement {
            key: "sharing"
            label: "File Sharing"
            sub: "Nearby devices"
            icon: "../../assets/icons/folder.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 0
            gridY: 3
        }
        ListElement {
            key: "focus"
            label: "Focus Mode"
            sub: "Quiet workspace"
            icon: "../../assets/icons/info.svg"
            kind: "toggle"
            on: false
            value: 0
            colSpan: 2
            rowSpan: 1
            gridX: 2
            gridY: 3
        }
        ListElement {
            key: "volume"
            label: "Volume"
            sub: "65%"
            icon: "../../assets/icons/volume-2.svg"
            kind: "slider"
            on: false
            value: 0.65
            colSpan: 4
            rowSpan: 1
            gridX: 0
            gridY: 4
        }
        ListElement {
            key: "brightness"
            label: "Brightness"
            sub: "80%"
            icon: "../../assets/icons/monitor.svg"
            kind: "slider"
            on: false
            value: 0.8
            colSpan: 4
            rowSpan: 1
            gridX: 0
            gridY: 5
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: cBg
        border.color: cBorder
        border.width: 1
        radius: 32
        opacity: 0
        scale: 0.9
        transformOrigin: Item.TopRight
        transform: Translate {
            id: entranceOffset
            x: 24
            y: -24
        }

        Rectangle {
            id: topBar
            width: parent.width
            height: 50
            color: cTopBar
            radius: parent.radius

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: cBorder
            }

            Row {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: cSurface
                    border.width: 1
                    border.color: cBorder

                    Image {
                        anchors.centerIn: parent
                        source: "../../assets/icons/power.svg"
                        width: 15
                        height: 15
                        layer.enabled: true
                        layer.effect: ColorOverlay { color: cText }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = cSurfaceHover
                        onExited: parent.color = cSurface
                        onClicked: appList.launchApp("vamora-powermenu")
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: editMode ? cAccent : cSurface
                    border.width: 1
                    border.color: cBorder

                    Image {
                        anchors.centerIn: parent
                        source: "../../assets/icons/edit.svg"
                        width: 14
                        height: 14
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: editMode ? cOnAccent : cText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = editMode ? cAccent : cSurfaceHover
                        onExited: parent.color = editMode ? cAccent : cSurface
                        onClicked: editMode = !editMode
                    }
                }
            }

            Rectangle {
                x: parent.width - width - 16
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: cSurface
                border.width: 1
                border.color: cBorder

                Image {
                    anchors.centerIn: parent
                    source: "../../assets/icons/settings.svg"
                    width: 15
                    height: 15
                    layer.enabled: true
                    layer.effect: ColorOverlay { color: cText }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = cSurfaceHover
                    onExited: parent.color = cSurface
                    onClicked: appList.launchApp("vamora-settings")
                }
            }
        }

        Flickable {
            id: scrollView
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 1
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: cTextMuted
                    opacity: 0.65
                }
                background: null
            }

            Column {
                id: contentColumn
                width: scrollView.width - 32
                x: 16
                y: 14
                spacing: 12

                Text {
                    text: editMode ? "EDIT QUICK CONTROLS" : "QUICK CONTROLS"
                    color: editMode ? cText : cTextFaint
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                    font.family: "Inter"
                    leftPadding: 2
                }

                Item {
                    id: toggleGrid
                    width: parent.width
                    property int layoutRevision: 0
                    property int contentRows: {
                        var revision = layoutRevision
                        var rows = 1
                        for (var i = 0; i < toggleModel.count; ++i) {
                            var item = toggleModel.get(i)
                            rows = Math.max(rows, item.gridY + item.rowSpan)
                        }
                        return rows
                    }
                    implicitHeight: contentRows * window.gridUnitHeight +
                        Math.max(0, contentRows - 1) * window.gridGap
                    height: implicitHeight

                    Repeater {
                        model: toggleModel

                        delegate: QuickTile {
                            controlKey: model.key
                            spanColumns: model.colSpan
                            spanRows: model.rowSpan
                            tileLabel: model.label
                            tileSub: model.sub
                            tileIcon: model.icon
                            active: model.on
                            sliderControl: model.kind === "slider"
                            sliderValue: model.value

                            x: model.gridX *
                                (window.gridUnitWidth() + window.gridGap)
                                + dragOffsetX
                            y: model.gridY *
                                (window.gridUnitHeight + window.gridGap)
                                + dragOffsetY
                            width: spanColumns * window.gridUnitWidth() +
                                (spanColumns - 1) * window.gridGap
                            height: spanRows * window.gridUnitHeight +
                                (spanRows - 1) * window.gridGap

                            Behavior on x {
                                enabled: !dragArea.pressed
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on y {
                                enabled: !dragArea.pressed
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            onToggled: {
                                if (!window.editMode && !sliderControl)
                                    toggleModel.setProperty(index, "on",
                                        !model.on)
                            }
                            onMoveRequested: function(key, column, row) {
                                if (window.editMode)
                                    window.moveTile(key, column, row)
                            }
                            onResizeRequested: function(key, columns, rows) {
                                if (window.editMode)
                                    window.resizeTile(key, columns, rows)
                            }
                            onAddRequested: {
                                window.openAddTileMenu()
                            }
                            onStackSlotToggled: function(slot) {
                                // A stack owns its icon state, while empty
                                // slots remain add buttons.
                                if (slot === 0) {
                                    var item = toggleModel.get(index)
                                    toggleModel.setProperty(index, "on",
                                        !item.on)
                                }
                            }
                            onValueRequested: function(key, value) {
                                var itemIndex = window.modelIndex(key)
                                if (itemIndex >= 0)
                                    toggleModel.setProperty(itemIndex,
                                        "value", value)
                            }
                            onResizeFinished: window.saveLayout()
                            onMoveFinished: window.saveLayout()
                            onValueFinished: window.saveLayout()
                        }
                    }
                }
            }
        }
    }

    // iOS-like control-center entrance: start above and to the right of the
    // statusbar, then travel down-left into place.
    ParallelAnimation {
        id: entranceAnimation
        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.9
            to: 1
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        }
        NumberAnimation {
            target: entranceOffset
            property: "x"
            from: 24
            to: 0
            duration: 210
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: entranceOffset
            property: "y"
            from: -24
            to: 0
            duration: 210
            easing.type: Easing.OutCubic
        }
    }

    // 1x1 is icon-only. A one-dimensional span is horizontal. Any regular
    // tile with both dimensions above one becomes a mini icon stack.
    component QuickTile: Rectangle {
        id: tile

        property string controlKey: ""
        property int spanColumns: 1
        property int spanRows: 1
        property string tileLabel: ""
        property string tileSub: ""
        property url tileIcon
        property bool active: false
        property bool sliderControl: false
        property real sliderValue: 0.5
        property real dragOffsetX: 0
        property real dragOffsetY: 0

        signal toggled()
        signal moveRequested(string key, int column, int row)
        signal moveFinished()
        signal resizeRequested(string key, int columns, int rows)
        signal resizeFinished()
        signal addRequested(real x, real y)
        signal stackSlotToggled(int slot)
        signal valueRequested(string key, real value)
        signal valueFinished()

        readonly property bool isStack: !sliderControl &&
            spanColumns > 1 && spanRows > 1
        readonly property bool isCompact: spanColumns === 1 &&
            spanRows === 1
        readonly property bool isHorizontal: !isStack && !isCompact

        function stackControlCount() {
            return 1
        }

        function stackIcon(slot) {
            return tile.tileIcon
        }

        function stackSlotActive(slot) {
            return slot === 0 && tile.active
        }

        radius: 16
        color: (!isStack && active) ? cAccent :
            (tileMouse.containsMouse ? cSurfaceHover : cSurface)
        border.width: 1
        border.color: (!isStack && active) ? cAccent : cBorder

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            enabled: !window.editMode && !tile.isStack
            hoverEnabled: true
            preventStealing: true
            onClicked: tile.toggled()
        }

        Image {
            visible: tile.isCompact
            anchors.centerIn: parent
            width: Math.min(28, parent.width - 22)
            height: width
            source: tile.tileIcon
            fillMode: Image.PreserveAspectFit
            smooth: false
            sourceSize.width: 64
            sourceSize.height: 64
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: tile.active ? cOnAccent : cText
            }
        }

        Row {
            visible: tile.isHorizontal
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                width: Math.min(34, parent.height - 20)
                height: width
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                color: cBg

                Image {
                    anchors.centerIn: parent
                    width: Math.min(19, parent.width - 10)
                    height: width
                    source: tile.tileIcon
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    sourceSize.width: 64
                    sourceSize.height: 64
                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: tile.active ? cOnAccent : cText
                    }
                }
            }

            Column {
                width: Math.max(0, parent.width - 44)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: tile.tileLabel
                    color: tile.active ? cOnAccent : cText
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: "Inter"
                    width: parent.width
                    elide: Text.ElideRight
                }

                Text {
                    visible: !tile.sliderControl
                    text: tile.active ? tile.tileSub : "Off"
                    color: tile.active ? cOnAccent : cTextMuted
                    opacity: tile.active ? 0.7 : 1
                    font.pixelSize: 10
                    font.family: "Inter"
                    width: parent.width
                    elide: Text.ElideRight
                }

                Text {
                    visible: tile.sliderControl
                    text: Math.round(tile.sliderValue * 100) + "%"
                    color: cTextMuted
                    font.pixelSize: 10
                    font.family: "Inter"
                    width: parent.width
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: tile.sliderControl
                    id: sliderTrack
                    width: parent.width
                    height: 7
                    radius: 4
                    color: cBg

                    Rectangle {
                        width: Math.max(7, sliderTrack.width *
                            tile.sliderValue)
                        height: parent.height
                        radius: 4
                        color: cAccent
                    }

                    Rectangle {
                        x: Math.max(0, sliderTrack.width * tile.sliderValue -
                            width / 2)
                        y: (parent.height - height) / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: cText
                        border.width: 2
                        border.color: cBorder
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        onPressed: tile.valueRequested(tile.controlKey,
                            Math.max(0, Math.min(1, mouse.x / width)))
                        onPositionChanged: {
                            if (pressed)
                                tile.valueRequested(tile.controlKey,
                                    Math.max(0, Math.min(1,
                                        mouse.x / width)))
                        }
                        onReleased: tile.valueFinished()
                    }
                }
            }
        }

        GridLayout {
            visible: tile.isStack
            anchors.fill: parent
            anchors.margins: 10
            columns: tile.spanColumns
            rows: tile.spanRows
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: tile.spanColumns * tile.spanRows

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: 0
                    radius: 7
                    color: tile.stackSlotActive(index) ? cAccent :
                        (stackMouse.containsMouse ? cSurfaceHover :
                         Qt.darker(cSurface, 1.12))
                    border.width: tile.stackSlotActive(index) ? 1 : 0
                    border.color: cAccent

                    Image {
                        visible: index < tile.stackControlCount()
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.62
                        height: width
                        source: tile.stackIcon(index)
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        sourceSize.width: 64
                        sourceSize.height: 64
                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: tile.stackSlotActive(index) ? cOnAccent : cText
                        }
                    }

                    Text {
                        visible: index >= tile.stackControlCount()
                        anchors.centerIn: parent
                        text: "+"
                        color: cTextMuted
                        font.pixelSize: Math.max(12,
                            Math.min(parent.width, parent.height) * 0.45)
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: stackMouse
                        visible: index < tile.stackControlCount()
                        z: 7
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tile.stackSlotToggled(index)
                    }

                    MouseArea {
                        visible: index >= tile.stackControlCount()
                        z: 6
                        anchors.fill: parent
                        onClicked: {
                            window.openAddTileMenu()
                        }
                    }
                }
            }
        }

        // Edit-mode dragging is separate from the normal toggle MouseArea.
        // preventStealing keeps Flickable from taking a touch/mouse gesture
        // that began on a tile, so moving and resizing remain reliable.
        MouseArea {
            id: dragArea
            visible: window.editMode
            z: 5
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true

            property real startX: 0
            property real startY: 0
            property int startColumn: 0
            property int startRow: 0

            onPressed: {
                tile.dragOffsetX = 0
                tile.dragOffsetY = 0
                var point = dragArea.mapToItem(null, mouse.x, mouse.y)
                startX = point.x
                startY = point.y
                var itemIndex = window.modelIndex(tile.controlKey)
                if (itemIndex >= 0) {
                    startColumn = toggleModel.get(itemIndex).gridX
                    startRow = toggleModel.get(itemIndex).gridY
                }
                mouse.accepted = true
            }

            onPositionChanged: {
                if (!pressed)
                    return
                var point = dragArea.mapToItem(null, mouse.x, mouse.y)
                var deltaX = point.x - startX
                var deltaY = point.y - startY
                var column = startColumn +
                    Math.round(deltaX /
                        (window.gridUnitWidth() + window.gridGap))
                var row = startRow +
                    Math.round(deltaY /
                        (window.gridUnitHeight + window.gridGap))
                var itemIndex = window.modelIndex(tile.controlKey)
                if (itemIndex < 0)
                    return

                var item = toggleModel.get(itemIndex)
                var boundedColumn = Math.max(0, Math.min(
                    window.gridColumns - item.colSpan, column))
                var boundedRow = Math.max(0, Math.min(99, row))
                if (window.canPlace(tile.controlKey, boundedColumn,
                                    boundedRow, item.colSpan, item.rowSpan)) {
                    tile.dragOffsetX = deltaX -
                        (boundedColumn - startColumn) *
                        (window.gridUnitWidth() + window.gridGap)
                    tile.dragOffsetY = deltaY -
                        (boundedRow - startRow) *
                        (window.gridUnitHeight + window.gridGap)
                    tile.moveRequested(tile.controlKey, boundedColumn,
                                       boundedRow)
                } else {
                    tile.dragOffsetX = 0
                    tile.dragOffsetY = 0
                }
            }

            onReleased: {
                tile.dragOffsetX = 0
                tile.dragOffsetY = 0
                tile.moveFinished()
            }
        }

        Rectangle {
            id: resizeHandle
            visible: window.editMode
            z: 10
            width: 16
            height: 16
            radius: 5
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 7
            anchors.bottomMargin: 7
            color: "transparent"
            opacity: resizeMouse.containsMouse || resizeMouse.pressed ? 1 : 0.8

            // iOS-style resize affordance: only the thick, rounded corner is
            // visible; there is no square button behind it.
            Canvas {
                anchors.fill: parent
                anchors.margins: 1

                onPaint: {
                    var context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    context.strokeStyle = cText
                    context.lineWidth = 5
                    context.lineCap = "round"
                    context.lineJoin = "round"
                    context.beginPath()
                    context.moveTo(3, height - 4)
                    context.lineTo(width - 3, height - 4)
                    context.lineTo(width - 3, 3)
                    context.stroke()
                }
            }

            MouseArea {
                id: resizeMouse
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeFDiagCursor

                property real startX: 0
                property real startY: 0
                property real startWidth: 0
                property real startHeight: 0

                onPressed: {
                    var point = resizeHandle.mapToItem(null, mouse.x, mouse.y)
                    startX = point.x
                    startY = point.y
                    startWidth = tile.width
                    startHeight = tile.height
                    mouse.accepted = true
                }

                onPositionChanged: {
                    if (!pressed)
                        return

                    var point = resizeHandle.mapToItem(null, mouse.x, mouse.y)
                    var dx = point.x - startX
                    var dy = point.y - startY
                    var unitWidth = window.gridUnitWidth()
                    var columns = Math.max(1, Math.min(window.gridColumns,
                        Math.round((startWidth + dx + window.gridGap) /
                            (unitWidth + window.gridGap))))
                    var rows = Math.max(1, Math.min(4,
                        Math.round((startHeight + dy + window.gridGap) /
                            (window.gridUnitHeight + window.gridGap))))
                    tile.resizeRequested(tile.controlKey, columns, rows)
                }

                onReleased: tile.resizeFinished()
            }
        }
    }
}