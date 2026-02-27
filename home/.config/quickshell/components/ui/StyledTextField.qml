import QtQuick
import QtQuick.Controls

import ".."

TextField {
    id: field

    Theme { id: theme }

    color: theme.textPrimary
    selectByMouse: true
    selectionColor: theme.selected
    selectedTextColor: theme.textPrimary
    font.family: theme.fontMono
    font.pixelSize: 12

    background: Rectangle {
        radius: 4
        color: theme.bgSecondary
        border.width: 1
        border.color: theme.borderSubtle
    }
}
