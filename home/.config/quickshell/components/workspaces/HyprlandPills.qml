import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    property int maxCount: 5
    property color activeColor: "#78b0ff"
    property color inactiveColor: "#2b2b2b"
    property int pillSpacing: 7

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: root.pillSpacing

        Repeater {
            model: root.maxCount

            delegate: Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: Hyprland.focusedWorkspace
                    && Hyprland.focusedWorkspace.id === wsId

                width: isActive ? 24 : 14
                height: 10
                radius: 999
                color: isActive ? root.activeColor : root.inactiveColor
                border.width: 0

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsId)
                }
            }
        }
    }
}
