import SwiftUI

@main
struct TrackMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The Settings scene keeps SwiftUI happy; the actual preferences window
        // is opened manually by MenuBarController (NSWindow + NSHostingController)
        // so it works reliably in accessory / menu-bar-only mode.
        Settings {
            PreferencesView()
                .environmentObject(PreferencesManager.shared)
        }
    }
}
