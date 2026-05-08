# Plan: automatic idle, lockscreen, and monitor power-off for QuickNix

## Goal

Add the behavior that QuickNix currently lacks:

1. lock the session with a real Wayland session lock,
2. turn monitors off automatically after an idle timeout,
3. optionally suspend after a later idle timeout,
4. cancel pending actions when the user moves the mouse or presses a key,
5. keep the implementation aligned with QuickNix's existing settings and compositor abstraction.

This plan is based on how `examples/DankMaterialShell` implements the same behavior, with notes for adapting it to QuickNix rather than copying the whole DMS stack.

## What DankMaterialShell does

Relevant files:

- `examples/DankMaterialShell/quickshell/Services/IdleService.qml`
- `examples/DankMaterialShell/quickshell/Modules/Lock/Lock.qml`
- `examples/DankMaterialShell/quickshell/Modules/Lock/FadeToLockWindow.qml`
- `examples/DankMaterialShell/quickshell/Modules/Lock/FadeToDpmsWindow.qml`
- `examples/DankMaterialShell/quickshell/DMSShell.qml`
- `examples/DankMaterialShell/quickshell/Services/CompositorService.qml`
- `examples/DankMaterialShell/quickshell/Services/SessionService.qml`

DMS splits the feature into a few clear layers:

### 1. Idle detection service

`IdleService.qml` is a singleton that creates `Quickshell.Wayland.IdleMonitor` instances dynamically with `Qt.createQmlObject()`.

It creates separate monitors for:

- monitor-off timeout,
- lock timeout,
- suspend timeout.

Important DMS details:

- It checks whether `IdleMonitor` is available before enabling power management.
- It uses `respectInhibitors: true` so external idle inhibitors can block idle behavior.
- It has an `_enableGate` rearm trick: when timeouts change, monitors are briefly disabled and re-enabled.
- It tracks whether monitors are currently off with `monitorsOff`.
- It emits signals instead of directly owning all UI:
  - `lockRequested`
  - `fadeToLockRequested`
  - `cancelFadeToLock`
  - `fadeToDpmsRequested`
  - `cancelFadeToDpms`
  - `requestMonitorOff`
  - `requestMonitorOn`
  - `requestSuspend`

### 2. Fade overlays before actions

DMS creates one fade window per screen in `DMSShell.qml`.

- `FadeToLockWindow.qml` fades to black, then emits `fadeCompleted`; DMS calls `IdleService.lockRequested()`.
- `FadeToDpmsWindow.qml` fades to black, then calls `IdleService.requestMonitorOff()`.
- Both are `PanelWindow`s on `WlrLayershell.Overlay` with exclusive keyboard focus while active.
- Mouse or keyboard input cancels the fade.

This gives users a short grace period before the lock or DPMS action fires.

### 3. Real lockscreen

DMS uses `WlSessionLock`, not just a fullscreen panel.

`Lock.qml` owns the lock lifecycle:

- `shouldLock` drives `WlSessionLock.locked`.
- A `WlSessionLockSurface` is created per output.
- `LockSurface` provides the actual UI and PAM authentication.
- Successful auth calls `unlock()` and clears `shouldLock`.
- The lock can be triggered by idle, IPC, startup, or loginctl events.

It also has safety details:

- `lockPowerOffArmed` can power monitors off immediately after lock if configured.
- `dpmsReapplyTimer` reapplies monitor-off after the lock starts, avoiding compositor races.
- `lockWakeDebounce` prevents immediate wake loops after monitors are powered off.
- It bridges with `loginctl` through DMS's Go daemon when enabled.

### 4. Compositor monitor power control

DMS exposes `CompositorService.powerOffMonitors()` / `powerOnMonitors()`.

Backend behavior:

- Niri: `NiriService.powerOffMonitors()` / `powerOnMonitors()`.
- Hyprland: `Hyprland.dispatch("dpms off")` / `dpms on`.
- Sway/Scroll/Miracle: `I3.dispatch("output * dpms off")` / `on`.
- DWL: `mmsg disable_monitor,<output>` / `enable_monitor,<output>`.
- Labwc: calls DMS's helper CLI: `dms dpms off/on`, implemented via `wlr-output-power-management`.

### 5. Suspend and loginctl integration

DMS has a `SessionService.qml` that handles suspend, hibernate, idle inhibitors, and loginctl state.

For QuickNix, the important behavior is:

- idle suspend should call a central suspend function,
- if `lockBeforeSuspend` / `lockOnSuspend` is enabled, lock first, then suspend,
- deeper loginctl integration can be added later, but is not needed for the first working version.

## Current QuickNix state

QuickNix already has several partial pieces:

- `Commons/Settings.qml` and `Assets/settings-default.json` already define `Settings.data.idle`:
  - `enabled`
  - `screenOffTimeout`
  - `lockTimeout`
  - `suspendTimeout`
  - `fadeDuration`
  - custom action and resume commands
- `Services/Compositor/CompositorService.qml` already has:
  - `turnOffMonitors()`
  - `turnOnMonitors()`
  - `lock()`
  - `suspend()`
  - `lockAndSuspend()`
- compositor backends already implement monitor power functions for Hyprland, Niri, Sway, Mango, Labwc, and generic ext-workspace fallback.
- `Services/UI/PanelService.qml` already has a `lockScreen` property.
- `Services/Power/IdleInhibitorService.qml` only implements a manual caffeine toggle using `systemd-inhibit`; it does not perform automatic idle actions.

Missing pieces:

- no `IdleService.qml` in QuickNix,
- no `Modules/LockScreen` in QuickNix,
- `PanelService.lockScreen` is never registered,
- `CompositorService.lock()` tries to activate `PanelService.lockScreen`, but there is no lockscreen object,
- `shell.qml` does not initialize automatic idle management.

## Implementation plan

### Phase 1: add a real QuickNix lockscreen

Create a new module directory:

```text
Modules/LockScreen/
  LockScreen.qml
  LockContext.qml
  LockScreenBackground.qml   # optional, can be folded into LockScreen.qml initially
```

Recommended MVP behavior:

1. `LockScreen.qml` should be a `Loader { active: false }`.
2. On completed, register itself:

   ```qml
   PanelService.lockScreen = root
   ```

3. The loaded item should contain:

   ```qml
   WlSessionLock {
     locked: root.active

     WlSessionLockSurface {
       // lock UI for each screen
     }
   }
   ```

4. Use `Quickshell.Services.Pam.PamContext` in `LockContext.qml` to authenticate.
5. Use `/etc/pam.d/login` by default, with an override env var such as `QUICKNIX_PAM_SERVICE`.
6. Determine the user from `Quickshell.env("USER")` or `Quickshell.env("LOGNAME")`.
7. On successful PAM auth:
   - set `lockSession.locked = false`,
   - clear password state,
   - set `root.active = false` after a short delay.
8. On failed auth:
   - clear password input,
   - show an error.
9. Respect existing QuickNix settings where possible:
   - `Settings.data.general.lockScreenMonitors`
   - `Settings.data.general.compactLockScreen`
   - `Settings.data.general.lockScreenBlur`
   - `Settings.data.general.lockScreenTint`
   - `Settings.data.general.showSessionButtonsOnLockScreen`
   - `Settings.data.general.lockOnSuspend`
10. Run hooks when lock state changes:
   - `Settings.data.hooks.screenLock`
   - `Settings.data.hooks.screenUnlock`

Keep the first UI simple. The critical security feature is `WlSessionLock`; visual polish can follow later.

### Phase 2: instantiate the lockscreen from `shell.qml`

Add the lockscreen to the loaded shell content after settings/state are ready:

```qml
import qs.Modules.LockScreen
```

Inside the main loaded `Item` in `shell.qml`, instantiate:

```qml
LockScreen {}
```

This makes the existing `CompositorService.lock()` and `CompositorService.lockAndSuspend()` paths meaningful, because `PanelService.lockScreen` will finally point at a real lockscreen.

### Phase 3: add `Services/Power/IdleService.qml`

Create:

```text
Services/Power/IdleService.qml
```

Base it on the DMS structure, but map settings to QuickNix's existing schema.

Core properties:

```qml
readonly property bool idleMonitorAvailable: typeof IdleMonitor !== "undefined"
property bool enabled: Settings.data.idle.enabled
property int screenOffTimeout: Settings.data.idle.screenOffTimeout
property int lockTimeout: Settings.data.idle.lockTimeout
property int suspendTimeout: Settings.data.idle.suspendTimeout
property bool monitorsOff: false
property bool isShellLocked: PanelService.lockScreen?.active || false
```

Signals to expose:

```qml
signal lockRequested
signal fadeToLockRequested
signal cancelFadeToLock
signal fadeToDpmsRequested
signal cancelFadeToDpms
signal requestMonitorOff
signal requestMonitorOn
signal requestSuspend
```

Behavior:

1. Dynamically create `IdleMonitor` objects with `Qt.createQmlObject()` so QuickNix does not fail to parse on systems without idle protocol support.
2. Use one monitor per stage:
   - `screenOffMonitor`
   - `lockMonitor`
   - `suspendMonitor`
3. Bind monitor enabled state to:
   - idle settings enabled,
   - timeout > 0,
   - idle monitor availability,
   - no QuickNix caffeine/inhibitor state.
4. Prefer `respectInhibitors: true` when supported, matching DMS.
5. When screen-off monitor becomes idle:
   - request fade-to-DPMS first,
   - after fade completes, call `CompositorService.turnOffMonitors()`.
6. When screen-off monitor becomes non-idle:
   - cancel fade,
   - call `CompositorService.turnOnMonitors()` if monitors were off.
7. When lock monitor becomes idle:
   - request fade-to-lock first,
   - after fade completes, activate `PanelService.lockScreen.active = true`.
8. When suspend monitor becomes idle:
   - if `Settings.data.general.lockOnSuspend`, call `CompositorService.lockAndSuspend()`;
   - otherwise call `CompositorService.suspend()`.
9. On settings changes, rearm/recreate monitors. DMS's `_enableGate` pattern is a good approach.
10. Implement `Settings.data.idle.customCommands` after the core stages work.

### Phase 4: add fade-to-black windows

Create:

```text
Modules/LockScreen/FadeToLockWindow.qml
Modules/LockScreen/FadeToDpmsWindow.qml
```

or a generic:

```text
Modules/LockScreen/FadeToActionWindow.qml
```

Use the DMS pattern:

- `PanelWindow`
- transparent window with black `Rectangle` overlay
- `WlrLayershell.layer: WlrLayershell.Overlay`
- `WlrLayershell.exclusiveZone: -1`
- exclusive keyboard focus while active
- opacity animation from `0` to `1`
- duration from `Settings.data.idle.fadeDuration * 1000`
- mouse/key input cancels

Instantiate one fade window per screen in `shell.qml`, like DMS does in `DMSShell.qml`:

```qml
Variants {
  model: Quickshell.screens
  delegate: Loader {
    active: Settings.data.idle.enabled
    sourceComponent: FadeToLockWindow { screen: modelData }
  }
}
```

Connect to `IdleService` signals:

- `onFadeToLockRequested` → `startFade()`
- `onCancelFadeToLock` → `cancelFade()`
- `onFadeCompleted` → `IdleService.lockRequested()` or direct lock call

Repeat for DPMS.

### Phase 5: wire idle service into `shell.qml`

In the main loaded item in `shell.qml`, after existing service init:

```qml
Qt.callLater(function () {
  PowerProfileService.init();
  NotificationRulesService.init();
  IdleService.init();
});
```

Add/import `IdleService` via the existing `import qs.Services.Power`.

Also add `Connections` or direct service signal handlers either in `IdleService.qml` or in `shell.qml`:

- `requestMonitorOff` → `CompositorService.turnOffMonitors()`
- `requestMonitorOn` → `CompositorService.turnOnMonitors()`
- `lockRequested` → `CompositorService.lock()` or direct `PanelService.lockScreen.active = true`
- `requestSuspend` → suspend/lock-and-suspend logic

Prefer keeping action execution inside `IdleService.qml` so `shell.qml` only instantiates UI windows.

### Phase 6: harden monitor power control

Audit current backend implementations before relying on them for automatic idle DPMS:

- Hyprland: current `hyprctl dispatch dpms off/on` is fine.
- Niri: current `Niri.dispatch(["power-off-monitors"])` / `power-on-monitors` is fine.
- Sway/Scroll: current `swaymsg output * dpms off/on` is fine.
- Mango: current per-output `mmsg disable_monitor` / `enable_monitor` matches the existing backend pattern.
- Labwc and generic ext-workspace currently call `wlr-randr --off` / `--on`; verify this is actually safe. This may disable outputs rather than use DPMS.

Recommended improvement:

- add `wlopm` to `nix/package.nix` runtime deps,
- use `wlopm --off '*'` and `wlopm --on '*'` for generic wlroots DPMS fallback,
- keep compositor-native commands for Hyprland, Niri, and Sway.

Avoid using display configuration tools for power management unless there is no DPMS alternative.

### Phase 7: make idle inhibition work

QuickNix already has `IdleInhibitorService.isInhibited`.

Add one of these approaches:

1. MVP: bind `IdleMonitor.enabled` to `!IdleInhibitorService.isInhibited`.
2. Better: use native `IdleInhibitor` if available, and fall back to the existing `systemd-inhibit` process.
3. Keep `respectInhibitors: true` on `IdleMonitor` to honor external applications where supported.

The result should be:

- caffeine enabled → no screen-off, lock, or suspend,
- caffeine disabled → idle timers resume.

### Phase 8: optional loginctl/session integration

Do this only after the local lockscreen and idle timers work.

Possible additions:

- Add a small `SessionService.qml` for loginctl state.
- Listen for `loginctl lock-session` events and activate `PanelService.lockScreen`.
- Notify unlock state back to logind if feasible.
- Implement lock-before-suspend with a delay inhibitor, similar to DMS's Go daemon.

This is not required for the MVP because QuickNix already controls its own session menu suspend path through `CompositorService.lockAndSuspend()`.

### Phase 9: settings and defaults

The settings schema already has an `idle` block. Keep the existing default:

```json
"idle": {
  "enabled": false,
  "screenOffTimeout": 600,
  "lockTimeout": 660,
  "suspendTimeout": 1800,
  "fadeDuration": 5
}
```

This means the new behavior is opt-in by default.

Later, add settings UI/search entries for:

- enable idle management,
- screen-off timeout,
- lock timeout,
- suspend timeout,
- fade duration,
- custom commands,
- lock-on-suspend,
- lock screen monitor selection.

## Testing plan

### Basic startup

1. Start QuickNix with the feature present and `idle.enabled = false`.
2. Confirm no idle monitors activate.
3. Confirm no parse errors on compositors without `ext-idle-notify-v1`.

### Manual lock

1. Trigger `CompositorService.lock()` through the session menu or a temporary keybind.
2. Confirm `WlSessionLock` appears on all configured monitors.
3. Enter a wrong password; confirm it stays locked.
4. Enter the right password; confirm it unlocks and unloads.

### Idle screen-off

Use short test values:

```json
"idle": {
  "enabled": true,
  "screenOffTimeout": 5,
  "lockTimeout": 0,
  "suspendTimeout": 0,
  "fadeDuration": 2
}
```

Expected:

1. after 5 seconds idle, fade starts,
2. moving mouse during fade cancels,
3. if not cancelled, monitors power off,
4. moving mouse/pressing key powers monitors back on.

### Idle lock

```json
"lockTimeout": 5
```

Expected:

1. fade starts,
2. input cancels fade,
3. if not cancelled, lockscreen activates,
4. unlock works through PAM.

### Idle suspend

```json
"suspendTimeout": 10
```

Test both:

- `general.lockOnSuspend = true`
- `general.lockOnSuspend = false`

Expected:

- with lock-on-suspend, the lockscreen is activated before suspend,
- without it, system suspends directly.

### Inhibitor

1. Enable QuickNix caffeine / idle inhibitor.
2. Wait longer than all idle timeouts.
3. Confirm no fade, lock, screen-off, or suspend happens.
4. Disable inhibitor and confirm timers work again.

### Compositor matrix

Test at least:

- Hyprland: DPMS off/on and lock/unlock.
- Niri: power-off-monitors/power-on-monitors.
- Sway/Scroll: `output * dpms off/on`.
- Generic wlroots/Labwc: `wlopm` fallback.

## Risks and constraints

- A lockscreen must use `WlSessionLock`; a normal fullscreen `PanelWindow` is not secure.
- PAM config differs by distro. Provide an env override and safe defaults.
- Some compositors do not support `ext-idle-notify-v1`; the service must degrade gracefully.
- Some monitor-off commands disable outputs rather than use DPMS; prefer compositor-native DPMS or `wlopm`.
- Hot reload while locked is dangerous. Consider disabling hot reload or guarding reload while `PanelService.lockScreen.active` is true.
- Multi-monitor locking needs a surface per output. Do not only lock the primary monitor.

## Recommended MVP checklist

1. Add `Modules/LockScreen/LockContext.qml` with PAM auth.
2. Add `Modules/LockScreen/LockScreen.qml` with `WlSessionLock` and register it in `PanelService`.
3. Instantiate `LockScreen {}` in `shell.qml`.
4. Add `Services/Power/IdleService.qml` with three dynamic `IdleMonitor`s.
5. Add fade window(s) and instantiate them per screen.
6. Wire idle actions to `CompositorService.turnOffMonitors()`, `CompositorService.lock()`, and `CompositorService.lockAndSuspend()` / `suspend()`.
7. Add `wlopm` or otherwise harden generic DPMS fallback.
8. Test with short timeouts on Hyprland/Niri/Sway before enabling defaults.
