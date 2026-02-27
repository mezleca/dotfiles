import QtQuick
import QtQuick.Layouts

import ".."

Rectangle {
    id: card

    Theme { id: theme }

    required property string title
    default property alias content: content_column.data

    radius: 5
    color: theme.bgPrimary
    border.width: 1
    border.color: theme.borderSubtle
    implicitHeight: content_layout.implicitHeight + 20

    ColumnLayout {
        id: content_layout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Text {
            text: card.title
            color: theme.textPrimary
            font.family: theme.fontMain
            font.pixelSize: 13
            font.weight: Font.ExtraBold
        }

        ColumnLayout {
            id: content_column
            Layout.fillWidth: true
            spacing: 7
        }
    }
}
