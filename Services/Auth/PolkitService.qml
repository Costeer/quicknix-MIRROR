pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons

Singleton {
  id: root

  readonly property bool disablePolkitIntegration: Quickshell.env("QUICKNIX_DISABLE_POLKIT") === "1"

  property bool polkitAvailable: false
  property var agent: null

  function createPolkitAgent() {
    try {
      const qmlString = `
        import QtQuick
        import Quickshell.Services.Polkit

        PolkitAgent {}
      `;

      agent = Qt.createQmlObject(qmlString, root, "QuickNix.PolkitAgent");
      polkitAvailable = true;
      Logger.i("PolkitService", "Initialized successfully");
    } catch (e) {
      polkitAvailable = false;
      Logger.w("PolkitService", "Polkit integration unavailable; authentication prompts disabled. This requires a Quickshell build with Polkit support.");
    }
  }

  Component.onCompleted: {
    if (disablePolkitIntegration) {
      Logger.i("PolkitService", "Disabled by QUICKNIX_DISABLE_POLKIT=1");
      return;
    }

    createPolkitAgent();
  }
}
