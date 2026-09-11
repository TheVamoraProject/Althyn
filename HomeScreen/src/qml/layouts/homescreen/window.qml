import QtQuick
import QtQuick.Controls
import QtQuick.Window
import com.vamora

Window {
    id: window
    readonly property int statusBarHeight: 30
    visible: true; width: Screen.width; height: Math.max(0,Screen.height-statusBarHeight); x: 0; y: statusBarHeight
    title: "Vamora Homescreen"; color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint
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

    AppList { id: appList }

    function defaultLayout() {
        var items=[]; for (var i=0;i<apps.length;i++) items.push({type:"app",id:apps[i].id,x:i%gridCols,y:Math.floor(i/gridCols)%gridRows,width:1,height:1,page:Math.floor(i/(gridCols*gridRows)),appName:apps[i].appName,iconPath:apps[i].iconPath,execStr:apps[i].execStr,desktopPath:apps[i].desktopPath})
        var pageCount=Math.max(1,Math.min(100,Math.ceil(items.length/(gridCols*gridRows)))); var pages=[]; for(var p=0;p<pageCount;p++) pages.push({id:p,items:items.filter(function(x){return x.page===p;})}); return {version:1,grid:{columns:gridCols,rows:gridRows},pages:pages,folders:{}}
    }
    function buildPages() {
        var result=[]; var source=layout.pages||[{id:0,items:[]}];
        for(var p=0;p<source.length;p++){ var mapped=[]; for(var j=0;j<(source[p].items||[]).length;j++){var item=source[p].items[j]; var app=apps.find(function(a){return a.id===item.id}); if(item.type==="app"&&!app) continue; if(app){item.appName=app.appName;item.iconPath=app.iconPath;item.execStr=app.execStr;item.desktopPath=app.desktopPath} mapped.push(item)} result.push(mapped) }
        if(!result.length) result=[[]];
        for(var a=0;a<apps.length;a++) { var found=false; for(var q=0;q<result.length;q++) for(var r=0;r<result[q].length;r++) if(result[q][r].type==="app"&&result[q][r].id===apps[a].id) found=true; if(found) continue; var placed=false; for(var q2=0;q2<result.length&&!placed;q2++) for(var y=0;y<gridRows&&!placed;y++) for(var x=0;x<gridCols&&!placed;x++){var occupied=result[q2].some(function(i){return i.x===x&&i.y===y}); if(!occupied){result[q2].push({type:"app",id:apps[a].id,x:x,y:y,width:1,height:1,page:q2,appName:apps[a].appName,iconPath:apps[a].iconPath,execStr:apps[a].execStr,desktopPath:apps[a].desktopPath});placed=true}} if(!placed&&result.length<100) result.push([{type:"app",id:apps[a].id,x:0,y:0,width:1,height:1,page:result.length,appName:apps[a].appName,iconPath:apps[a].iconPath,execStr:apps[a].execStr,desktopPath:apps[a].desktopPath}]); }
        pagesModel=result;
    }
    function persist(){ layout.pages=[]; for(var p=0;p<pagesModel.length;p++) layout.pages.push({id:p,items:pagesModel[p]}); appList.saveLayout(JSON.stringify(layout)) }
    function load() {
        apps=JSON.parse(appList.getAppsJson()); var g=String(appList.getGrid()).trim().split("x"); gridCols=parseInt(g[0])||4; gridRows=parseInt(g[1])||6;
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
    SwipeView { id:pagesView; anchors.top:indicatorRow.bottom; anchors.topMargin:24; anchors.bottom:parent.bottom; anchors.left:parent.left; anchors.right:parent.right; anchors.bottomMargin:24; clip:true; Repeater { model:window.pagesModel.length; HomePage { items:window.pagesModel[index]||[]; cols:gridCols; rows:gridRows; textColor:cText; hoverColor:cHover; animateEntrance:window.firstLoad; onLaunch:function(e){appList.launchApp(e)}; onItemChanged:function(item){window.updateItemPosition(index,item)}; onAppRightClicked:function(x,y,path,name){appContextMenu.targetDesktopPath=path;appContextMenu.targetAppName=name;appContextMenu.popup(x,y)}; onBgRightClicked:function(x,y){bgContextMenu.popup(x,y)}; onRequestPageShift:function(item,direction){window.moveItemAcrossPages(item,direction,index)} } } }
    ContextMenu { id:appContextMenu; hostWindow:window; property string targetDesktopPath:""; property string targetAppName:""; model:[{label:"Remove from Homescreen",icon:"../../assets/icons/pin-off.svg",destructive:true,action:function(){appList.removeApp(targetDesktopPath);refresh()}},{label:"---"},{label:"App Info",icon:"../../assets/icons/info.svg"}] }
    ContextMenu { id:bgContextMenu; hostWindow:window; model:[{label:"Add Page",icon:"../../assets/icons/apps.svg",action:function(){addPage()}},{label:"Remove Current Page",icon:"../../assets/icons/pin-off.svg",destructive:true,action:function(){removePage()}},{label:"Add Widget",icon:"../../assets/icons/apps.svg"},{label:"Homescreen Settings",icon:"../../assets/icons/info.svg"},{label:"Refresh",icon:"../../assets/icons/info.svg",action:function(){refresh()}},{label:"---"},{label:"Power",icon:"../../assets/icons/power.svg",destructive:true,action:function(){appList.launchApp("vamora-powermenu")}}] }
}
