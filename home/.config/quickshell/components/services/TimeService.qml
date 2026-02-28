pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property var currentDate: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentDate = new Date()
    }
}
