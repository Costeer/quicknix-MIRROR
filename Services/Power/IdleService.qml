pragma Singleton

import QtQuick
import Quickshell
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

  readonly property bool enabled: Settings.data.idle.enabled && !IdleInhibitorService.isInhibited
  readonly property int screenOffTimeout: Settings.data.idle.screenOffTimeout
  readonly property int lockTimeout: Settings.data.idle.lockTimeout
  readonly property int suspendTimeout: Settings.data.idle.suspendTimeout
  readonly property bool isShellLocked: PanelService.lockScreen ? PanelService.lockScreen.active : false

  signal lockRequested
  signal fadeToLockRequested
  signal cancelFadeToLock
  signal fadeToDpmsRequested
  signal cancelFadeToDpms
  signal requestMonitorOff
  signal requestMonitorOn
  signal requestSuspend

  property var screenOffMonitor: null
  property var lockMonitor: null
  property var suspendMonitor: null

  onScreenOffTimeoutChanged: rearm()
  onLockTimeoutChanged: rearm()
  onSuspendTimeoutChanged: rearm()
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
    Logger.i("IdleService", "Initialized enabled=" + enabled + " screenOff=" + screenOffTimeout + " lock=" + lockTimeout + " suspend=" + suspendTimeout + " inhibited=" + IdleInhibitorService.isInhibited);
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
          if (root.monitorsOff) root.requestMonitorOn();
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
    } catch (e) {
      Logger.e("IdleService", "Failed to create IdleMonitor objects: " + e);
    }
  }

  onRequestMonitorOff: {
    Logger.i("IdleService", "Requesting monitor off");
    monitorsOff = true;
    CompositorService.turnOffMonitors();
  }

  onRequestMonitorOn: {
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
}
