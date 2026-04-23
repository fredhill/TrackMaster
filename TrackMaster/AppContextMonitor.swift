import AppKit

@MainActor
final class AppContextMonitor {

    private(set) var currentBundleID: String = ""
    private(set) var currentAppName: String = ""

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Capture the currently active app at startup
        if let app = NSWorkspace.shared.frontmostApplication {
            currentBundleID = app.bundleIdentifier ?? ""
            currentAppName  = app.localizedName ?? ""
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        currentBundleID = app.bundleIdentifier ?? ""
        currentAppName  = app.localizedName ?? ""
    }
}
