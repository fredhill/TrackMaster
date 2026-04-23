import SwiftUI

@main
struct TrackMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(PreferencesManager.shared)
        }
    }
}
