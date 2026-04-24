pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property var events: ([])
  property bool loading: false
  property bool available: false
  property string lastError: ""

  readonly property string scriptPath: Quickshell.shellDir + "/Scripts/python/src/calendar/ics-subscription-fetch.py"
  readonly property string cacheFile: Settings.cacheDir + "calendar-subscriptions.json"

  function eventsForDate(year, month, day) {
    var startOfDay = new Date(year, month, day).getTime() / 1000
    var endOfDay = startOfDay + 86400
    return root.events.filter(function (evt) {
      return evt.start >= startOfDay && evt.start < endOfDay
    })
  }

  function eventsForMonth(year, month) {
    var startOfMonth = new Date(year, month, 1).getTime() / 1000
    var endOfMonth = new Date(year, month + 1, 1).getTime() / 1000
    return root.events.filter(function (evt) {
      return evt.start >= startOfMonth && evt.start < endOfMonth
    })
  }

  function hasEventsOnDate(year, month, day) {
    return root.eventsForDate(year, month, day).length > 0
  }

  function buildSubscriptionsJson() {
    var subs = Settings.data.calendar.subscriptions || []
    var config = []
    for (var i = 0; i < subs.length; i++) {
      var s = subs[i]
      if (s.enabled !== false) {
        config.push({
                      "url": s.url || "",
                      "name": s.name || "Subscription",
                      "color": s.color || "",
                      "enabled": true
                    })
      }
    }
    return JSON.stringify(config)
  }

  function loadEvents() {
    if (!root.available || root.loading)
      return
    if (!Settings.data.calendar.subscriptions || Settings.data.calendar.subscriptions.length === 0) {
      root.events = []
      return
    }

    root.loading = true
    root.lastError = ""

    var subsJson = root.buildSubscriptionsJson()

    var now = new Date()
    var daysBehind = 7
    var daysAhead = 45
    var fromTs = Math.floor(new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysBehind).getTime() / 1000)
    var toTs = Math.floor(new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysAhead).getTime() / 1000)

    fetchProcess.command = ["python3", root.scriptPath, "--config-json", subsJson, "--from", String(fromTs), "--to", String(toTs)]
    fetchProcess.running = true
  }

  function parseEvents(raw) {
    if (!raw || raw.trim() === "")
      return []
    try {
      var parsed = JSON.parse(raw)
      if (!Array.isArray(parsed))
        return []
      var seen = {}
      var deduped = []
      for (var i = 0; i < parsed.length; i++) {
        var evt = parsed[i]
        var key = evt.uid + "|" + evt.start
        if (!seen[key]) {
          seen[key] = true
          deduped.push(evt)
        }
      }
      return deduped
    } catch (e) {
      Logger.w("CalendarSubscriptionService", "Failed to parse events:", e)
      return []
    }
  }

  function setEvents(newEvents) {
    root.events = newEvents
    root.loading = false
    saveCache()
  }

  function loadFromCache() {
    if (!cacheFileView.path)
      return
    try {
      var cached = cacheAdapter.cachedEvents
      if (cached && cached.length > 0) {
        root.events = cached
      }
    } catch (e) {}
  }

  function saveCache() {
    try {
      cacheAdapter.cachedEvents = root.events
      cacheFileView.writeAdapter()
    } catch (e) {}
  }

  Process {
    id: availabilityProcess
    running: false
    command: ["sh", "-c", "command -v python3 && python3 -c \"import icalendar; import recurring_ical_events\""]
    onExited: function (code) {
      root.available = (code === 0)
      if (root.available) {
        Logger.i("CalendarSubscriptionService", "Available")
        root.loadFromCache()
        root.loadEvents()
      } else {
        Logger.d("CalendarSubscriptionService", "Unavailable (python3 + icalendar + recurring-ical-events required)")
      }
    }
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: fetchProcess
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var events = root.parseEvents(text)
        root.setEvents(events)
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.lastError = text.trim()
          Logger.w("CalendarSubscriptionService", root.lastError)
        }
      }
    }
    onExited: function (code) {
      if (code !== 0) {
        root.loading = false
        if (!root.lastError)
          root.lastError = "Process exited with code " + code
      }
    }
  }

  FileView {
    id: cacheFileView
    path: root.cacheFile
    printErrors: false
    watchChanges: false

    JsonAdapter {
      id: cacheAdapter
      property var cachedEvents: ([])
    }
  }

  Timer {
    id: refreshTimer
    interval: (Settings.data.calendar.refreshInterval || 300) * 1000 * 60
    repeat: true
    running: root.available && Settings.data.calendar.subscriptions && Settings.data.calendar.subscriptions.length > 0
    onTriggered: root.loadEvents()
  }

  Connections {
    target: Settings.data.calendar
    function onSubscriptionsChanged() {
      if (root.available) {
        refreshDebounce.restart()
      }
    }
  }

  Timer {
    id: refreshDebounce
    interval: 1000
    onTriggered: root.loadEvents()
  }

  Component.onCompleted: {
    availabilityProcess.running = true
  }
}
