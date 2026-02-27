import QtQuick
import QtQuick.Controls

import ".."

ComboBox {
    id: combo

    Theme { id: theme }

    implicitHeight: 30

    contentItem: Text {
        leftPadding: 10
        rightPadding: 24
        text: combo.displayText
        color: theme.textPrimary
        font.family: theme.fontMain
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 4
        color: theme.bgSecondary
        border.width: 1
        border.color: theme.borderSubtle
    }

    delegate: ItemDelegate {
        width: combo.width
        text: modelData
        font.family: theme.fontMain
        font.pixelSize: 12
        font.weight: Font.DemiBold
        padding: 8

        contentItem: Text {
            text: parent.text
            color: theme.textPrimary
            font.family: theme.fontMain
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 4
            color: highlighted ? theme.selected : "transparent"
        }
    }

    popup: Popup {
        y: combo.height + 4
        width: combo.width
        padding: 6

        background: Rectangle {
            radius: 4
            color: theme.bgSecondary
            border.width: 1
            border.color: theme.borderSubtle
        }

        contentItem: ListView {
            implicitHeight: contentHeight
            model: combo.delegateModel
            clip: true
            currentIndex: combo.highlightedIndex
        }
    }

    indicator: Text {
        text: "▾"
        color: theme.textMuted
        font.family: theme.fontMain
        font.pixelSize: 11
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

}
