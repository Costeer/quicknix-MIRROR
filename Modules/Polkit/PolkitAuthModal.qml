import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Auth
import qs.Widgets

FloatingWindow {
  id: root

  property string passwordInput: ""
  property var currentFlow: PolkitService.agent?.flow
  property bool isLoading: false
  property bool awaitingFprintForPassword: false

  property string polkitEtcPamText: ""
  property string polkitLibPamText: ""
  property string systemAuthPamText: ""
  property string commonAuthPamText: ""
  property string passwordAuthPamText: ""

  readonly property bool polkitPamHasFprint: {
    const polkitText = polkitEtcPamText !== "" ? polkitEtcPamText : polkitLibPamText;
    if (!polkitText)
      return false;
    return pamModuleEnabled(polkitText, "pam_fprintd") || (polkitText.includes("system-auth") && pamModuleEnabled(systemAuthPamText, "pam_fprintd")) || (polkitText.includes("common-auth") && pamModuleEnabled(commonAuthPamText, "pam_fprintd")) || (polkitText.includes("password-auth") && pamModuleEnabled(passwordAuthPamText, "pam_fprintd"));
  }

  function stripPamComment(line) {
    if (!line)
      return "";
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#"))
      return "";
    const hashIdx = trimmed.indexOf("#");
    if (hashIdx >= 0)
      return trimmed.substring(0, hashIdx).trim();
    return trimmed;
  }

  function pamModuleEnabled(pamText, moduleName) {
    if (!pamText || !moduleName)
      return false;
    const lines = pamText.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = stripPamComment(lines[i]);
      if (line && line.includes(moduleName))
        return true;
    }
    return false;
  }

  function focusPasswordField() {
    passwordField.inputItem.forceActiveFocus();
  }

  function show() {
    passwordInput = "";
    isLoading = false;
    awaitingFprintForPassword = false;
    visible = true;
    Qt.callLater(focusPasswordField);
  }

  function hide() {
    visible = false;
  }

  function _commitSubmit() {
    if (!currentFlow)
      return;
    isLoading = true;
    awaitingFprintForPassword = false;
    currentFlow.submit(passwordInput);
    passwordInput = "";
  }

  function submitAuth() {
    if (!currentFlow || isLoading)
      return;
    if (!currentFlow.isResponseRequired) {
      awaitingFprintForPassword = true;
      return;
    }
    _commitSubmit();
  }

  function cancelAuth() {
    if (isLoading)
      return;
    awaitingFprintForPassword = false;
    if (currentFlow) {
      currentFlow.cancelAuthenticationRequest();
      return;
    }
    hide();
  }

  title: "Authentication"
  visible: false
  implicitWidth: Style.toOdd(460 * Style.uiScaleRatio)
  implicitHeight: Style.toOdd(236 * Style.uiScaleRatio)
  minimumSize: Qt.size(implicitWidth, implicitHeight)
  maximumSize: Qt.size(implicitWidth, implicitHeight)
  color: "transparent"

  onVisibleChanged: {
    if (visible) {
      Qt.callLater(focusPasswordField);
      return;
    }
    passwordInput = "";
    isLoading = false;
    awaitingFprintForPassword = false;
  }

  Connections {
    target: PolkitService.agent
    enabled: PolkitService.polkitAvailable

    function onAuthenticationRequestStarted() {
      show();
    }

    function onIsActiveChanged() {
      if (!(PolkitService.agent?.isActive ?? false))
        hide();
    }
  }

  Connections {
    target: currentFlow
    enabled: currentFlow !== null

    function onIsResponseRequiredChanged() {
      if (!currentFlow.isResponseRequired)
        return;
      if (awaitingFprintForPassword && passwordInput !== "") {
        _commitSubmit();
        return;
      }
      awaitingFprintForPassword = false;
      isLoading = false;
      passwordInput = "";
      passwordField.inputItem.forceActiveFocus();
    }

    function onAuthenticationSucceeded() {
      hide();
    }

    function onAuthenticationFailed() {
      isLoading = false;
    }

    function onAuthenticationRequestCancelled() {
      hide();
    }
  }

  FileView {
    path: "/etc/pam.d/polkit-1"
    printErrors: false
    onLoaded: root.polkitEtcPamText = text()
    onLoadFailed: root.polkitEtcPamText = ""
  }

  FileView {
    path: "/usr/lib/pam.d/polkit-1"
    printErrors: false
    onLoaded: root.polkitLibPamText = text()
    onLoadFailed: root.polkitLibPamText = ""
  }

  FileView {
    path: "/etc/pam.d/system-auth"
    printErrors: false
    onLoaded: root.systemAuthPamText = text()
    onLoadFailed: root.systemAuthPamText = ""
  }

  FileView {
    path: "/etc/pam.d/common-auth"
    printErrors: false
    onLoaded: root.commonAuthPamText = text()
    onLoadFailed: root.commonAuthPamText = ""
  }

  FileView {
    path: "/etc/pam.d/password-auth"
    printErrors: false
    onLoaded: root.passwordAuthPamText = text()
    onLoadFailed: root.passwordAuthPamText = ""
  }

  FocusScope {
    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: event => {
      cancelAuth();
      event.accepted = true;
    }

    NBox {
      anchors.fill: parent
      forceOpaque: true
      color: Color.mSurface
      border.color: Color.mOutline
      radius: Style.radiusL
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: polkitPamHasFprint ? "fingerprint" : "shield-lock"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
          Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXS

          NText {
            text: "Authentication required"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NText {
            text: currentFlow?.message ?? ""
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
            maximumLineCount: 2
            visible: text !== ""
            Layout.fillWidth: true
          }

          NText {
            text: currentFlow?.supplementaryMessage ?? ""
            pointSize: Style.fontSizeS
            color: (currentFlow?.supplementaryIsError ?? false) ? Color.mError : Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
            maximumLineCount: 2
            visible: text !== ""
            Layout.fillWidth: true
          }
        }

        NIconButton {
          icon: "x"
          tooltipText: I18n.tr("common.cancel")
          enabled: !isLoading
          colorBg: "transparent"
          colorBgHover: Color.mError
          colorFg: Color.mOnSurface
          colorFgHover: Color.mOnError
          onClicked: cancelAuth()
          Layout.alignment: Qt.AlignTop
        }
      }

      Item {
        Layout.fillHeight: true
      }

      NText {
        text: currentFlow?.inputPrompt ?? ""
        pointSize: Style.fontSizeS
        color: Color.mOnSurface
        visible: text !== ""
        Layout.fillWidth: true
      }

      NTextInput {
        id: passwordField
        Layout.fillWidth: true
        inputIconName: polkitPamHasFprint ? "fingerprint" : "key"
        text: root.passwordInput
        echoMode: (currentFlow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
        enabled: !isLoading
        showClearButton: false
        onTextChanged: root.passwordInput = text
        onAccepted: submitAuth()
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Item {
          Layout.fillWidth: true
        }

        NButton {
          text: I18n.tr("common.cancel")
          outlined: true
          enabled: !isLoading
          backgroundColor: Color.mOnSurfaceVariant
          textColor: Color.mOnSurface
          onClicked: cancelAuth()
          Layout.preferredWidth: 120 * Style.uiScaleRatio
        }

        NButton {
          text: isLoading ? "Authenticating..." : I18n.tr("common.confirm")
          icon: isLoading ? "loader-2" : "check"
          enabled: !isLoading && currentFlow !== null
          onClicked: submitAuth()
          Layout.preferredWidth: 160 * Style.uiScaleRatio
        }
      }
    }
  }
}
