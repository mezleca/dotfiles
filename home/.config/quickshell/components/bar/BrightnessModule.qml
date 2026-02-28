import Quickshell
import Quickshell.Io
import QtQuick

import ".."
import "../services"

Item {
    id: root

    property bool visibleModule: true
    property string clickCommand: ""
    property string screenName: ""
    property string brightnessText: "--%"
    property int refreshBurst: 0

    Theme { id: theme }

    implicitHeight: 24
    visible: visibleModule

    function refreshBrightness() {
        if (brightnessProc.running) {
            return
        }
        const target = BrightnessService.getTargetForScreen(root.screenName)
        if (!target) {
            return
        }
        brightnessProc.command = ["sh", "-lc", root.buildDdcShellCommand(target, "getvcp 10")]
        brightnessProc.running = true
    }

    Process {
        id: brightnessProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = (this.text || "").trim()
                root.updateFromDdcOutput(text)
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1200
        running: true
        repeat: true
        onTriggered: root.refreshBrightness()
    }

    Timer {
        id: quickRefreshTimer
        interval: 180
        running: false
        repeat: false
        onTriggered: {
            if (root.refreshBurst > 0) {
                root.refreshBrightness()
                root.refreshBurst -= 1
                if (root.refreshBurst > 0) {
                    quickRefreshTimer.restart()
                }
            }
        }
    }

    Component.onCompleted: {
        BrightnessService.ensureDetect()
        root.refreshBrightness()
    }

    Row {
        id: contentRow
        spacing: 6
        height: parent.height

        Text {
            text: "󰌵"
            anchors.verticalCenter: parent.verticalCenter
            color: theme.textPrimary
            font.family: theme.fontMain
            font.weight: Font.ExtraBold
            font.pixelSize: 13
        }

        Text {
            text: root.brightnessText
            anchors.verticalCenter: parent.verticalCenter
            color: theme.textPrimary
            font.family: theme.fontMain
            font.weight: Font.ExtraBold
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.clickCommand.length > 0) {
                clickProc.command = ["sh", "-lc", root.clickCommand]
                clickProc.running = true
            }
        }
        onWheel: (wheel) => {
            const target = BrightnessService.getTargetForScreen(root.screenName)
            if (!target) {
                return
            }
            if (wheel.angleDelta.y > 0) {
                adjustProc.command = ["sh", "-lc", root.buildDdcShellCommand(target, "setvcp 10 + 10")]
            } else {
                adjustProc.command = ["sh", "-lc", root.buildDdcShellCommand(target, "setvcp 10 - 10")]
            }
            adjustProc.running = true
        }
    }

    Process { id: clickProc }
    Process {
        id: adjustProc
        onExited: {
            root.refreshBrightness()
            root.refreshBurst = 5
            root.quickRefreshTimer.restart()
        }
    }

    implicitWidth: contentRow.implicitWidth

    function buildDdcShellCommand(ddcTarget, args) {
        let targetArgs = ""
        if (ddcTarget.bus.length > 0) {
            targetArgs = "-b " + ddcTarget.bus
        } else {
            targetArgs = "-d " + ddcTarget.display
        }
        return "ddcutil --sleep-multiplier=0.05 " + targetArgs + " " + args + " 2>&1"
    }

    function updateFromDdcOutput(text) {
        if (text.length === 0) {
            return
        }
        if (text.indexOf("DDC communication failed") !== -1) {
            return
        }
        const detailedMatch = text.match(/current value\s*=\s*([0-9]+).*max value\s*=\s*([0-9]+)/i)
        if (detailedMatch && detailedMatch[1] && detailedMatch[2]) {
            const curDetailed = Number(detailedMatch[1])
            const maxDetailed = Number(detailedMatch[2])
            if (!isNaN(curDetailed) && !isNaN(maxDetailed) && maxDetailed > 0) {
                root.brightnessText = String(Math.round((curDetailed / maxDetailed) * 100)) + "%"
                return
            }
        }
        const briefMatch = text.match(/VCP\s+10\s+\w\s+([0-9a-fx]+)\s+([0-9a-fx]+)/i)
        if (briefMatch && briefMatch[1] && briefMatch[2]) {
            const curBrief = parseInt(briefMatch[1], 0)
            const maxBrief = parseInt(briefMatch[2], 0)
            if (!isNaN(curBrief) && !isNaN(maxBrief) && maxBrief > 0) {
                root.brightnessText = String(Math.round((curBrief / maxBrief) * 100)) + "%"
            }
        }
    }
}
