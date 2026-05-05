import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private weak var preferencesManager: PreferencesManager?
    private var prefsWindow: NSWindow?

    private var isConnected = false

    init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = icon(connected: false)
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "TrackMaster"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
            .with(target: self))
        menu.addItem(.separator())

        let statusMenuItem = NSMenuItem(title: "Device: Not connected", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit TrackMaster", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        self.statusItem = item
    }

    func updateDeviceStatus(connected: Bool) {
        isConnected = connected
        statusItem?.button?.image = icon(connected: connected)
        statusItem?.button?.image?.isTemplate = true

        if let item = statusItem?.menu?.item(withTag: 100) {
            item.title = connected ? "Device: Connected" : "Device: Not connected"
        }
    }

    // MARK: - Preferences window

    @objc private func openPreferences() {
        // If already open, just bring it forward
        if let w = prefsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        guard let pm = preferencesManager else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TrackMaster"
        window.center()
        window.contentViewController = NSHostingController(
            rootView: PreferencesView().environmentObject(pm)
        )
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        // Temporarily become a regular app so the window comes to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        prefsWindow = window
    }

    // MARK: - Private

    private func icon(connected: Bool) -> NSImage? {
        let name = "cursorarrow.and.square.on.square.dashed"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "TrackMaster")
        if connected {
            return img?.withSymbolConfiguration(.init(scale: .medium))
        } else {
            return img?.withSymbolConfiguration(.init(paletteColors: [.tertiaryLabelColor]))
        }
    }
}

// MARK: - NSWindowDelegate

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === prefsWindow else { return }
        prefsWindow = nil
        // Go back to accessory mode (no Dock icon) when prefs window closes
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NSMenuItem helper

private extension NSMenuItem {
    func with(target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }
}
