@preconcurrency import CoreGraphics
import AppKit

// EventInterceptor installs a CGEvent tap at kCGHIDEventTap.
// It intercepts all mouse events, applies button mappings and scroll modifier logic,
// and posts synthetic CGEvents for remapped actions.
// Runs on the main run loop — same thread as ChordDetector and other modules.

@MainActor
final class EventInterceptor {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Injected dependencies
    var chordDetector: ChordDetector?
    var appContextMonitor: AppContextMonitor?
    var preferencesManager: PreferencesManager?
    var volumeController: VolumeController?
    var focusController: FocusController?

    // App-switcher state: Cmd is held while user scrolls through candidates
    private var appSwitcherActive = false

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)  |
            (1 << CGEventType.leftMouseUp.rawValue)    |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue)   |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)   |
            (1 << CGEventType.scrollWheel.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    func reinstall() {
        stop()
        start()
    }

    // MARK: - Event handler (called from CGEvent tap callback on main run loop)

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        let bundleID  = appContextMonitor?.currentBundleID ?? ""
        let snapshot  = preferencesManager?.snapshot

        switch type {

        // MARK: Left mouse (Bottom-Left button)
        case .leftMouseDown:
            let decision = chordDetector?.processButtonDown(.bottomLeft) ?? .passThrough
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: .bottomLeft, bundleID: bundleID) ?? .leftClick
            return perform(action: action, event: event, isDown: true)

        case .leftMouseUp:
            let decision = chordDetector?.processButtonUp(.bottomLeft) ?? .passThrough
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: .bottomLeft, bundleID: bundleID) ?? .leftClick
            return perform(action: action, event: event, isDown: false)

        // MARK: Right mouse (Bottom-Right button)
        case .rightMouseDown:
            let decision = chordDetector?.processButtonDown(.bottomRight) ?? .passThrough
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: .bottomRight, bundleID: bundleID) ?? .rightClick
            return perform(action: action, event: event, isDown: true)

        case .rightMouseUp:
            let decision = chordDetector?.processButtonUp(.bottomRight) ?? .passThrough
            // Release app-switcher Cmd if active
            if appSwitcherActive {
                postKeyEvent(keyCode: 0x37, down: false)  // Cmd up
                appSwitcherActive = false
            }
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: .bottomRight, bundleID: bundleID) ?? .rightClick
            return perform(action: action, event: event, isDown: false)

        // MARK: Other mouse buttons (Top-Left, Top-Right)
        case .otherMouseDown:
            let btnNum = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            guard let buttonID = ButtonID.from(cgButtonNumber: btnNum) else { return event }
            let decision = chordDetector?.processButtonDown(buttonID) ?? .passThrough
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: buttonID, bundleID: bundleID) ?? .noAction
            return perform(action: action, event: event, isDown: true)

        case .otherMouseUp:
            let btnNum = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            guard let buttonID = ButtonID.from(cgButtonNumber: btnNum) else { return event }
            let decision = chordDetector?.processButtonUp(buttonID) ?? .passThrough
            if decision == .suppress { return nil }
            let action = snapshot?.effectiveAction(button: buttonID, bundleID: bundleID) ?? .noAction
            return perform(action: action, event: event, isDown: false)

        // MARK: Scroll wheel
        case .scrollWheel:
            return handleScroll(event: event, bundleID: bundleID, snapshot: snapshot)

        default:
            return event
        }
    }

    // MARK: - Chord callback

    func handleChordFired() {
        postQuitToFrontmostApp()
    }

    // MARK: - Scroll handling

    private func handleScroll(event: CGEvent, bundleID: String, snapshot: MappingSnapshot?) -> CGEvent? {
        let rawDelta = Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let increase = rawDelta > 0

        if let modifier = chordDetector?.heldScrollModifier() {
            switch modifier {
            case .bottomLeft:
                volumeController?.scrollTick(increase: increase)
                return nil  // consume scroll

            case .bottomRight:
                handleAppSwitcherScroll(forward: increase)
                return nil

            case .topRight:
                focusController?.scrollTick(forward: increase)
                return nil

            default:
                break
            }
        }

        // Per-app scroll override
        if let override = snapshot?.scrollOverride(for: bundleID) {
            switch override.scrollAction {
            case .zoomInOut:
                postKeyCombo(modifiers: [.maskCommand], keyCode: increase ? 0x18 : 0x1B)  // Cmd+= / Cmd+-
                return nil
            case .horizontal:
                let horiz = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 0, wheel2: Int32(rawDelta), wheel3: 0)
                return horiz
            case .normal:
                break
            }
        }

        return event
    }

    // MARK: - App switcher scroll (Cmd+Tab)

    private func handleAppSwitcherScroll(forward: Bool) {
        if !appSwitcherActive {
            // Open switcher: Cmd+Tab
            postKeyEvent(keyCode: 0x30, down: true,  flags: .maskCommand)  // Tab down
            postKeyEvent(keyCode: 0x30, down: false, flags: .maskCommand)  // Tab up
            appSwitcherActive = true
        } else {
            // Cycle: Tab (forward) or Shift+Tab (backward)
            let flags: CGEventFlags = forward ? .maskCommand : [.maskCommand, .maskShift]
            postKeyEvent(keyCode: 0x30, down: true,  flags: flags)
            postKeyEvent(keyCode: 0x30, down: false, flags: flags)
        }
    }

    // MARK: - Action dispatch

    private func perform(action: ActionConfig, event: CGEvent, isDown: Bool) -> CGEvent? {
        switch action {
        case .leftClick:
            return event  // pass through unchanged

        case .rightClick:
            let t: CGEventType = isDown ? .rightMouseDown : .rightMouseUp
            return CGEvent(mouseEventSource: nil, mouseType: t,
                           mouseCursorPosition: event.location, mouseButton: .right)

        case .middleClick:
            let t: CGEventType = isDown ? .otherMouseDown : .otherMouseUp
            let e = CGEvent(mouseEventSource: nil, mouseType: t,
                            mouseCursorPosition: event.location, mouseButton: .center)
            e?.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            return e

        case .doubleClick:
            guard isDown else { return nil }
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: event.location, mouseButton: .left)
            let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                               mouseCursorPosition: event.location, mouseButton: .left)
            down?.setIntegerValueField(.mouseEventClickState, value: 2)
            up?.setIntegerValueField(.mouseEventClickState, value: 2)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            return nil  // suppress original

        case .browserBack:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [.maskCommand], keyCode: 0x21)  // [
            return nil

        case .browserForward:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [.maskCommand], keyCode: 0x1E)  // ]
            return nil

        case .spotlightSearch:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [.maskCommand], keyCode: 0x31)  // Space
            return nil

        case .missionControl:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [], keyCode: 0xA0)  // Mission Control key
            return nil

        case .appExpose:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [], keyCode: 0xA1)
            return nil

        case .launchpad:
            guard isDown else { return nil }
            postKeyCombo(modifiers: [], keyCode: 0x98)
            return nil

        case .noAction:
            return nil
        }
    }

    // MARK: - Cmd+Q to frontmost app

    private func postQuitToFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != "com.apple.loginwindow" else { return }
        // Verify the app responds to Cmd+Q by attempting to post it
        app.activate()
        postKeyCombo(modifiers: [.maskCommand], keyCode: 0x0C)  // Q
    }

    // MARK: - CGEvent helpers

    private func postKeyCombo(modifiers: CGEventFlags, keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = modifiers
        up?.flags   = modifiers
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func postKeyEvent(keyCode: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: .hidSystemState)
        let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down)
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
    }
}

// MARK: - CGEvent tap C callback

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<EventInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    let result = MainActor.assumeIsolated {
        interceptor.handleEvent(type: type, event: event)
    }
    if let result {
        return Unmanaged.passUnretained(result)
    }
    return nil  // suppress event
}
