import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Widgets

NBox {
  id: root
  Layout.fillWidth: true
  implicitHeight: calendarContent.implicitHeight + Style.margin2M

  readonly property string viewMode: _viewMode
  property string _viewMode: "month"

  readonly property var now: Time.now
  property int calendarMonth: now.getMonth()
  property int calendarYear: now.getFullYear()
  readonly property int firstDayOfWeek: Settings.data.location && Settings.data.location.firstDayOfWeek !== undefined ? Settings.data.location.firstDayOfWeek : I18n.locale.firstDayOfWeek

  property int selectedDay: now.getDate()
  property int selectedMonth: now.getMonth()
  property int selectedYear: now.getFullYear()

  function _daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate();
  }

  function _clampDay(year, month, day) {
    return Math.max(1, Math.min(day, _daysInMonth(year, month)));
  }

  function selectDate(year, month, day) {
    selectedYear = year;
    selectedMonth = month;
    selectedDay = _clampDay(year, month, day);

    if (calendarYear !== selectedYear)
      calendarYear = selectedYear;
    if (calendarMonth !== selectedMonth)
      calendarMonth = selectedMonth;
  }

  function selectToday() {
    const t = new Date();
    selectDate(t.getFullYear(), t.getMonth(), t.getDate());
  }

  function resetToToday() {
    calendarMonth = now.getMonth();
    calendarYear = now.getFullYear();
    selectToday();
  }

  function _selectedDateObject() {
    return new Date(selectedYear, selectedMonth, selectedDay);
  }

  function _weekStartDate(date) {
    // Timetable weeks always start on Monday, independent of locale settings.
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const day = d.getDay();
    const diff = (day + 6) % 7;
    d.setDate(d.getDate() - diff);
    return d;
  }

  property var weekStart: _weekStartDate(_selectedDateObject())

  function _weekEndDate() {
    const d = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate());
    d.setDate(d.getDate() + 6);
    return d;
  }

  function _weekTitle() {
    const end = _weekEndDate();
    const startMonth = I18n.locale.monthName(weekStart.getMonth(), Locale.ShortFormat).toUpperCase();
    const endMonth = I18n.locale.monthName(end.getMonth(), Locale.ShortFormat).toUpperCase();
    if (weekStart.getFullYear() !== end.getFullYear())
      return startMonth + " " + weekStart.getDate() + " " + weekStart.getFullYear() + " — " + endMonth + " " + end.getDate() + " " + end.getFullYear();
    if (weekStart.getMonth() !== end.getMonth())
      return startMonth + " " + weekStart.getDate() + " — " + endMonth + " " + end.getDate() + " " + end.getFullYear();
    return startMonth + " " + weekStart.getDate() + " — " + end.getDate() + " " + end.getFullYear();
  }

  function toggleView() {
    _viewMode = _viewMode === "month" ? "week" : "month";
  }

  function navigateToPreviousPeriod() {
    if (_viewMode === "week")
      navigateToPreviousWeek();
    else
      navigateToPreviousMonth();
  }

  function navigateToNextPeriod() {
    if (_viewMode === "week")
      navigateToNextWeek();
    else
      navigateToNextMonth();
  }

  function navigateToPreviousWeek() {
    _moveSelectionByDays(-7);
  }

  function navigateToNextWeek() {
    _moveSelectionByDays(7);
  }

  function _moveSelectionByDays(deltaDays) {
    const d = _selectedDateObject();
    d.setDate(d.getDate() + deltaDays);
    selectDate(d.getFullYear(), d.getMonth(), d.getDate());
  }

  function _moveSelectionByMonths(deltaMonths) {
    const day = selectedDay;
    const d = new Date(selectedYear, selectedMonth + deltaMonths, 1);
    selectDate(d.getFullYear(), d.getMonth(), _clampDay(d.getFullYear(), d.getMonth(), day));
  }

  function _jumpToMonthEdge(toEnd) {
    selectDate(calendarYear, calendarMonth, toEnd ? _daysInMonth(calendarYear, calendarMonth) : 1);
  }

  function _selectedIsInVisibleMonth() {
    return selectedYear === calendarYear && selectedMonth === calendarMonth;
  }

  function _selectedIndexInGrid() {
    const model = grid.daysModel;
    if (!model || model.length === 0)
      return -1;
    for (var i = 0; i < model.length; i++) {
      const it = model[i];
      if (it && it.year === selectedYear && it.month === selectedMonth && it.day === selectedDay)
        return i;
    }
    return -1;
  }

  function showSelectedTooltip() {
    const idx = _selectedIndexInGrid();
    if (idx < 0)
      return false;
    const it = grid.daysModel[idx];
    if (!it || !it.currentMonth)
      return false;
    const tip = root.buildEventTooltip(it.year, it.month, it.day);
    if (!tip)
      return false;
    const cell = dayRepeater.itemAt(idx);
    if (!cell)
      return false;
    TooltipService.show(cell, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontDefault);
    return true;
  }

  // Returns true if the key was handled.
  function handleKey(event) {
    switch (event.key) {
    case Qt.Key_Escape:
      TooltipService.hide();
      return true;
    case Qt.Key_V:
      toggleView();
      return true;
    case Qt.Key_T:
      if (event.modifiers & Qt.ControlModifier) {
        selectToday();
        return true;
      }
      return false;
    case Qt.Key_Left:
      if (_viewMode === "week")
        navigateToPreviousWeek();
      else
        _moveSelectionByDays(-1);
      return true;
    case Qt.Key_Right:
      if (_viewMode === "week")
        navigateToNextWeek();
      else
        _moveSelectionByDays(1);
      return true;
    case Qt.Key_Up:
      _moveSelectionByDays(-7);
      return true;
    case Qt.Key_Down:
      _moveSelectionByDays(7);
      return true;
    case Qt.Key_PageUp:
      if (_viewMode === "week")
        navigateToPreviousWeek();
      else
        _moveSelectionByMonths(-1);
      return true;
    case Qt.Key_PageDown:
      if (_viewMode === "week")
        navigateToNextWeek();
      else
        _moveSelectionByMonths(1);
      return true;
    case Qt.Key_H:
      navigateToPreviousPeriod();
      return true;
    case Qt.Key_L:
      navigateToNextPeriod();
      return true;
    case Qt.Key_R:
      resetToToday();
      return true;
    case Qt.Key_Home:
      _jumpToMonthEdge(false);
      return true;
    case Qt.Key_End:
      _jumpToMonthEdge(true);
      return true;
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      return showSelectedTooltip();
    default:
      return false;
    }
  }

  function getISOWeekNumber(date) {
    const target = new Date(date.valueOf());
    const dayNr = (date.getDay() + 6) % 7;
    target.setDate(target.getDate() - dayNr + 3);
    const firstThursday = new Date(target.getFullYear(), 0, 4);
    const diff = target - firstThursday;
    const oneWeek = 1000 * 60 * 60 * 24 * 7;
    return 1 + Math.round(diff / oneWeek);
  }

  function navigateToPreviousMonth() {
    let newDate = new Date(root.calendarYear, root.calendarMonth - 1, 1);
    root.calendarYear = newDate.getFullYear();
    root.calendarMonth = newDate.getMonth();

    // Keep selection anchored to visible month
    root.selectDate(root.calendarYear, root.calendarMonth, root.selectedDay);
  }

  function navigateToNextMonth() {
    let newDate = new Date(root.calendarYear, root.calendarMonth + 1, 1);
    root.calendarYear = newDate.getFullYear();
    root.calendarMonth = newDate.getMonth();

    root.selectDate(root.calendarYear, root.calendarMonth, root.selectedDay);
  }

  onCalendarMonthChanged: {
    // If month is changed externally (buttons / wheel), keep selection in view.
    if (!_selectedIsInVisibleMonth()) {
      selectDate(calendarYear, calendarMonth, selectedDay);
    }
  }

  onCalendarYearChanged: {
    if (!_selectedIsInVisibleMonth()) {
      selectDate(calendarYear, calendarMonth, selectedDay);
    }
  }

  function eventsForDate(year, month, day) {
    if (!Settings.data.location.showCalendarEvents || !CalendarSubscriptionService.available)
      return []
    return CalendarSubscriptionService.eventsForDate(year, month, day)
  }

  function eventsIntersectingDate(year, month, day) {
    if (!Settings.data.location.showCalendarEvents || !CalendarSubscriptionService.available)
      return []
    var startOfDay = new Date(year, month, day).getTime() / 1000
    var endOfDay = startOfDay + 86400
    var evts = CalendarSubscriptionService.events.filter(function (evt) {
      return evt.start < endOfDay && evt.end > startOfDay
    })
    evts.sort(function (a, b) { return a.start - b.start })
    return evts
  }

  function timedEventsForDate(year, month, day) {
    return eventsIntersectingDate(year, month, day).filter(function (evt) { return !evt.allDay })
  }

  function allDayEventsForDate(year, month, day) {
    return eventsIntersectingDate(year, month, day).filter(function (evt) { return evt.allDay })
  }

  function minutesFromDayStart(epoch, year, month, day) {
    var dayStart = new Date(year, month, day).getTime() / 1000
    return Math.max(0, Math.min(1440, Math.round((epoch - dayStart) / 60)))
  }

  function eventDurationMinutes(evt, year, month, day) {
    var dayStart = new Date(year, month, day).getTime() / 1000
    var dayEnd = dayStart + 86400
    return Math.max(20, Math.round((Math.min(evt.end, dayEnd) - Math.max(evt.start, dayStart)) / 60))
  }

  function hasEventsOnDate(year, month, day) {
    if (!Settings.data.location.showCalendarEvents || !CalendarSubscriptionService.available)
      return false
    return CalendarSubscriptionService.hasEventsOnDate(year, month, day)
  }

  function getEventColor(evt, isToday) {
    if (evt.color && evt.color.length > 0)
      return evt.color
    if (isToday)
      return Color.mSecondary
    return Color.mPrimary
  }

  function formatTime(epoch) {
    var d = new Date(epoch * 1000)
    var h = d.getHours()
    var m = d.getMinutes()
    var ampm = ""
    if (Settings.data.location.use12hourFormat) {
      ampm = h >= 12 ? " PM" : " AM"
      h = h % 12
      if (h === 0)
        h = 12
    }
    return (m < 10 ? h + ":0" + m : h + ":" + m) + ampm
  }

  function buildEventTooltip(year, month, day) {
    var evts = root.eventsForDate(year, month, day)
    if (evts.length === 0)
      return ""
    var lines = []
    for (var i = 0; i < Math.min(evts.length, 8); i++) {
      var evt = evts[i]
      var time = evt.allDay ? "All day" : (formatTime(evt.start) + " - " + formatTime(evt.end))
      lines.push(evt.summary + "\n" + time + (evt.location ? " · " + evt.location : ""))
    }
    if (evts.length > 8)
      lines.push("+" + (evts.length - 8) + " more")
    return lines.join("\n\n")
  }

  WheelHandler {
    target: root
    enabled: root._viewMode === "month"
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function (event) {
      if (event.angleDelta.y > 0)
        root.navigateToPreviousMonth();
      else if (event.angleDelta.y < 0)
        root.navigateToNextMonth();
      event.accepted = true;
    }
  }

  ColumnLayout {
    id: calendarContent
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Item {
        Layout.preferredWidth: Style.marginS
      }

      NText {
        text: root._viewMode === "week" ? root._weekTitle() : I18n.locale.monthName(root.calendarMonth, Locale.LongFormat).toUpperCase() + " " + root.calendarYear
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NDivider {
        Layout.fillWidth: true
      }

      Item {
        implicitWidth: prevMonthBtn.implicitWidth
        implicitHeight: prevMonthBtn.implicitHeight

        NIconButton {
          id: prevMonthBtn
          anchors.fill: parent
          icon: "chevron-left"
          onClicked: root.navigateToPreviousPeriod()
        }

        NKeyHint {
          key: "h"
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -badgeSize * 0.25
          anchors.bottomMargin: -badgeSize * 0.25
          z: 1
        }
      }

      Item {
        implicitWidth: resetBtn.implicitWidth
        implicitHeight: resetBtn.implicitHeight

        NIconButton {
          id: resetBtn
          anchors.fill: parent
          icon: "calendar"
          onClicked: root.resetToToday()
        }

        NKeyHint {
          key: "r"
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -badgeSize * 0.25
          anchors.bottomMargin: -badgeSize * 0.25
          z: 1
        }
      }

      Item {
        implicitWidth: viewBtn.implicitWidth
        implicitHeight: viewBtn.implicitHeight

        NIconButton {
          id: viewBtn
          anchors.fill: parent
          icon: root._viewMode === "week" ? "calendar-month" : "calendar-week"
          onClicked: root.toggleView()
        }

        NKeyHint {
          key: "v"
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -badgeSize * 0.25
          anchors.bottomMargin: -badgeSize * 0.25
          z: 1
        }
      }

      Item {
        implicitWidth: nextMonthBtn.implicitWidth
        implicitHeight: nextMonthBtn.implicitHeight

        NIconButton {
          id: nextMonthBtn
          anchors.fill: parent
          icon: "chevron-right"
          onClicked: root.navigateToNextPeriod()
        }

        NKeyHint {
          key: "l"
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.rightMargin: -badgeSize * 0.25
          anchors.bottomMargin: -badgeSize * 0.25
          z: 1
        }
      }
    }

    RowLayout {
      visible: root._viewMode === "month"
      Layout.fillWidth: true
      spacing: 0

      Item {
        visible: Settings.data.location && Settings.data.location.showWeekNumberInCalendar
        Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.7 : 0
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 7
        rows: 1
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
          model: 7
          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.fontSizeS * 2

            NText {
              anchors.centerIn: parent
              text: {
                let dayIndex = (root.firstDayOfWeek + index) % 7;
                const dayName = I18n.locale.dayName(dayIndex, Locale.ShortFormat);
                return dayName.substring(0, 2).toUpperCase();
              }
              color: Color.mPrimary
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }

    RowLayout {
      visible: root._viewMode === "month"
      Layout.fillWidth: true
      spacing: 0

      ColumnLayout {
        visible: Settings.data.location && Settings.data.location.showWeekNumberInCalendar
        Layout.preferredWidth: visible ? Style.baseWidgetSize * 0.7 : 0
        Layout.alignment: Qt.AlignTop
        spacing: Style.marginXXS

        property var weekNumbers: {
          if (!grid.daysModel || grid.daysModel.length === 0)
            return [];
          const weeks = [];
          const numWeeks = Math.ceil(grid.daysModel.length / 7);
          for (var i = 0; i < numWeeks; i++) {
            const dayIndex = i * 7;
            if (dayIndex < grid.daysModel.length) {
              const weekDay = grid.daysModel[dayIndex];
              const date = new Date(weekDay.year, weekDay.month, weekDay.day);
              let thursday = new Date(date);
              let daysToThursday = (4 - root.firstDayOfWeek + 7) % 7;
              thursday.setDate(date.getDate() + daysToThursday);
              weeks.push(root.getISOWeekNumber(thursday));
            }
          }
          return weeks;
        }

        Repeater {
          model: parent.weekNumbers
          Item {
            Layout.preferredWidth: Style.baseWidgetSize * 0.7
            Layout.preferredHeight: Style.baseWidgetSize * 0.9

            NText {
              anchors.centerIn: parent
              color: Qt.alpha(Color.mPrimary, 0.7)
              pointSize: Style.fontSizeXXS
              text: modelData
            }
          }
        }
      }

      GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 7
        columnSpacing: Style.marginXXS
        rowSpacing: Style.marginXXS

        property int month: root.calendarMonth
        property int year: root.calendarYear

        property var daysModel: {
          const firstOfMonth = new Date(year, month, 1);
          const lastOfMonth = new Date(year, month + 1, 0);
          const daysInMonth = lastOfMonth.getDate();
          const firstDayOfWeek = root.firstDayOfWeek;
          const firstOfMonthDayOfWeek = firstOfMonth.getDay();
          let daysBefore = (firstOfMonthDayOfWeek - firstDayOfWeek + 7) % 7;
          const lastOfMonthDayOfWeek = lastOfMonth.getDay();
          const daysAfter = (firstDayOfWeek - lastOfMonthDayOfWeek - 1 + 7) % 7;
          const days = [];
          const today = new Date();

          const prevMonth = new Date(year, month, 0);
          const prevMonthDays = prevMonth.getDate();
          for (var i = daysBefore - 1; i >= 0; i--) {
            const day = prevMonthDays - i;
            days.push({
                        "day": day,
                        "month": month - 1,
                        "year": month === 0 ? year - 1 : year,
                        "today": false,
                        "currentMonth": false
                      });
          }

          for (var day = 1; day <= daysInMonth; day++) {
            const date = new Date(year, month, day);
            const isToday = date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate();
            days.push({
                        "day": day,
                        "month": month,
                        "year": year,
                        "today": isToday,
                        "currentMonth": true
                      });
          }

          for (var i = 1; i <= daysAfter; i++) {
            days.push({
                        "day": i,
                        "month": month + 1,
                        "year": month === 11 ? year + 1 : year,
                        "today": false,
                        "currentMonth": false
                      });
          }

          return days;
        }

        Repeater {
          id: dayRepeater
          model: grid.daysModel

          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 0.9

            readonly property bool isSelected: modelData.year === root.selectedYear && modelData.month === root.selectedMonth && modelData.day === root.selectedDay

            property var dayEvents: modelData.currentMonth ? root.eventsForDate(modelData.year, modelData.month, modelData.day) : []

            MouseArea {
              anchors.fill: parent
              hoverEnabled: modelData.currentMonth && dayEvents.length > 0
              onClicked: {
                TooltipService.hide(parent);
                root.selectDate(modelData.year, modelData.month, modelData.day);
                if (modelData.currentMonth) {
                  // Optional: show immediately when clicking a day with events
                  var tip = root.buildEventTooltip(modelData.year, modelData.month, modelData.day);
                  if (tip)
                    TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontDefault);
                }
              }
              onEntered: {
                var tip = root.buildEventTooltip(modelData.year, modelData.month, modelData.day)
                if (tip)
                  TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontDefault)
              }
              onExited: TooltipService.hide(parent)
            }

            Rectangle {
              width: Style.baseWidgetSize * 0.9
              height: Style.baseWidgetSize * 0.9
              anchors.centerIn: parent
              radius: Style.radiusM
              color: modelData.today ? Color.mSecondary : "transparent"
              border.width: isSelected ? Style.borderM : 0
              border.color: isSelected ? Color.mPrimary : "transparent"

              NText {
                anchors.centerIn: parent
                text: modelData.day
                color: {
                  if (modelData.today)
                    return Color.mOnSecondary;
                  if (modelData.currentMonth)
                    return Color.mOnSurface;
                  return Color.mOnSurfaceVariant;
                }
                opacity: modelData.currentMonth ? 1.0 : 0.4
                pointSize: Style.fontSizeM
                font.weight: modelData.today ? Style.fontWeightBold : Style.fontWeightMedium
              }

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }

              Behavior on border.color {
                ColorAnimation { duration: Style.animationFast }
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.marginXXXS
              spacing: Style.marginXXXS
              visible: dayEvents.length > 0

              Repeater {
                model: Math.min(dayEvents.length, 4)

                Rectangle {
                  width: Style.marginXS
                  height: width
                  radius: width / 2
                  color: {
                    var evt = dayEvents[index]
                    return root.getEventColor(evt, modelData.today)
                  }
                }
              }
            }
          }
        }
      }
    }

    ColumnLayout {
      id: weekView
      visible: root._viewMode === "week"
      Layout.fillWidth: true
      spacing: Style.marginS

      property real timeColumnWidth: Style.baseWidgetSize * 1.05
      property real dayHeaderHeight: Style.baseWidgetSize * 1.1
      property real allDayHeight: Style.baseWidgetSize * 1.0
      property real hourHeight: Math.round(34 * Style.uiScaleRatio)
      property real gridHeight: hourHeight * 24
      property var weekDays: {
        var days = []
        for (var i = 0; i < 7; i++) {
          var d = new Date(root.weekStart.getFullYear(), root.weekStart.getMonth(), root.weekStart.getDate() + i)
          var today = new Date()
          days.push({
                      "day": d.getDate(),
                      "month": d.getMonth(),
                      "year": d.getFullYear(),
                      "dow": d.getDay(),
                      "today": d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate()
                    })
        }
        return days
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        Item {
          Layout.preferredWidth: weekView.timeColumnWidth
          Layout.preferredHeight: weekView.dayHeaderHeight
        }

        Repeater {
          model: weekView.weekDays

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: weekView.dayHeaderHeight
            radius: Style.radiusM
            color: modelData.today ? Color.mSecondary : Qt.alpha(Color.mSurface, 0.55)
            border.width: Style.borderS
            border.color: modelData.today ? Qt.alpha(Color.mSecondary, 0.8) : Style.boxBorderColor

            Column {
              anchors.centerIn: parent
              spacing: -Style.marginXXS

              NText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.locale.dayName(modelData.dow, Locale.ShortFormat).substring(0, 2).toUpperCase()
                pointSize: Style.fontSizeXXS
                font.weight: Style.fontWeightBold
                color: modelData.today ? Color.mOnSecondary : Color.mPrimary
              }

              NText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.day
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: modelData.today ? Color.mOnSecondary : Color.mOnSurface
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectDate(modelData.year, modelData.month, modelData.day)
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          Layout.preferredWidth: weekView.timeColumnWidth
          Layout.preferredHeight: weekView.allDayHeight
          text: qsTr("ALL")
          pointSize: Style.fontSizeXXS
          font.weight: Style.fontWeightBold
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignRight
          verticalAlignment: Text.AlignVCenter
        }

        Repeater {
          model: weekView.weekDays

          Rectangle {
            id: allDayCell
            Layout.fillWidth: true
            Layout.preferredHeight: weekView.allDayHeight
            radius: Style.radiusS
            color: Qt.alpha(Color.mSurface, 0.45)
            border.width: Style.borderS
            border.color: Style.boxBorderColor
            clip: true

            property var dayData: modelData
            property var allDayEvents: root.allDayEventsForDate(dayData.year, dayData.month, dayData.day)

            Column {
              anchors.fill: parent
              anchors.margins: Style.marginXXXS
              spacing: Style.marginXXXS

              Repeater {
                model: Math.min(parent.parent.allDayEvents.length, 2)

                Rectangle {
                  property var eventData: allDayCell.allDayEvents[index]
                  width: parent.width
                  height: Math.round(Style.baseWidgetSize * 0.32)
                  radius: Style.radiusXS
                  color: root.getEventColor(eventData, allDayCell.dayData.today)

                  NText {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginXXS
                    anchors.rightMargin: Style.marginXXS
                    text: parent.eventData.summary || qsTr("Event")
                    pointSize: Style.fontSizeXXS
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnPrimary
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                  }
                }
              }
            }
          }
        }
      }

      Flickable {
        id: weekFlick
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(360 * Style.uiScaleRatio)
        contentWidth: width
        contentHeight: weekView.gridHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
          width: weekFlick.width
          height: weekView.gridHeight

          Repeater {
            model: 25
            Item {
              width: parent.width
              height: Style.borderS
              y: index * weekView.hourHeight

              Rectangle {
                x: weekView.timeColumnWidth + Style.marginXXS
                width: parent.width - x
                height: Style.borderS
                color: index % 6 === 0 ? Qt.alpha(Color.mOutline, 0.65) : Qt.alpha(Color.mOutline, 0.25)
              }

              NText {
                visible: index < 24
                x: 0
                y: -contentHeight / 2
                width: weekView.timeColumnWidth - Style.marginXXS
                text: (index < 10 ? "0" + index : index) + ":00"
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignRight
              }
            }
          }

          Row {
            x: weekView.timeColumnWidth + Style.marginXXS
            y: 0
            width: parent.width - x
            height: parent.height
            spacing: Style.marginXXS

            Repeater {
              model: weekView.weekDays

              Item {
                id: dayColumn
                width: (parent.width - Style.marginXXS * 6) / 7
                height: parent.height
                property var dayData: modelData

                Rectangle {
                  anchors.fill: parent
                  radius: Style.radiusXS
                  color: Qt.alpha(Color.mSurface, 0.22)
                  border.width: Style.borderS
                  border.color: Qt.alpha(Color.mOutline, 0.25)
                }

                property var timedEvents: root.timedEventsForDate(dayData.year, dayData.month, dayData.day)

                Repeater {
                  model: parent.timedEvents

                  Rectangle {
                    property var eventData: modelData
                    x: Style.marginXXXS
                    y: (root.minutesFromDayStart(eventData.start, dayColumn.dayData.year, dayColumn.dayData.month, dayColumn.dayData.day) / 60) * weekView.hourHeight
                    width: parent.width - Style.marginXXS
                    height: Math.max(Style.baseWidgetSize * 0.65, (root.eventDurationMinutes(eventData, dayColumn.dayData.year, dayColumn.dayData.month, dayColumn.dayData.day) / 60) * weekView.hourHeight - Style.marginXXXS)
                    radius: Style.radiusS
                    color: Qt.alpha(root.getEventColor(eventData, dayColumn.dayData.today), 0.9)
                    border.width: Style.borderS
                    border.color: Qt.alpha(Color.mOnPrimary, 0.25)
                    clip: true

                    Column {
                      anchors.fill: parent
                      anchors.margins: Style.marginXXXS
                      spacing: 0

                      NText {
                        width: parent.width
                        text: eventData.summary || qsTr("Event")
                        pointSize: Style.fontSizeXXS
                        font.weight: Style.fontWeightBold
                        color: Color.mOnPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                      }

                      NText {
                        width: parent.width
                        text: root.formatTime(eventData.start) + " – " + root.formatTime(eventData.end)
                        pointSize: Style.fontSizeXXS
                        color: Qt.alpha(Color.mOnPrimary, 0.82)
                        elide: Text.ElideRight
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onEntered: {
                        var tip = (eventData.summary || qsTr("Event")) + "\n" + root.formatTime(eventData.start) + " - " + root.formatTime(eventData.end) + (eventData.location ? " · " + eventData.location : "")
                        TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontDefault)
                      }
                      onExited: TooltipService.hide(parent)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
