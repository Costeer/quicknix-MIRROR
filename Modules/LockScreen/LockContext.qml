import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Commons

Scope {
  id: root

  signal unlocked
  signal failed

  property string password: ""
  property bool busy: false
  property bool waitingForResponse: false
  property string message: ""
  property bool error: false

  readonly property string pamService: Quickshell.env("QUICKNIX_PAM_SERVICE") || "login"
  readonly property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

  function tryUnlock() {
    if (busy)
      return;
    error = false;
    message = "";
    busy = true;
    waitingForResponse = false;
    pam.start();
  }

  function reset() {
    password = "";
    busy = false;
    waitingForResponse = false;
    message = "";
    error = false;
    pam.abort();
  }

  PamContext {
    id: pam
    configDirectory: "/etc/pam.d"
    config: root.pamService
    user: root.username

    onPamMessage: {
      if (message && message.length > 0) {
        root.message = message;
        root.error = messageIsError;
      }
      if (responseRequired) {
        root.waitingForResponse = true;
        respond(root.password);
      }
    }

    onCompleted: result => {
      root.busy = false;
      root.waitingForResponse = false;
      if (result === PamResult.Success) {
        root.password = "";
        root.unlocked();
      } else {
        root.password = "";
        root.error = true;
        root.message = "Authentication failed";
        root.failed();
      }
    }
  }
}
