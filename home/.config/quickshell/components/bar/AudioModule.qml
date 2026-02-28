import Quickshell
import Quickshell.Io
import QtQuick

import ".."

Item {
    id: root

    property bool visibleModule: true
    property string clickCommand: ""
    property string volumeText: "--%"
    property bool muted: false

    Theme { id: theme }

    implicitHeight: 24
    visible: visibleModule

    function volumeIcon() {
        if (root.muted || root.volumeText === "0%") {
            return "󰖁"
        }
        const pct = parseInt(root.volumeText, 10)
        if (isNaN(pct)) {
            return "󰕾"
        }
        if (pct <= 30) {
            return "󰖀"
        }
        if (pct <= 70) {
            return "󰕾"
        }
        return "󰕾"
    }

    function refreshVolume() {
        if (volumeProc.running) {
            return
        }
        volumeProc.command = ["sh", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        volumeProc.running = true
    }

    Process {
        id: volumeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = (this.text || "").trim()
                const match = text.match(/Volume:\s*([0-9]*\.?[0-9]+)/i)
                if (match && match[1]) {
                    const raw = Math.max(0, Math.min(1.5, Number(match[1])))
                    const pct = Math.round(raw * 100)
                    root.volumeText = String(pct) + "%"
                }
                root.muted = text.indexOf("MUTED") !== -1
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refreshVolume()
    }

    Component.onCompleted: root.refreshVolume()

    Row {
        id: contentRow
        spacing: 6
        height: parent.height

        Text {
            text: root.volumeIcon()
            anchors.verticalCenter: parent.verticalCenter
            color: theme.textPrimary
            font.family: theme.fontMain
            font.weight: Font.ExtraBold
            font.pixelSize: 13
        }

        Text {
            text: root.volumeText
            anchors.verticalCenter: parent.verticalCenter
            color: theme.textPrimary
            font.family: theme.fontMain
            font.weight: Font.ExtraBold
            font.pixelSize: 13
        }
    }

    implicitWidth: contentRow.implicitWidth
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
            if (wheel.angleDelta.y > 0) {
                adjustProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]
            } else {
                adjustProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
            }
            adjustProc.running = true
            root.refreshVolume()
        }
    }

    Process { id: clickProc }
    Process { id: adjustProc }
}
