import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import com.vamora

Item {
    id: tile

    property string widgetName: ""
    // file:// URL to the widget's own QML file, resolved from its
    // .widget manifest's Package/Source (see applist.rs). Empty means no
    // matching widget was found (removed/renamed on disk) — show a plain
    // placeholder box instead of crashing a Loader on a bad path.
    property string widgetSource: ""
    property color textColor: "#f4f4f5"
    // Label colour: textColor, or dark text where the wallpaper behind the
    // label is bright (no outline needed).
    property bool darkLabel: false
    readonly property color labelColor: darkLabel ? "#18181b" : textColor
    function updateLabelColor() {
        var w = tile.Window.window
        if (!w || !tile.visible || tile.width <= 0) return
        var p = tile.mapToItem(null, 0, tile.height - 20)
        var l = wallLuma.luminance(Math.round(p.x), Math.round(p.y), Math.round(tile.width), 20, w.width, w.height)
        if (l < 0) return
        // small hysteresis so a label never flickers around the threshold
        tile.darkLabel = tile.darkLabel ? l > 0.44 : l > 0.5
    }
    WallLuma { id: wallLuma }
    Timer { id: lumaTimer; interval: 350; repeat: true; running: tile.visible; triggeredOnStart: true; onTriggered: tile.updateLabelColor() }
    // The widget's own Vamify=true/false (missing defaults to true):
    // rounds the widget's rendered content to match the rest of VamoraOS,
    // or leaves it exactly as the widget draws itself.
    property bool vamifyEnabled: true
    // icons.corner_radius from VamoraSys (0-32, 32 = full circle).
    property real iconCornerRadiusRaw: 8
    // Grid cells this tile spans (itemData.width/height) — same
    // convention as AppTile.tileSpanW/H: a plain 1x1 widget keeps the
    // exact fixed "icon" size, anything resized bigger grows to match.
    property int tileSpanW: 1
    property int tileSpanH: 1

    signal rightClicked(real x, real y)

    readonly property bool hasWidget: widgetName !== ""

    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: tile.hasWidget

        Item {
            id: contentSlot
            readonly property bool resized: tile.tileSpanW > 1 || tile.tileSpanH > 1
            width: resized ? Math.max(52, tile.width - 12) : 52
            height: resized ? Math.max(52, tile.height - 30) : 52
            anchors.horizontalCenter: parent.horizontalCenter

            function radiusFor(size) {
                var r = Math.min(tile.iconCornerRadiusRaw, 32) / 32 * (size / 2)
                // A full circle suits an icon but not a big card: cap large widgets.
                return size > 64 ? Math.min(r, 28) : r
            }

            // The widget's actual rendered content — this, not some icon
            // standing in for it, is what gets rounded below, exactly the
            // same way an app icon does.
            Item {
                id: content
                anchors.fill: parent
                visible: false // only used as the OpacityMask source below

                Loader {
                    anchors.fill: parent
                    active: tile.widgetSource !== ""
                    source: tile.widgetSource
                }

                // Shown only if the widget's QML couldn't be resolved
                // (deleted/moved on disk after its .widget manifest was
                // scanned) — the title below already carries the name,
                // so this is just a plain placeholder, no text.
                Rectangle {
                    anchors.fill: parent
                    color: "#332a2e35"
                    visible: tile.widgetSource === ""
                }
            }

            Rectangle {
                id: mask
                anchors.fill: parent
                radius: tile.vamifyEnabled ? contentSlot.radiusFor(Math.min(width, height)) : 0
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: content
                maskSource: mask
            }
        }

        Text {
            text: tile.widgetName
            color: tile.labelColor
            Behavior on color { ColorAnimation { duration: 160 } }
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Medium
            width: tile.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: function(mouse) {
            var pt = tile.mapToItem(null, mouse.x, mouse.y)
            tile.rightClicked(pt.x, pt.y)
        }
    }
}
