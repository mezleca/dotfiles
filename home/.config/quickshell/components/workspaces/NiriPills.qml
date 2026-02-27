import Quickshell.Io
import QtQuick

Item {
    id: root

    property int maxCount: 5
    property color activeColor: "#78b0ff"
    property color inactiveColor: "#2b2b2b"
    property int pillSpacing: 7
    property var workspaces: []
    property bool refreshQueued: false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function asInt(v, fallback) {
        const n = Number(v)
        return Number.isFinite(n) ? Math.trunc(n) : fallback
    }

    function pick(obj, keys) {
        for (let i = 0; i < keys.length; i += 1) {
            const k = keys[i]
            if (Object.prototype.hasOwnProperty.call(obj, k) && obj[k] !== undefined && obj[k] !== null) {
                return obj[k]
            }
        }
        return undefined
    }

    function parseWorkspaces(jsonText) {
        let parsed = []
        try {
            parsed = JSON.parse(jsonText || "[]")
        } catch (_e) {
            return
        }

        if (!Array.isArray(parsed)) {
            if (parsed && Array.isArray(parsed.workspaces)) {
                parsed = parsed.workspaces
            } else if (parsed && parsed.Ok && Array.isArray(parsed.Ok.Workspaces)) {
                parsed = parsed.Ok.Workspaces
            } else if (parsed && parsed.Ok && Array.isArray(parsed.Ok.workspaces)) {
                parsed = parsed.Ok.workspaces
            }
        }

        if (!Array.isArray(parsed)) {
            return
        }

        const out = []
        for (let i = 0; i < parsed.length; i += 1) {
            const ws = parsed[i] || {}
            const id = asInt(pick(ws, ["idx", "index", "id", "workspace_idx", "workspace_index"]), -1)
            if (id < 1) {
                continue
            }

            const isActive = Boolean(pick(ws, ["is_active", "is_focused", "active", "focused"]))

            out.push({
                id: id,
                isActive: isActive
            })
        }

        out.sort((a, b) => a.id - b.id)
        root.workspaces = out
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWorkspaces(this.text)
        }
        onExited: {
            if (root.refreshQueued) {
                root.refreshQueued = false
                wsProc.running = true
            }
        }
    }

    Process {
        id: focusProc
    }

    Process {
        id: eventProc
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                if (data && data.length > 0) {
                    refreshDebounce.restart()
                }
            }
        }
        onExited: {
            eventReconnect.restart()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 35
        repeat: false
        onTriggered: {
            if (!wsProc.running) {
                wsProc.running = true
            } else {
                root.refreshQueued = true
            }
        }
    }

    Timer {
        id: eventReconnect
        interval: 300
        repeat: false
        onTriggered: {
            if (!eventProc.running) {
                eventProc.running = true
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!wsProc.running) {
                wsProc.running = true
            } else {
                root.refreshQueued = true
            }
        }
    }

    Component.onCompleted: {
        wsProc.running = true
        eventProc.running = true
    }

    Row {
        id: row
        spacing: root.pillSpacing

        Repeater {
            model: root.maxCount

            delegate: Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: {
                    for (let i = 0; i < root.workspaces.length; i += 1) {
                        const ws = root.workspaces[i]
                        if (ws.id === wsId) {
                            return Boolean(ws.isActive)
                        }
                    }
                    return false
                }
                readonly property bool exists: {
                    for (let i = 0; i < root.workspaces.length; i += 1) {
                        if (root.workspaces[i].id === wsId) {
                            return true
                        }
                    }
                    return false
                }

                width: isActive ? 24 : 14
                height: 10
                radius: 999
                color: isActive ? root.activeColor : root.inactiveColor
                opacity: exists ? 1.0 : 0.45
                border.width: 0

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!focusProc.running) {
                            focusProc.command = ["niri", "msg", "action", "focus-workspace", String(wsId)]
                            focusProc.running = true
                        }
                    }
                }
            }
        }
    }
}
