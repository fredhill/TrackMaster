# TrackMaster — Architecture

Technical reference for contributors and anyone curious about how it works.

---

## How It Works (High Level)

The Kensington Expert Mouse is a standard USB HID device. macOS handles it natively for basic input — left click, right click, scroll. TrackMaster layers on top of this using two system APIs:

1. **IOKit HID Framework** — connects directly to the device by USB Vendor/Product ID, receives raw button and scroll ring events
2. **CGEvent Tap** — installs a global event tap at `kCGHIDEventTap` level, intercepts mouse events before they reach any application, and either passes them through or replaces them with remapped actions

No kernel extensions. No drivers. Everything runs in userspace.

---

## Device Identity

| Property | Value |
|---|---|
| USB Vendor ID | `0x047D` (Kensington) |
| USB Product ID | `0x1020` (Expert Mouse Wired) |
| HID Usage Page | Generic Desktop (0x01) |
| HID Usage | Mouse (0x02) |
| Button count | 4 |
| Axes | X, Y (cursor), Z (scroll ring) |

> **Note on top button HID numbers:** The HID button numbers for the Top-Left and Top-Right buttons are not consistent across all firmware revisions of this device. Use the Debug scheme's HID Event Logger to verify the exact numbers on your specific unit before assuming Button 3/4 or Button 8/9.

---

## Module Reference

### HIDManager
**File:** `Sources/TrackMaster/HIDManager.swift`

Owns the `IOHIDManager` instance. On startup, opens a manager filtered to `VendorID = 0x047D`, `ProductID = 0x1020`. Registers device connect/disconnect callbacks. When the device connects, registers an input value callback that fires on every button press/release and scroll tick.

Routes events:
- Button events → `ChordDetector`
- Scroll events → `EventInterceptor` (with modifier button state from `ChordDetector`)

Handles device hot-plug cleanly — if the device is unplugged mid-session, notifies `MenuBarController` to update the status icon and re-initializes on reconnect.

---

### EventInterceptor
**File:** `Sources/TrackMaster/EventInterceptor.swift`

Installs a `CGEventTap` at `kCGHIDEventTap` with `kCGEventTapOptionDefault` (active tap — can suppress and replace events). Requires Accessibility permission.

For each intercepted mouse event:
1. Checks `ChordDetector` — if a chord is active, suppress the event and fire the chord action instead
2. Checks `AppContextMonitor` for the current frontmost app bundle ID
3. Looks up the active mapping from `PreferencesManager` (global defaults + any per-app override)
4. Posts a synthetic `CGEvent` for the mapped action, or calls the appropriate API (CoreAudio for volume, etc.)

Reinstalls the event tap after system sleep/wake, as `CGEventTap` can silently drop on wake.

---

### ChordDetector
**File:** `Sources/TrackMaster/ChordDetector.swift`

Pure Swift — no system framework dependencies. Maintains a `Set<ButtonID>` of currently held buttons. On each button-down event, checks if the new set matches any configured chord within a 50ms coincidence window.

For the Cmd+Q chord specifically:
- If safety delay is enabled (`PreferencesManager.chordQuitSafetyDelay`), starts a `DispatchWorkItem` timer
- If both buttons are released before the timer fires, cancels the work item
- If the timer fires while both are held, posts the chord action

Emits chord events upward to `EventInterceptor`. When a chord fires, marks both constituent buttons as "consumed" so their individual button-up events don't trigger single-button actions.

---

### AppContextMonitor
**File:** `Sources/TrackMaster/AppContextMonitor.swift`

Observes `NSWorkspace.shared.notificationCenter` for `didActivateApplicationNotification`. Caches the current `bundleIdentifier` of the frontmost app. `EventInterceptor` queries this synchronously on the event tap callback thread — the cache ensures no blocking.

---

### FocusController
**File:** `Sources/TrackMaster/FocusController.swift`

Manages the Focus mode cycle state. At launch, reads the ordered Focus cycle list from `PreferencesManager`. Includes an implicit "No Focus" (off) state at position 0.

Focus switching uses the Shortcuts CLI bridge:
```swift
Process.launchedProcess(launchPath: "/usr/bin/shortcuts",
                        arguments: ["run", "TrackMaster - Set Focus", "--input-path", "-"])
```
The user creates a Shortcut named `TrackMaster - Set Focus` during onboarding. The app passes the target Focus mode name as input.

On each scroll tick while Top-Right is held, advances or retreats the cycle index and calls `HUDWindowController.show(focusName:icon:)`.

---

### VolumeController
**File:** `Sources/TrackMaster/VolumeController.swift`

Gets and sets system output volume via CoreAudio:
- `AudioHardwareGetProperty` with `kAudioHardwarePropertyDefaultSystemOutputDevice` to find the output device
- `AudioDeviceGetProperty` / `AudioDeviceSetProperty` with `kAudioDevicePropertyVolumeScalar` on the master channel

One scroll tick = one volume step (~6.25%, or 1/16 of full range). Clamps at 0.0 and 1.0. Scroll events while Bottom-Left is held are throttled to a minimum 80ms interval to prevent runaway volume changes from fast spinning.

---

### HUDWindowController
**File:** `Sources/TrackMaster/HUDWindowController.swift`

Manages a borderless `NSWindow` positioned at the center of the main screen (or near the menu bar, per preferences). The window hosts a SwiftUI `NSHostingView` with a `HUDView` that shows the Focus mode name and its system SF Symbol icon.

Appearance:
- `NSVisualEffectView` with `.hudWindow` material
- Rounded corners (16pt radius)
- Fade-in animation on show, fade-out on dismiss
- Auto-dismiss timer: resets on each scroll tick, fires 1.5s after the last tick

The window is set to `NSWindow.Level.floating` so it appears above all app content but below system UI.

---

### PreferencesManager
**File:** `Sources/TrackMaster/PreferencesManager.swift`

Single source of truth for all user configuration. Reads/writes a `TrackMasterPreferences` Codable struct to `UserDefaults` under the suite `com.trackmaster.preferences`.

```swift
struct TrackMasterPreferences: Codable {
    var buttonMappings: [ButtonID: ActionConfig]
    var appOverrides: [AppOverrideRule]        // ordered, first match wins
    var chords: [ChordConfig]
    var scrollConfig: ScrollConfig
    var scrollAppOverrides: [ScrollAppOverrideRule]
    var focusCycleOrder: [String]              // Focus mode identifiers
    var focusHUDPosition: HUDPosition          // .center or .nearMenuBar
    var chordQuitSafetyDelay: TimeInterval?    // nil = disabled
    var launchAtLogin: Bool
}
```

Publishes changes via `@Published` so the SwiftUI preferences UI stays in sync.

---

### MenuBarController
**File:** `Sources/TrackMaster/MenuBarController.swift`

Owns the `NSStatusItem`. Icon state:
- Device connected + remapping active → filled SF Symbol
- Device disconnected → outlined SF Symbol with badge

Menu items: Open Preferences, separator, device status, separator, Quit TrackMaster.

---

## Event Flow

```
Physical button press on trackball
  │
  ▼
IOKit HID callback (HIDManager)
  │
  ▼
ChordDetector.buttonDown(id:)
  ├── Chord detected? ──────────────► Suppress both buttons
  │                                   Fire chord action via EventInterceptor
  │                                   (Cmd+Q, or other configured chord)
  │
  └── No chord ──────────────────────► Single button event
                                        │
                                        ▼
                                   EventInterceptor (CGEvent tap)
                                        │
                                        ▼
                                   AppContextMonitor.currentBundleID
                                        │
                                        ▼
                                   PreferencesManager.activeMapping(for:)
                                        │
                                   ┌────┴────┐
                              Override?    Global default
                                   │            │
                                   └────┬────┘
                                        ▼
                                   Post synthetic CGEvent
                                   or call system API
                                   (CoreAudio, Shortcuts CLI, etc.)
```

---

## Permissions Detail

### Accessibility
Required for `CGEventTapCreate` with `kCGEventTapOptionDefault`. Without it, the tap either fails silently or gets created as passive-only (cannot suppress/replace events).

Check: `AXIsProcessTrusted()`  
Request: Open System Settings URL — `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

### Input Monitoring (may be required)
Some macOS versions require Input Monitoring in addition to Accessibility for HID-level event taps.

Check: `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`

### No App Sandbox
`CGEventTap` at `kCGHIDEventTap` and direct `IOHIDManager` access are both incompatible with the App Sandbox entitlement. TrackMaster sets `com.apple.security.app-sandbox = NO`. This means it cannot be submitted to the Mac App Store.

---

## Build Schemes

| Scheme | Purpose |
|---|---|
| `TrackMaster` | Release build — no debug UI |
| `TrackMaster Debug` | Adds a live HID Event Logger window showing raw button numbers, scroll deltas, device connection state, active bundle ID, and current mapping profile. Use this first to verify the HID button numbers for your specific device firmware. |

---

## Adding Support for Other Kensington Models

The main change needed is in `HIDManager.swift` — add the new device's USB Product ID to the device matching dictionary. All other modules operate on the abstract `ButtonID` enum and don't need to know about specific hardware.

Known Kensington USB Product IDs (unverified for newer models — contributions welcome):

| Model | Product ID |
|---|---|
| Expert Mouse Wired (K64325) | `0x1020` |
| Expert Mouse Wireless | `0x1022` |
| Slimblade Pro | TBD |
| Orbit Wireless | TBD |

---

## Sleep / Wake Handling

Both `IOHIDManager` connections and `CGEventTap` instances can silently drop after system sleep. TrackMaster observes `NSWorkspace.didWakeNotification` and re-initializes both on wake.

---

*TrackMaster · MIT License · 2026*
