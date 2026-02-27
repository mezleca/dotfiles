pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    width: 0
    height: 0
    visible: false

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell"
    readonly property string settingsPath: configDir + "/settings.json"
    property bool loaded: false

    property alias showWorkspaces: adapter.showWorkspaces
    property alias showTitle: adapter.showTitle
    property alias showTray: adapter.showTray
    property alias showCpu: adapter.showCpu
    property alias showMem: adapter.showMem
    property alias showClock: adapter.showClock
    property alias clockMode: adapter.clockMode
    property alias clockClickAction: adapter.clockClickAction
    property alias transitionFadeIn: adapter.transitionFadeIn
    property alias transitionFadeOut: adapter.transitionFadeOut
    property alias transitionDurationMs: adapter.transitionDurationMs
    property alias barPosition: adapter.barPosition
    property alias barHeight: adapter.barHeight
    property alias titleLimit: adapter.titleLimit
    property alias workspaceCount: adapter.workspaceCount
    property alias workspaceShowNumber: adapter.workspaceShowNumber
    property alias workspaceWidth: adapter.workspaceWidth
    property alias workspaceRadius: adapter.workspaceRadius

    property alias accent: adapter.accent
    property alias bgPrimary: adapter.bgPrimary
    property alias bgSecondary: adapter.bgSecondary
    property alias bgTertiary: adapter.bgTertiary
    property alias borderSubtle: adapter.borderSubtle
    property alias textPrimary: adapter.textPrimary
    property alias textMuted: adapter.textMuted
    property alias selected: adapter.selected

    function reload() {
        fileView.reload()
    }

    function queueSave() {
        if (!loaded) {
            return
        }
        saveTimer.restart()
    }

    JsonAdapter {
        id: adapter

        property bool showWorkspaces: true
        property bool showTitle: true
        property bool showTray: true
        property bool showCpu: true
        property bool showMem: true
        property bool showClock: true
        property string clockMode: "time"
        property string clockClickAction: "show_text"
        property bool transitionFadeIn: true
        property bool transitionFadeOut: true
        property int transitionDurationMs: 180
        property string barPosition: "top"
        property int barHeight: 36
        property int titleLimit: 50
        property int workspaceCount: 5
        property bool workspaceShowNumber: false
        property int workspaceWidth: 16
        property int workspaceRadius: 999

        property string accent: "#78b0ff"
        property string bgPrimary: "#141414"
        property string bgSecondary: "#111111"
        property string bgTertiary: "#0f0f0f"
        property string borderSubtle: "#2b2b2b"
        property string textPrimary: "#d6d6d6"
        property string textMuted: "#9aa9bb"
        property string selected: "#22344f"
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.configDir]
        running: false
        onExited: {
            fileView.writeAdapter()
            fileView.reload()
        }
    }

    Timer {
        id: saveTimer
        interval: 140
        repeat: false
        onTriggered: fileView.writeAdapter()
    }

    FileView {
        id: fileView
        path: root.settingsPath
        adapter: adapter
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.loaded = true
        onLoadFailed: {
            mkdirProc.running = true
        }
    }

    onShowWorkspacesChanged: queueSave()
    onShowTitleChanged: queueSave()
    onShowTrayChanged: queueSave()
    onShowCpuChanged: queueSave()
    onShowMemChanged: queueSave()
    onShowClockChanged: queueSave()
    onClockModeChanged: queueSave()
    onClockClickActionChanged: queueSave()
    onTransitionFadeInChanged: queueSave()
    onTransitionFadeOutChanged: queueSave()
    onTransitionDurationMsChanged: queueSave()
    onBarPositionChanged: queueSave()
    onBarHeightChanged: queueSave()
    onTitleLimitChanged: queueSave()
    onWorkspaceCountChanged: queueSave()
    onWorkspaceShowNumberChanged: queueSave()
    onWorkspaceWidthChanged: queueSave()
    onWorkspaceRadiusChanged: queueSave()
    onAccentChanged: queueSave()
    onBgPrimaryChanged: queueSave()
    onBgSecondaryChanged: queueSave()
    onBgTertiaryChanged: queueSave()
    onBorderSubtleChanged: queueSave()
    onTextPrimaryChanged: queueSave()
    onTextMutedChanged: queueSave()
    onSelectedChanged: queueSave()

    Component.onCompleted: fileView.reload()
}
