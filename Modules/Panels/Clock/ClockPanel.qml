import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.MainScreen
import qs.Services.Media
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  property bool quickToggleMode: false

  property var panelOrder: ["audioPanel", "brightnessPanel", "batteryPanel", "networkPanel", "notificationHistoryPanel", "caffeine"]

  property var panelMeta: ({
    "audioPanel": {
      "toggleIcon": AudioService.muted ? "volume-off" : "settings-audio",
      "toggleKey": "m",
      "active": !AudioService.muted,
      "hasToggle": true,
      "label": I18n.tr("panels.audio.title"),
      "panelKey": "a",
      "panelName": "audioPanel"
    },
    "brightnessPanel": {
      "icon": "settings-display",
      "label": I18n.tr("panels.display.title"),
      "panelKey": "d",
      "panelName": "brightnessPanel",
      "hasToggle": false
    },
    "batteryPanel": {
      "icon": "battery",
      "label": I18n.tr("common.battery"),
      "panelKey": "b",
      "panelName": "batteryPanel",
      "hasToggle": false
    },
    "networkPanel": {
      "toggleIcon": NetworkService.wifiEnabled ? "wifi" : "wifi-off",
      "toggleKey": "w",
      "active": NetworkService.wifiEnabled,
      "hasToggle": true,
      "label": I18n.tr("common.wifi"),
      "panelKey": "p",
      "panelName": "networkPanel"
    },
    "notificationHistoryPanel": {
      "toggleIcon": NotificationService.doNotDisturb ? "bell-off" : "bell",
      "toggleKey": "n",
      "active": !NotificationService.doNotDisturb,
      "hasToggle": true,
      "label": I18n.tr("common.notifications"),
      "panelKey": "o",
      "panelName": "notificationHistoryPanel"
    },
    "caffeine": {
      "toggleIcon": IdleInhibitorService.isInhibited ? "coffee" : "coffee-off",
      "toggleKey": "c",
      "active": IdleInhibitorService.isInhibited,
      "hasToggle": true,
      "label": qsTr("Caffeine"),
      "panelKey": "c",
      "panelName": ""
    }
  })

  panelContent: Item {
    id: panelContent
    anchors.fill: parent

    focus: true

    Connections {
      target: root
      function onOpened() {
        panelContent.forceActiveFocus();
      }
      function onClosed() {
        root.quickToggleMode = false;
      }
    }

     Keys.onPressed: event => {
                       if (event.key === Qt.Key_T) {
                         root.quickToggleMode = !root.quickToggleMode;
                         event.accepted = true;
                         return;
                       }

                       if (calendarMonthCard && calendarMonthCard.handleKey && calendarMonthCard.handleKey(event)) {
                         event.accepted = true;
                         return;
                       }

                       for (var i = 0; i < root.panelOrder.length; i++) {
                         var panelName = root.panelOrder[i];
                         var info = root.panelMeta[panelName];
                         if (!info)
                           continue;

                         if ((root.quickToggleMode || panelName === "caffeine") && info.hasToggle && info.toggleKey.length === 1 && event.key === Qt.Key_A + info.toggleKey.charCodeAt(0) - 0x61) {
                            var tile = tileRepeater.itemAt(i);
                            if (tile)
                              tile.toggleActivated = true;
                            toggleTimer.actionName = panelName;
                            toggleTimer.restart();
                            event.accepted = true;
                            return;
                          }

                          if (!root.quickToggleMode && info.panelKey && info.panelKey.length === 1 && event.key === Qt.Key_A + info.panelKey.charCodeAt(0) - 0x61) {
                            if (info.panelName && info.panelName.length > 0) {
                              var tile2 = tileRepeater.itemAt(i);
                              if (tile2)
                                tile2.panelActivated = true;
                              openTimer.panelName = info.panelName;
                              openTimer.restart();
                            }
                            event.accepted = true;
                            return;
                          }
                       }
                     }

    function openPanel(panelName) {
      var target = PanelService.getPanel(panelName, root.screen);
      if (!target)
        return;
      if (PanelService.openedPanel === target) {
        target.close();
      } else if (PanelService.openedPanel) {
        PanelService.openedPanel.close();
        Qt.callLater(function () {
          target.open();
        });
      } else {
        target.open();
      }
    }

    Timer {
      id: openTimer
      interval: 150
      property string panelName: ""
      onTriggered: panelContent.openPanel(panelName)
    }

    Timer {
      id: toggleTimer
      interval: 150
      property string actionName: ""
      onTriggered: {
        if (actionName === "audioPanel")
          AudioService.setOutputMuted(!AudioService.muted);
        else if (actionName === "networkPanel")
          NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
        else if (actionName === "notificationHistoryPanel")
          NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
        else if (actionName === "caffeine")
          IdleInhibitorService.toggle();
      }
    }

    readonly property real contentPreferredWidth: Math.round((calendarMonthCard && calendarMonthCard.viewMode === "week" ? 620 : (Settings.data.location && Settings.data.location.showWeekNumberInCalendar ? 440 : 420)) * Style.uiScaleRatio)
    readonly property real contentPreferredHeight: content.implicitHeight + Style.margin2L

    ColumnLayout {
      id: content
      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginM

      CalendarHeaderCard {
        Layout.fillWidth: true
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.marginL
        Layout.rightMargin: Style.marginL
        spacing: Style.marginS

        NText {
          text: "quickToggle"
          pointSize: Style.fontSizeXXS
          font.weight: Style.fontWeightSemiBold
          color: Color.mOnSurfaceVariant
        }

        Rectangle {
          id: quickToggleKeycap
          Layout.alignment: Qt.AlignVCenter
          width: Math.round(Style.baseWidgetSize * 0.8)
          height: Math.round(Style.baseWidgetSize * 0.55)
          radius: Style.iRadiusS
          color: root.quickToggleMode ? Color.mPrimary : Color.mSurfaceVariant
          border.color: root.quickToggleMode ? Qt.alpha(Color.mOnPrimary, 0.3) : Color.mOutline
          border.width: Style.borderS

          NText {
            anchors.centerIn: parent
            text: "t"
            family: Settings.data.ui.fontFixed || "monospace"
            pointSize: Style.fontSizeXS
            font.weight: Style.fontWeightBold
            color: root.quickToggleMode ? Color.mOnPrimary : Color.mOnSurface
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.quickToggleMode = !root.quickToggleMode
          }

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation { duration: Style.animationFast }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          height: Style.borderS
          radius: height / 2
          color: root.quickToggleMode ? Qt.alpha(Color.mPrimary, 0.6) : Qt.alpha(Color.mOutline, 0.6)

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation { duration: Style.animationFast }
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginS
        rowSpacing: Style.marginM
        flow: GridLayout.LeftToRight

        Repeater {
          id: tileRepeater
          model: root.panelOrder

          delegate: Rectangle {
            id: quickTile
            Layout.fillWidth: true
            implicitHeight: Style.baseWidgetSize * 1.7
            radius: implicitHeight / 2
            color: {
              if (panelActivated)
                return Color.mPrimary;
              if (toggleModeActive)
                return Qt.alpha(Color.mPrimary, 0.14);
              if (tileMouse.containsMouse || (meta.hasToggle && iconMouseArea.containsMouse))
                return Color.mSurface;
              return Color.mSurfaceVariant;
            }
            border.width: Style.borderS
            border.color: Style.boxBorderColor

            property var meta: root.panelMeta[modelData] || ({})

            readonly property bool toggleModeActive: root.quickToggleMode && meta.hasToggle

            property bool panelActivated: false
            property bool toggleActivated: false

            onPanelActivatedChanged: {
              if (panelActivated)
                panelAnim.start();
            }

            onToggleActivatedChanged: {
              if (toggleActivated)
                toggleAnim.start();
            }

            SequentialAnimation {
              id: panelAnim
              NumberAnimation {
                target: quickTile
                property: "scale"
                to: 1.08
                duration: Style.animationFaster
              }
              PauseAnimation {
                duration: 50
              }
              NumberAnimation {
                target: quickTile
                property: "scale"
                to: 1.0
                duration: Style.animationFast
                easing.type: Easing.OutBack
              }
              PropertyAction {
                target: quickTile
                property: "panelActivated"
                value: false
              }
            }

            SequentialAnimation {
              id: toggleAnim
              NumberAnimation {
                target: iconCircle
                property: "scale"
                to: 1.15
                duration: Style.animationFaster
              }
              PauseAnimation {
                duration: 50
              }
              NumberAnimation {
                target: iconCircle
                property: "scale"
                to: 1.0
                duration: Style.animationFast
                easing.type: Easing.OutBack
              }
              PropertyAction {
                target: quickTile
                property: "toggleActivated"
                value: false
              }
            }

            Behavior on color {
              enabled: !Settings.data.general.animationDisabled && !panelActivated
              ColorAnimation {
                duration: Style.animationFast
              }
            }

            MouseArea {
              id: tileMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData === "caffeine") {
                  quickTile.toggleActivated = true;
                  toggleTimer.actionName = modelData;
                  toggleTimer.restart();
                  return;
                }

                if (toggleModeActive) {
                  quickTile.toggleActivated = true;
                  toggleTimer.actionName = modelData;
                  toggleTimer.restart();
                  return;
                }

                if (meta.panelName && meta.panelName.length > 0) {
                  quickTile.panelActivated = true;
                  openTimer.panelName = meta.panelName;
                  openTimer.restart();
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.marginL
              anchors.rightMargin: Style.marginL
              spacing: Style.marginS

              Item {
                id: iconCircleContainer
                implicitWidth: Style.baseWidgetSize * 1.1
                implicitHeight: Style.baseWidgetSize * 1.1
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                  id: iconCircle
                  anchors.fill: parent
                  radius: width / 2
                  scale: 1.0
                  color: {
                    if (quickTile.toggleActivated)
                      return Color.mPrimary;
                    if (meta.hasToggle)
                      return meta.active ? Color.mPrimary : Color.mSurfaceVariant;
                    return Qt.alpha(Color.mPrimary, 0.12);
                  }

                  border.width: toggleModeActive ? Style.borderM : 0
                  border.color: toggleModeActive ? Qt.alpha(Color.mPrimary, 0.9) : "transparent"

                  Behavior on color {
                    ColorAnimation {
                      duration: Style.animationFast
                    }
                  }

                  Behavior on scale {
                    enabled: !Color.isTransitioning
                    NumberAnimation {
                      duration: Style.animationFast
                      easing.type: Easing.OutBack
                    }
                  }

                  NIcon {
                    icon: meta.hasToggle ? (meta.toggleIcon || "settings") : (meta.icon || "settings")
                    pointSize: Style.fontSizeL
                    color: {
                      if (quickTile.toggleActivated)
                        return Color.mOnPrimary;
                      if (meta.hasToggle)
                        return meta.active ? Color.mOnPrimary : Color.mOnSurfaceVariant;
                      return Color.mPrimary;
                    }
                    anchors.centerIn: parent

                    Behavior on color {
                      ColorAnimation {
                        duration: Style.animationFast
                      }
                    }
                  }

                  MouseArea {
                    id: iconMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    visible: meta.hasToggle
                    enabled: toggleModeActive || modelData === "caffeine"
                    onClicked: {
                      quickTile.toggleActivated = true;
                      toggleTimer.actionName = modelData;
                      toggleTimer.restart();
                    }
                  }
                }

                NKeyHint {
                  id: toggleKeyHint
                  key: meta.hasToggle ? (meta.toggleKey || "") : ""
                  readonly property bool _shouldShow: root.quickToggleMode && meta.hasToggle && meta.toggleKey.length > 0
                  visible: opacity > 0.01
                  opacity: _shouldShow ? 1.0 : 0.0
                  scale: _shouldShow ? 1.0 : 0.85
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.rightMargin: -toggleKeyHint.badgeSize * 0.3
                  anchors.bottomMargin: -toggleKeyHint.badgeSize * 0.3
                  z: 1

                  Behavior on opacity {
                    enabled: !Color.isTransitioning
                    NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutQuad }
                  }

                  Behavior on scale {
                    enabled: !Color.isTransitioning
                    NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutBack }
                  }
                }
              }

              NText {
                text: meta.label || ""
                pointSize: Style.fontSizeXS
                font.weight: Style.fontWeightMedium
                color: {
                  if (panelActivated)
                    return Color.mOnPrimary;
                  return Color.mOnSurface;
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              Item {
                id: panelKeyHintWrap
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                implicitWidth: w
                implicitHeight: panelKeyHint.badgeSize
                clip: true

                readonly property bool _shouldShow: !root.quickToggleMode && meta.panelKey && meta.panelKey.length > 0
                property real w: _shouldShow ? panelKeyHint.badgeSize : 0

                Behavior on w {
                  enabled: !Settings.data.general.animationDisabled
                  NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutQuad }
                }

                NKeyHint {
                  id: panelKeyHint
                  anchors.centerIn: parent
                  key: meta.panelKey || ""
                  visible: opacity > 0.01
                  opacity: panelKeyHintWrap._shouldShow ? 1.0 : 0.0
                  scale: panelKeyHintWrap._shouldShow ? 1.0 : 0.85

                  Behavior on opacity {
                    enabled: !Color.isTransitioning
                    NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutQuad }
                  }

                  Behavior on scale {
                    enabled: !Color.isTransitioning
                    NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutBack }
                  }
                }
              }
            }
          }
        }
      }

      CalendarMonthCard {
        id: calendarMonthCard
        Layout.fillWidth: true
      }
    }
  }
}
