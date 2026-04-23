# TrackMaster

**A native macOS app for the Kensington Expert Mouse Wired Trackball (K64325)**  
Button remapping, chords, scroll modifiers, per-app rules, and Focus cycling — built in Swift for macOS Tahoe and later.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-in%20development-yellow)

---

## The Story

I've used the Kensington Expert Mouse trackball for years. It's one of those peripheral decisions you make once and never revisit — the large ball, the scroll ring, the ambidextrous layout. It just works, and once it's part of your workflow you stop thinking about it.

What made it even better was the Kensington system preference pane. Nothing fancy — a simple UI that let you assign actions to the four buttons, tweak scroll speed, and set up per-app overrides. It wasn't glamorous software, but it did exactly what it needed to do.

Then macOS Tahoe came out and quietly broke it.

The preference pane still shows up, but the button remapping doesn't work anymore. Apple's tightening of system extension policies finally caught up with the driver Kensington was relying on. Kensington hasn't shipped an update. For basic use — left click, right click, scroll — the trackball still works fine, because macOS handles that natively. But all the customization is gone.

I looked around for alternatives. BetterTouchTool can technically do some of this, but it's a $22 general-purpose tool and configuring a trackball inside it feels like assembling furniture with the wrong manual. I didn't find anything purpose-built for the Expert Mouse on modern macOS.

So I decided to build it myself.

I'm not a professional developer. I work in distance learning, I do a lot of DIY projects, and I'm the kind of person who would rather figure out how something works than wait for someone else to fix it. This project started as a conversation with Claude — mapping out exactly what the app needed to do, how it would talk to the hardware, what the architecture should look like — and then turned into a proper build.

TrackMaster does what the old Kensington pane did, and a few things it never did: button chords, scroll ring modifiers for volume and app switching, and a Focus mode cycler with a HUD overlay. It's a menu bar app, it launches at login, and it's built entirely in Swift with no kernel extensions.

If you have a Kensington Expert Mouse and you're on macOS Tahoe, I hope this saves you the frustration I had. If you want to fork it, improve the UI, add support for other Kensington models, or just poke around the code — go for it. That's why it's here.

---

## Features

- **Full button remapping** — assign any action to all 4 buttons
- **Per-app context overrides** — different mappings for Safari, Lightroom, or any app you choose
- **Button chords** — hold two buttons simultaneously for a new action (Bottom-Left + Bottom-Right = Quit App)
- **Scroll ring modifiers**
  - Bottom-Left + Scroll → System Volume
  - Bottom-Right + Scroll → App Switcher (Cmd+Tab cycling)
  - Top-Right + Scroll → Cycle macOS Focus profiles
- **Focus HUD overlay** — floating indicator when switching Focus modes
- **Per-app scroll behavior** — configure scroll ring per app (e.g. zoom in Lightroom)
- **Native SwiftUI UI** — visual trackball diagram, sidebar navigation, Light/Dark mode
- **Menu bar only** — no Dock icon, launches at login via SMAppService
- **No kernel extensions** — runs entirely in userspace via IOKit HID + CGEvent tap

---

## Requirements

| Requirement | Details |
|---|---|
| macOS | 14.0 (Sonoma) or later. Developed on macOS Tahoe (15.x). |
| Device | Kensington Expert Mouse Wired Trackball — Model M01306, P/N K64325, USB-A |
| Xcode | 16.0 or later |
| Swift | 6.0 |
| Apple Developer Account | Free tier sufficient for personal use |

> **Note:** TrackMaster cannot be distributed via the Mac App Store because it requires Accessibility access and disables App Sandbox — both necessary to intercept HID events at the system level.

---

## Installation

### Download (when releases are available)
1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag TrackMaster to your Applications folder
3. Launch TrackMaster
4. When prompted, grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility**
5. The trackball icon appears in your menu bar — you're set

### Build from Source
```bash
git clone https://github.com/YOUR_USERNAME/TrackMaster.git
cd TrackMaster
open TrackMaster.xcodeproj
```
Select the **TrackMaster** scheme and build (⌘B). For first-time HID button verification, use the **TrackMaster Debug** scheme which includes a live HID event logger window.

> On first run after building locally, macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## Default Button Layout

```
┌─────────────────────────────┐
│  [Spotlight]    [Right Click]│
│                              │
│      ◯  scroll ring  ◯      │
│         ●  ball  ●          │
│                              │
│  [Left Click]  [Double Click]│
└─────────────────────────────┘
```

| Button | Default Action |
|---|---|
| Top-Left | Spotlight Search (⌘Space) |
| Top-Right | Right Click |
| Bottom-Left | Left Click |
| Bottom-Right | Double Click |

### Scroll Ring Modifiers

| Hold + Scroll | Action |
|---|---|
| Bottom-Left + Scroll Ring | Volume Up / Down |
| Bottom-Right + Scroll Ring | Cycle App Switcher |
| Top-Right + Scroll Ring | Cycle Focus Profiles |

### Chords

| Combo | Action |
|---|---|
| Bottom-Left + Bottom-Right | Quit Frontmost App (⌘Q) |

All of the above are configurable in Preferences.

---

## Permissions

TrackMaster requires **Accessibility** access to intercept mouse button events globally. This is the same permission used by apps like BetterTouchTool and Karabiner-Elements. Without it, the app can detect the device but cannot remap any buttons.

You will be prompted on first launch. You can also grant it manually:  
**System Settings → Privacy & Security → Accessibility → TrackMaster → toggle ON**

---

## Architecture Overview

TrackMaster is built around two core system APIs:

- **IOKit HID Framework** — discovers the Kensington device by USB Vendor ID (`0x047D`) and Product ID (`0x1020`), and receives raw button/scroll events
- **CGEvent Tap** — intercepts mouse events at the HID level before they reach applications, enabling true remapping rather than just layering on top

Key modules: `HIDManager`, `EventInterceptor`, `ChordDetector`, `AppContextMonitor`, `FocusController`, `VolumeController`, `HUDWindowController`, `PreferencesManager`, `MenuBarController`.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full technical breakdown.

---

## Contributing

This started as a personal project and I'm not a professional developer, so the bar for "better than what I wrote" is probably not that high. Contributions are very welcome.

A few things that would be especially useful:
- Support for other Kensington models (the wireless Expert Mouse, Orbit, Slimblade)
- UI polish and design improvements
- Testing on different macOS versions
- Bug reports with HID event logs (use the Debug scheme)

Please open an issue before starting large changes so we can talk through the approach first.

---

## Known Limitations

- Wired USB only in v1 — no Bluetooth/wireless support yet
- Not available on Mac App Store (App Sandbox incompatibility)
- Focus mode cycling requires creating a Shortcut in the Shortcuts app during onboarding (Apple doesn't expose a direct Focus API)
- HID button numbers for the top two buttons may vary by firmware revision — the Debug build includes a logger to verify them

---

## License

MIT License — see [`LICENSE`](LICENSE) for full text.

Copyright (c) 2026 TrackMaster Contributors

---

## Acknowledgments

Built with help from [Claude](https://claude.ai) for architecture planning and code generation. Hardware reference: Kensington Expert Mouse Wired Trackball (K64325), USB VendorID `0x047D`, ProductID `0x1020`.
