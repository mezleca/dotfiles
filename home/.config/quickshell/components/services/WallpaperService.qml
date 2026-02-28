pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false

    property var wallpapers: []
    property bool isScanning: false
    property bool isApplying: false

    signal applyFinished()

    function refresh() {
        if (scanProc.running) {
            return
        }
        isScanning = true
        scanProc.command = ["/home/rel/.local/bin/wallpaperctl", "list"]
        scanProc.running = true
    }

    function apply(pathValue) {
        if (applyProc.running) {
            return
        }
        const p = (pathValue || "").trim()
        if (p.length === 0) {
            return
        }
        isApplying = true
        applyProc.command = ["/home/rel/.local/bin/wallpaperctl", "apply", p]
        applyProc.running = true
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const parsed = []
                for (let i = 0; i < lines.length; i += 1) {
                    const itemPath = (lines[i] || "").trim()
                    if (itemPath.length > 0) {
                        parsed.push({ path: itemPath })
                    }
                }
                root.wallpapers = parsed
                root.isScanning = false
            }
        }
        onExited: {
            root.isScanning = false
        }
    }

    Process {
        id: applyProc
        onExited: {
            root.isApplying = false
            root.applyFinished()
        }
    }
}
