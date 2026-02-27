import QtQuick
import QtQuick.Controls

import ".."

CheckBox {
    id: styled_check

    Theme { id: theme }

    indicator: Rectangle {
        width: 18
        height: 18
        radius: 2
        color: styled_check.checked ? theme.textAccent : theme.bgPrimary
        border.width: 1
        border.color: styled_check.checked ? theme.textAccent : theme.borderSubtle
    }

    contentItem: Item { width: 0; height: 0 }
    hoverEnabled: true
}
