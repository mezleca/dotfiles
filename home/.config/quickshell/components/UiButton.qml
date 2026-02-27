import QtQuick

Rectangle {
    id: root

    Theme {
        id: theme
    }

    property alias text: label.text
    property bool enabled: true
    property color bgColor: theme.selected
    property color bgHover: theme.bgTertiary
    property color bgDisabled: theme.bgSecondary
    property color textColor: theme.textPrimary
    signal clicked()

    implicitWidth: Math.max(88, label.implicitWidth + 24)
    implicitHeight: 34
    radius: 6
    border.width: 1
    border.color: root.enabled ? theme.textAccent : theme.borderSubtle
    color: !root.enabled ? bgDisabled : mouseArea.containsMouse ? bgHover : bgColor
    opacity: root.enabled ? 1.0 : 0.7

    Text {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.family: "Manrope"
        font.weight: Font.DemiBold
        font.pixelSize: 12
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
