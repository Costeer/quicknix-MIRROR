pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Services.System
import qs.Services.UI

Singleton {
  id: root

  readonly property bool wifiAvailable: _wifiAvailable
  readonly property bool internetConnectivity: _internetConnectivity
  readonly property string networkConnectivity: _networkConnectivity

  property bool _wifiAvailable: false
  property string _networkConnectivity: "unknown"
  property bool _internetConnectivity: false
  property string lastError: ""
  property bool nmcliAvailable: false

  readonly property bool wifiEnabled: Networking.wifiEnabled
  property var networks: ({})
  property bool wifiConnected: false
  property string activeWifiIf: ""
  property var activeWifiDetails: ({})
  property bool wifiDetailsLoading: false
  property double activeWifiDetailsTimestamp: 0
  property bool wifiInit: false

  property bool connecting: false
  property string connectingTo: ""
  property string disconnectingFrom: ""
  property string forgettingNetwork: ""
  property bool scanPending: false
  property bool scanningActive: false
  property var existingProfiles: ({})

  property bool airplaneModeEnabled: false
  property bool airplaneModeToggled: false

  Connections {
    target: root
    function onWifiEnabledChanged() {
      if (!root.wifiInit)
        return;
      wifiDebounce.restart();
    }
  }

  Component.onCompleted: {
    Logger.i("Network", "Service started");
    nmcliCheckProcess.running = true;
    wifiInitTimer.running = true;
  }

  Process {
    id: nmcliCheckProcess
    running: false
    command: ["nmcli", "--version"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim().length > 0) {
          root.nmcliAvailable = true;
          Logger.i("Network", "nmcli detected");
          deviceStatusProcess.running = true;
          connectivityCheckProcess.running = true;
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim().length > 0) {
          root.nmcliAvailable = false;
          Logger.w("Network", "nmcli not available");
        }
      }
    }
  }

  Timer {
    id: wifiInitTimer
    interval: 500
    onTriggered: {
      root.wifiInit = true;
      if (root.wifiEnabled && root.nmcliAvailable)
        scan();
    }
  }

  Timer {
    id: wifiDebounce
    interval: 300
    onTriggered: {
      if (!root.nmcliAvailable)
        return;
      if (root.airplaneModeToggled) {
        root.airplaneModeToggled = false;
        if (root.wifiEnabled) {
          scan();
        } else {
          root.networks = ({});
        }
        return;
      }
      if (root.wifiEnabled) {
        ToastService.showNotice(I18n.tr("common.wifi"), I18n.tr("common.enabled"), "wifi");
        scan();
      } else {
        ToastService.showNotice(I18n.tr("common.wifi"), I18n.tr("common.disabled"), "wifi-off");
        root.networks = ({});
      }
    }
  }

  Timer {
    id: connectivityCheckTimer
    interval: 15000
    running: root.nmcliAvailable && root.wifiConnected
    repeat: true
    onTriggered: connectivityCheckProcess.running = true
  }

  Timer {
    id: delayedScanTimer
    interval: 7000
    onTriggered: scan()
  }

  function setWifiEnabled(enabled) {
    if (!root.nmcliAvailable)
      return;
    Logger.i("Wi-Fi", "SetWifiEnabled", enabled);
    Networking.wifiEnabled = enabled;
  }

  function setAirplaneMode(state) {
    root.airplaneModeToggled = true;
    if (state) {
      Quickshell.execDetached(["rfkill", "block", "all"]);
      root.airplaneModeEnabled = true;
      ToastService.showNotice(I18n.tr("toast.airplane-mode.title"), I18n.tr("common.enabled"), "plane");
    } else {
      Quickshell.execDetached(["rfkill", "unblock", "all"]);
      root.airplaneModeEnabled = false;
      ToastService.showNotice(I18n.tr("toast.airplane-mode.title"), I18n.tr("common.disabled"), "plane-off");
    }
  }

  function scan() {
    if (!root.nmcliAvailable || !root.wifiEnabled)
      return;
    lastError = "";
    if (profileCheckProcess.running || scanProcess.running) {
      root.scanPending = true;
      return;
    }
    profileCheckProcess.running = true;
    root.scanningActive = true;
    Logger.d("Network", "Scanning Wi-Fi networks...");
  }

  function connect(ssid, password) {
    if (!root.nmcliAvailable || connecting)
      return;

    const isSaved = networks[ssid] && networks[ssid].existing;
    connecting = true;
    connectingTo = ssid;
    lastError = "";

    connectProcess.ssid = ssid;
    connectProcess.password = password || "";

    if (isSaved) {
      connectProcess.mode = "saved";
    } else {
      connectProcess.mode = "new";
    }
    connectProcess.running = true;
  }

  function disconnect(ssid) {
    if (!root.nmcliAvailable)
      return;
    disconnectingFrom = ssid;
    disconnectProcess.ssid = ssid;
    disconnectProcess.running = true;
  }

  function forget(ssid) {
    if (!root.nmcliAvailable)
      return;
    forgettingNetwork = ssid;
    forgetProcess.ssid = ssid;
    forgetProcess.running = true;
  }

  function refreshActiveWifiDetails() {
    const now = Date.now();
    if (wifiDetailsLoading || activeWifiIf && wifiConnected && activeWifiDetails && (now - activeWifiDetailsTimestamp) < 10000)
      return;
    if (wifiConnected && activeWifiIf) {
      wifiDetailsLoading = true;
      deviceStatusProcess.running = true;
    }
  }

  function updateNetworkStatus(ssid, connected) {
    let nets = networks;
    for (let key in nets) {
      if (nets[key].connected && key !== ssid)
        nets[key].connected = false;
    }
    if (nets[ssid]) {
      nets[ssid].connected = connected;
      nets[ssid].existing = true;
    } else if (connected) {
      nets[ssid] = {
        "ssid": ssid,
        "security": "--",
        "signal": 100,
        "connected": true,
        "existing": true
      };
    }
    networks = ({});
    networks = nets;
  }

  function getSignalInfo(signal, isConnected) {
    let icon = "";
    if (isConnected) {
      if (root._networkConnectivity === "limited")
        icon = "wifi-exclamation";
      else if (root._networkConnectivity === "portal" || root._networkConnectivity === "unknown")
        icon = "wifi-question";
    }
    const label = signal >= 80 ? I18n.tr("wifi.signal.excellent") : signal >= 60 ? I18n.tr("wifi.signal.good") : signal >= 35 ? I18n.tr("wifi.signal.fair") : signal >= 15 ? I18n.tr("wifi.signal.poor") : I18n.tr("wifi.signal.weak");
    if (!icon)
      icon = signal >= 80 ? "wifi" : signal >= 60 ? "wifi-3" : signal >= 35 ? "wifi-2" : signal >= 15 ? "wifi-1" : "wifi-0";
    return {
      icon,
      label
    };
  }

  function isSecured(security) {
    return security && security !== "--" && security.trim() !== "";
  }

  function getIcon() {
    if (root.airplaneModeEnabled)
      return "plane";
    if (!root.wifiEnabled)
      return "wifi-off";
    if (root.wifiConnected) {
      let s = (root.activeWifiDetails && root.activeWifiDetails.signal !== undefined && root.activeWifiDetails.signal !== "") ? root.activeWifiDetails.signal : 0;
      return root.getSignalInfo(s, true).icon;
    }
    if (root.connecting || Object.keys(root.networks).length > 0)
      return "wifi-question";
    return root._wifiAvailable ? "wifi-0" : "wifi-off";
  }

  Process {
    id: deviceStatusProcess
    running: false
    command: ["sh", "-c", "nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS,CAPABILITIES.SPEED device show; echo \"------\"; nmcli -t -f IN-USE,SIGNAL,RATE,CHAN,FREQ,BANDWIDTH device wifi list"]
    environment: ({
                    "LC_ALL": "C"
                  })

    stdout: StdioCollector {
      onStreamFinished: {
        const outputParts = text.split("------");
        const deviceText = outputParts[0];
        const wifiText = outputParts[1] || "";

        let lines = deviceText.split("\n");
        let deviceBlocks = [];
        let currentBlock = [];

        for (let i = 0; i < lines.length; i++) {
          let line = lines[i].trim();
          if (!line)
            continue;
          if (line.startsWith("GENERAL.DEVICE:")) {
            if (currentBlock.length > 0)
              deviceBlocks.push(currentBlock);
            currentBlock = [line];
          } else if (currentBlock.length > 0) {
            currentBlock.push(line);
          }
        }
        if (currentBlock.length > 0)
          deviceBlocks.push(currentBlock);

        let activeWifiIf = "";
        let wifiAvailable = false;

        let newActiveWifiDetails = ({});

        for (let b = 0; b < deviceBlocks.length; b++) {
          let block = deviceBlocks[b];
          let name = "";
          let type = "";
          let stateStr = "";

          for (let l = 0; l < block.length; l++) {
            let line = block[l];
            if (line.startsWith("GENERAL.DEVICE:"))
              name = line.substring(15).trim();
            else if (line.startsWith("GENERAL.TYPE:"))
              type = line.substring(13).trim();
            else if (line.startsWith("GENERAL.STATE:"))
              stateStr = line.substring(14).trim();
          }

          if (stateStr.indexOf("(unmanaged)") !== -1)
            continue;
          let isConnected = stateStr.indexOf("(connected)") !== -1;

          if (type === "wifi") {
            wifiAvailable = true;
            if (isConnected && !activeWifiIf) {
              activeWifiIf = name;
              newActiveWifiDetails.ifname = name;
              for (let l = 0; l < block.length; l++) {
                let line = block[l];
                if (line.startsWith("GENERAL.CONNECTION:"))
                  newActiveWifiDetails.connectionName = line.substring(20).trim();
                else if (line.startsWith("GENERAL.HWADDR:"))
                  newActiveWifiDetails.hwAddr = line.substring(15).trim();
                else if (line.startsWith("IP4.ADDRESS:"))
                  newActiveWifiDetails.ipv4 = line.substring(12).trim().split("/")[0];
                else if (line.startsWith("IP4.GATEWAY:"))
                  newActiveWifiDetails.gateway4 = line.substring(12).trim();
              }
            }
          }
        }

        if (activeWifiIf && wifiText) {
          let signal = "";
          let rate = "";
          let channel = "";
          let freq = "";

          const wifiLines = wifiText.split("\n");
          for (let i = 0; i < wifiLines.length; i++) {
            const line = wifiLines[i].trim();
            if (line.startsWith("*")) {
              const parts = line.split(":");
              if (parts.length >= 6) {
                signal = parts[1];
                rate = parts[2];
                channel = parts[3];
                freq = parts[4].replace(" MHz", "");
              }
              break;
            }
          }

          let band = "";
          if (freq) {
            const f = +freq;
            if (f >= 5925 && f < 7125)
              band = "6 GHz";
            else if (f >= 5150 && f < 5925)
              band = "5 GHz";
            else if (f >= 2400 && f < 2500)
              band = "2.4 GHz";
            else
              band = freq + " MHz";
          }

          newActiveWifiDetails.band = band;
          newActiveWifiDetails.channel = channel;
          newActiveWifiDetails.signal = signal;
          newActiveWifiDetails.rate = rate;
        }

        root._wifiAvailable = wifiAvailable;
        root.wifiConnected = activeWifiIf !== "";

        root.activeWifiIf = activeWifiIf;
        root.activeWifiDetails = newActiveWifiDetails;
        root.activeWifiDetailsTimestamp = Date.now();
        root.wifiDetailsLoading = false;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        root.wifiDetailsLoading = false;
      }
    }
  }

  Process {
    id: connectivityCheckProcess
    running: false
    command: ["nmcli", "networking", "connectivity", "check"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = text.trim();
        if (!r)
          return;
        root._networkConnectivity = r === "none" ? "unknown" : r;
        root._internetConnectivity = r === "full";
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim())
          Logger.w("Network", "Connectivity check error: " + text);
      }
    }
  }

  Process {
    id: profileCheckProcess
    running: false
    command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]

    stdout: StdioCollector {
      onStreamFinished: {
        var profiles = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var l = lines[i];
          if (l && l.trim())
            profiles[l.trim()] = true;
        }
        root.existingProfiles = profiles;
        scanProcess.running = true;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() && root.scanningActive) {
          delayedScanTimer.interval = 5000;
          delayedScanTimer.restart();
        }
      }
    }
  }

  Process {
    id: scanProcess
    running: false
    command: ["nmcli", "-t", "-f", "SSID,SECURITY,SIGNAL,IN-USE", "device", "wifi", "list", "--rescan", "yes"]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        const networksMap = {};

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim();
          if (!line)
            continue;

          const parts = line.split(":");
          if (parts.length < 4)
            continue;

          const inUse = parts[parts.length - 1];
          const signal = parseInt(parts[parts.length - 2]) || 0;
          let security = parts[parts.length - 3];
          if (security)
            security = security.replace("WPA2 WPA3", "WPA2/WPA3").replace("WPA1 WPA2", "WPA1/WPA2");
          const ssid = parts.slice(0, parts.length - 3).join(":");

          if (ssid) {
            const isConnected = inUse === "*";
            if (!networksMap[ssid]) {
              networksMap[ssid] = {
                "ssid": ssid,
                "security": security || "--",
                "signal": signal,
                "connected": isConnected,
                "existing": !!root.existingProfiles[ssid]
              };
            } else {
              if (isConnected) {
                networksMap[ssid].connected = true;
                networksMap[ssid].signal = signal;
                connectivityCheckProcess.running = true;
              } else if (!networksMap[ssid].connected && signal > networksMap[ssid].signal) {
                networksMap[ssid].signal = signal;
              }
            }
          }
        }

        root.networks = networksMap;
        Logger.d("Network", "Scan complete:", Object.keys(networksMap).length, "networks");

        if (Object.values(networksMap).some(n => n.connected))
          root.refreshActiveWifiDetails();

        if (root.scanPending) {
          root.scanPending = false;
          delayedScanTimer.interval = 100;
          delayedScanTimer.restart();
        }
        root.scanningActive = false;
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          Logger.w("Network", "Scan error: " + text);
          if (root.scanPending) {
            root.scanPending = false;
            delayedScanTimer.interval = 3000;
          } else if (root.scanningActive) {
            delayedScanTimer.interval = 10000;
          }
          delayedScanTimer.restart();
        }
        root.scanningActive = false;
      }
    }
  }

  Process {
    id: connectProcess
    property string mode: "new"
    property string ssid: ""
    property string password: ""
    running: false

    command: {
      if (mode === "saved") {
        return ["nmcli", "-t", "connection", "up", "id", ssid];
      } else {
        var cmd = ["nmcli", "-t", "device", "wifi", "connect", ssid];
        if (password)
          cmd.push("password", password);
        if (root.activeWifiIf)
          cmd.push("ifname", root.activeWifiIf);
        return cmd;
      }
    }

    environment: ({
                    "LC_ALL": "C"
                  })

    stdout: StdioCollector {
      onStreamFinished: {
        const output = text.trim();
        if (!output || (output.indexOf("successfully activated") === -1 && output.indexOf("Connection successfully") === -1))
          return;

        root.wifiConnected = true;
        root.updateNetworkStatus(connectProcess.ssid, true);
        root.refreshActiveWifiDetails();

        root.connecting = false;
        root.connectingTo = "";
        Logger.i("Network", "Connected to: '" + connectProcess.ssid + "'");
        ToastService.showNotice(I18n.tr("common.wifi"), I18n.tr("toast.wifi.connected", {
          "ssid": connectProcess.ssid
        }), root.getIcon());

        delayedScanTimer.interval = 5000;
        delayedScanTimer.restart();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim()) {
          root.connecting = false;
          root.connectingTo = "";

          if (text.indexOf("Secrets were required") !== -1 || text.indexOf("no secrets provided") !== -1)
            root.lastError = I18n.tr("toast.wifi.incorrect-password");
          else if (text.indexOf("No network with SSID") !== -1)
            root.lastError = I18n.tr("toast.wifi.network-not-found");
          else if (text.indexOf("Timeout") !== -1)
            root.lastError = I18n.tr("toast.wifi.connection-timeout");
          else
            root.lastError = I18n.tr("toast.wifi.connection-failed");

          Logger.w("Network", "Connect error: " + text);
          ToastService.showWarning(I18n.tr("common.wifi"), root.lastError || I18n.tr("toast.wifi.connection-failed"), "wifi-exclamation");
          wifiConnected = false;
        }
      }
    }
  }

  Process {
    id: disconnectProcess
    property string ssid: ""
    running: false
    command: ["nmcli", "connection", "down", "id", ssid]

    stdout: StdioCollector {
      onStreamFinished: {
        Logger.i("Network", "Disconnected from: '" + disconnectProcess.ssid + "'");
        root.wifiConnected = false;
        ToastService.showNotice(I18n.tr("common.wifi"), I18n.tr("toast.wifi.disconnected", {
          "ssid": disconnectProcess.ssid
        }), "wifi-off");
        root.updateNetworkStatus(disconnectProcess.ssid, false);
        root.disconnectingFrom = "";
        delayedScanTimer.interval = 3000;
        delayedScanTimer.restart();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.disconnectingFrom = "";
        delayedScanTimer.interval = 5000;
        delayedScanTimer.restart();
      }
    }
  }

  Process {
    id: forgetProcess
    property string ssid: ""
    running: false
    environment: ({
                    "LC_ALL": "C"
                  })

    command: {
      var script = `
        ssid="$1"
        UUID=$(nmcli -t -f NAME,UUID,TYPE connection show | awk -F: -v target="$ssid" '$1 == target && $3 == "802-11-wireless" { print $2; exit }')
        if [ -n "$UUID" ]; then
            nmcli connection delete uuid "$UUID" 2>/dev/null && echo "Deleted: $ssid"
        else
            echo "No profile found for: $ssid"
        fi
      `;
      return ["sh", "-c", script, "--", ssid];
    }

    stdout: StdioCollector {
      onStreamFinished: {
        Logger.i("Network", "Forget: \"" + forgetProcess.ssid + "\"");
        let nets = root.networks;
        if (nets[forgetProcess.ssid])
          nets[forgetProcess.ssid].existing = false;
        root.networks = ({});
        root.networks = nets;
        root.forgettingNetwork = "";
        delayedScanTimer.interval = 5000;
        delayedScanTimer.restart();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.forgettingNetwork = "";
        delayedScanTimer.interval = 5000;
        delayedScanTimer.restart();
      }
    }
  }

  Process {
    id: networkMonitorProcess
    running: root.nmcliAvailable
    command: ["nmcli", "-t", "monitor"]
    environment: ({
                    "LC_ALL": "C"
                  })
    stdout: SplitParser {
      onRead: data => {
        if (data.endsWith(": connected") || data.endsWith(": disconnected")) {
          Logger.d("Network", "State changed: " + data);
          deviceStatusProcess.running = true;
          connectivityCheckProcess.running = true;
        }
      }
    }
  }
}
