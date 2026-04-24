pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Widgets

Singleton {
  id: root

  signal pluginWidgetRegistryUpdated

  property var widgets: ({
                           "Battery": batteryComponent,
                           "Brightness": brightnessComponent,
                           "Clock": clockComponent,
                           "NotificationHistory": notificationHistoryComponent,
                           "Spacer": spacerComponent,
                           "Tray": trayComponent,
                           "Volume": volumeComponent,
                           "Workspace": workspaceComponent
                         })

  property var widgetSettingsMap: ({
                                     "Battery": "WidgetSettings/BatterySettings.qml",
                                     "Brightness": "WidgetSettings/BrightnessSettings.qml",
                                     "Clock": "WidgetSettings/ClockSettings.qml",
                                     "Network": "",
                                     "NotificationHistory": "WidgetSettings/NotificationHistorySettings.qml",
                                     "Spacer": "WidgetSettings/SpacerSettings.qml",
                                     "Tray": "WidgetSettings/TraySettings.qml",
                                     "Volume": "WidgetSettings/VolumeSettings.qml",
                                     "Workspace": "WidgetSettings/WorkspaceSettings.qml"
                                   })

  property var widgetMetadata: ({
                                  "Battery": {
                                    "displayMode": "graphic-clean",
                                    "deviceNativePath": "__default__",
                                    "showPowerProfiles": false,
                                    "showQuickNixPerformance": false,
                                    "hideIfNotDetected": true,
                                    "hideIfIdle": false
                                  },
                                  "Brightness": {
                                    "displayMode": "alwaysHide",
                                    "iconColor": "none",
                                    "textColor": "none",
                                    "applyToAllMonitors": false
                                  },
                                  "Clock": {
                                    "clockColor": "none",
                                    "useCustomFont": false,
                                    "customFont": "",
                                    "formatHorizontal": "HH:mm ddd, MMM dd",
                                    "formatVertical": "HH mm - dd MM",
                                    "tooltipFormat": "HH:mm ddd, MMM dd"
                                  },
                                  "Network": {
                                    "displayMode": "icon",
                                    "iconColor": "none",
                                    "textColor": "none"
                                  },
                                  "NotificationHistory": {
                                    "showUnreadBadge": true,
                                    "hideWhenZero": false,
                                    "hideWhenZeroUnread": false,
                                    "unreadBadgeColor": "primary",
                                    "iconColor": "none"
                                  },
                                  "Spacer": {
                                    "width": 20
                                  },
                                  "Tray": {
                                    "blacklist": [],
                                    "colorizeIcons": false,
                                    "chevronColor": "none",
                                    "pinned": [],
                                    "drawerEnabled": true,
                                    "hidePassive": false
                                  },
                                  "Volume": {
                                    "displayMode": "alwaysHide",
                                    "middleClickCommand": "pwvucontrol || pavucontrol",
                                    "iconColor": "none",
                                    "textColor": "none"
                                  },
                                  "Workspace": {
                                    "labelMode": "none",
                                    "followFocusedScreen": false,
                                    "hideUnoccupied": false,
                                    "characterCount": 2,
                                    "showApplications": false,
                                    "showApplicationsHover": false,
                                    "showLabelsOnlyWhenOccupied": true,
                                    "colorizeIcons": false,
                                    "unfocusedIconsOpacity": 1.0,
                                    "groupedBorderOpacity": 1.0,
                                    "enableScrollWheel": true,
                                    "iconScale": 0.8,
                                    "focusedColor": "primary",
                                    "occupiedColor": "none",
                                    "emptyColor": "none",
                                    "showBadge": true,
                                    "pillSize": 0.6,
                                    "fontWeight": "bold"
                                  }
                                })

  property Component batteryComponent: Component {
    Battery {}
  }
  property Component brightnessComponent: Component {
    Brightness {}
  }
  property Component clockComponent: Component {
    Clock {}
  }
  property Component notificationHistoryComponent: Component {
    NotificationHistory {}
  }
  property Component spacerComponent: Component {
    Spacer {}
  }
  property Component trayComponent: Component {
    Tray {}
  }
  property Component volumeComponent: Component {
    Volume {}
  }
  property Component workspaceComponent: Component {
    Workspace {}
  }

  function init() {
    Logger.i("BarWidgetRegistry", "Service started");
  }

  function getWidget(id) {
    return widgets[id] || null;
  }

  function hasWidget(id) {
    return id in widgets;
  }

  function getAvailableWidgets() {
    return Object.keys(widgets);
  }

  function widgetHasUserSettings(id) {
    return widgetMetadata[id] !== undefined;
  }

  property var pluginWidgets: ({})
  property var pluginWidgetMetadata: ({})

  function registerPluginWidget(pluginId, component, metadata) {
    if (!pluginId || !component) {
      Logger.e("BarWidgetRegistry", "Cannot register plugin widget: invalid parameters");
      return false;
    }
    var widgetId = "plugin:" + pluginId;
    pluginWidgets[widgetId] = component;
    pluginWidgetMetadata[widgetId] = metadata || {};
    widgets[widgetId] = component;
    widgetMetadata[widgetId] = metadata || {};
    Logger.i("BarWidgetRegistry", "Registered plugin widget:", widgetId);
    root.pluginWidgetRegistryUpdated();
    return true;
  }

  function unregisterPluginWidget(pluginId) {
    var widgetId = "plugin:" + pluginId;
    if (!pluginWidgets[widgetId]) {
      Logger.w("BarWidgetRegistry", "Plugin widget not registered:", widgetId);
      return false;
    }
    delete pluginWidgets[widgetId];
    delete pluginWidgetMetadata[widgetId];
    delete widgets[widgetId];
    delete widgetMetadata[widgetId];
    Logger.i("BarWidgetRegistry", "Unregistered plugin widget:", widgetId);
    root.pluginWidgetRegistryUpdated();
    return true;
  }

  function isPluginWidget(id) {
    return id.startsWith("plugin:");
  }

  property var cpuIntensiveWidgets: []

  function isCpuIntensive(id) {
    if (pluginWidgetMetadata[id]?.cpuIntensive)
      return true;
    return cpuIntensiveWidgets.indexOf(id) >= 0;
  }

  function getPluginWidgets() {
    return Object.keys(pluginWidgets);
  }
}
