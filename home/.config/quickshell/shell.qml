//@ pragma UseQApplication
import Quickshell
import Quickshell._Window as QSW
import Quickshell.Services.SystemTray
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import QtQuick.Layouts

import "components"

ShellRoot {
    readonly property int barHeight: settings.barHeight

    readonly property var settings: ShellSettings

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            anchors {
                top: settings.barPosition === "top"
                bottom: settings.barPosition === "bottom"
                left: true
                right: true
            }

            implicitHeight: barHeight
            exclusiveZone: barHeight
            aboveWindows: true
            focusable: false
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: QSW.ExclusionMode.Normal
            WlrLayershell.exclusiveZone: barHeight

            Bar {
                barPosition: settings.barPosition
                barHeight: barHeight
                screenName: modelData.name
            }
        }
    }
}
