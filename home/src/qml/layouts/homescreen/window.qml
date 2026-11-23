import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import com.vamora

Window {
    id: window
    readonly property int statusBarHeight: 30
    visible: true; width: Screen.width; height: Math.max(0,Screen.height-statusBarHeight); x: 0; y: statusBarHeight
    title: "Vamora Homescreen"; color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    // Wayland (layer-shell). Bottom layer (above the wallpaper, below every
    // window), anchored on all four edges. Exclusion zone 0 means it is laid
    // out inside the area the status bar reserves, so it starts below the
    // bar. Ignored on X11.
    LayerShell.Window.scope: "althyn-home"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.exclusionZone: 0
    readonly property color cText: "#f4f4f5"
    readonly property color cTextMuted: "#a1a1aa"
    readonly property color cDotActive: "#f4f4f5"
    readonly property color cDotInactive: "#80a1a1aa"
    readonly property color cHover: "#26f4f4f5"
    property int gridCols: 4
    property int gridRows: 6
    property var apps: []
    property var layout: ({})
    property var pagesModel: [[]]
    // True only for the brief window right after startup, so the first
    // homescreen paint plays the entrance "bloom" once. Cleared shortly
    // after so the periodic refresh() below (which rebuilds every icon
    // every few seconds) never replays it.
    property bool firstLoad: true
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle), read
    // once at startup — same convention as the launcher and start menu.
    property real iconCornerRadiusRaw: 8
    // Widgets discovered from ~/Desktop/*.widget manifests, each resolved
    // to its actual QML file. Existing "widget" items in the saved layout
    // reference one of these by package (see HomePage.qml).
    property var availableWidgets: []
    // The item (if any) currently in explicit "Resize" mode, entered via
    // an icon's right-click menu — forces its resize handle visible and
    // disables page swiping for the duration of the drag, since a
    // corner-drag can otherwise fight with SwipeView's own gesture,
    // especially on touch where there's no hover to reveal the handle
    // in the first place.
    property var resizingItem: null
    function beginResize(item) { resizingItem = item; pagesView.interactive = false }
    function endResize() { resizingItem = null; pagesView.interactive = true }

    AppList { id: appList }

    // Whether a w×h box at (x,y) overlaps an existing item's own x/y/w/h
    // footprint — apps are always 1x1 but widgets can be bigger, so
    // placement has to check actual rectangles, not just single cells.
    function itemsOverlap(a, x, y, w, h) {
        return !(x + w <= a.x || a.x + a.width <= x || y + h <= a.y || a.y + a.height <= y)
    }
    function canPlaceOnPage(pageItems, x, y, w, h) {
        if (x < 0 || y < 0 || x + w > gridCols || y + h > gridRows) return false
        for (var i = 0; i < pageItems.length; i++) if (itemsOverlap(pageItems[i], x, y, w, h)) return false
        return true
    }
    // Finds the first free w×h spot across existing pages (scanning each
    // page top-left to bottom-right), adding a new page if none of the
    // existing ones have room — same "just fits it in somewhere" behavior
    // apps already get, generalized to a footprint bigger than one cell.
    function findFreeSpot(pages, w, h) {
        for (var p = 0; p < pages.length; p++) {
            for (var y = 0; y <= gridRows - h; y++) {
                for (var x = 0; x <= gridCols - w; x++) {
                    if (canPlaceOnPage(pages[p], x, y, w, h)) return {page: p, x: x, y: y}
                }
            }
        }
        if (pages.length < 100) { pages.push([]); return {page: pages.length - 1, x: 0, y: 0} }
        return null
    }

    function defaultLayout() {
        var items=[]; for (var i=0;i<apps.length;i++) items.push({type:"app",id:apps[i].id,x:i%gridCols,y:Math.floor(i/gridCols)%gridRows,width:1,height:1,page:Math.floor(i/(gridCols*gridRows)),appName:apps[i].appName,iconPath:apps[i].iconPath,execStr:apps[i].execStr,desktopPath:apps[i].desktopPath,directRound:apps[i].directRound,bgColor:apps[i].bgColor})
        var pageCount=Math.max(1,Math.min(100,Math.ceil(items.length/(gridCols*gridRows)))); var pages=[]; for(var p=0;p<pageCount;p++) pages.push(items.filter(function(x){return x.page===p;}))
        // Any widget on disk is, same as an app on disk, already "added" —
        // drop it into the first free spot that fits its declared size.
        for (var w=0; w<availableWidgets.length; w++) {
            var wd=availableWidgets[w]; var spot=findFreeSpot(pages, wd.width, wd.height); if (!spot) continue
            pages[spot.page].push({type:"widget",package:wd.package,name:wd.name,x:spot.x,y:spot.y,width:wd.width,height:wd.height,page:spot.page})
        }
        var pagesOut=[]; for(var pp=0;pp<pages.length;pp++) pagesOut.push({id:pp,items:pages[pp]})
        return {version:1,grid:{columns:gridCols,rows:gridRows},pages:pagesOut,folders:{}}
    }
    function buildPages() {
        var result=[]; var source=layout.pages||[{id:0,items:[]}]
        for(var p=0;p<source.length;p++){
            var mapped=[]
            for(var j=0;j<(source[p].items||[]).length;j++){
                var item=source[p].items[j]
                if (item.type==="app") {
                    var app=apps.find(function(a){return a.id===item.id}); if(!app) continue
                    item.appName=app.appName;item.iconPath=app.iconPath;item.execStr=app.execStr;item.desktopPath=app.desktopPath;item.directRound=app.directRound;item.bgColor=app.bgColor
                } else if (item.type==="widget") {
                    var wdg=availableWidgets.find(function(w){return w.package===item.package}); if(!wdg) continue // .widget file or its qml is gone
                    item.name=item.name||wdg.name
                }
                mapped.push(item)
            }
            result.push(mapped)
        }
        if(!result.length) result=[[]]
        for(var a=0;a<apps.length;a++) { var found=false; for(var q=0;q<result.length;q++) for(var r=0;r<result[q].length;r++) if(result[q][r].type==="app"&&result[q][r].id===apps[a].id) found=true; if(found) continue; var placed=false; for(var q2=0;q2<result.length&&!placed;q2++) for(var y=0;y<gridRows&&!placed;y++) for(var x=0;x<gridCols&&!placed;x++){var occupied=result[q2].some(function(i){return itemsOverlap(i,x,y,1,1)}); if(!occupied){result[q2].push({type:"app",id:apps[a].id,x:x,y:y,width:1,height:1,page:q2,appName:apps[a].appName,iconPath:apps[a].iconPath,execStr:apps[a].execStr,desktopPath:apps[a].desktopPath,directRound:apps[a].directRound,bgColor:apps[a].bgColor});placed=true}} if(!placed&&result.length<100) result.push([{type:"app",id:apps[a].id,x:0,y:0,width:1,height:1,page:result.length,appName:apps[a].appName,iconPath:apps[a].iconPath,execStr:apps[a].execStr,desktopPath:apps[a].desktopPath,directRound:apps[a].directRound,bgColor:apps[a].bgColor}]); }
        // Same "already added, just find it a spot" treatment for any
        // widget whose .widget manifest exists but isn't on a page yet.
        for (var wi=0; wi<availableWidgets.length; wi++) {
            var wd2=availableWidgets[wi]; var wFound=false
            for(var wq=0;wq<result.length;wq++) for(var wr=0;wr<result[wq].length;wr++) if(result[wq][wr].type==="widget"&&result[wq][wr].package===wd2.package) wFound=true
            if (wFound) continue
            var spot=findFreeSpot(result, wd2.width, wd2.height); if (!spot) continue
            result[spot.page].push({type:"widget",package:wd2.package,name:wd2.name,x:spot.x,y:spot.y,width:wd2.width,height:wd2.height,page:spot.page})
        }
        pagesModel=result
    }
    function persist(){ layout.pages=[]; for(var p=0;p<pagesModel.length;p++) layout.pages.push({id:p,items:pagesModel[p]}); appList.saveLayout(JSON.stringify(layout)) }
    function load() {
        apps=JSON.parse(appList.getAppsJson()); var g=String(appList.getGrid()).trim().split("x"); gridCols=parseInt(g[0])||4; gridRows=parseInt(g[1])||6;
        iconCornerRadiusRaw=parseFloat(appList.getIconCornerRadius())||iconCornerRadiusRaw;
        availableWidgets=JSON.parse(appList.getWidgetsJson());
        var raw=String(appList.loadLayout()); var saved=null; try{saved=raw?JSON.parse(raw):null}catch(e){saved=null}
        if(!saved||!saved.grid||saved.grid.columns!==gridCols||saved.grid.rows!==gridRows||!Array.isArray(saved.pages)||saved.pages.length<1||saved.pages.length>100){layout=defaultLayout();persist()}else layout=saved; buildPages(); if(apps.length && pagesModel.every(function(page){return page.length===0;})){layout=defaultLayout();persist();buildPages()}
    }
    function addPage(){if(pagesModel.length<100){pagesModel=pagesModel.concat([[]]);persist();pagesView.currentIndex=pagesModel.length-1}}
    function removePage(){if(pagesModel.length>1){pagesModel.splice(pagesView.currentIndex,1);pagesModel=pagesModel.slice();persist();pagesView.currentIndex=Math.max(0,pagesView.currentIndex-1)}}
    // Moves itemData from fromPageIndex to the adjacent page (fromPageIndex + direction),
    // dropping it into the first free cell there. Creates a new trailing page on
    // demand if the item is dragged past the last page. Also flips the SwipeView
    // to the destination page so the move is visible.
    function moveItemAcrossPages(itemData, direction, fromPageIndex) {
        var toPageIndex = fromPageIndex + direction
        if (toPageIndex < 0) return
        var newPagesModel = pagesModel.slice()
        if (toPageIndex >= newPagesModel.length) {
            if (newPagesModel.length >= 100) return
            newPagesModel = newPagesModel.concat([[]])
        }
        // Work on fresh copies of the two affected pages (not the arrays
        // pagesModel already holds references to) — mutating those in place
        // (splice/push) wouldn't change their reference, and QML's change
        // notification for "items" only fires on a genuinely different
        // reference. Without this, the destination page's icon list quietly
        // never re-renders even though the data is correct underneath.
        var fromItems = newPagesModel[fromPageIndex].slice()
        var srcIdx = fromItems.indexOf(itemData)
        if (srcIdx === -1) return
        var toItems = newPagesModel[toPageIndex].slice()

        var w = itemData.width || 1, h = itemData.height || 1
        var placed = false
        for (var y = 0; y <= gridRows - h && !placed; y++) {
            for (var x = 0; x <= gridCols - w && !placed; x++) {
                var free = true
                for (var i = 0; i < toItems.length && free; i++) {
                    var it = toItems[i]
                    if (x < it.x + it.width && x + w > it.x && y < it.y + it.height && y + h > it.y) free = false
                }
                if (free) { itemData.x = x; itemData.y = y; placed = true }
            }
        }
        if (!placed) return // destination page is full — leave the item where it was

        fromItems.splice(srcIdx, 1)
        itemData.page = toPageIndex
        toItems.push(itemData)
        newPagesModel[fromPageIndex] = fromItems
        newPagesModel[toPageIndex] = toItems
        pagesModel = newPagesModel
        persist()
        pagesView.currentIndex = toPageIndex
    }
    // Commits a dragged item's new x/y/width/height into the canonical
    // pagesModel and saves to disk. Deliberately does NOT trust that `item`
    // is literally the same object reference pagesModel already holds —
    // matches by reference first, falls back to matching by desktopPath/id,
    // and always persists at the end regardless, so a save is never silently
    // skipped.
    function updateItemPosition(pageIndex, item) {
        var pg = pagesModel[pageIndex]
        if (!pg) { persist(); return }
        var idx = pg.indexOf(item)
        if (idx === -1) {
            for (var i=0;i<pg.length;i++) {
                var it = pg[i]
                if ((item.desktopPath && it.desktopPath===item.desktopPath) || (it.id===item.id && it.type===item.type && it.appName===item.appName)) { idx=i; break }
            }
        }
        if (idx !== -1) {
            var newPg = pg.slice()
            newPg[idx] = Object.assign({}, newPg[idx], {x:item.x, y:item.y, width:item.width, height:item.height})
            var newModel = pagesModel.slice()
            newModel[pageIndex] = newPg
            pagesModel = newModel
        }
        persist()
    }
    // ---- Drag and drop (see HomePage.qml) ----
    // Does `a` stand for the same icon as `b`?
    function sameItem(a, b) {
        if (a.type !== b.type) return false
        if (a.type === "app") return a.id === b.id
        if (a.type === "widget") return a.package === b.package
        return a.path === b.path
    }
    // The free spot for a w×h box that is closest to (col,row), or null.
    function nearestFree(pageItems, col, row, w, h, ignore) {
        var others = pageItems.filter(function(i) { return i !== ignore })
        var best = null, bestDist = 1e9
        for (var y = 0; y <= gridRows - h; y++) for (var x = 0; x <= gridCols - w; x++) {
            if (!canPlaceOnPage(others, x, y, w, h)) continue
            var d = (x - col) * (x - col) + (y - row) * (y - row)
            if (d < bestDist) { bestDist = d; best = {x: x, y: y} }
        }
        return best
    }
    function findItem(probe) {
        for (var p = 0; p < pagesModel.length; p++)
            for (var i = 0; i < pagesModel[p].length; i++)
                if (sameItem(pagesModel[p][i], probe)) return {page: p, index: i}
        return null
    }
    // A drop of one of our own icons is applied once its drag has finished
    // (afterDrag), so the icon being dragged is not rebuilt underneath the drag.
    property var pendingInternalDrop: null
    function handleDrop(pageIndex, info) {
        if (info.internal) { pendingInternalDrop = info; return }
        dropExternal(pageIndex, info)
    }
    function applyInternalDrop(info) {
        var found = findItem(info.internal)
        if (!found) return
        var item = pagesModel[found.page][found.index]
        var w = item.width || 1, h = item.height || 1
        // Same rule as before the native drag: dropped well past a page edge
        // after a real drag moves it to the neighbouring page.
        var left = info.px - info.internal.gx, top = info.py - info.internal.gy
        var dist = Math.abs(left - info.internal.left) + Math.abs(top - info.internal.top)
        var nearLeft = left <= info.edgeZone
        var nearRight = left + w * info.cellW >= info.pageWidth - info.edgeZone
        if (dist >= info.dragThreshold && (nearLeft || nearRight)) { moveItemAcrossPages(item, nearLeft ? -1 : 1, found.page); return }
        var spot = nearestFree(pagesModel[found.page], info.col, info.row, w, h, item)
        if (!spot) return
        item.x = spot.x; item.y = spot.y
        updateItemPosition(found.page, item)
    }
    // Files from outside: apps/widgets are moved or copied into ~/Desktop, folders
    // are pinned by reference; each lands on the cell it was dropped on (or the
    // closest free one).
    function dropExternal(pageIndex, info) {
        if (!info.urls.length) return
        var results = JSON.parse(String(appList.importDropped(info.urls.join("\n"), info.move)))
        if (!results.length) return
        apps = JSON.parse(appList.getAppsJson())
        availableWidgets = JSON.parse(appList.getWidgetsJson())
        var model = pagesModel.map(function(pg) { return pg.slice() })
        var col = info.col, row = info.row
        for (var r = 0; r < results.length; r++) {
            var res = results[r], item = null, w = 1, h = 1
            if (res.kind === "app") item = {type: "app", id: res.id}
            else if (res.kind === "folder") item = {type: "folder", name: res.name, path: res.path}
            else if (res.kind === "widget") {
                var wd = availableWidgets.find(function(x) { return x.package === res.package })
                if (!wd) continue
                item = {type: "widget", package: wd.package, name: wd.name}; w = wd.width; h = wd.height
            }
            if (!item) continue
            // Already on the homescreen: this drop moves it to the new spot.
            for (var p = 0; p < model.length; p++) model[p] = model[p].filter(function(it) { return !sameItem(it, item) })
            var target = pageIndex, spot = nearestFree(model[pageIndex] || [], col, row, w, h, null)
            if (!spot) {
                var fs = findFreeSpot(model, w, h)
                if (!fs) continue
                target = fs.page; spot = {x: fs.x, y: fs.y}
            }
            item.x = spot.x; item.y = spot.y; item.width = w; item.height = h; item.page = target
            model[target].push(item)
            col = spot.x; row = spot.y
        }
        pagesModel = model
        persist()
        buildPages()
    }
    // Called when a drag that started on one of our icons ends. A Move means the
    // file left (Dock, file manager): rebuild now instead of waiting for refresh().
    function afterDrag(item, dropAction) {
        var pending = pendingInternalDrop; pendingInternalDrop = null
        if (pending) { applyInternalDrop(pending); return }
        // The source can be told "ignored" even though another client took the
        // file, so whether it left is decided by rescanning, not by dropAction.
        if (item.type !== "folder") { rescanItem = item; rescanTimer.restart() }
    }
    // Shortly after a drop, check whether the file left (moved to the Dock or a
    // file manager); if so drop the icon now instead of waiting for refresh().
    property var rescanItem: null
    Timer {
        id: rescanTimer
        interval: 400
        onTriggered: {
            var item = window.rescanItem; window.rescanItem = null
            if (!item) return
            var fresh = JSON.parse(appList.getAppsJson())
            var widgets = JSON.parse(appList.getWidgetsJson())
            var gone = item.type === "app" ? !fresh.some(function(a) { return a.id === item.id })
                                           : !widgets.some(function(w) { return w.package === item.package })
            if (!gone) return
            window.apps = fresh
            window.availableWidgets = widgets
            window.pagesModel = window.pagesModel.map(function(pg) { return pg.filter(function(it) { return !window.sameItem(it, item) }) })
            window.persist(); window.buildPages()
        }
    }
    function removeItem(item) {
        if (item.type === "app") appList.removeApp(item.desktopPath || "")
        var model = pagesModel.map(function(pg) { return pg.filter(function(it) { return !sameItem(it, item) }) })
        pagesModel = model
        persist()
        if (item.type === "app") refresh()
    }
    function refresh(){
        var freshApps=JSON.parse(appList.getAppsJson());
        // Guard against a transient/incomplete app scan wiping the homescreen:
        // if it comes back empty while pages already have items placed, skip
        // this cycle rather than treating every icon as "uninstalled" and
        // having buildPages() re-flow everything back into a fresh
        // alphabetical layout (and persisting that bad state).
        var hasPlacedItems=pagesModel.some(function(pg){return pg.length>0});
        if (freshApps.length===0 && hasPlacedItems) return;
        var before=JSON.stringify(pagesModel);
        var beforeModel=pagesModel;
        apps=freshApps;
        // icons.corner_radius can change while the homescreen is running
        // (it never closes) — pick up a live change the same way apps
        // themselves get picked up, rather than only reading it once at
        // startup.
        var freshRadius=parseFloat(appList.getIconCornerRadius());
        if (!isNaN(freshRadius) && freshRadius!==iconCornerRadiusRaw) {
            iconCornerRadiusRaw=freshRadius;
        }
        buildPages();
        if(JSON.stringify(pagesModel)!==before) {
            persist();
        } else {
            // Nothing actually changed. buildPages() unconditionally builds
            // brand-new page/item objects, and reassigning pagesModel to them
            // would destroy and recreate every icon delegate — which, if a
            // drag is in progress right now, destroys the very cell being
            // dragged before its release handler (the one that saves the
            // dropped position) ever runs. Restore the original reference so
            // nothing rebuilds when there's no real change to show.
            pagesModel=beforeModel;
        }
    }
    Component.onCompleted: load()
    Timer { interval:3000; running:true; repeat:true; onTriggered:refresh() }
    // Entrance animation window: long enough for the slowest-staggered icon
    // (bottom-right of a full page) to finish blooming, comfortably before
    // the first periodic refresh() above would otherwise force a replay.
    Timer { interval:1100; running:true; repeat:false; onTriggered: window.firstLoad=false }

    Row { id: indicatorRow; anchors.top:parent.top; anchors.topMargin:48; anchors.horizontalCenter:parent.horizontalCenter; spacing:8; z:10
        Repeater { model: window.pagesModel.length; Rectangle { readonly property bool active:index===pagesView.currentIndex; width:active?22:7;height:7;radius:3.5;color:active?cDotActive:cDotInactive; MouseArea{anchors.fill:parent;anchors.margins:-6;onClicked:pagesView.currentIndex=index} } }
    }
    SwipeView { id:pagesView; anchors.top:indicatorRow.bottom; anchors.topMargin:24; anchors.bottom:parent.bottom; anchors.left:parent.left; anchors.right:parent.right; anchors.bottomMargin:24; clip:true; Repeater { model:window.pagesModel.length; HomePage { items:window.pagesModel[index]||[]; cols:gridCols; rows:gridRows; textColor:cText; hoverColor:cHover; iconCornerRadiusRaw:window.iconCornerRadiusRaw; availableWidgets:window.availableWidgets; animateEntrance:window.firstLoad; resizingItem:window.resizingItem; onLaunch:function(e){appList.launchApp(e)}; onItemChanged:function(item){window.updateItemPosition(index,item)}; onAppRightClicked:function(x,y,item){appContextMenu.targetItem=item;appContextMenu.targetDesktopPath=item.desktopPath||"";appContextMenu.targetAppName=item.appName||item.name||"";appContextMenu.popup(x,y)}; onBgRightClicked:function(x,y){bgContextMenu.popup(x,y)}; onRequestPageShift:function(item,direction){window.moveItemAcrossPages(item,direction,index)}; onEndResizeItem:window.endResize(); pageIndex:index; onDropped:function(info){window.handleDrop(index,info)}; onDragFinished:function(item,action){window.afterDrag(item,action)}; onOpenFolder:function(p){appList.openPath(p)} } } }
    VamoraContextMenu { id:appContextMenu; hostWindow:window; property string targetDesktopPath:""; property string targetAppName:""; property var targetItem:null; model:[{label:"Resize",icon:"../../assets/icons/apps.svg",action:function(){window.beginResize(targetItem)}},{label:"---"},{label:"Remove from Homescreen",icon:"../../assets/icons/pin-off.svg",destructive:true,action:function(){window.removeItem(targetItem)}},{label:"---"},{label:"App Info",icon:"../../assets/icons/info.svg"}] }
    VamoraContextMenu { id:bgContextMenu; hostWindow:window; model:[{label:"Add Page",icon:"../../assets/icons/apps.svg",action:function(){addPage()}},{label:"Remove Current Page",icon:"../../assets/icons/pin-off.svg",destructive:true,action:function(){removePage()}},{label:"Add Widget",icon:"../../assets/icons/apps.svg"},{label:"Homescreen Settings",icon:"../../assets/icons/info.svg"},{label:"Refresh",icon:"../../assets/icons/info.svg",action:function(){refresh()}},{label:"---"},{label:"Power",icon:"../../assets/icons/power.svg",destructive:true,action:function(){appList.launchApp("althyn-power")}}] }
}
