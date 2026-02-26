import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property bool enabled: true
    property color bgColor: "#1b2a3e"
    property color bgHover: "#233955"
    property color bgDisabled: "#202020"
    property color textColor: "#d6d6d6"
    signal clicked()

    implicitWidth: Math.max(88, label.implicitWidth + 24)
    implicitHeight: 34
    radius: 6
    border.width: 1
    border.color: root.enabled ? "#3c5582" : "#2b2b2b"
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
