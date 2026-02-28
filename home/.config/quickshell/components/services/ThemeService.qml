pragma Singleton

import QtQuick
import ".."

Item {
    id: root
    visible: false

    readonly property var settings: ShellSettings
    readonly property var predefinedThemes: [
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

    function applyTheme(themeData) {
        if (!themeData) {
            return
        }
        settings.accent = themeData.accent
        settings.bgPrimary = themeData.bgPrimary
        settings.bgSecondary = themeData.bgSecondary
        settings.bgTertiary = themeData.bgTertiary
        settings.borderSubtle = themeData.borderSubtle
        settings.textPrimary = themeData.textPrimary
        settings.textMuted = themeData.textMuted
        settings.selected = themeData.selected
    }

    function isValidHex(colorValue) {
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test((colorValue || "").trim())
    }
}
