pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI

Singleton {
  id: root

  readonly property bool idleMonitorAvailable: {
    try { return typeof IdleMonitor !== "undefined"; } catch (e) { return false; }
  }

  property bool _initialized: false
  property bool _enableGate: true
  property bool monitorsOff: false
  property bool lidClosed: false
  property bool lidStateKnown: false

  readonly property bool enabled: Settings.data.idle.enabled && !IdleInhibitorService.isInhibited
  readonly property int screenOffTimeout: Settings.data.idle.screenOffTimeout
  readonly property int lockTimeout: Settings.data.idle.lockTimeout
  readonly property int suspendTimeout: Settings.data.idle.suspendTimeout
  readonly property int hibernateTimeout: Settings.data.idle.hibernateTimeout || 0
  readonly property int lidHibernateTimeout: Settings.data.idle.lidHibernateTimeout || 0
  readonly property bool disableCaffeineOnLidClose: Settings.data.idle.disableCaffeineOnLidClose !== false
  readonly property bool isShellLocked: PanelService.lockScreen ? PanelService.lockScreen.active : false

  signal lockRequested
  signal fadeToLockRequested
  signal cancelFadeToLock
  signal fadeToDpmsRequested
  signal cancelFadeToDpms
  signal requestMonitorOff
  signal requestMonitorOn
  signal requestSuspend
  signal requestHibernate

  property var screenOffMonitor: null
  property var lockMonitor: null
  property var suspendMonitor: null
  property var hibernateMonitor: null

  onScreenOffTimeoutChanged: rearm()
  onLockTimeoutChanged: rearm()
  onSuspendTimeoutChanged: rearm()
  onHibernateTimeoutChanged: rearm()
  onLidHibernateTimeoutChanged: if (lidClosed) restartLidHibernateTimer()
  onEnabledChanged: rearm()

  function init() {
    if (_initialized)
      return;
    _initialized = true;
    if (!idleMonitorAvailable) {
      Logger.w("IdleService", "IdleMonitor unavailable; automatic idle actions disabled");
      return;
    }
    createMonitors();
    Logger.i("IdleService", "Initialized enabled=" + enabled + " screenOff=" + screenOffTimeout + " lock=" + lockTimeout + " suspend=" + suspendTimeout + " hibernate=" + hibernateTimeout + " lidHibernate=" + lidHibernateTimeout + " inhibited=" + IdleInhibitorService.isInhibited);
  }

  function rearm() {
    if (!_initialized)
      return;
    _enableGate = false;
    Qt.callLater(() => _enableGate = true);
  }

  function monitorQml() {
    return `import QtQuick\nimport Quickshell.Wayland\nIdleMonitor { enabled: false; timeout: 86400; respectInhibitors: true }`;
  }

  function lidStateCommand() {
    return "for lid in /proc/acpi/button/lid/*/state; do [ -r \"$lid\" ] && cat \"$lid\" && exit 0; done; exit 1";
  }

  function handleLidState(output) {
    const closed = String(output || "").toLowerCase().indexOf("closed") >= 0;
    const wasClosed = lidClosed;
    lidStateKnown = true;
    lidClosed = closed;

    if (closed && !wasClosed) {
      Logger.i("IdleService", "Laptop lid closed, locking session and turning off monitors");
      if (disableCaffeineOnLidClose && IdleInhibitorService.isInhibited) {
        Logger.i("IdleService", "Disabling caffeine because laptop lid closed");
        IdleInhibitorService.disable(false);
      }
      CompositorService.lock();
      lidMonitorOffTimer.restart();
      restartLidHibernateTimer();
    } else if (!closed && wasClosed) {
      lidHibernateTimer.stop();
      if (monitorsOff) {
        Logger.i("IdleService", "Laptop lid opened, turning monitors on");
        requestMonitorOn();
      }
    }
  }

  function restartLidHibernateTimer() {
    lidHibernateTimer.stop();
    if (lidHibernateTimeout > 0) {
      lidHibernateTimer.interval = Math.max(1, lidHibernateTimeout) * 1000;
      lidHibernateTimer.restart();
      Logger.i("IdleService", "Lid hibernate timer armed for " + lidHibernateTimeout + " seconds");
    }
  }

  function createMonitors() {
    try {
      screenOffMonitor = Qt.createQmlObject(monitorQml(), root, "QuickNix.ScreenOffIdleMonitor");
      screenOffMonitor.timeout = Qt.binding(() => root.screenOffTimeout > 0 ? root.screenOffTimeout : 86400);
      screenOffMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.screenOffTimeout > 0);
      Logger.i("IdleService", "Screen-off monitor created timeout=" + screenOffMonitor.timeout + " enabled=" + screenOffMonitor.enabled);
      screenOffMonitor.isIdleChanged.connect(() => {
        Logger.i("IdleService", "Screen-off idle changed: " + screenOffMonitor.isIdle);
        if (screenOffMonitor.isIdle) root.fadeToDpmsRequested();
        else {
          root.cancelFadeToDpms();
          if (root.monitorsOff && !root.lidClosed) root.requestMonitorOn();
        }
      });

      lockMonitor = Qt.createQmlObject(monitorQml(), root, "QuickNix.LockIdleMonitor");
      lockMonitor.timeout = Qt.binding(() => root.lockTimeout > 0 ? root.lockTimeout : 86400);
      lockMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.lockTimeout > 0);
      Logger.i("IdleService", "Lock monitor created timeout=" + lockMonitor.timeout + " enabled=" + lockMonitor.enabled);
      lockMonitor.isIdleChanged.connect(() => {
        Logger.i("IdleService", "Lock idle changed: " + lockMonitor.isIdle + " locked=" + root.isShellLocked);
        if (lockMonitor.isIdle && !root.isShellLocked) root.fadeToLockRequested();
        else root.cancelFadeToLock();
      });

      suspendMonitor = Qt.createQmlObject(monitorQml(), root, "QuickNix.SuspendIdleMonitor");
      suspendMonitor.timeout = Qt.binding(() => root.suspendTimeout > 0 ? root.suspendTimeout : 86400);
      suspendMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.suspendTimeout > 0);
      Logger.i("IdleService", "Suspend monitor created timeout=" + suspendMonitor.timeout + " enabled=" + suspendMonitor.enabled);
      suspendMonitor.isIdleChanged.connect(() => {
        Logger.i("IdleService", "Suspend idle changed: " + suspendMonitor.isIdle);
        if (suspendMonitor.isIdle) root.requestSuspend();
      });

      hibernateMonitor = Qt.createQmlObject(monitorQml(), root, "QuickNix.HibernateIdleMonitor");
      hibernateMonitor.timeout = Qt.binding(() => root.hibernateTimeout > 0 ? root.hibernateTimeout : 86400);
      hibernateMonitor.enabled = Qt.binding(() => root._enableGate && root.enabled && root.hibernateTimeout > 0);
      Logger.i("IdleService", "Hibernate monitor created timeout=" + hibernateMonitor.timeout + " enabled=" + hibernateMonitor.enabled);
      hibernateMonitor.isIdleChanged.connect(() => {
        Logger.i("IdleService", "Hibernate idle changed: " + hibernateMonitor.isIdle);
        if (hibernateMonitor.isIdle) root.requestHibernate();
      });
    } catch (e) {
      Logger.e("IdleService", "Failed to create IdleMonitor objects: " + e);
    }
  }

  Process {
    id: lidStateProcess
    command: ["sh", "-c", root.lidStateCommand()]
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.handleLidState(this.text)
    }
  }

  Timer {
    id: lidPollTimer
    interval: 500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!lidStateProcess.running) lidStateProcess.running = true
  }

  Timer {
    id: lidMonitorOffTimer
    interval: 150
    repeat: false
    onTriggered: root.requestMonitorOff()
  }

  Timer {
    id: lidHibernateTimer
    interval: 86400 * 1000
    repeat: false
    onTriggered: if (root.lidClosed) root.requestHibernate()
  }

  onRequestMonitorOff: {
    Logger.i("IdleService", "Requesting monitor off");
    monitorsOff = true;
    CompositorService.turnOffMonitors();
  }

  onRequestMonitorOn: {
    if (lidClosed) {
      Logger.i("IdleService", "Ignoring monitor-on request while laptop lid is closed");
      return;
    }
    Logger.i("IdleService", "Requesting monitor on");
    monitorsOff = false;
    CompositorService.turnOnMonitors();
  }

  onLockRequested: {
    Logger.i("IdleService", "Requesting lock");
    CompositorService.lock();
  }

  onRequestSuspend: {
    if (Settings.data.general.lockOnSuspend) CompositorService.lockAndSuspend();
    else CompositorService.suspend();
  }

  onRequestHibernate: {
    Logger.i("IdleService", "Requesting hibernate");
    CompositorService.lock();
    CompositorService.hibernate();
  }
}
