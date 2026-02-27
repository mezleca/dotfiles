import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

import "."
import "bar"

Item {
    id: root
    anchors.fill: parent
    property string barPosition: "top"
    property int barHeight: 36

    Theme {
        id: theme
    }

    readonly property var settings: ShellSettings

    property string cpuText: "--%"
    property string memText: "--%"
    property int titleLimit: settings.titleLimit
    property real prevCpuUsed: -1
    property real prevCpuTotal: -1

    function clean(text, fallback) {
        const t = (text || "").trim()
        return t.length > 0 ? t : fallback
    }

    function shorten(text, maxChars) {
        const t = clean(text, "Desktop")
        if (t.length <= maxChars) {
            return t
        }
        return t.slice(0, Math.max(0, maxChars - 3)) + "..."
    }

    function parseCpuFromProcStat(text) {
        const line = (text || "").split("\n")[0] || ""
        const fields = line.trim().split(/\s+/)
        if (fields.length < 5 || fields[0] !== "cpu") {
            return
        }

        let total = 0
        for (let i = 1; i < fields.length; i += 1) {
            total += Number(fields[i]) || 0
        }

        const idle = (Number(fields[4]) || 0) + (Number(fields[5]) || 0)
        const used = total - idle

        let pct = 0
        if (root.prevCpuTotal > 0 && total > root.prevCpuTotal) {
            const deltaTotal = total - root.prevCpuTotal
            const deltaUsed = used - root.prevCpuUsed
            pct = deltaTotal > 0 ? (deltaUsed * 100.0) / deltaTotal : 0
        } else {
            pct = total > 0 ? (used * 100.0) / total : 0
        }

        root.prevCpuUsed = used
        root.prevCpuTotal = total
        root.cpuText = Math.max(0, Math.min(100, Math.round(pct))) + "%"
    }

    function parseMemFromProcMeminfo(text) {
        const lines = (text || "").split("\n")
        let total = 0
        let available = 0

        for (let i = 0; i < lines.length; i += 1) {
            const line = lines[i]
            if (line.indexOf("MemTotal:") === 0) {
                total = Number(line.replace(/[^\d]/g, "")) || 0
            } else if (line.indexOf("MemAvailable:") === 0) {
                available = Number(line.replace(/[^\d]/g, "")) || 0
            }
        }

        if (total <= 0) {
            root.memText = "--%"
            return
        }

        const usedPct = ((total - available) * 100.0) / total
        root.memText = Math.max(0, Math.min(100, Math.round(usedPct))) + "%"
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bgPrimary
        border.width: 0
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: theme.border
    }

    FileView {
        id: procStatFile
        path: "/proc/stat"
        preload: true
        onLoaded: root.parseCpuFromProcStat(this.text())
        onFileChanged: this.reload()
    }

    FileView {
        id: procMeminfoFile
        path: "/proc/meminfo"
        preload: true
        onLoaded: root.parseMemFromProcMeminfo(this.text())
        onFileChanged: this.reload()
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            procStatFile.reload()
            procMeminfoFile.reload()
        }
    }

    Component.onCompleted: {
        procStatFile.reload()
        procMeminfoFile.reload()
    }

    WorkspacePills {
        id: leftWorkspaces
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: settings.showWorkspaces
        maxCount: settings.workspaceCount
        showNumber: settings.workspaceShowNumber
        itemHeight: Math.round(root.height * 0.5)
        itemWidth: settings.workspaceWidth
        itemRadius: Math.max(0, Math.min(100, settings.workspaceRadius))
        activeColor: theme.textAccent
        inactiveColor: theme.borderSubtle
    }

    Text {
        id: leftTitle
        anchors.left: settings.showWorkspaces ? leftWorkspaces.right : parent.left
        anchors.leftMargin: settings.showWorkspaces ? 18 : 12
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: rightGroup.left
        anchors.rightMargin: 12
        visible: settings.showTitle
        text: root.shorten(root.clean(ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : "", "Desktop"), root.titleLimit)
        elide: Text.ElideRight
        color: theme.textPrimary
        font.family: theme.fontMain
        font.weight: Font.ExtraBold
        font.pixelSize: 12
    }

    Row {
        id: rightGroup
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Rectangle {
            id: trayContainer
            visible: settings.showTray
            height: 24
            width: Math.max(24, trayGroup.implicitWidth + 12)
            radius: 7
            color: theme.bgTertiary
            border.width: 0

            Row {
                id: trayGroup
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: SystemTray.items

                    delegate: Rectangle {
                        required property var modelData
                        width: 18
                        height: 18
                        radius: 4
                        color: "transparent"

                        IconImage {
                            anchors.fill: parent
                            implicitSize: 18
                            source: modelData.icon
                            asynchronous: true
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu && trayMenu.menu) {
                                        if (trayMenu.visible) {
                                            trayMenu.close()
                                        }
                                        trayMenu.open()
                                    } else {
                                        modelData.secondaryActivate()
                                    }
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate()
                                } else {
                                    if (modelData.onlyMenu && modelData.hasMenu && trayMenu.menu) {
                                        if (trayMenu.visible) {
                                            trayMenu.close()
                                        }
                                        trayMenu.open()
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                            onWheel: (wheel) => modelData.scroll(wheel.angleDelta.y, false)
                        }

                        QsMenuAnchor {
                            id: trayMenu
                            menu: modelData.menu
                            anchor.item: trayMouse
                            anchor.edges: Edges.Bottom | Edges.Left
                            anchor.gravity: Edges.Top | Edges.Left
                            anchor.adjustment: PopupAdjustment.All
                        }
                    }
                }
            }
        }

        StatItem {
            visible: settings.showCpu
            icon: "󰘚"
            value: root.cpuText
            textColor: theme.textPrimary
        }

        StatItem {
            visible: settings.showMem
            icon: "󰍛"
            value: root.memText
            textColor: theme.textPrimary
        }

        ClockModule {
            barPosition: root.barPosition
            visibleClock: settings.showClock
            clockMode: settings.clockMode
            clockClickAction: settings.clockClickAction
            transitionFadeIn: settings.transitionFadeIn
            transitionFadeOut: settings.transitionFadeOut
            transitionDurationMs: settings.transitionDurationMs
        }
    }
}
