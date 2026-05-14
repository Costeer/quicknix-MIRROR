pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property bool isInhibited: false

  function disable(showToast = true) {
    if (!isInhibited)
      return;

    if (inhibitorProcess.running)
      inhibitorProcess.signal(15);
    isInhibited = false;
    if (showToast)
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.disabled"), "keep-awake-off");
    Logger.i("IdleInhibitor", "Disabled");
  }

  function enable(showToast = true) {
    if (isInhibited)
      return;

    inhibitorProcess.command = ["systemd-inhibit", "--what=idle", "--why=QuickNix caffeine", "--mode=block", "sleep", "infinity"];
    inhibitorProcess.running = true;
    isInhibited = true;
    if (showToast)
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.enabled"), "keep-awake-on");
    Logger.i("IdleInhibitor", "Enabled");
  }

  function toggle() {
    if (isInhibited)
      disable();
    else
      enable();
  }

  Process {
    id: inhibitorProcess
    running: false

    onExited: function (exitCode, exitStatus) {
      if (isInhibited) {
        Logger.w("IdleInhibitor", "Process exited unexpectedly:", exitCode);
        isInhibited = false;
      }
    }
  }

  Component.onDestruction: {
    if (inhibitorProcess.running)
      inhibitorProcess.signal(15);
  }
}
