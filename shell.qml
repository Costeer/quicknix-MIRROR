import QtQuick
import Quickshell

import qs.Commons

import qs.Modules.Bar
import qs.Modules.LockScreen
import qs.Modules.MainScreen
import qs.Modules.Notification
import qs.Modules.OSD
import qs.Modules.Toast

import qs.Services.Compositor
import qs.Services.Hardware
import qs.Services.Location
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.UI

ShellRoot {
  id: shellRoot

  property bool i18nLoaded: false
  property bool settingsLoaded: false
  property bool shellStateLoaded: false

  Component.onCompleted: {
    Logger.i("Shell", "---------------------------");
    Logger.i("Shell", "QuickNix Hello!");
  }

  Connections {
    target: Quickshell
    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup();
    }
    function onReloadFailed() {
      if (!Settings?.isDebug) {
        Quickshell.inhibitReloadPopup();
      }
    }
  }

  Connections {
    target: I18n ? I18n : null
    function onTranslationsLoaded() {
      i18nLoaded = true;
    }
  }

  Connections {
    target: Settings ? Settings : null
    function onSettingsLoaded() {
      settingsLoaded = true;
    }
  }

  Connections {
    target: ShellState ? ShellState : null
    function onIsLoadedChanged() {
      if (ShellState.isLoaded) {
        shellStateLoaded = true;
      }
    }
  }

  Loader {
    active: i18nLoaded && settingsLoaded && shellStateLoaded

    sourceComponent: Item {
      Component.onCompleted: {
        Logger.i("Shell", "---------------------------");

        ImageCacheService.init();

        Qt.callLater(function () {
          PowerProfileService.init();
          if (typeof NotificationRulesService !== "undefined")
            NotificationRulesService.init();
          IdleService.init();
        });
      }

      AllScreens {}
      Notification {}
      ToastOverlay {}
      OSD {}
      LockScreen {}

      Variants {
        model: Quickshell.screens
        delegate: FadeToActionWindow {
          required property ShellScreen modelData
          screen: modelData
          onFadeCompleted: IdleService.requestMonitorOff()
          Component.onCompleted: {
            IdleService.fadeToDpmsRequested.connect(startFade);
            IdleService.cancelFadeToDpms.connect(cancelFade);
          }
          Component.onDestruction: {
            IdleService.fadeToDpmsRequested.disconnect(startFade);
            IdleService.cancelFadeToDpms.disconnect(cancelFade);
          }
        }
      }

      Variants {
        model: Quickshell.screens
        delegate: FadeToActionWindow {
          required property ShellScreen modelData
          screen: modelData
          onFadeCompleted: IdleService.lockRequested()
          Component.onCompleted: {
            IdleService.fadeToLockRequested.connect(startFade);
            IdleService.cancelFadeToLock.connect(cancelFade);
          }
          Component.onDestruction: {
            IdleService.fadeToLockRequested.disconnect(startFade);
            IdleService.cancelFadeToLock.disconnect(cancelFade);
          }
        }
      }
    }
  }
}
