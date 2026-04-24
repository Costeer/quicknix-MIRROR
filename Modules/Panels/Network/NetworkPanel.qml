import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(560 * Style.uiScaleRatio)

  property string passwordTarget: ""
  property int focusIndex: -1

  readonly property var connectedNetworks: {
    var nets = [];
    var keys = Object.keys(NetworkService.networks);
    for (var i = 0; i < keys.length; i++) {
      var n = NetworkService.networks[keys[i]];
      if (n.connected)
        nets.push(n);
    }
    return nets;
  }

  readonly property var savedNetworks: {
    var nets = [];
    var keys = Object.keys(NetworkService.networks);
    for (var i = 0; i < keys.length; i++) {
      var n = NetworkService.networks[keys[i]];
      if (n.existing && !n.connected)
        nets.push(n);
    }
    nets.sort(function (a, b) {
      return b.signal - a.signal;
    });
    return nets;
  }

  readonly property var availableNetworks: {
    var nets = [];
    var keys = Object.keys(NetworkService.networks);
    for (var i = 0; i < keys.length; i++) {
      var n = NetworkService.networks[keys[i]];
      if (!n.connected && !n.existing)
        nets.push(n);
    }
    nets.sort(function (a, b) {
      return b.signal - a.signal;
    });
    return nets;
  }

  readonly property var allNetworks: connectedNetworks.concat(savedNetworks).concat(availableNetworks)

  readonly property var selectedNet: focusIndex >= 0 && focusIndex < allNetworks.length ? allNetworks[focusIndex] : null

  onOpened: {
    if (NetworkService.wifiEnabled && !NetworkService.scanningActive)
      NetworkService.scan();
  }

  function isHighlighted(idx) {
    if (idx < 0 || idx >= allNetworks.length)
      return false;
    return allNetworks[idx].connected || idx === focusIndex;
  }

  panelContent: Item {
    id: panelContent

    focus: true

    Connections {
      target: root
      function onOpened() {
        panelContent.forceActiveFocus();
      }
    }

    Keys.onPressed: event => {
                      if (root.passwordTarget.length > 0)
                        return;

                      if (event.key === Qt.Key_T) {
                        NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
                        toggleKeyHint.active = true;
                        event.accepted = true;
                        return;
                      }
                      if (event.key === Qt.Key_R) {
                        if (NetworkService.wifiEnabled) {
                          NetworkService.scan();
                          refreshKeyHint.active = true;
                        }
                        event.accepted = true;
                        return;
                      }
                      if (event.key === Qt.Key_Escape) {
                        root.focusIndex = -1;
                        event.accepted = true;
                        return;
                      }

                      if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        var idx = event.key - Qt.Key_1;
                        if (idx < root.allNetworks.length) {
                          root.focusIndex = idx;
                          scrollToIndex(idx);
                        }
                        event.accepted = true;
                        return;
                      }

                      if (root.selectedNet) {
                        if (event.key === Qt.Key_C && !root.selectedNet.connected) {
                          connectKeyHint.active = true;
                          if (NetworkService.isSecured(root.selectedNet.security) && !root.selectedNet.existing) {
                            root.passwordTarget = root.selectedNet.ssid;
                            passwordField.text = "";
                            Qt.callLater(function () {
                              passwordField.forceActiveFocus();
                            });
                          } else {
                            NetworkService.connect(root.selectedNet.ssid);
                          }
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_D && root.selectedNet.connected) {
                          disconnectKeyHint.active = true;
                          NetworkService.disconnect(root.selectedNet.ssid);
                          root.focusIndex = -1;
                          event.accepted = true;
                          return;
                        }
                        if (event.key === Qt.Key_P && root.selectedNet.existing) {
                          pinKeyHint.active = true;
                          NetworkService.forget(root.selectedNet.ssid);
                          root.focusIndex = -1;
                          event.accepted = true;
                          return;
                        }
                      }

                      if (event.key === Qt.Key_Up) {
                        if (root.focusIndex > 0) {
                          root.focusIndex--;
                          scrollToIndex(root.focusIndex);
                        }
                        event.accepted = true;
                        return;
                      }
                      if (event.key === Qt.Key_Down) {
                        if (root.focusIndex < root.allNetworks.length - 1) {
                          root.focusIndex++;
                          scrollToIndex(root.focusIndex);
                        }
                        event.accepted = true;
                        return;
                      }
                      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.selectedNet) {
                          if (root.selectedNet.connected) {
                            NetworkService.disconnect(root.selectedNet.ssid);
                            root.focusIndex = -1;
                          } else if (root.selectedNet.existing) {
                            NetworkService.connect(root.selectedNet.ssid);
                          } else if (NetworkService.isSecured(root.selectedNet.security)) {
                            root.passwordTarget = root.selectedNet.ssid;
                            passwordField.text = "";
                            Qt.callLater(function () {
                              passwordField.forceActiveFocus();
                            });
                          } else {
                            NetworkService.connect(root.selectedNet.ssid);
                          }
                        }
                        event.accepted = true;
                        return;
                      }
                    }

    function scrollToIndex(idx) {
      var item = networkRepeater.itemAt(idx);
      if (item) {
        var flickable = scrollView._internalFlickable;
        if (!flickable)
          return;
        var pos = flickable.contentItem.mapFromItem(item, 0, 0);
        if (pos.y < flickable.contentY)
          flickable.contentY = pos.y - Style.marginM;
        else if (pos.y + item.height > flickable.contentY + flickable.height)
          flickable.contentY = pos.y + item.height - flickable.height + Style.marginM;
      }
    }

    property real contentPreferredHeight: Math.min(root.preferredHeight, mainColumn.implicitHeight + Style.margin2L)

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: NetworkService.getIcon()
            pointSize: Style.fontSizeXXL
            color: NetworkService.wifiEnabled ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          NText {
            text: I18n.tr("common.wifi")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          Item {
            width: toggleBtn.width
            height: toggleBtn.height
            NIconButton {
              id: toggleBtn
              icon: NetworkService.wifiEnabled ? "wifi" : "wifi-off"
              tooltipText: NetworkService.wifiEnabled ? I18n.tr("common.disable") : I18n.tr("common.enable")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            }
            NKeyHint {
              id: toggleKeyHint
              key: "t"
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.rightMargin: -Style.marginXXS
              anchors.bottomMargin: -Style.marginXXS
            }
          }

          Item {
            width: refreshBtn.width
            height: refreshBtn.height
            NIconButton {
              id: refreshBtn
              icon: NetworkService.scanningActive ? "loader" : "refresh"
              tooltipText: I18n.tr("common.refresh")
              baseSize: Style.baseWidgetSize * 0.8
              enabled: NetworkService.wifiEnabled && !NetworkService.scanningActive
              onClicked: NetworkService.scan()
            }
            NKeyHint {
              id: refreshKeyHint
              key: "r"
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.rightMargin: -Style.marginXXS
              anchors.bottomMargin: -Style.marginXXS
            }
          }
        }
      }

      Rectangle {
        visible: NetworkService.lastError.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: errorRow.implicitHeight + Style.margin2M
        color: Qt.alpha(Color.mError, 0.1)
        radius: Style.radiusS
        border.width: Style.borderS
        border.color: Color.mError

        RowLayout {
          id: errorRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NIcon {
            icon: "warning"
            pointSize: Style.fontSizeL
            color: Color.mError
          }

          NText {
            text: NetworkService.lastError
            color: Color.mError
            pointSize: Style.fontSizeS
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            baseSize: Style.baseWidgetSize * 0.6
            onClicked: NetworkService.lastError = ""
          }
        }
      }

      NScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.mSurface

        ColumnLayout {
          width: scrollView.availableWidth
          spacing: 0

          NBox {
            visible: !NetworkService.wifiEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: disabledContent.implicitHeight + Style.margin2M

            ColumnLayout {
              id: disabledContent
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }
              NIcon {
                icon: "wifi-off"
                pointSize: 48
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
              NText {
                text: I18n.tr("wifi.panel.disabled")
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
              NText {
                text: I18n.tr("wifi.panel.enable-message")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
              Item {
                Layout.fillHeight: true
              }
            }
          }

          NBox {
            visible: NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length === 0 && NetworkService.scanningActive
            Layout.fillWidth: true
            Layout.preferredHeight: scanningContent.implicitHeight + Style.margin2M

            ColumnLayout {
              id: scanningContent
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }
              NBusyIndicator {
                running: visible
                color: Color.mPrimary
                size: Style.baseWidgetSize
                Layout.alignment: Qt.AlignHCenter
              }
              NText {
                text: I18n.tr("wifi.panel.searching")
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
              Item {
                Layout.fillHeight: true
              }
            }
          }

          NBox {
            visible: NetworkService.wifiEnabled && Object.keys(NetworkService.networks).length === 0 && !NetworkService.scanningActive
            Layout.fillWidth: true
            Layout.preferredHeight: emptyContent.implicitHeight + Style.margin2M

            ColumnLayout {
              id: emptyContent
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }
              NIcon {
                icon: "wifi-question"
                pointSize: 48
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
              NText {
                text: I18n.tr("wifi.panel.no-networks")
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }
              Item {
                Layout.fillHeight: true
              }
            }
          }

          ColumnLayout {
            visible: NetworkService.wifiEnabled && root.allNetworks.length > 0
            width: parent.width
            spacing: Style.marginXS

            Repeater {
              id: networkRepeater
              model: root.allNetworks

              delegate: Rectangle {
                id: networkTile
                Layout.fillWidth: true
                height: tileContent.implicitHeight + Style.margin2M
                radius: height / 2
                color: {
                  if (modelData.connected)
                    return Color.mPrimary;
                  if (index === root.focusIndex)
                    return Color.mSurfaceVariant;
                  return Color.mSurface;
                }
                border.width: index === root.focusIndex && !modelData.connected ? Style.borderM : 0
                border.color: Color.mPrimary

                Behavior on color {
                  enabled: !Settings.data.general.animationDisabled
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }

                RowLayout {
                  id: tileContent
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginL
                  anchors.rightMargin: Style.marginM
                  spacing: Style.marginS

                  Rectangle {
                    visible: index < 9
                    width: Style.baseWidgetSize * 0.5
                    height: width
                    radius: width / 2
                    color: index === root.focusIndex ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter

                    NText {
                      anchors.centerIn: parent
                      text: (index + 1).toString()
                      pointSize: Style.fontSizeXXS
                      font.weight: Style.fontWeightBold
                      color: index === root.focusIndex ? Color.mPrimary : Color.mOnSurfaceVariant
                    }
                  }

                  NIcon {
                    icon: NetworkService.getSignalInfo(modelData.signal, modelData.connected).icon
                    pointSize: Style.fontSizeXL
                    color: modelData.connected ? Color.mOnPrimary : Color.mOnSurface
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    NText {
                      text: modelData.ssid
                      pointSize: Style.fontSizeM
                      font.weight: modelData.connected ? Style.fontWeightBold : Style.fontWeightMedium
                      color: modelData.connected ? Color.mOnPrimary : Color.mOnSurface
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    RowLayout {
                      spacing: Style.marginS

                      NText {
                        text: modelData.connected ? I18n.tr("common.connected") : NetworkService.getSignalInfo(modelData.signal, false).label
                        pointSize: Style.fontSizeXXS
                        color: modelData.connected ? Qt.alpha(Color.mOnPrimary, 0.7) : Color.mOnSurfaceVariant
                      }

                      NText {
                        visible: text.length > 0
                        text: NetworkService.isSecured(modelData.security) ? modelData.security : ""
                        pointSize: Style.fontSizeXXS
                        color: modelData.connected ? Qt.alpha(Color.mOnPrimary, 0.7) : Color.mOnSurfaceVariant
                      }

                      NIcon {
                        visible: modelData.existing && !modelData.connected
                        icon: "star"
                        pointSize: Style.fontSizeXXS
                        color: modelData.connected ? Qt.alpha(Color.mOnPrimary, 0.7) : Color.mPrimary
                      }
                    }
                  }

                  NBusyIndicator {
                    visible: NetworkService.connecting && NetworkService.connectingTo === modelData.ssid
                    running: visible
                    color: modelData.connected ? Color.mOnPrimary : Color.mPrimary
                    size: Style.baseWidgetSize * 0.5
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {
                    root.focusIndex = index;
                    panelContent.forceActiveFocus();
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.selectedNet && root.passwordTarget.length === 0 ? contextRow.implicitHeight + Style.margin2L : 0
        Layout.maximumHeight: root.selectedNet && root.passwordTarget.length === 0 ? contextRow.implicitHeight + Style.margin2L : 0
        visible: root.selectedNet !== null && root.passwordTarget.length === 0
        clip: true
        radius: Style.radiusL
        color: Color.mSurfaceVariant
        border.width: Style.borderM
        border.color: Color.mPrimary

        RowLayout {
          id: contextRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.marginL
          anchors.rightMargin: Style.marginL
          spacing: Style.marginM

          NText {
            text: root.selectedNet ? root.selectedNet.ssid : ""
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.maximumWidth: 180
          }

          Item {
            Layout.fillWidth: true
          }

          RowLayout {
            visible: root.selectedNet && root.selectedNet.connected
            spacing: Style.marginXS

            Item {
              width: disconnectBtn.implicitWidth
              height: disconnectBtn.implicitHeight
              NIconButton {
                id: disconnectBtn
                icon: "close"
                tooltipText: I18n.tr("common.disconnect")
                baseSize: Style.baseWidgetSize * 0.85
                onClicked: {
                  NetworkService.disconnect(root.selectedNet.ssid);
                  root.focusIndex = -1;
                }
              }
              NKeyHint {
                id: disconnectKeyHint
                key: "d"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -Style.marginXXS
                anchors.bottomMargin: -Style.marginXXS
              }
            }
          }

          RowLayout {
            visible: root.selectedNet && !root.selectedNet.connected
            spacing: Style.marginXS

            Item {
              width: connectBtn.implicitWidth
              height: connectBtn.implicitHeight
              NIconButton {
                id: connectBtn
                icon: "check"
                tooltipText: I18n.tr("common.connect")
                baseSize: Style.baseWidgetSize * 0.85
                onClicked: {
                  if (NetworkService.isSecured(root.selectedNet.security) && !root.selectedNet.existing) {
                    root.passwordTarget = root.selectedNet.ssid;
                    passwordField.text = "";
                    Qt.callLater(function () {
                      passwordField.forceActiveFocus();
                    });
                  } else {
                    NetworkService.connect(root.selectedNet.ssid);
                  }
                }
              }
              NKeyHint {
                id: connectKeyHint
                key: "c"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -Style.marginXXS
                anchors.bottomMargin: -Style.marginXXS
              }
            }
          }

          RowLayout {
            visible: root.selectedNet && root.selectedNet.existing
            spacing: Style.marginXS

            Item {
              width: pinBtn.implicitWidth
              height: pinBtn.implicitHeight
              NIconButton {
                id: pinBtn
                icon: "star-off"
                tooltipText: I18n.tr("common.forget")
                baseSize: Style.baseWidgetSize * 0.85
                onClicked: {
                  NetworkService.forget(root.selectedNet.ssid);
                  root.focusIndex = -1;
                }
              }
              NKeyHint {
                id: pinKeyHint
                key: "p"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -Style.marginXXS
                anchors.bottomMargin: -Style.marginXXS
              }
            }
          }
        }
      }

      Rectangle {
        id: passwordBar
        visible: root.passwordTarget.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? passwordRow.implicitHeight + Style.margin2M : 0
        Layout.maximumHeight: visible ? passwordRow.implicitHeight + Style.margin2M : 0
        radius: Style.radiusL
        color: Color.mSurfaceVariant
        border.width: Style.borderS
        border.color: Color.mPrimary

        RowLayout {
          id: passwordRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.marginL
          anchors.rightMargin: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "lock"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
          }

          NText {
            text: root.passwordTarget
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.maximumWidth: 120
          }

          NTextInput {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: I18n.tr("wifi.panel.enter-password")
            Component.onCompleted: inputItem.echoMode = TextInput.Password
            onAccepted: {
              if (text.length > 0) {
                NetworkService.connect(root.passwordTarget, text);
                root.passwordTarget = "";
                panelContent.forceActiveFocus();
              }
            }
          }

          NIconButton {
            icon: "check"
            baseSize: Style.baseWidgetSize * 0.7
            enabled: passwordField.text.length > 0
            onClicked: {
              NetworkService.connect(root.passwordTarget, passwordField.text);
              root.passwordTarget = "";
              panelContent.forceActiveFocus();
            }
          }

          NIconButton {
            icon: "close"
            baseSize: Style.baseWidgetSize * 0.7
            onClicked: {
              root.passwordTarget = "";
              panelContent.forceActiveFocus();
            }
          }
        }
      }
    }
  }
}
