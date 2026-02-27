import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "components"

ShellRoot {
    id: root
    property var wallpapers: []
    property string selectedPathKey: ""
    property real panelOpacity: 1.0

    function refreshList() {
        scanProc.command = ["/home/rel/.local/bin/wallpaperctl", "list"]
        scanProc.running = true
    }

    function applySelected(pathValue) {
        if (applyProc.running) {
            return
        }

        const p = pathValue || selectedPathKey
        if (p.length === 0) {
            return
        }

        applyProc.command = ["/home/rel/.local/bin/wallpaperctl", "apply", p]
        applyProc.running = true
    }

    function close_picker() {
        if (settings.transitionFadeOut) {
            fadeOut.restart()
        } else {
            Qt.quit()
        }
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                const items = []
                for (const p of lines) {
                    items.push({ path: p })
                }
                wallpapers = items
                selectedPathKey = ""
            }
        }
    }

    Process {
        id: applyProc
    }

    Theme {
        id: theme
    }

    readonly property var settings: ShellSettings

    FloatingWindow {
        id: picker
        visible: true
        implicitWidth: 800
        implicitHeight: 520
        color: "#121212"
        title: "Wallpaper Picker"
        Shortcut {
            sequence: "Escape"
            onActivated: root.close_picker()
        }
        onVisibleChanged: {
            if (!visible) {
                Qt.quit()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: theme.bgPrimary
            border.width: 1
            border.color: theme.border
            opacity: root.panelOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: wallpapers.length > 0 ? "Wallpapers (" + wallpapers.length + ")" : "Wallpapers"
                        color: theme.textPrimary
                        font.family: theme.fontMain
                        font.weight: Font.ExtraBold
                        font.pixelSize: 14
                    }

                    Item { Layout.fillWidth: true }

                    UiButton {
                        text: "Refresh"
                        onClicked: {
                            wallpapers = []
                            selectedPathKey = ""
                            refreshList()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: theme.bgSecondary
                        border.width: 1
                        border.color: theme.borderSubtle

                        Item {
                            id: gridHost
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            readonly property int desiredCellWidth: 248
                            readonly property int desiredCellHeight: 164
                            readonly property int columns: Math.max(1, Math.floor(width / desiredCellWidth))

                            GridView {
                                id: grid
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: gridHost.columns * gridHost.desiredCellWidth
                                clip: true
                                cellWidth: gridHost.desiredCellWidth
                                cellHeight: gridHost.desiredCellHeight
                                model: wallpapers
                                cacheBuffer: 900

                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    x: Math.floor((grid.cellWidth - width) / 2)
                                    y: Math.floor((grid.cellHeight - height) / 2)
                                    width: grid.cellWidth - 10
                                    height: grid.cellHeight - 10
                                    clip: false

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: 7
                                        antialiasing: true
                                        color: "transparent"
                                        border.width: root.selectedPathKey === modelData.path ? 2 : 1
                                        border.color: root.selectedPathKey === modelData.path ? theme.border : theme.borderSubtle
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 5
                                        clip: true
                                        antialiasing: true
                                        color: "#000000"

                                        Image {
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: false
                                            sourceSize.width: 320
                                            sourceSize.height: 220
                                            source: "file://" + modelData.path
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedPathKey = modelData.path
                                            root.applySelected(modelData.path)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "panelOpacity"
        from: 0.0
        to: 1.0
        duration: Math.max(0, settings.transitionDurationMs)
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "panelOpacity"
        from: root.panelOpacity
        to: 0.0
        duration: Math.max(0, settings.transitionDurationMs)
        easing.type: Easing.OutCubic
        onFinished: Qt.quit()
    }

    Component.onCompleted: {
        refreshList()
        if (settings.transitionFadeIn) {
            root.panelOpacity = 0.0
            fadeIn.restart()
        } else {
            root.panelOpacity = 1.0
        }
    }
}
