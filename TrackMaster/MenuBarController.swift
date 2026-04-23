import AppKit
import SwiftUI

@MainActor
final class MenuBarController {

    private var statusItem: NSStatusItem?
    private weak var preferencesManager: PreferencesManager?

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

        let statusItem = NSMenuItem(title: "Device: Not connected", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

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

    // MARK: - Private

    private func icon(connected: Bool) -> NSImage? {
        let name = connected
            ? "cursorarrow.and.square.on.square.dashed"
            : "cursorarrow.and.square.on.square.dashed"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "TrackMaster")
        // Use different rendering weight to visually distinguish connected vs disconnected
        if connected {
            return img?.withSymbolConfiguration(.init(scale: .medium))
        } else {
            return img?.withSymbolConfiguration(.init(paletteColors: [.tertiaryLabelColor]))
        }
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSMenuItem helper

private extension NSMenuItem {
    func with(target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }
}
