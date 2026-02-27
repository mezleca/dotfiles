import QtQuick
import QtQuick.Controls

import ".."

Button {
    id: btn

    Theme { id: theme }

    implicitHeight: 30
    implicitWidth: Math.max(84, contentItem.implicitWidth + 20)

    contentItem: Text {
        text: btn.text
        color: theme.textPrimary
        font.family: theme.fontMain
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 4
        color: btn.down ? theme.bgTertiary : theme.selected
        border.width: 1
        border.color: theme.borderSubtle
    }
}
