import QtQuick

Row {
    id: root

    property string icon: ""
    property string value: "--%"
    property color textColor: "#b5b5b5"
    property int iconTextGap: 6
    property int itemHeight: 24
    spacing: iconTextGap
    height: itemHeight

    Text {
        text: root.icon
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        font.family: "Manrope"
        font.weight: Font.ExtraBold
        font.pixelSize: 13
    }

    Text {
        text: root.value
        anchors.verticalCenter: parent.verticalCenter
        color: root.textColor
        font.family: "Manrope"
        font.weight: Font.ExtraBold
        font.pixelSize: 13
    }
}
