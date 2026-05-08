import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

PanelWindow {
  id: root

  property bool fading: false
  property bool cancelArmed: false

  signal fadeCompleted
  signal cancelled

  color: "transparent"
  visible: fading || overlay.opacity > 0
  WlrLayershell.layer: WlrLayershell.Overlay
  WlrLayershell.exclusiveZone: -1
  // Do not take keyboard focus here: on some compositors focusing the fade
  // layer itself counts as activity and immediately cancels the idle state.
  // Real key/mouse activity is still detected by IdleMonitor becoming non-idle.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  function startFade() {
    Logger.i("FadeToAction", "Starting idle fade on " + (screen ? screen.name : "unknown"));
    completeTimer.stop();
    initialInputGuard.restart();
    cancelArmed = false;
    fading = true;
    overlay.opacity = 1;
    completeTimer.restart();
  }

  function cancelFade() {
    if ((!fading && overlay.opacity <= 0) || !cancelArmed)
      return;
    Logger.i("FadeToAction", "Cancelling idle fade on " + (screen ? screen.name : "unknown"));
    completeTimer.stop();
    fading = false;
    overlay.opacity = 0;
    cancelled();
  }

  Timer {
    id: initialInputGuard
    interval: 300
    repeat: false
    onTriggered: root.cancelArmed = true
  }

  Rectangle {
    id: overlay
    anchors.fill: parent
    color: "#050508"
    opacity: 0

    Behavior on opacity {
      NumberAnimation {
        duration: Math.max(0, Settings.data.idle.fadeDuration * 1000)
        easing.type: Easing.OutCubic
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: false
    onPressed: root.cancelFade()
  }

  Item {
    anchors.fill: parent
    focus: root.fading
    Keys.onPressed: event => {
      event.accepted = true;
      root.cancelFade();
    }
  }

  Timer {
    id: completeTimer
    interval: Math.max(0, Settings.data.idle.fadeDuration * 1000)
    repeat: false
    onTriggered: {
      Logger.i("FadeToAction", "Idle fade completed on " + (root.screen ? root.screen.name : "unknown"));
      root.fading = false;
      root.fadeCompleted();
    }
  }
}
