import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: tile

    property string widgetName: ""
    // file:// URL to the widget's own QML file, resolved from its
    // .widget manifest's Package/Source (see applist.rs). Empty means no
    // matching widget was found (removed/renamed on disk) — show a plain
    // placeholder box instead of crashing a Loader on a bad path.
    property string widgetSource: ""
    property color textColor: "#f4f4f5"
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
                return Math.min(tile.iconCornerRadiusRaw, 32) / 32 * (size / 2)
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
            color: tile.textColor
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
