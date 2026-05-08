import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI

Loader {
  id: root
  active: false

  Component.onCompleted: PanelService.lockScreen = root
  Component.onDestruction: if (PanelService.lockScreen === root) PanelService.lockScreen = null

  onActiveChanged: {
    const hooks = Settings.data.hooks;
    if (hooks && hooks.enabled) {
      const cmd = active ? hooks.screenLock : hooks.screenUnlock;
      if (cmd && cmd.length > 0)
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
  }

  Timer {
    id: unloadTimer
    interval: 200
    repeat: false
    onTriggered: root.active = false
  }

  sourceComponent: Item {
    id: container

    LockContext {
      id: lockContext
      onUnlocked: {
        sessionLock.locked = false;
        unloadTimer.restart();
      }
    }

    WlSessionLock {
      id: sessionLock
      locked: root.active

      WlSessionLockSurface {
        id: surface
        color: "#101014"

        Rectangle {
          anchors.fill: parent
          color: "#101014"

          Rectangle {
            anchors.fill: parent
            color: Color.mPrimary
            opacity: Settings.data.general.lockScreenTint ? 0.10 : 0.04
          }

          ColumnLayout {
            width: Math.min(parent.width * 0.82, 460)
            anchors.centerIn: parent
            spacing: 18

            Text {
              Layout.fillWidth: true
              text: Qt.formatTime(new Date(), "HH:mm")
              color: Color.mOnSurface
              font.pixelSize: Settings.data.general.compactLockScreen ? 54 : 78
              font.weight: Font.DemiBold
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              Layout.fillWidth: true
              text: Qt.formatDate(new Date(), "dddd, MMMM d")
              color: Color.mOnSurfaceVariant
              font.pixelSize: 18
              horizontalAlignment: Text.AlignHCenter
            }

            TextField {
              id: passwordInput
              Layout.fillWidth: true
              Layout.topMargin: 18
              text: lockContext.password
              echoMode: TextInput.Password
              placeholderText: "Password"
              enabled: !lockContext.busy
              focus: true
              horizontalAlignment: Text.AlignHCenter
              onTextChanged: lockContext.password = text
              onAccepted: lockContext.tryUnlock()
              Component.onCompleted: forceActiveFocus()
            }

            Button {
              Layout.alignment: Qt.AlignHCenter
              text: lockContext.busy ? "Unlocking…" : "Unlock"
              enabled: !lockContext.busy
              onClicked: lockContext.tryUnlock()
            }

            Text {
              Layout.fillWidth: true
              visible: lockContext.message.length > 0
              text: lockContext.message
              color: lockContext.error ? Color.mError : Color.mOnSurfaceVariant
              font.pixelSize: 14
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }
}
