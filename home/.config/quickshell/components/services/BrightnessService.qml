pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false

    property var ddcTargets: ({})
    property bool ddcReady: false

    function ensureDetect() {
        if (ddcDetectProc.running || root.ddcReady) {
            return
        }
        ddcDetectProc.running = true
    }

    function getTargetForScreen(screenName) {
        if (!screenName || String(screenName).length === 0) {
            return null
        }
        const key = String(screenName)
        if (root.ddcTargets[key]) {
            return root.ddcTargets[key]
        }
        return null
    }

    function parseDdcDetect(text) {
        const map = {}
        const blocks = (text || "").trim().split("\n\n")
        for (let i = 0; i < blocks.length; i += 1) {
            const block = blocks[i]
            if (!block) {
                continue
            }
            const displayMatch = block.match(new RegExp("Display\\s+([0-9]+)"))
            const busMatch = block.match(new RegExp("I2C bus:\\s*/dev/i2c-([0-9]+)"))
            const connectorMatch = block.match(new RegExp("DRM[_ ]connector:\\s*card\\d+-(.+)"))
            if (!displayMatch || !connectorMatch) {
                continue
            }
            const display = displayMatch[1] || ""
            const connector = connectorMatch[1] ? connectorMatch[1].trim() : ""
            if (connector.length === 0) {
                continue
            }
            map[connector] = {
                "display": display,
                "bus": busMatch ? busMatch[1] : ""
            }
        }
        return map
    }

    Process {
        id: ddcDetectProc
        command: ["ddcutil", "detect", "--sleep-multiplier=0.5"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ddcTargets = root.parseDdcDetect(this.text || "")
                root.ddcReady = true
            }
        }
    }
}
