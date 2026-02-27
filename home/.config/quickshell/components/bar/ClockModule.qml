import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import ".."

Item {
    id: root

    property string barPosition: "top"
    property bool visibleClock: true
    property string clockMode: "time"
    property string clockClickAction: "show_text"

    property bool transitionFadeIn: true
    property bool transitionFadeOut: true
    property int transitionDurationMs: 180

    property bool showAltText: false
    property var calendarViewDate: new Date()
    property real calendarOpacity: 1.0

    Theme { id: theme }

    implicitWidth: clockText.implicitWidth
    implicitHeight: 24
    visible: visibleClock

    SystemClock {
        id: clock
        enabled: true
        precision: SystemClock.Minutes
    }

    readonly property var currentDate: clock.date

    function monthLabel(dateObj) {
        return dateObj.toLocaleString(Qt.locale().name, "MMMM yyyy")
    }

    function shiftCalendarMonth(delta) {
        const d = new Date(root.calendarViewDate.getTime())
        d.setMonth(d.getMonth() + delta, 1)
        root.calendarViewDate = d
    }

    function openCalendar() {
        if (calendarPopup.visible) {
            return
        }

        dismissLayer.visible = true
        calendarPopup.visible = true
        if (transitionFadeIn) {
            calendarOpacity = 0.0
            calendarFadeIn.restart()
        } else {
            calendarOpacity = 1.0
        }
    }

    function closeCalendar() {
        if (!calendarPopup.visible) {
            return
        }

        dismissLayer.visible = false

        if (transitionFadeOut) {
            calendarFadeOut.restart()
        } else {
            calendarOpacity = 1.0
            calendarPopup.visible = false
        }
    }

    function handleClockClick() {
        if (clockClickAction === "open_calendar_popup") {
            if (calendarPopup.visible) {
                closeCalendar()
            } else {
                openCalendar()
            }
            return
        }

        if (showAltText) {
            showAltText = false
            altTextTimer.stop()
        } else {
            showAltText = true
            altTextTimer.restart()
        }
    }

    Timer {
        id: altTextTimer
        interval: 2000
        repeat: false
        onTriggered: root.showAltText = false
    }

    NumberAnimation {
        id: calendarFadeIn
        target: root
        property: "calendarOpacity"
        from: 0.0
        to: 1.0
        duration: Math.max(0, transitionDurationMs)
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: calendarFadeOut
        target: root
        property: "calendarOpacity"
        from: root.calendarOpacity
        to: 0.0
        duration: Math.max(0, transitionDurationMs)
        easing.type: Easing.OutCubic
        onFinished: {
            root.calendarOpacity = 1.0
            calendarPopup.visible = false
        }
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: root.showAltText
            ? Qt.formatDateTime(root.currentDate, "ddd, dd MMM yyyy")
            : (clockMode === "date_time"
                ? Qt.formatDateTime(root.currentDate, "dd/MM HH:mm")
                : Qt.formatDateTime(root.currentDate, "HH:mm"))
        color: theme.textPrimary
        font.family: theme.fontMain
        font.weight: Font.ExtraBold
        font.pixelSize: 13
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.handleClockClick()
    }

    PopupWindow {
        id: dismissLayer
        visible: false
        color: "transparent"
        implicitWidth: 8000
        implicitHeight: 8000
        anchor.item: root
        anchor.rect.x: -4000
        anchor.rect.y: -4000

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeCalendar()
        }
    }

    PopupWindow {
        id: calendarPopup
        visible: false
        color: "transparent"
        implicitWidth: 300
        implicitHeight: 290
        anchor.item: root
        anchor.rect.x: {
            const preferredX = root.width - implicitWidth
            return Math.max(-root.x + 8, Math.min(preferredX, root.parent ? (root.parent.width - root.x - implicitWidth - 8) : preferredX))
        }
        anchor.rect.y: root.barPosition === "bottom" ? (-implicitHeight - 8) : (root.height + 8)

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: theme.bgSecondary
            border.width: 1
            border.color: theme.borderSubtle
            opacity: root.calendarOpacity

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        color: theme.bgPrimary
                        border.width: 1
                        border.color: theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftCalendarMonth(-1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.monthLabel(root.calendarViewDate)
                        color: theme.textPrimary
                        font.family: theme.fontMain
                        font.weight: Font.ExtraBold
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: 4
                        color: theme.bgPrimary
                        border.width: 1
                        border.color: theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            color: theme.textPrimary
                            font.family: theme.fontMain
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftCalendarMonth(1)
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: theme.textMuted
                                font.family: theme.fontMain
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 4

                    property int month: root.calendarViewDate.getMonth()
                    property int year: root.calendarViewDate.getFullYear()
                    property var daysModel: {
                        const firstOfMonth = new Date(year, month, 1)
                        const lastOfMonth = new Date(year, month + 1, 0)
                        const daysInMonth = lastOfMonth.getDate()
                        const firstDayOfWeek = 1
                        const jsDay = firstOfMonth.getDay()
                        const firstMapped = jsDay === 0 ? 7 : jsDay
                        const daysBefore = (firstMapped - firstDayOfWeek + 7) % 7
                        const days = []
                        const today = root.currentDate

                        const prevMonthLast = new Date(year, month, 0).getDate()
                        for (let i = daysBefore - 1; i >= 0; i -= 1) {
                            days.push({ day: prevMonthLast - i, currentMonth: false, today: false })
                        }

                        for (let day = 1; day <= daysInMonth; day += 1) {
                            const isToday = today.getFullYear() === year && today.getMonth() === month && today.getDate() === day
                            days.push({ day: day, currentMonth: true, today: isToday })
                        }

                        const remaining = 42 - days.length
                        for (let i = 1; i <= remaining; i += 1) {
                            days.push({ day: i, currentMonth: false, today: false })
                        }

                        return days
                    }

                    Repeater {
                        model: parent.daysModel

                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                radius: 4
                                color: modelData.today ? theme.textAccent : "transparent"
                                border.width: modelData.today ? 0 : 1
                                border.color: theme.borderSubtle
                                opacity: modelData.currentMonth ? 1.0 : 0.45

                                Text {
                                    anchors.centerIn: parent
                                    text: String(modelData.day)
                                    color: modelData.today ? theme.bgPrimary : theme.textPrimary
                                    font.family: theme.fontMain
                                    font.pixelSize: 11
                                    font.weight: modelData.today ? Font.ExtraBold : Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
