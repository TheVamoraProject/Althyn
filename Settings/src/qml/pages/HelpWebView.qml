import QtQuick
import QtWebView

Item {
    id: embeddedHelp
    property alias url: helpWeb.url
    property alias loading: helpWeb.loading
    property alias loadProgress: helpWeb.loadProgress
    property alias canGoBack: helpWeb.canGoBack
    property alias canGoForward: helpWeb.canGoForward

    function goBack() { helpWeb.goBack() }
    function goForward() { helpWeb.goForward() }
    function reload() { helpWeb.reload() }

    WebView {
        id: helpWeb
        anchors.fill: parent
        url: "https://vamora.vercel.app/projects/vamoraos/help"
    }
}