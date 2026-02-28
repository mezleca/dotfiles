import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

import "."
import "bar"
import "services"

Item {
    id: root
    anchors.fill: parent
    property string barPosition: "top"
    property int barHeight: 36
    property string screenName: ""

    Theme {
        id: theme
    }

    readonly property var settings: ShellSettings

    property int titleLimit: settings.titleLimit

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


    Rectangle {
        anchors.fill: parent
        color: theme.bgPrimary
        border.width: 0
    }

    Rectangle {
        x: 0
        y: root.barPosition === "top" ? (parent.height - 1) : 0
        width: parent.width
        height: 1
        color: theme.border
        visible: settings.barShowBorder
    }

    readonly property var stats: StatsService
    readonly property var titleService: TitleService

    WorkspacePills {
        id: leftWorkspaces
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: settings.showWorkspaces
        maxCount: settings.workspaceCount
        showNumber: settings.workspaceShowNumber
        itemHeight: Math.round(root.height * (settings.workspaceHeightFactor / 100.0))
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
        text: root.shorten(root.clean(titleService.activeTitle, "Desktop"), root.titleLimit)
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
            value: stats.cpuText
            textColor: theme.textPrimary
        }

        StatItem {
            visible: settings.showMem
            icon: "󰍛"
            value: stats.memText
            textColor: theme.textPrimary
        }

        AudioModule {
            visibleModule: settings.showAudio
            clickCommand: settings.audioClickCommand
        }

        BrightnessModule {
            visibleModule: settings.showBrightness
            clickCommand: settings.brightnessClickCommand
            screenName: root.screenName
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
