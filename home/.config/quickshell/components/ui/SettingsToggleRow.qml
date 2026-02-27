import QtQuick

import ".."
import "."

Item {
    id: row_root

    Theme { id: theme }

    required property string title
    required property bool checked
    required property var on_toggle

    implicitHeight: 24

    Row {
        anchors.fill: parent
        spacing: 8

        StyledCheckBox {
            id: check
            checked: row_root.checked
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            onClicked: row_root.on_toggle(checked)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            width: parent.width - 26

            Text {
                text: row_root.title
                color: theme.textPrimary
                font.family: theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
