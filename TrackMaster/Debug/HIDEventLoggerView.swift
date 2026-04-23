#if ENABLE_HID_LOGGER
import SwiftUI

struct HIDEventLoggerView: View {
    @ObservedObject var hidManager: HIDManager
    let appContextMonitor: AppContextMonitor

    @State private var isPaused = false
    @State private var filterText = ""

    var filteredEntries: [HIDLogEntry] {
        let entries = hidManager.logEntries
        if filterText.isEmpty { return entries }
        return entries.filter { $0.description.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 16) {
                StatusBadge(
                    label: "Device",
                    value: hidManager.isDeviceConnected ? "Connected" : "Not connected",
                    color: hidManager.isDeviceConnected ? .green : .red
                )
                StatusBadge(
                    label: "Accessibility",
                    value: AXIsProcessTrusted() ? "Granted" : "Not granted",
                    color: AXIsProcessTrusted() ? .green : .orange
                )
                StatusBadge(
                    label: "Active App",
                    value: appContextMonitor.currentBundleID.isEmpty ? "—" : appContextMonitor.currentBundleID,
                    color: .blue
                )
                Spacer()
            }
            .padding(10)
            .background(.bar)

            Divider()

            // Event log
            ScrollViewReader { proxy in
                List(filteredEntries) { entry in
                    Text(entry.description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(colorFor(entry: entry))
                        .id(entry.id)
                }
                .listStyle(.plain)
                .onChange(of: hidManager.logEntries.count) { _, _ in
                    if !isPaused, let last = filteredEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Toolbar
            HStack(spacing: 12) {
                TextField("Filter…", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Toggle(isOn: $isPaused) {
                    Label(isPaused ? "Paused" : "Live", systemImage: isPaused ? "pause.circle" : "circle.fill")
                }
                .toggleStyle(.button)

                Button("Clear") { hidManager.logEntries.removeAll() }

                Spacer()

                Text("\(filteredEntries.count) events")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(10)
            .background(.bar)
        }
        .frame(minWidth: 560, minHeight: 360)
    }

    private func colorFor(entry: HIDLogEntry) -> Color {
        if entry.usagePage == UInt32(kHIDPage_Button) { return .primary }
        return .secondary
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}
#endif
