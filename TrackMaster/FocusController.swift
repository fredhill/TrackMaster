import Foundation
import AppKit

// FocusController manages the Focus mode cycle driven by Top-Right + scroll ring.
// Focus switching uses the Shortcuts CLI bridge because Apple has no public Focus API.
// The user must create a Shortcut named "TrackMaster - Set Focus" during onboarding
// that accepts the Focus mode name as its input and activates it.

@MainActor
final class FocusController {

    weak var hudController: HUDWindowController?
    private weak var preferencesManager: PreferencesManager?

    private var currentIndex: Int = 0
    private var lastTickDate: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.08

    // Cycle entries: "Off" is always first, then user-configured modes
    private var cycleEntries: [FocusEntry] = [FocusEntry(name: "Focus Off", iconName: "moon.zzz")]

    init(preferencesManager: PreferencesManager) {
        self.preferencesManager = preferencesManager
        rebuildCycle()
    }

    func rebuildCycle() {
        guard let prefs = preferencesManager else { return }
        var entries: [FocusEntry] = [FocusEntry(name: "Focus Off", iconName: "moon.zzz")]
        for name in prefs.preferences.focusCycleOrder {
            entries.append(FocusEntry(name: name, iconName: iconName(for: name)))
        }
        cycleEntries = entries
    }

    func scrollTick(forward: Bool) {
        let now = Date()
        guard now.timeIntervalSince(lastTickDate) >= throttleInterval else { return }
        lastTickDate = now

        guard !cycleEntries.isEmpty else { return }

        let delta = forward ? 1 : -1
        currentIndex = ((currentIndex + delta) % cycleEntries.count + cycleEntries.count) % cycleEntries.count

        let entry = cycleEntries[currentIndex]
        activateFocus(entry: entry)
        hudController?.show(name: entry.name, iconName: entry.iconName)
    }

    // MARK: - Shortcuts CLI bridge

    private func activateFocus(entry: FocusEntry) {
        if entry.name == "Focus Off" {
            runShortcut(name: "TrackMaster - Set Focus", input: "off")
        } else {
            runShortcut(name: "TrackMaster - Set Focus", input: entry.name)
        }
    }

    private func runShortcut(name: String, input: String) {
        let process = Process()
        process.launchPath = "/usr/bin/shortcuts"
        process.arguments  = ["run", name, "--input-path", "-"]

        let pipe = Pipe()
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        do {
            try process.run()
            if let data = input.data(using: .utf8) {
                pipe.fileHandleForWriting.write(data)
            }
            pipe.fileHandleForWriting.closeFile()
        } catch {
            // Shortcut not set up yet — silently ignore
        }
    }

    // MARK: - Icon mapping

    private func iconName(for focusName: String) -> String {
        let lower = focusName.lowercased()
        if lower.contains("work")     { return "briefcase" }
        if lower.contains("sleep")    { return "bed.double" }
        if lower.contains("personal") { return "person" }
        if lower.contains("fitness")  { return "figure.run" }
        if lower.contains("gaming")   { return "gamecontroller" }
        return "moon"
    }
}

// MARK: - Focus Entry

struct FocusEntry: Sendable {
    let name: String
    let iconName: String
}
