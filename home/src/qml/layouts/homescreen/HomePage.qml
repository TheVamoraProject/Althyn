import QtQuick

Item {
    id: page
    property var items: []
    property int cols: 4
    property int rows: 6
    property color textColor: "#f4f4f5"
    property color hoverColor: "#26f4f4f5"
    signal launch(string execStr)
    signal itemChanged(var item)
    signal appRightClicked(real x, real y, var itemData)
    signal bgRightClicked(real x, real y)
    // Fired when an item is dragged to (and held at) the left/right edge
    // of the page, requesting a move to the adjacent page. direction is
    // -1 (previous page) or +1 (next page).
    signal requestPageShift(var itemData, int direction)
    // Something was dropped on this page (see the DropArea below): either one
    // of our own icons (internal) or files from elsewhere. window.qml does the work.
    signal dropped(var info)
    // A drag that started on one of this page's icons has ended.
    signal dragFinished(var itemData, int dropAction)
    signal openFolder(string path)
    property int pageIndex: 0
    readonly property int pageCellW: Math.max(1, Math.floor((page.width - 32) / page.cols))
    readonly property int pageCellH: Math.max(1, Math.floor((page.height - 32) / page.rows))
    // How close to the true page edge (in px) a dropped item must be to move
    // it to the adjacent page instead of just repositioning it on this page.
    property int edgeZone: 30
    // Minimum total drag distance (px) required before an edge drop counts as
    // "move to the other page" — without this, simply picking an icon up and
    // putting it back down near its own resting spot (which can already sit
    // close to the page edge) would wrongly send it to the next page.
    property int meaningfulDragThreshold: 40
    // When true, newly-created icon cells play a staggered "bloom" entrance
    // (HyperOS-style cascade) instead of appearing instantly. Set by the
    // window for the initial homescreen load only.
    property bool animateEntrance: false
    // icons.corner_radius passed down from window.qml (0-32, 32 = circle).
    property real iconCornerRadiusRaw: 8
    // Widgets discovered from ~/Desktop/*.widget manifests (see
    // window.qml/applist.rs), each already resolved to its actual QML
    // file. A "widget" item in the layout references one by package.
    property var availableWidgets: []
    // The item (if any) currently in explicit "Resize" mode (see
    // window.qml's beginResize/endResize) — forces that item's resize
    // handle visible even without hover, e.g. for touch.
    property var resizingItem: null
    // Fired when a resize drag that was started via the explicit "Resize"
    // menu action finishes, so window.qml can turn page-swiping back on.
    signal endResizeItem()

    // ---- Drag and drop ----------------------------------------------------
    // Every icon is dragged as a real file (text/uri-list), so it can be dropped
    // on the Dock or into a file manager, and files from a file manager can be
    // dropped here. The extra application/x-althyn-home-item format marks our own
    // icons so a drop inside the homescreen just repositions them.
    function uriFor(path) {
        return encodeURI("file://" + path).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }
    function sourcePath(item) {
        if (item.type === "app") return item.desktopPath || ""
        if (item.type === "folder") return item.path || ""
        var w = page.availableWidgets.find(function(x) { return x.package === item.package })
        return w ? (w.manifest || "") : ""
    }
    function mimeFor(item, gx, gy) {
        var m = {}
        m["application/x-althyn-home-item"] = JSON.stringify({
            type: item.type, id: item.id || "", package: item.package || "", path: item.path || "",
            gx: gx, gy: gy, w: item.width || 1, h: item.height || 1,
            left: 16 + item.x * page.pageCellW, top: 16 + item.y * page.pageCellH })
        var path = page.sourcePath(item)
        if (path !== "") { m["text/uri-list"] = page.uriFor(path) + "\r\n"; m["text/plain"] = path }
        return m
    }
    // The grid cell a drop at (px, py) lands on. Our own icons keep the spot they
    // were grabbed at; files from elsewhere land on the cell under the pointer.
    function targetCell(px, py, internal) {
        var w = internal ? internal.w : 1, h = internal ? internal.h : 1
        var cx = internal ? Math.round((px - internal.gx - 16) / page.pageCellW) : Math.floor((px - 16) / page.pageCellW)
        var cy = internal ? Math.round((py - internal.gy - 16) / page.pageCellH) : Math.floor((py - 16) / page.pageCellH)
        return { col: Math.max(0, Math.min(page.cols - w, cx)), row: Math.max(0, Math.min(page.rows - h, cy)), w: w, h: h }
    }

    Rectangle {
        id: dropHighlight
        visible: dropArea.containsDrag && dropArea.cell !== null
        x: 16 + (dropArea.cell ? dropArea.cell.col : 0) * page.pageCellW + 4
        y: 16 + (dropArea.cell ? dropArea.cell.row : 0) * page.pageCellH + 4
        width: (dropArea.cell ? dropArea.cell.w : 1) * page.pageCellW - 8
        height: (dropArea.cell ? dropArea.cell.h : 1) * page.pageCellH - 8
        radius: 14
        color: page.hoverColor
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        property var cell: null
        property var internal: null
        function parseInternal(ev) {
            if (ev.formats.indexOf("application/x-althyn-home-item") < 0) return null
            try { return JSON.parse(ev.getDataAsString("application/x-althyn-home-item")) } catch (e) { return null }
        }
        onEntered: function(ev) {
            internal = parseInternal(ev)
            ev.accepted = internal !== null || ev.hasUrls
            cell = ev.accepted ? page.targetCell(ev.x, ev.y, internal) : null
        }
        onPositionChanged: function(ev) {
            if (cell !== null) cell = page.targetCell(ev.x, ev.y, internal)
        }
        onExited: { cell = null; internal = null }
        onDropped: function(ev) {
            var internalPayload = parseInternal(ev)
            var urls = []
            if (ev.hasUrls) for (var i = 0; i < ev.urls.length; i++) urls.push(String(ev.urls[i]))
            if (urls.length === 0 && internalPayload === null && ev.formats.indexOf("text/plain") >= 0) {
                var lines = String(ev.getDataAsString("text/plain")).split("\n")
                for (var j = 0; j < lines.length; j++) {
                    var l = lines[j].trim()
                    if (l.indexOf("/") === 0) urls.push("file://" + l)
                    else if (l.indexOf("file://") === 0) urls.push(l)
                }
            }
            var spot = page.targetCell(ev.x, ev.y, internalPayload)
            ev.acceptProposedAction()
            page.dropped({
                internal: internalPayload, urls: urls, move: ev.proposedAction === Qt.MoveAction,
                px: ev.x, py: ev.y, col: spot.col, row: spot.row, w: spot.w, h: spot.h,
                cellW: page.pageCellW, cellH: page.pageCellH, pageWidth: page.width,
                edgeZone: page.edgeZone, dragThreshold: page.meaningfulDragThreshold })
            cell = null; internal = null
        }
    }

    MouseArea {
        anchors.fill: parent
        // RightButton for desktop right-click; LeftButton is accepted too
        // so a long press on empty space works as the touch equivalent
        // (see onPressAndHold below) — a plain tap is ignored.
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                var p = page.mapToItem(null, mouse.x, mouse.y)
                page.bgRightClicked(p.x, p.y)
            }
        }
        onPressAndHold: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                var p = page.mapToItem(null, mouse.x, mouse.y)
                page.bgRightClicked(p.x, p.y)
            }
        }
    }

    Repeater {
        model: page.items
        delegate: Item {
            id: cell
            property var itemData: modelData
            property int cellW: Math.max(1, Math.floor((page.width - 32) / page.cols))
            property int cellH: Math.max(1, Math.floor((page.height - 32) / page.rows))
            x: 16 + itemData.x * cellW
            y: 16 + itemData.y * cellH
            width: Math.max(cellW, itemData.width * cellW)
            height: Math.max(cellH, itemData.height * cellH)
            z: cell.Drag.active ? 10 : 1

            // Native drag (see "Drag and drop" above). Apps and widgets are
            // offered as a Move (the file leaves the homescreen with the drop);
            // folders are only referenced, so they are offered as Copy/Link.
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: itemData.type === "folder" ? (Qt.CopyAction | Qt.LinkAction) : Qt.MoveAction
            Drag.proposedAction: itemData.type === "folder" ? Qt.LinkAction : Qt.MoveAction
            Drag.onDragFinished: function(dropAction) { page.dragFinished(itemData, dropAction) }
            function beginNativeDrag(gx, gy) {
                cell.grabToImage(function(result) {
                    if (!dragArea.pressed) return   // released before the snapshot was ready
                    cell.Drag.imageSource = result.url
                    cell.Drag.hotSpot = Qt.point(gx, gy)
                    cell.Drag.mimeData = page.mimeFor(itemData, gx, gy)
                    cell.Drag.active = true
                })
            }

            // iOS/HyperOS-style entrance: only on the initial homescreen load
            // (page.animateEntrance), icons "bloom" in from small+transparent
            // to full size, with a ripple delay based on distance from the
            // center of the grid — center icons pop first, the ripple spreads
            // outward to the edges, like a respring/unlock animation.
            property bool playEntrance: page.animateEntrance
            property real distFromCenter: Math.sqrt(Math.pow(itemData.x - (page.cols - 1) / 2, 2) + Math.pow(itemData.y - (page.rows - 1) / 2, 2))
            opacity: playEntrance ? 0 : 1
            scale: playEntrance ? 0.4 : 1
            transformOrigin: Item.Center
            Component.onCompleted: if (playEntrance) entranceAnim.start()
            SequentialAnimation {
                id: entranceAnim
                PauseAnimation { duration: cell.distFromCenter * 55 }
                ParallelAnimation {
                    NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                    NumberAnimation { target: cell; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.9 }
                }
            }

            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 14; color: dragArea.containsMouse ? page.hoverColor : "transparent"; visible: itemData.type !== "app" || dragArea.containsMouse }
            Loader {
                anchors.fill: parent; anchors.margins: Math.max(4, Math.floor(Math.min(cellW,cellH)*0.08))
                sourceComponent: itemData.type === "widget" ? widgetTileComponent : appTileComponent
            }

            Component {
                id: appTileComponent
                AppTile {
                    appName: itemData.appName || (itemData.type === "folder" ? (itemData.name || "Folder") : "")
                    iconPath: itemData.type === "folder" ? "../../assets/icons/folder.svg" : (itemData.iconPath || "../../assets/icons/unknown.svg")
                    directRound: !!itemData.directRound || !itemData.iconPath
                    bgColor: itemData.bgColor || ""
                    iconCornerRadiusRaw: page.iconCornerRadiusRaw
                    tileSpanW: itemData.width || 1
                    tileSpanH: itemData.height || 1
                    textColor: page.textColor; hoverColor: page.hoverColor
                    onClicked: {
                        if (itemData.type === "app") page.launch(itemData.execStr || "")
                        else if (itemData.type === "folder") page.openFolder(itemData.path || "")
                    }
                    onRightClicked: function(px,py) { page.appRightClicked(px,py,itemData) }
                }
            }

            Component {
                id: widgetTileComponent
                WidgetTile {
                    // itemData.package identifies which discovered widget
                    // this placed instance is — matches Package= from its
                    // .widget manifest (see applist.rs).
                    readonly property var widget: page.availableWidgets.find(function(w) { return w.package === itemData.package })
                    widgetName: itemData.name || (widget ? widget.name : "Widget")
                    widgetSource: widget ? widget.source : ""
                    vamifyEnabled: widget ? widget.vamify : true
                    iconCornerRadiusRaw: page.iconCornerRadiusRaw
                    tileSpanW: itemData.width || 1
                    tileSpanH: itemData.height || 1
                    textColor: page.textColor
                    onRightClicked: function(px,py) { page.appRightClicked(px,py,itemData) }
                }
            }
            MouseArea {
                id: dragArea; anchors.fill: parent; acceptedButtons: Qt.LeftButton; hoverEnabled: true; propagateComposedEvents: true
                // Keeps the page swipe from taking over once an icon is pressed.
                preventStealing: true
                property real pressX: 0
                property real pressY: 0
                property bool dragStarted: false
                onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y; dragStarted = false }
                onPositionChanged: function(mouse) {
                    if (!pressed || dragStarted || cell.Drag.active) return
                    var dx = mouse.x - pressX, dy = mouse.y - pressY
                    if (Math.sqrt(dx * dx + dy * dy) < Qt.styleHints.startDragDistance) return
                    dragStarted = true
                    cell.beginNativeDrag(pressX, pressY)
                }
            }
            Rectangle { width: 14; height: 14; radius: 4; color: page.textColor; visible: page.resizingItem === itemData; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3
                MouseArea { anchors.fill: parent; cursorShape: Qt.SizeFDiagCursor; onPressed: { mouse.accepted=true }
                    onPositionChanged: {
                        if (pressed) {
                            var minW=1, minH=1, maxW=page.cols, maxH=page.rows
                            if (itemData.type === "widget") {
                                var w = page.availableWidgets.find(function(x) { return x.package === itemData.package })
                                if (w) { minW=w.minWidth; minH=w.minHeight; maxW=Math.min(w.maxWidth, page.cols); maxH=Math.min(w.maxHeight, page.rows) }
                            }
                            var nw=Math.max(minW,Math.min(Math.min(maxW,page.cols-itemData.x),Math.round((mouse.x+cell.width)/cellW)))
                            var nh=Math.max(minH,Math.min(Math.min(maxH,page.rows-itemData.y),Math.round((mouse.y+cell.height)/cellH)))
                            itemData.width=nw; itemData.height=nh; cell.width=nw*cellW; cell.height=nh*cellH
                        }
                    }
                    onReleased: {
                        page.itemChanged(itemData)
                        if (page.resizingItem === itemData) page.endResizeItem()
                    }
                }
            }
        }
    }
}
