import SwiftUI
import AppKit

struct AboutView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var refreshTimer: Timer? = nil

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "cursorarrow.and.square.on.square.dashed")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TrackMaster")
                            .font(.title2.bold())
                        Text("Version \(appVersion)")
                            .foregroundStyle(.secondary)
                        Text("Kensington Expert Mouse Wired Trackball")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Device") {
                DeviceStatusRow()
            }

            Section("Permissions") {
                HStack {
                    Label("Accessibility", systemImage: "accessibility")
                    Spacer()
                    if isAccessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout)
                    } else {
                        Button("Open Privacy Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            )
                        }
                        .foregroundStyle(.orange)
                        .font(.callout)
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $prefs.preferences.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .onAppear {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                isAccessibilityGranted = AXIsProcessTrusted()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Device Status Row

struct DeviceStatusRow: View {
    @State private var isConnected = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Label("Kensington Expert Mouse Wired", systemImage: "computermouse")
            Spacer()
            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Label("Not detected", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .onReceive(timer) { _ in
            // Poll device connection state via AppDelegate
            if let delegate = NSApp.delegate as? AppDelegate {
                isConnected = delegate.hidManager.isDeviceConnected
            }
        }
    }
}
