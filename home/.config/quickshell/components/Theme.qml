import QtQuick

Item {
    id: root
    width: 0
    height: 0
    visible: false

    readonly property var settings: ShellSettings

    readonly property color bgPrimary: settings.bgPrimary
    readonly property color bgSecondary: settings.bgSecondary
    readonly property color bgTertiary: settings.bgTertiary
    readonly property color border: settings.accent
    readonly property color borderSubtle: settings.borderSubtle
    readonly property color textPrimary: settings.textPrimary
    readonly property color textMuted: settings.textMuted
    readonly property color textAccent: settings.accent
    readonly property color selected: settings.selected

    readonly property string fontMain: "Manrope"
    readonly property string fontMono: "CommitMono Nerd Font"
}
