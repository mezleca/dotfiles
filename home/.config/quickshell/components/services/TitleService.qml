pragma Singleton

import Quickshell
import Quickshell.Wayland
import QtQuick

Item {
    id: root
    visible: false

    readonly property string activeTitle: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
}
