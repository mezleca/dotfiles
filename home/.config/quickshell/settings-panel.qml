import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "components"

ShellRoot {
    id: root

    property int currentTab: 0
    property var wallpapers: []
    property string selectedPathKey: ""
    property real panelOpacity: 1.0

    function refresh_wallpapers() {
        scan_proc.command = ["/home/rel/.local/bin/wallpaperctl", "list"]
        scan_proc.running = true
    }

    function apply_wallpaper(path_value) {
        if (apply_proc.running) {
            return
        }

        const target_path = path_value || selectedPathKey
        if (target_path.length == 0) {
            return
        }

        apply_proc.command = ["/home/rel/.local/bin/wallpaperctl", "apply", target_path]
        apply_proc.running = true
    }

    function apply_theme(theme_data) {
        settings.accent = theme_data.accent
        settings.bgPrimary = theme_data.bgPrimary
        settings.bgSecondary = theme_data.bgSecondary
        settings.bgTertiary = theme_data.bgTertiary
        settings.borderSubtle = theme_data.borderSubtle
        settings.textPrimary = theme_data.textPrimary
        settings.textMuted = theme_data.textMuted
        settings.selected = theme_data.selected
    }

    function is_valid_hex(color_value) {
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test((color_value || "").trim())
    }

    function close_panel() {
        if (settings.transitionFadeOut) {
            panelFadeOut.restart()
        } else {
            Qt.quit()
        }
    }

    readonly property var predefined_themes: [
        {
            name: "noctalia dark",
            accent: "#6ca0ff",
            bgPrimary: "#13151a",
            bgSecondary: "#171a21",
            bgTertiary: "#1d212a",
            borderSubtle: "#2b3040",
            textPrimary: "#e6eaf2",
            textMuted: "#9ba7bb",
            selected: "#24344f"
        },
        {
            name: "graphite",
            accent: "#78b0ff",
            bgPrimary: "#141414",
            bgSecondary: "#111111",
            bgTertiary: "#0f0f0f",
            borderSubtle: "#2b2b2b",
            textPrimary: "#d6d6d6",
            textMuted: "#9aa9bb",
            selected: "#22344f"
        },
        {
            name: "slate",
            accent: "#7ab7ff",
            bgPrimary: "#10161c",
            bgSecondary: "#0c1116",
            bgTertiary: "#090e13",
            borderSubtle: "#283240",
            textPrimary: "#d8e1ed",
            textMuted: "#9ba9bc",
            selected: "#1f3348"
        },
        {
            name: "warm dark",
            accent: "#f5b57a",
            bgPrimary: "#181410",
            bgSecondary: "#14100d",
            bgTertiary: "#100d0b",
            borderSubtle: "#3a2e27",
            textPrimary: "#f2e3d5",
            textMuted: "#b99f89",
            selected: "#3f2f26"
        },
        {
            name: "paper light",
            accent: "#4d77c8",
            bgPrimary: "#f2f4f8",
            bgSecondary: "#e9edf4",
            bgTertiary: "#dde3ee",
            borderSubtle: "#bcc7d8",
            textPrimary: "#1e2a3c",
            textMuted: "#5b6a80",
            selected: "#cfdaf0"
        },
        {
            name: "sand light",
            accent: "#4f7f7a",
            bgPrimary: "#f7f4ee",
            bgSecondary: "#f0ece3",
            bgTertiary: "#e7e0d4",
            borderSubtle: "#cdc1ae",
            textPrimary: "#2e2a24",
            textMuted: "#6f6458",
            selected: "#ddd4c6"
        }
    ]

    Theme {
        id: theme
    }

    readonly property var settings: ShellSettings

    Process {
        id: scan_proc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const parsed = []

                for (let i = 0; i < lines.length; i += 1) {
                    const item_path = (lines[i] || "").trim()
                    if (item_path.length > 0) {
                        parsed.push({ path: item_path })
                    }
                }

                root.wallpapers = parsed
            }
        }
    }

    Process {
        id: apply_proc
    }

    component StyledButton: Button {
        id: btn

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

    component StyledTextField: TextField {
        id: field

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

    component StyledSlider: Slider {
        id: slider

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

    component StyledComboBox: ComboBox {
        id: combo

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

    component SectionCard: Rectangle {
        id: card

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

    component TransitionSelect: Item {
        id: transitionRoot

        implicitHeight: 30
        implicitWidth: 220

        function summaryText() {
            const items = []
            if (settings.transitionFadeIn) {
                items.push("fade in")
            }
            if (settings.transitionFadeOut) {
                items.push("fade out")
            }
            if (items.length === 0) {
                return "none"
            }
            return items.join(" + ")
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
                text: transitionRoot.summaryText()
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (transitionPopup.visible) {
                        transitionPopup.close()
                    } else {
                        transitionPopup.open()
                    }
                }
            }
        }

        Popup {
            id: transitionPopup
            parent: panel.contentItem
            x: transitionRoot.mapToItem(panel.contentItem, 0, 0).x
            y: transitionRoot.mapToItem(panel.contentItem, 0, transitionRoot.height + 4).y
            width: 220
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 8

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

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        StyledCheckBox {
                            id: none_check
                            checked: !settings.transitionFadeIn && !settings.transitionFadeOut
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            onClicked: {
                                settings.transitionFadeIn = false
                                settings.transitionFadeOut = false
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "none"
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            settings.transitionFadeIn = false
                            settings.transitionFadeOut = false
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 24

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        StyledCheckBox {
                            id: fade_in_check
                            checked: settings.transitionFadeIn
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            onClicked: settings.transitionFadeIn = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "fade in"
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fade_in_check.toggle()
                    }
                }

                Item {
                    width: parent.width
                    height: 24

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        StyledCheckBox {
                            id: fade_out_check
                            checked: settings.transitionFadeOut
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            onClicked: settings.transitionFadeOut = checked
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: "fade out"
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fade_out_check.toggle()
                    }
                }
            }
        }
    }

    component StyledCheckBox: CheckBox {
        id: styled_check

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

    component SettingsToggleRow: Item {
        id: row_root

        required property string title
        required property bool checked
        required property var on_toggle

        implicitHeight: 24

        Row {
            anchors.fill: parent
            spacing: 8

            StyledCheckBox {
                id: check
                checked: row_root.checked
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                onClicked: row_root.on_toggle(checked)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                width: parent.width - 26

                Text {
                    text: row_root.title
                    color: theme.textPrimary
                    font.family: theme.fontMain
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    component ColorInputRow: Item {
        id: color_row

        required property string label
        required property string value
        required property var on_apply

        implicitHeight: 36

        RowLayout {
            anchors.fill: parent
            spacing: 10

            Text {
                Layout.preferredWidth: 120
                text: color_row.label
                color: theme.textPrimary
                font.family: theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 4
                color: color_row.value
                border.width: 1
                border.color: theme.borderSubtle
            }

            StyledTextField {
                id: input
                Layout.fillWidth: true
                text: color_row.value
                onEditingFinished: {
                    const v = text.trim()
                    if (root.is_valid_hex(v)) {
                        color_row.on_apply(v)
                    } else {
                        text = color_row.value
                    }
                }
            }

            StyledButton {
                text: "Apply"
                onClicked: {
                    const v = input.text.trim()
                    if (root.is_valid_hex(v)) {
                        color_row.on_apply(v)
                    } else {
                        input.text = color_row.value
                    }
                }
            }
        }
    }

    FloatingWindow {
        id: panel
        visible: true
        implicitWidth: 920
        implicitHeight: 560
        color: "transparent"
        title: "Shell Settings"

        Shortcut {
            sequence: "Escape"
            onActivated: root.close_panel()
        }

        onVisibleChanged: {
            if (!visible) {
                Qt.quit()
            }
        }

        Rectangle {
            id: panelSurface
            anchors.fill: parent
            radius: 6
            color: theme.bgPrimary
            border.width: 1
            border.color: theme.borderSubtle
            opacity: root.panelOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 5
                    color: theme.bgSecondary
                    border.width: 1
                    border.color: theme.borderSubtle

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Repeater {
                            model: [
                                { name: "Config", idx: 0 },
                                { name: "Wallpaper", idx: 1 },
                                { name: "Colors", idx: 2 }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                width: 130
                                height: parent.height
                                radius: 4
                                color: root.currentTab == modelData.idx ? theme.selected : "transparent"
                                border.width: root.currentTab == modelData.idx ? 1 : 0
                                border.color: root.currentTab == modelData.idx ? theme.textAccent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: theme.textPrimary
                                    font.family: theme.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentTab = modelData.idx
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 5
                    color: theme.bgSecondary
                    border.width: 1
                    border.color: theme.borderSubtle

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 12
                        sourceComponent: root.currentTab == 0 ? config_tab : (root.currentTab == 1 ? wallpaper_tab : colors_tab)
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: panelFadeIn
        target: root
        property: "panelOpacity"
        from: 0.0
        to: 1.0
        duration: Math.max(0, settings.transitionDurationMs)
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: panelFadeOut
        target: root
        property: "panelOpacity"
        from: root.panelOpacity
        to: 0.0
        duration: Math.max(0, settings.transitionDurationMs)
        easing.type: Easing.OutCubic
        onFinished: Qt.quit()
    }

    Component {
        id: config_tab

        Flickable {
            clip: true
            contentWidth: width
            contentHeight: config_content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: config_content
                width: parent.width
                spacing: 10

                SectionCard {
                    Layout.fillWidth: true
                    title: "Bar Modules"

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Workspaces"
                        checked: settings.showWorkspaces
                        on_toggle: checked => { settings.showWorkspaces = checked }
                    }

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Window Title"
                        checked: settings.showTitle
                        on_toggle: checked => { settings.showTitle = checked }
                    }

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "System Tray"
                        checked: settings.showTray
                        on_toggle: checked => { settings.showTray = checked }
                    }

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "CPU"
                        checked: settings.showCpu
                        on_toggle: checked => { settings.showCpu = checked }
                    }

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Memory"
                        checked: settings.showMem
                        on_toggle: checked => { settings.showMem = checked }
                    }

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Clock"
                        checked: settings.showClock
                        on_toggle: checked => { settings.showClock = checked }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Bar"

                    Text {
                        text: "Position"
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: ["top", "bottom"]
                        currentIndex: settings.barPosition === "bottom" ? 1 : 0
                        onActivated: {
                            settings.barPosition = currentIndex === 1 ? "bottom" : "top"
                        }
                    }

                    Text {
                        text: "Height: " + String(settings.barHeight)
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 28
                        to: 64
                        stepSize: 1
                        value: settings.barHeight
                        onMoved: settings.barHeight = Math.round(value)
                    }
                }

                SectionCard {
                    visible: settings.showTitle
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Title"

                    Text {
                        text: "Max chars: " + String(settings.titleLimit)
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 20
                        to: 120
                        stepSize: 1
                        value: settings.titleLimit
                        onMoved: settings.titleLimit = Math.round(value)
                    }
                }

                SectionCard {
                    visible: settings.showWorkspaces
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Workspaces"

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Show Number"
                        checked: settings.workspaceShowNumber
                        on_toggle: checked => { settings.workspaceShowNumber = checked }
                    }

                    Text {
                        text: "Visible count: " + String(settings.workspaceCount)
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 3
                        to: 10
                        stepSize: 1
                        value: settings.workspaceCount
                        onMoved: settings.workspaceCount = Math.round(value)
                    }

                    Text {
                        text: "Width: " + String(settings.workspaceWidth)
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 10
                        to: 48
                        stepSize: 1
                        value: settings.workspaceWidth
                        onMoved: settings.workspaceWidth = Math.round(value)
                    }

                    Text {
                        text: "Radius: " + String(settings.workspaceRadius)
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 1
                        value: settings.workspaceRadius
                        onMoved: settings.workspaceRadius = Math.round(value)
                    }
                }

                SectionCard {
                    visible: settings.showClock
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Clock"

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: ["show text", "open calendar popup"]
                        currentIndex: settings.clockClickAction == "open_calendar_popup" ? 1 : 0
                        onActivated: {
                            settings.clockClickAction = currentIndex == 1 ? "open_calendar_popup" : "show_text"
                        }
                    }

                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    title: "Transitions"

                    Text {
                        text: "Effects"
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    TransitionSelect {
                        Layout.preferredWidth: 200
                    }

                    Text {
                        text: "Duration: " + String(settings.transitionDurationMs) + " ms"
                        color: theme.textMuted
                        font.family: theme.fontMain
                        font.pixelSize: 11
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: 600
                        stepSize: 10
                        value: settings.transitionDurationMs
                        onMoved: settings.transitionDurationMs = Math.round(value)
                    }
                }

            }
        }
    }

    Component {
        id: wallpaper_tab

        ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.wallpapers.length > 0 ? "Wallpapers (" + root.wallpapers.length + ")" : "Wallpapers"
                    color: theme.textPrimary
                    font.family: theme.fontMain
                    font.weight: Font.ExtraBold
                    font.pixelSize: 13
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledButton {
                    text: "Refresh"
                    onClicked: root.refresh_wallpapers()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 5
                color: theme.bgPrimary
                border.width: 1
                border.color: theme.borderSubtle
                clip: true

                Item {
                    id: grid_host
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true

                    readonly property int desired_cell_width: 220
                    readonly property int desired_cell_height: 142
                    readonly property int columns: Math.max(1, Math.floor(width / desired_cell_width))

                    GridView {
                        id: wallpaper_grid
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: grid_host.columns * grid_host.desired_cell_width
                        cellWidth: grid_host.desired_cell_width
                        cellHeight: grid_host.desired_cell_height
                        clip: true
                        model: root.wallpapers
                        cacheBuffer: 1200

                        delegate: Item {
                            required property var modelData

                            width: wallpaper_grid.cellWidth - 10
                            height: wallpaper_grid.cellHeight - 10
                            x: Math.floor((wallpaper_grid.cellWidth - width) / 2)
                            y: Math.floor((wallpaper_grid.cellHeight - height) / 2)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 6
                                color: "transparent"
                                border.width: root.selectedPathKey == modelData.path ? 2 : 1
                                border.color: root.selectedPathKey == modelData.path ? theme.textAccent : theme.borderSubtle
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 4
                                clip: true
                                color: theme.bgTertiary

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: false
                                    sourceSize.width: 320
                                    sourceSize.height: 220
                                    source: "file://" + modelData.path
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedPathKey = modelData.path
                                    root.apply_wallpaper(modelData.path)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: colors_tab

        Flickable {
            clip: true
            contentWidth: width
            contentHeight: color_content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: color_content
                width: parent.width
                spacing: 10

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    title: "Accent"

                    RowLayout {
                        spacing: 8

                        Repeater {
                            model: ["#78b0ff", "#6dd6a6", "#ff9f6d", "#f87171", "#c084fc", "#facc15", "#34d399", "#60a5fa"]

                            delegate: Rectangle {
                                required property var modelData

                                width: 26
                                height: 26
                                radius: 4
                                color: modelData
                                border.width: settings.accent == modelData ? 2 : 1
                                border.color: settings.accent == modelData ? "#ffffff" : theme.borderSubtle

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settings.accent = modelData
                                }
                            }
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    title: "Predefined Themes"

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: root.predefined_themes

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 86
                                radius: 5
                                color: modelData.bgSecondary
                                border.width: settings.bgPrimary == modelData.bgPrimary && settings.accent == modelData.accent ? 2 : 1
                                border.color: settings.bgPrimary == modelData.bgPrimary && settings.accent == modelData.accent ? settings.accent : theme.borderSubtle

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 7

                                    Row {
                                        width: parent.width
                                        height: 28
                                        spacing: 0

                                        Rectangle {
                                            width: parent.width / 3
                                            height: parent.height
                                            radius: 3
                                            color: modelData.bgPrimary
                                        }

                                        Rectangle {
                                            width: parent.width / 3
                                            height: parent.height
                                            color: modelData.bgSecondary
                                        }

                                        Rectangle {
                                            width: parent.width / 3
                                            height: parent.height
                                            radius: 3
                                            color: modelData.bgTertiary
                                        }
                                    }

                                    Row {
                                        spacing: 8

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 3
                                            color: modelData.accent
                                        }

                                        Text {
                                            text: modelData.name
                                            color: modelData.textPrimary
                                            font.family: theme.fontMain
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.apply_theme(modelData)
                                }
                            }
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    title: "Custom Palette"

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "accent"
                        value: settings.accent
                        on_apply: v => { settings.accent = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "bg_primary"
                        value: settings.bgPrimary
                        on_apply: v => { settings.bgPrimary = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "bg_secondary"
                        value: settings.bgSecondary
                        on_apply: v => { settings.bgSecondary = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "bg_tertiary"
                        value: settings.bgTertiary
                        on_apply: v => { settings.bgTertiary = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "border_subtle"
                        value: settings.borderSubtle
                        on_apply: v => { settings.borderSubtle = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "text_primary"
                        value: settings.textPrimary
                        on_apply: v => { settings.textPrimary = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "text_muted"
                        value: settings.textMuted
                        on_apply: v => { settings.textMuted = v }
                    }

                    ColorInputRow {
                        Layout.fillWidth: true
                        label: "selected"
                        value: settings.selected
                        on_apply: v => { settings.selected = v }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refresh_wallpapers()
        if (settings.transitionFadeIn) {
            root.panelOpacity = 0.0
            panelFadeIn.restart()
        } else {
            root.panelOpacity = 1.0
        }
    }
}
