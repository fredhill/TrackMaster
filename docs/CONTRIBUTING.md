# Contributing to TrackMaster

First off — thanks for taking the time to look at this. TrackMaster started as a personal project to fix a tool I use every day, and if you're here you probably have a Kensington trackball and the same frustration I did.

I'm not a professional developer. Contributions that improve the code, the UI, the hardware support, or the documentation are all welcome.

---

## Before You Start

Please **open an issue before starting large changes** — not to gate things, but so we can talk through the approach and avoid duplicated effort. For small fixes, bug reports, or documentation improvements, just go ahead.

---

## What's Most Useful Right Now

- **Other Kensington models** — wireless Expert Mouse, Slimblade, Orbit. The USB Product IDs are what's needed. If you have one of these devices, running the Debug scheme and sharing the HID output would be a huge help even if you don't write code.
- **UI polish** — the SwiftUI preferences interface is functional but was designed by someone who thinks in systems, not pixels. If you have design instincts, please use them.
- **Testing on macOS versions** — especially older Sonoma point releases and whatever Tahoe updates ship
- **Bug reports** — especially with HID event logs from the Debug scheme attached

---

## Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/TrackMaster.git
cd TrackMaster
open TrackMaster.xcodeproj
```

Build the **TrackMaster Debug** scheme first. This opens a HID Event Logger window that shows raw button numbers and scroll events from your device — useful for verifying that the device is being detected correctly before anything else.

You'll need to grant **Accessibility** permission to the debug build the first time it runs. macOS treats signed debug builds as separate from release builds for permission purposes.

---

## Code Style

- Swift 6, SwiftUI where possible, AppKit where necessary
- No third-party dependencies — the whole point is that this is a lightweight native tool
- Comments for anything non-obvious, especially around IOKit and CGEvent tap behavior
- Prefer clarity over cleverness — this codebase should be readable by someone who isn't a macOS systems programmer

---

## Submitting a Pull Request

1. Fork the repo
2. Create a branch: `git checkout -b your-feature-name`
3. Make your changes
4. Test on a physical Kensington Expert Mouse if at all possible
5. Open a PR with a description of what you changed and why

For hardware support additions, include the USB Product ID and the device model name you tested with.

---

## Reporting Bugs

Open an issue with:
- macOS version
- TrackMaster version (or commit hash if built from source)
- What happened vs. what you expected
- If it's a button/scroll issue: the HID Event Logger output from the Debug scheme (launch the Debug build and reproduce the issue with the logger window open)

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License that covers this project.
