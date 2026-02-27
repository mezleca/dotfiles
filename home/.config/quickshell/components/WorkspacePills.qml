import Quickshell
import QtQuick

Item {
    id: root

    property int maxCount: 5
    property color activeColor: "#78b0ff"
    property color inactiveColor: "#2b2b2b"
    property bool showNumber: false
    property int itemHeight: 10
    property int itemWidth: 16
    property int itemRadius: 999

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    readonly property string desktopName: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase()
    readonly property bool useNiri: desktopName.indexOf("niri") !== -1
    readonly property bool useHyprland: desktopName.indexOf("hypr") !== -1

    readonly property string hyprSource: Qt.resolvedUrl("workspaces/HyprlandPills.qml")
    readonly property string niriSource: Qt.resolvedUrl("workspaces/NiriPills.qml")
    readonly property string fallbackSource: Qt.resolvedUrl("workspaces/FallbackPills.qml")

    Loader {
        id: loader
        anchors.fill: parent
        source: root.useNiri ? root.niriSource : (root.useHyprland ? root.hyprSource : root.fallbackSource)

        onLoaded: root.syncProps()
        onStatusChanged: {
            if (status === Loader.Error && source !== root.fallbackSource) {
                source = root.fallbackSource
            }
        }
    }

    function syncProps() {
        if (!loader.item) {
            return
        }

        loader.item.maxCount = root.maxCount
        loader.item.activeColor = root.activeColor
        loader.item.inactiveColor = root.inactiveColor
        loader.item.showNumber = root.showNumber
        loader.item.itemHeight = root.itemHeight
        loader.item.itemWidth = root.itemWidth
        loader.item.itemRadius = root.itemRadius
    }

    onMaxCountChanged: syncProps()
    onActiveColorChanged: syncProps()
    onInactiveColorChanged: syncProps()
    onShowNumberChanged: syncProps()
    onItemHeightChanged: syncProps()
    onItemWidthChanged: syncProps()
    onItemRadiusChanged: syncProps()
}
