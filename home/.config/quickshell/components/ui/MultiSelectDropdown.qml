import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import ".."
import "."

Item {
    id: root

    Theme { id: theme }

    property var options: []
    property var selectedKeys: []
    property string noneKey: "none"
    property string allKey: "all"
    property bool includeNone: true
    property bool includeAll: true
    property string labelNone: "none"
    property string labelAll: "all"
    property string summaryText: ""
    property var popupParent: null
    property bool isOpen: false
    // placeholder to keep state if needed later

    signal selectionChanged(var keys)

    implicitHeight: 30
    implicitWidth: 220

    function computeSummary() {
        if (root.selectedKeys.indexOf(root.noneKey) !== -1) {
            return root.labelNone
        }
        if (root.selectedKeys.indexOf(root.allKey) !== -1) {
            return root.labelAll
        }
        if (root.selectedKeys.length === 0) {
            return root.labelNone
        }
        const labels = []
        for (let i = 0; i < root.options.length; i += 1) {
            const opt = root.options[i]
            if (root.selectedKeys.indexOf(opt.key) !== -1) {
                labels.push(opt.label)
            }
        }
        return labels.join(" + ")
    }

    function applySelection(keys) {
        const next = root.normalizeSelection(keys)
        root.selectedKeys = next
        root.selectionChanged(next)
    }

    function setNone() {
        if (root.selectedKeys.indexOf(root.noneKey) !== -1) {
            applySelection([])
        } else {
            applySelection([root.noneKey])
        }
    }

    function setAll() {
        const keys = [root.allKey]
        for (let i = 0; i < root.options.length; i += 1) {
            keys.push(root.options[i].key)
        }
        applySelection(keys)
    }

    function toggleKey(key) {
        const next = root.selectedKeys.slice(0)
        const idx = next.indexOf(key)
        if (idx === -1) {
            next.push(key)
        } else {
            next.splice(idx, 1)
        }
        applySelection(next)
    }

    onSelectedKeysChanged: {
        const normalized = root.normalizeSelection(root.selectedKeys)
        if (normalized.join("|") !== root.selectedKeys.join("|")) {
            root.selectedKeys = normalized
        }
    }

    Rectangle {
        id: selectButton
        anchors.fill: parent
        radius: 4
        color: theme.bgSecondary
        border.width: 1
        border.color: theme.borderSubtle

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: root.summaryText.length > 0 ? root.summaryText : root.computeSummary()
            color: theme.textPrimary
            font.family: theme.fontMain
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: "▾"
            color: theme.textMuted
            font.family: theme.fontMain
            font.pixelSize: 11
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (root.isOpen) {
                    dropdownPopup.close()
                } else {
                    dropdownPopup.x = root.mapToItem(dropdownPopup.parent, 0, 0).x
                    dropdownPopup.y = root.mapToItem(dropdownPopup.parent, 0, root.height + 4).y
                    dropdownPopup.open()
                }
            }
        }
    }

    Popup {
        id: dropdownPopup
        parent: root.popupParent || root.parent
        width: 220
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 8
        onOpened: {
            root.isOpen = true
            root.updatePopupPosition()
        }
        onClosed: {
            root.isOpen = false
        }

        background: Rectangle {
            radius: 4
            color: theme.bgSecondary
            border.width: 1
            border.color: theme.borderSubtle
        }

        Column {
            spacing: 6
            width: parent.width

            Item {
                width: parent.width
                height: 24
                visible: root.includeNone
                opacity: 1.0

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    StyledCheckBox {
                        id: none_check
                        checked: root.selectedKeys.indexOf(root.noneKey) !== -1
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        onClicked: root.setNone()
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.labelNone
                        color: theme.textPrimary
                        font.family: theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setNone()
                }
            }

            Item {
                width: parent.width
                height: 24
                visible: root.includeAll

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    StyledCheckBox {
                        id: all_check
                        checked: root.selectedKeys.indexOf(root.allKey) !== -1
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        onClicked: root.setAll()
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.labelAll
                        color: theme.textPrimary
                        font.family: theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setAll()
                }
            }

            Repeater {
                model: root.options

                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: 24
                    property bool locked: root.includeNone && root.selectedKeys.indexOf(root.noneKey) !== -1
                    opacity: locked ? 0.5 : 1.0

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                    StyledCheckBox {
                        id: item_check
                        checked: root.selectedKeys.indexOf(modelData.key) !== -1
                        enabled: !locked
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        onClicked: root.toggleKey(modelData.key)
                    }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.label
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !locked
                        onClicked: root.toggleKey(modelData.key)
                    }
                }
            }
        }
    }

    function normalizeSelection(keys) {
        const next = []
        for (let i = 0; i < keys.length; i += 1) {
            const k = keys[i]
            if (next.indexOf(k) === -1) {
                next.push(k)
            }
        }

        const hasNone = root.includeNone && next.indexOf(root.noneKey) !== -1
        if (hasNone) {
            return [root.noneKey]
        }

        const hasAll = root.includeAll && next.indexOf(root.allKey) !== -1
        if (hasAll) {
            const allKeys = [root.allKey]
            for (let i = 0; i < root.options.length; i += 1) {
                allKeys.push(root.options[i].key)
            }
            return allKeys
        }

        return next
    }

    function updatePopupPosition() {
        if (!dropdownPopup.visible) {
            return
        }
        const target = root.popupParent || root.parent
        if (!target) {
            return
        }
        let nextX = root.mapToItem(target, 0, 0).x
        let nextY = root.mapToItem(target, 0, root.height + 4).y
        const maxX = target.width - dropdownPopup.width - 8
        const maxY = target.height - dropdownPopup.implicitHeight - 8

        if (nextX < 8) {
            nextX = 8
        } else if (nextX > maxX) {
            nextX = Math.max(8, maxX)
        }

        if (nextY < 8) {
            nextY = 8
        } else if (nextY > maxY) {
            nextY = Math.max(8, maxY)
        }

        dropdownPopup.x = nextX
        dropdownPopup.y = nextY
    }

    onWidthChanged: updatePopupPosition()
    onHeightChanged: updatePopupPosition()
}
