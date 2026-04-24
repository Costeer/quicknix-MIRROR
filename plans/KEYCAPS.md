# Plan: Keyboard-First Panel Navigation
Global Panel-Opening Shortcuts
| Panel | Default Shortcut | Setting Key |
|-------|-----------------|-------------|
| Audio | Super+Shift+A | keyOpenAudio |
| Brightness | Super+Shift+B | keyOpenBrightness |
| Notifications | Super+Shift+N | keyOpenNotifications |
| Clock | Super+Shift+C | keyOpenClock |
| Tray | Super+Shift+T | keyOpenTray |
| Battery | Super+Shift+R (R for "remaining/power") | keyOpenBattery |
Panel Actions with Always-Visible Key Hints
NotificationHistoryPanel:
- d — Toggle DND (badge: d on bell icon)
- c — Clear history (badge: c on trash icon)
AudioPanel:
- m — Toggle output mute (badge: m on mute button)
- n — Toggle input mute (badge: n on input mute button)
- 1/2 — Switch tabs
BrightnessPanel:
- Up/Down — Adjust brightness (already mapped via slider focus)
BatteryPanel:
- p — Cycle power profile (badge: p on profile)
- t — Toggle performance mode (badge: t on toggle)
Implementation Order
1. Settings.qml — Add keybind entries for panel-opening shortcuts
2. MainScreen.qml — Add Instantiator blocks for each panel-open shortcut
3. SmartPanel.qml — Add Keys.onPressed forwarding infrastructure (catch single-key presses and call handler functions on the panel content)
4. Each panel QML — Implement handler functions and add always-visible key hint badges next to action buttons
5. Create a reusable NKeyHint component — A small badge component for displaying the shortcut key
Architectural Notes
- Panel-open shortcuts will toggle (open if closed, close if same panel is open)
- Single-key actions (d, c, m, etc.) are only active when the panel is open and focused
- SmartPanel already has exclusiveKeyboard and the MainScreen shortcut system — we extend this with a Keys.onPressed handler that catches alphanumeric keys and dispatches to the panel content's handler functions
- Key hints will be rendered as small text badges (e.g. [d]) next to icons, using a small monospace font in a subtle color

Implementation Plan: Keyboard-First Panel Navigation
New Component: Widgets/NKeyHint.qml
A reusable key-cap badge that visually looks like a keyboard key, following QuickNix's design language:
```
┌───┐
│ d │
└───┘
```
Design specs (matching existing patterns):
- Size: ~20x20px (proportional to Style.baseWidgetSize * 0.55)
- Background: Color.mSurfaceVariant (same as NIconButton default bg)
- Border: Style.borderS width, Color.mOutline color (same as all buttons)
- Radius: Style.iRadiusS (12px, consistent with small input elements)
- Text: Style.fontSizeXS (9pt), Style.fontWeightMedium (500), monospace font (Settings.data.ui.fontFixed), Color.mOnSurface color
- Animation on activation: Scale bounce to 1.2 + color flash to Color.mPrimary bg / Color.mOnPrimary text, then back — duration Style.animationNormal (300ms), Easing.OutBack
- Animation guard: enabled: !Color.isTransitioning
- Position: Overlaid on bottom-right of the parent button, offset -4px from each edge
Properties:
- property string key: "" — the key letter to display
- property bool active: false — triggers the activation animation
- Read-only positioning via anchors to parent
Animation detail: A SequentialAnimation on active change:
1. Scale → 1.15, bg → mPrimary, text → mOnPrimary (duration: animationFast)
2. Scale → 1.0, bg → mSurfaceVariant, text → mOnSurface (duration: animationNormal, Easing.OutBack)
---

## Step 1: Settings.qml — Add Panel-Opening Keybinds

Add to Settings.data.general.keybinds JsonObject:
property list<string> keyOpenAudio: ["Super+Shift+A"]
property list<string> keyOpenBrightness: ["Super+Shift+B"]
property list<string> keyOpenBattery: ["Super+Shift+R"]
property list<string> keyOpenNotifications: ["Super+Shift+N"]
property list<string> keyOpenClock: ["Super+Shift+C"]
property list<string> keyOpenTray: ["Super+Shift+T"]

---

## Step 2: MainScreen.qml — Add Panel-Opening Shortcuts

For each panel keybind, add an Instantiator + Shortcut block. These are active regardless of panel state (toggle behavior):

// Panel opening shortcuts
property var panelShortcuts: ({
  "keyOpenAudio": "audioPanel",
  "keyOpenBrightness": "brightnessPanel",
  "keyOpenBattery": "batteryPanel",
  "keyOpenNotifications": "notificationHistoryPanel",
  "keyOpenClock": "clockPanel",
  "keyOpenTray": "trayDrawerPanel"
})
Repeater {
  model: Object.keys(panelShortcuts)
  delegate: Instantiator {
    model: Settings.data.general.keybinds["key" + modelData] || []
    Shortcut {
      sequence: modelData
      enabled: !PanelService.isKeybindRecording
      onActivated: {
        var panelName = panelShortcuts[panelShortcutRepeater.model.get(index)];
        var target = PanelService.getPanel(panelName, root.screen);
        if (target) {
          if (PanelService.openedPanel === target) {
            target.close();
          } else if (PanelService.openedPanel) {
            PanelService.openedPanel.close();
            // defer open to after close animation starts
            Qt.callLater(() => target.open());
          } else {
            target.open();
          }
        }
      }
    }
  }
}
Actually, since Instantiator doesn't support dynamic model well, a cleaner approach is 6 separate Instantiator blocks (one per panel), following the exact same pattern as the existing escape/up/down shortcuts.

---

## Step 3: SmartPanel.qml — Add Keys.onPressed Dispatching

Add a Keys.onPressed handler to the inner panelContent Item that catches alphanumeric keys and dispatches to handler functions on the loaded content:
// Inside the panelContent Item
Keys.onPressed: event => {
  if (!contentLoader.item) return;
  var handler = null;
  switch (event.key) {
    case Qt.Key_D: handler = contentLoader.item.onDPressed; break;
    case Qt.Key_C: handler = contentLoader.item.onCPressed; break;
    case Qt.Key_M: handler = contentLoader.item.onMPressed; break;
    case Qt.Key_N: handler = contentLoader.item.onNPressed; break;
    case Qt.Key_P: handler = contentLoader.item.onPPressed; break;
    case Qt.Key_T: handler = contentLoader.item.onTPressed; break;
    case Qt.Key_1: handler = contentLoader.item.on1Pressed; break;
    case Qt.Key_2: handler = contentLoader.item.on2Pressed; break;
    case Qt.Key_3: handler = contentLoader.item.on3Pressed; break;
    case Qt.Key_4: handler = contentLoader.item.on4Pressed; break;
  }
  if (typeof handler === "function") {
    handler();
    event.accepted = true;
  }
}
But wait — the inner panelContent Item doesn't have focus: true set. The loaded content items (like NotificationHistoryPanel's Rectangle) set focus: true. So we need to ensure the key forwarding chain works: PanelWindow → Shortcut system → SmartPanel → contentLoader.item.
A better approach: Add the alphanumeric key dispatch in MainScreen.qml alongside the existing shortcuts, since that's where all keyboard handling already lives. Add a catch-all handler that forwards alphanumeric keys to the opened panel's content.
Actually, the cleanest approach: extend the existing Shortcut system in MainScreen with per-key Shortcut items for the in-panel actions. But Shortcut requires exact sequences and doesn't handle dynamic single-key presses well when a panel has focus.
The best approach: Add Keys.onPressed to the panelContent Item in SmartPanel.qml, and ensure the loaded content forwards keys up. The NotificationHistoryPanel already has Keys.onPressed on its Rectangle { focus: true } — we can add key handlers there directly.
Revised approach: Add keyboard handlers directly to each panel's panelContent component, using Keys.onPressed. This is simpler and each panel owns its own key handling.

---

Step 4: Per-Panel Keyboard Handlers + Key Hints
NotificationHistoryPanel.qml
Add to the Rectangle { id: panelContent; focus: true }:
Keys.onPressed: event => {
  // existing handlers already exist for Tab/Up/Down/Left/Right/Enter/Delete
  // Add new ones:
  switch (event.key) {
    case Qt.Key_D:
      NotificationService.doNotDisturb = !NotificationService.doNotDisturb;
      dndKeyHint.active = true;
      event.accepted = true;
      break;
    case Qt.Key_C:
      NotificationService.clearHistory();
      root.close();
      event.accepted = true;
      break;
  }
}
Add key hints next to header buttons. The header RowLayout currently has:
[NIcon] [NText] [NIconButton (dnd)] [NIconButton (clear)] [NIconButton (close)]
Wrap each action button in an Item that includes both the NIconButton and an NKeyHint overlay:
// DND toggle with key hint
Item {
  width: dndBtn.width
  height: dndBtn.height
  NIconButton {
    id: dndBtn
    icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
    baseSize: Style.baseWidgetSize * 0.8
    onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
  }
  NKeyHint {
    id: dndKeyHint
    key: "d"
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: -Style.marginXXS
    anchors.bottomMargin: -Style.marginXXS
  }
}
AudioPanel.qml
Add Keys.onPressed to panelContent:
- m → toggle output mute
- n → toggle input mute
- 1 → switch to Volumes tab
- 2 → switch to Devices tab
Add NKeyHint { key: "m" } overlay on the output mute NIconButton.
Add NKeyHint { key: "n" } overlay on the input mute NIconButton.
BrightnessPanel.qml
Add Keys.onPressed to panelContent:
- Up/Down → adjust first slider value by ±0.05 (focus the slider)
No extra key hints needed — Up/Down is intuitive for a slider panel.
BatteryPanel.qml
Add Keys.onPressed to panelContent:
- p → cycle power profile (increment index, wrap around)
- t → toggle performance mode
Add NKeyHint { key: "p" } on the profile section.
Add NKeyHint { key: "t" } on the performance toggle.
ClockPanel.qml — No interactive elements, skip.
TrayDrawerPanel.qml — exclusiveKeyboard: false by design, skip.

---

Step 5: NKeyHint Activation Animation

When a key is pressed, the corresponding NKeyHint should animate. The simplest mechanism:
Each panel's Keys.onPressed handler sets keyHint.active = true on the relevant hint. The NKeyHint component watches active and runs a SequentialAnimation:
onActiveChanged: {
  if (active) {
    activateAnimation.start();
    resetTimer.start();
  }
}
SequentialAnimation {
  id: activateAnimation
  NumberAnimation { target: keyBg; property: "scale"; to: 1.15; duration: Style.animationFaster }
  PropertyAction { target: keyBg; property: "color"; value: Color.mPrimary }
  PropertyAction { target: keyText; property: "color"; value: Color.mOnPrimary }
  PauseAnimation { duration: 100 }
  NumberAnimation { target: keyBg; property: "scale"; to: 1.0; duration: Style.animationNormal; easing.type: Easing.OutBack }
  PropertyAction { target: keyBg; property: "color"; value: Color.mSurfaceVariant }
  PropertyAction { target: keyText; property: "color"; value: Color.mOnSurface }
}
Timer {
  id: resetTimer
  interval: 400
  onTriggered: root.active = false
}

---

File Change Summary
| File | Changes |
|------|---------|
| Widgets/NKeyHint.qml | NEW — Key-cap badge component with activation animation |
| Commons/Settings.qml | Add 6 panel-opening keybind properties to keybinds |
| Modules/MainScreen/MainScreen.qml | Add 6 Instantiator+Shortcut blocks for panel toggling |
| Modules/MainScreen/SmartPanel.qml | No changes needed (keyboard handled per-panel) |
| Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml | Add d/c key handlers + NKeyHint badges on 2 buttons |
| Modules/Panels/Audio/AudioPanel.qml | Add m/n/1/2 key handlers + NKeyHint badges on 2 buttons |
| Modules/Panels/Brightness/BrightnessPanel.qml | Add Up/Down key handlers for slider |
| Modules/Panels/Battery/BatteryPanel.qml | Add p/t key handlers + NKeyHint badges |
Shall I proceed with implementation?
