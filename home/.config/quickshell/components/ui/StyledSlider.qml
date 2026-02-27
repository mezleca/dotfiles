import QtQuick
import QtQuick.Controls

import ".."

Slider {
    id: slider

    Theme { id: theme }

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: 8
        radius: 4
        color: theme.bgTertiary

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: 4
            color: theme.textAccent
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 8
        implicitHeight: 8
        radius: 4
        color: "transparent"
        border.width: 0
    }
}
