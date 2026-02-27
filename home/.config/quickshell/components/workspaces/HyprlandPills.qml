import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    property int maxCount: 5
    property color activeColor: "#78b0ff"
    property color inactiveColor: "#2b2b2b"
    property int pillSpacing: 7
    property bool showNumber: false
    property int itemHeight: 10
    property int itemWidth: 16
    property int itemRadius: 999

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

                width: isActive ? Math.round(root.itemWidth * 2.4) : Math.round(root.itemWidth * 1.4)
                height: root.itemHeight
                radius: root.itemRadius
                color: isActive ? root.activeColor : root.inactiveColor
                border.width: 0

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.showNumber
                    text: String(wsId)
                    color: isActive ? "#0a0a0a" : "#d6d6d6"
                    font.pixelSize: Math.round(root.itemHeight * 0.6)
                    font.weight: Font.DemiBold
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
