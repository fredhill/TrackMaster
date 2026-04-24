import AppKit
import SwiftUI

// HUDWindowController manages the floating Focus mode overlay.
// Appears centered on screen (or near menu bar per prefs), auto-dismisses after 1.5s.

@MainActor
final class HUDWindowController {

    private var window: NSWindow?
    private var dismissTimer: Timer?
    private let dismissDelay: TimeInterval = 1.5

    private weak var preferencesManager: PreferencesManager?

    init(preferencesManager: PreferencesManager? = nil) {
        self.preferencesManager = preferencesManager
    }

    func show(name: String, iconName: String) {
        dismissTimer?.invalidate()

        if window == nil {
            createWindow()
        }

        let hostingView = NSHostingView(rootView: HUDView(focusName: name, iconName: iconName))
        window?.contentView = hostingView
        window?.setFrameOrigin(windowOrigin())

        if window?.isVisible == false {
            window?.alphaValue = 0
            window?.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.window?.animator().alphaValue = 1
            }
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.dismiss() }
        }
    }

    // MARK: - Private

    private func createWindow() {
        let size = NSSize(width: 220, height: 80)
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isMovableByWindowBackground = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        win.hasShadow = false

        // NSVisualEffectView as the visual background
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true
        win.contentView = blur

        self.window = win
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            self.window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in self?.window?.orderOut(nil) }
        })
    }

    private func windowOrigin() -> NSPoint {
        let position = preferencesManager?.preferences.focusHUDPosition ?? .center
        guard let screen = NSScreen.main else { return .zero }
        let size = window?.frame.size ?? NSSize(width: 220, height: 80)

        switch position {
        case .center:
            return NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
        case .nearMenuBar:
            return NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.frame.maxY - screen.frame.height * 0.15 - size.height
            )
        }
    }
}
