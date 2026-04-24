pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  property bool isInhibited: false

  function toggle() {
    if (isInhibited) {
      if (inhibitorProcess.running)
        inhibitorProcess.signal(15);
      isInhibited = false;
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.disabled"), "keep-awake-off");
      Logger.i("IdleInhibitor", "Disabled");
    } else {
      inhibitorProcess.command = ["systemd-inhibit", "--what=idle", "--why=QuickNix caffeine", "--mode=block", "sleep", "infinity"];
      inhibitorProcess.running = true;
      isInhibited = true;
      ToastService.showNotice(I18n.tr("tooltips.keep-awake"), I18n.tr("common.enabled"), "keep-awake-on");
      Logger.i("IdleInhibitor", "Enabled");
    }
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
