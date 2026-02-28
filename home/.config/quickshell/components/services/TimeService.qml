pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property var currentDate: new Date()

    function alignToMinute() {
        const now = new Date()
        const msToNextMinute = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds())
        alignTimer.interval = Math.max(1000, msToNextMinute)
        alignTimer.start()
    }

    Timer {
        id: alignTimer
        repeat: false
        onTriggered: {
            root.currentDate = new Date()
            minuteTimer.restart()
        }
    }

    Timer {
        id: minuteTimer
        interval: 60000
        repeat: true
        onTriggered: root.currentDate = new Date()
    }

    Component.onCompleted: alignToMinute()
}
