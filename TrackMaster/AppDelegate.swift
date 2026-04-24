import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Core modules

    let preferencesManager = PreferencesManager.shared
    let appContextMonitor  = AppContextMonitor()
    let chordDetector      = ChordDetector()
    let volumeController   = VolumeController()

    private(set) lazy var focusController   = FocusController(preferencesManager: preferencesManager)
    private(set) lazy var hudController     = HUDWindowController(preferencesManager: preferencesManager)
    private(set) lazy var menuBarController = MenuBarController(preferencesManager: preferencesManager)
    private(set) var hidManager             = HIDManager()
    private(set) var eventInterceptor       = EventInterceptor()

    // File lock to prevent multiple instances
    private var lockFileDescriptor: Int32 = -1
    private let lockFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("com.trackmaster.app.lock")

    // MARK: - applicationDidFinishLaunching

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireFileLock() else {
            // Another instance is running
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Wire up modules
        focusController.hudController = hudController
        chordDetector.snapshot = preferencesManager.snapshot
        chordDetector.onChordFired = { [weak self] in
            self?.eventInterceptor.handleChordFired()
        }

        // HID hot-plug callbacks
        hidManager.onDeviceConnected    = { [weak self] in self?.menuBarController.updateDeviceStatus(connected: true) }
        hidManager.onDeviceDisconnected = { [weak self] in
            self?.menuBarController.updateDeviceStatus(connected: false)
            self?.eventInterceptor.reinstall()  // safety reinstall on disconnect/reconnect
        }

        // Wire event interceptor
        eventInterceptor.chordDetector      = chordDetector
        eventInterceptor.appContextMonitor  = appContextMonitor
        eventInterceptor.preferencesManager = preferencesManager
        eventInterceptor.volumeController   = volumeController
        eventInterceptor.focusController    = focusController

        // Keep chord detector snapshot in sync with preferences
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Sleep/wake handling
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        // Start services
        appContextMonitor.start()
        menuBarController.setup()
        hidManager.start()

        // Launch at login via SMAppService
        syncLaunchAtLogin()

        // Accessibility check — start event interceptor when permission is granted
        if AXIsProcessTrusted() {
            eventInterceptor.start()
        } else {
            promptAccessibility()
            pollForAccessibility()
        }

        #if ENABLE_HID_LOGGER
        showHIDLogger()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseFileLock()
    }

    // MARK: - Accessibility

    private func promptAccessibility() {
        // Use raw string key to avoid concurrency-unsafe global reference
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func pollForAccessibility() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.eventInterceptor.start()
            } else {
                self.pollForAccessibility()
            }
        }
    }

    // MARK: - Sleep / Wake

    @objc private func systemWillSleep(_ note: Notification) {
        eventInterceptor.stop()
    }

    @objc private func systemDidWake(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.eventInterceptor.reinstall()
        }
    }

    // MARK: - Preferences sync

    @objc private func preferencesDidChange(_ note: Notification) {
        chordDetector.snapshot = preferencesManager.snapshot
        focusController.rebuildCycle()
        syncLaunchAtLogin()
    }

    private func syncLaunchAtLogin() {
        let shouldLaunch = preferencesManager.preferences.launchAtLogin
        do {
            if shouldLaunch {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Registration may fail on unsigned builds; not fatal
        }
    }

    // MARK: - File lock

    private func acquireFileLock() -> Bool {
        // Create lock file if needed
        if !FileManager.default.fileExists(atPath: lockFilePath) {
            FileManager.default.createFile(atPath: lockFilePath, contents: nil)
        }
        let fd = open(lockFilePath, O_RDWR)
        guard fd >= 0 else { return false }
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            lockFileDescriptor = fd
            return true
        }
        close(fd)
        return false
    }

    private func releaseFileLock() {
        if lockFileDescriptor >= 0 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }

    // MARK: - Debug HID Logger

    #if ENABLE_HID_LOGGER
    private var loggerWindow: NSWindow?

    private func showHIDLogger() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "TrackMaster — HID Event Logger"
        win.center()
        win.contentViewController = NSHostingController(
            rootView: HIDEventLoggerView(hidManager: hidManager, appContextMonitor: appContextMonitor)
        )
        win.makeKeyAndOrderFront(nil)
        self.loggerWindow = win
    }
    #endif
}
