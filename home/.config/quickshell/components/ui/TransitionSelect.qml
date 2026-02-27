import QtQuick

import ".."
import "."

MultiSelectDropdown {
    id: transitionRoot

    readonly property var settings: ShellSettings

    options: [
        { key: "fade_in", label: "fade in" },
        { key: "fade_out", label: "fade out" }
    ]

    includeNone: false
    includeAll: false
    popupParent: panel.contentItem

    selectedKeys: {
        const keys = []
        if (settings.transitionFadeIn) {
            keys.push("fade_in")
        }
        if (settings.transitionFadeOut) {
            keys.push("fade_out")
        }
        return keys
    }

    onSelectionChanged: keys => {
        const hasFadeIn = keys.indexOf("fade_in") !== -1
        const hasFadeOut = keys.indexOf("fade_out") !== -1

        settings.transitionFadeIn = hasFadeIn
        settings.transitionFadeOut = hasFadeOut
    }
}
