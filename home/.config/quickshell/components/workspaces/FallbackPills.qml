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
                width: index === 0 ? 24 : 14
                height: 10
                radius: 999
                color: index === 0 ? root.activeColor : root.inactiveColor
                border.width: 0
            }
        }
    }
}
