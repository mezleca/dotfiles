pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false

    property string cpuText: "--%"
    property string memText: "--%"
    property real prevCpuUsed: -1
    property real prevCpuTotal: -1

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
}
