import Niri 0.1
import QtQuick

Item {
    id: root

    property int maxCount: 5
    property color activeColor: "#78b0ff"
    property color inactiveColor: "#2b2b2b"
    property int pillSpacing: 7

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Niri {
        id: niri
        Component.onCompleted: connect()
    }

    Row {
        id: row
        spacing: root.pillSpacing

        Repeater {
            model: niri.workspaces

            delegate: Rectangle {
                required property var model
                visible: index < root.maxCount
                width: model.isActive ? 24 : 14
                height: 10
                radius: 999
                color: model.isActive ? root.activeColor : root.inactiveColor
                border.width: 0

                Behavior on width {
                    NumberAnimation { duration: 120 }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: niri.focusWorkspaceById(model.id)
                }
            }
        }
    }
}
