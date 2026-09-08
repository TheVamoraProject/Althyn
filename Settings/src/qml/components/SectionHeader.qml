import QtQuick
import QtQuick.Controls

Text {
    property string label: ""
    text: label.toUpperCase()
    color: ApplicationWindow.window && !ApplicationWindow.window.darkTheme ? "#71717a" : "#a1a1aa"
    font { pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.1 }
    topPadding: 20
    bottomPadding: 6
    leftPadding: 2
}
