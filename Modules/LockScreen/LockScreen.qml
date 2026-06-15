import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../MainScreen/Backgrounds" as Backgrounds
import qs.Commons
import qs.Services.Hardware
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

Loader {
  id: root
  active: false

  Component.onCompleted: {
    PanelService.lockScreen = root;
    if (Quickshell.env("QUICKNIX_TEST_LOCKSCREEN") === "1") {
      Qt.callLater(function () {
        root.active = true;
      });
    }
  }
  Component.onDestruction: if (PanelService.lockScreen === root)
                             PanelService.lockScreen = null

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

    property date now: new Date()
    property bool releasing: false
    property bool confirmPowerOff: false

    Timer {
      interval: 1000
      running: true
      repeat: true
      onTriggered: container.now = new Date()
    }

    LockContext {
      id: lockContext
      onUnlocked: {
        container.releasing = true;
        unlockTransitionTimer.restart();
      }
    }

    Timer {
      id: unlockTransitionTimer
      interval: 520
      repeat: false
      onTriggered: {
        sessionLock.locked = false;
        unloadTimer.restart();
        container.releasing = false;
      }
    }

    Timer {
      id: powerConfirmReset
      interval: 3000
      repeat: false
      onTriggered: container.confirmPowerOff = false
    }

    WlSessionLock {
      id: sessionLock
      locked: root.active

      WlSessionLockSurface {
        id: surface
        color: "transparent"
        BackgroundEffect.blurRegion: lockBlurRegion

        Region {
          id: lockBlurRegion
          x: 0
          y: 0
          width: surface.width
          height: surface.height
        }

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          opacity: container.releasing ? 0 : 1

          Behavior on opacity {
            NumberAnimation {
              duration: 520
              easing.type: Easing.OutQuart
            }
          }

          Item {
            id: lockScene
            anchors.fill: parent
            opacity: container.releasing ? 0 : 1
            scale: container.releasing ? 1.035 : 1

            Behavior on opacity {
              NumberAnimation {
                duration: 700
                easing.type: Easing.OutQuart
              }
            }

            Behavior on scale {
              NumberAnimation {
                duration: 520
                easing.type: Easing.OutQuart
              }
            }

            Rectangle {
              id: wallpaperTint
              anchors.fill: parent
              color: Color.mSurface
              opacity: Settings.data.general.lockScreenTint ? 0.30 : 0.18

              Behavior on opacity {
                NumberAnimation {
                  duration: 520
                  easing.type: Easing.OutQuart
                }
              }
            }

            Item {
              id: desktopChrome
              anchors.fill: parent
              opacity: container.releasing ? 0 : 1

              Backgrounds.AllBackgrounds {
                anchors.fill: parent
                bar: lockBarPlaceholder
                windowRoot: lockWindowRoot
              }

              QtObject {
                id: lockWindowRoot
                readonly property var screen: surface.screen
              }

              Item {
                id: lockBarPlaceholder
                readonly property var barItem: lockBarPlaceholder
                property ShellScreen screen: surface.screen
                readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
                readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
                readonly property bool isFramed: Settings.data.bar.barType === "framed"
                readonly property real frameThickness: Settings.data.bar.frameThickness ?? 12
                readonly property bool barFloating: Settings.data.bar.barType === "floating"
                readonly property real barMarginH: barFloating ? Math.floor(Settings.data.bar.marginHorizontal) : 0
                readonly property real barMarginV: barFloating ? Math.floor(Settings.data.bar.marginVertical) : 0
                readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)
                readonly property bool isHidden: false

                x: {
                  if (barPosition === "right")
                    return (screen?.width ?? surface.width) - barHeight - barMarginH;
                  if (isFramed && !barIsVertical)
                    return frameThickness;
                  return barMarginH;
                }
                y: {
                  if (barPosition === "bottom")
                    return (screen?.height ?? surface.height) - barHeight - barMarginV;
                  if (isFramed && barIsVertical)
                    return frameThickness;
                  return barMarginV;
                }
                width: {
                  if (barIsVertical)
                    return barHeight;
                  if (isFramed)
                    return (screen?.width ?? surface.width) - frameThickness * 2;
                  return (screen?.width ?? surface.width) - barMarginH * 2;
                }
                height: {
                  if (!barIsVertical)
                    return barHeight;
                  if (isFramed)
                    return (screen?.height ?? surface.height) - frameThickness * 2;
                  return (screen?.height ?? surface.height) - barMarginV * 2;
                }

                readonly property int topLeftCornerState: {
                  if (barFloating)
                    return 0;
                  if (barPosition === "top" || barPosition === "left")
                    return -1;
                  if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "right"))
                    return barIsVertical ? 1 : 2;
                  return -1;
                }
                readonly property int topRightCornerState: {
                  if (barFloating)
                    return 0;
                  if (barPosition === "top" || barPosition === "right")
                    return -1;
                  if (Settings.data.bar.outerCorners && (barPosition === "bottom" || barPosition === "left"))
                    return barIsVertical ? 1 : 2;
                  return -1;
                }
                readonly property int bottomLeftCornerState: {
                  if (barFloating)
                    return 0;
                  if (barPosition === "bottom" || barPosition === "left")
                    return -1;
                  if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "right"))
                    return barIsVertical ? 2 : 1;
                  return -1;
                }
                readonly property int bottomRightCornerState: {
                  if (barFloating)
                    return 0;
                  if (barPosition === "bottom" || barPosition === "right")
                    return -1;
                  if (Settings.data.bar.outerCorners && (barPosition === "top" || barPosition === "left"))
                    return barIsVertical ? 2 : 1;
                  return -1;
                }
              }
            }

            RowLayout {
              id: lockscreenControls
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.topMargin: Math.max(18, Math.min(parent.width, parent.height) * 0.035)
              anchors.rightMargin: Math.max(18, Math.min(parent.width, parent.height) * 0.035)
              spacing: Style.marginS

              function iconButtonWidth(text) {
                return Math.max(44 * Style.uiScaleRatio, text.length > 0 ? 74 * Style.uiScaleRatio : 44 * Style.uiScaleRatio);
              }

              Rectangle {
                visible: BatteryService.batteryPresent
                Layout.preferredWidth: lockscreenControls.iconButtonWidth(batteryText.text)
                Layout.preferredHeight: 40 * Style.uiScaleRatio
                radius: height / 2
                color: Qt.alpha(Color.mSurfaceVariant, batteryMouse.containsMouse ? 0.98 : 0.76)

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.marginXS

                  NIcon {
                    icon: BatteryService.batteryIcon
                    pointSize: Style.fontSizeXL
                    color: (BatteryService.batteryCharging || BatteryService.batteryPluggedIn) ? Color.mPrimary : Color.mOnSurface
                  }

                  Text {
                    id: batteryText
                    text: BatteryService.batteryReady ? Math.round(BatteryService.batteryPercentage) + "%" : ""
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                    font.weight: Font.Medium
                  }
                }

                MouseArea {
                  id: batteryMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: PanelService.getPanel("batteryPanel", surface.screen)?.toggle(parent)
                }
              }

              Rectangle {
                id: brightnessControl
                property var monitor: BrightnessService.getMonitorForScreen(surface.screen)
                visible: monitor && monitor.brightnessControlAvailable
                Layout.preferredWidth: lockscreenControls.iconButtonWidth(brightnessText.text)
                Layout.preferredHeight: 40 * Style.uiScaleRatio
                radius: height / 2
                color: Qt.alpha(Color.mSurfaceVariant, brightnessMouse.containsMouse ? 0.98 : 0.76)

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.marginXS

                  NIcon {
                    icon: !brightnessControl.monitor || brightnessControl.monitor.brightness <= 0.001 ? "sun-off" : brightnessControl.monitor.brightness <= 0.5 ? "brightness-low" : "brightness-high"
                    pointSize: Style.fontSizeXL
                    color: Color.mOnSurface
                  }

                  Text {
                    id: brightnessText
                    text: brightnessControl.monitor && !isNaN(brightnessControl.monitor.brightness) ? Math.round(brightnessControl.monitor.brightness * 100) + "%" : ""
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                    font.weight: Font.Medium
                  }
                }

                MouseArea {
                  id: brightnessMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onWheel: wheel => {
                             if (!brightnessControl.monitor || !brightnessControl.monitor.brightnessControlAvailable)
                             return;
                             if (wheel.angleDelta.y > 0)
                             brightnessControl.monitor.increaseBrightness();
                             else if (wheel.angleDelta.y < 0)
                             brightnessControl.monitor.decreaseBrightness();
                           }
                  onClicked: PanelService.getPanel("brightnessPanel", surface.screen)?.toggle(parent)
                }
              }

              Rectangle {
                Layout.preferredWidth: lockscreenControls.iconButtonWidth(volumeText.text)
                Layout.preferredHeight: 40 * Style.uiScaleRatio
                radius: height / 2
                color: Qt.alpha(Color.mSurfaceVariant, volumeMouse.containsMouse ? 0.98 : 0.76)

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.marginXS

                  NIcon {
                    icon: AudioService.getOutputIcon()
                    pointSize: Style.fontSizeXL
                    color: Color.mOnSurface
                  }

                  Text {
                    id: volumeText
                    text: Math.round(Math.min(Settings.data.audio.volumeOverdrive ? 1.5 : 1.0, AudioService.volume) * 100) + "%"
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                    font.weight: Font.Medium
                  }
                }

                MouseArea {
                  id: volumeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onWheel: wheel => {
                             if (wheel.angleDelta.y > 0)
                             AudioService.increaseVolume();
                             else if (wheel.angleDelta.y < 0)
                             AudioService.decreaseVolume();
                           }
                  onClicked: AudioService.setOutputMuted(!AudioService.muted)
                }
              }

              Rectangle {
                Layout.preferredWidth: container.confirmPowerOff ? 148 * Style.uiScaleRatio : 40 * Style.uiScaleRatio
                Layout.preferredHeight: 40 * Style.uiScaleRatio
                radius: height / 2
                color: Qt.alpha(Color.mError, powerMouse.containsMouse || container.confirmPowerOff ? 0.98 : 0.78)

                Behavior on Layout.preferredWidth {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutQuart
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: container.confirmPowerOff ? Style.marginM : 0
                  anchors.rightMargin: container.confirmPowerOff ? Style.marginS : 0
                  spacing: Style.marginXS

                  NIcon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: container.confirmPowerOff ? 0 : (parent.width - width) / 2
                    icon: "shutdown"
                    pointSize: Style.fontSizeXL
                    color: Color.mOnError
                  }

                  Text {
                    Layout.fillWidth: true
                    visible: container.confirmPowerOff
                    text: "Power off?"
                    color: Color.mOnError
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: powerMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (container.confirmPowerOff) {
                      Quickshell.execDetached(["sh", "-c", "systemctl poweroff || loginctl poweroff"]);
                    } else {
                      container.confirmPowerOff = true;
                      powerConfirmReset.restart();
                    }
                  }
                }
              }
            }

            Item {
              anchors.fill: parent
              anchors.margins: Math.max(28, Math.min(parent.width, parent.height) * 0.055)

              ColumnLayout {
                visible: surface.width >= 760
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width * 0.54, 760 * Style.uiScaleRatio)
                spacing: Style.marginL

                Text {
                  Layout.fillWidth: true
                  text: Qt.formatTime(container.now, "HH:mm")
                  color: Color.mOnSurface
                  font.family: Settings.data.ui.fontDefault
                  font.pixelSize: (Settings.data.general.compactLockScreen ? 76 : 118) * Style.uiScaleRatio
                  font.weight: Font.Bold
                  lineHeight: 0.86
                }

                Text {
                  Layout.fillWidth: true
                  text: Qt.formatDate(container.now, "dddd, MMMM d")
                  color: Color.mOnSurfaceVariant
                  font.family: Settings.data.ui.fontDefault
                  font.pixelSize: 22 * Style.uiScaleRatio
                  font.weight: Font.Medium
                }
              }

              Rectangle {
                id: unlockCard
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Math.min(430 * Style.uiScaleRatio, parent.width * 0.92)
                height: cardContent.implicitHeight + Style.marginL * 2
                radius: height / 2
                color: Qt.alpha(Color.mSurfaceVariant, 0.88)

                ColumnLayout {
                  id: cardContent
                  anchors.fill: parent
                  anchors.margins: Style.marginL
                  spacing: Style.marginS

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54 * Style.uiScaleRatio
                    radius: height / 2
                    color: Color.mSurface

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.marginL
                      anchors.rightMargin: Style.marginM
                      spacing: Style.marginM

                      TextField {
                        id: passwordInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: lockContext.password
                        echoMode: TextInput.Password
                        placeholderText: lockContext.username.length > 0 ? lockContext.username : "Password"
                        placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.62)
                        color: Color.mOnSurface
                        enabled: !lockContext.busy
                        focus: true
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: false
                        background: null
                        font.family: Settings.data.ui.fontDefault
                        font.pixelSize: Style.fontSizeXL * Style.uiScaleRatio
                        onTextChanged: lockContext.password = text
                        onAccepted: lockContext.tryUnlock()
                        Component.onCompleted: forceActiveFocus()
                      }
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    visible: lockContext.message.length > 0
                    text: lockContext.message
                    color: lockContext.error ? Color.mError : Color.mOnSurfaceVariant
                    font.family: Settings.data.ui.fontDefault
                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
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
