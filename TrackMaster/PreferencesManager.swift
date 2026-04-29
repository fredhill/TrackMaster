import Foundation
import Combine

// MARK: - Button IDs

enum ButtonID: Int, Hashable, Codable, CaseIterable, Sendable {
    case bottomLeft = 1
    case bottomRight = 2
    case topRight = 3   // HID Button 3 — verify via HID logger on first run
    case topLeft = 4    // HID Button 4 — verify via HID logger on first run

    var displayName: String {
        switch self {
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        }
    }

    // CGEvent button number (kCGMouseEventButtonNumber, 0-indexed)
    var cgButtonNumber: Int {
        switch self {
        case .bottomLeft:  return 0
        case .bottomRight: return 1
        case .topRight:    return 2
        case .topLeft:     return 3
        }
    }

    static func from(cgButtonNumber: Int) -> ButtonID? {
        allCases.first { $0.cgButtonNumber == cgButtonNumber }
    }
}

// MARK: - Action Config

enum ActionConfig: String, Codable, Hashable, CaseIterable, Sendable {
    case leftClick
    case rightClick
    case middleClick
    case doubleClick
    case browserBack
    case browserForward
    case spotlightSearch
    case missionControl
    case appExpose
    case launchpad
    case noAction

    var displayName: String {
        switch self {
        case .leftClick:       return "Left Click"
        case .rightClick:      return "Right Click"
        case .middleClick:     return "Middle Click"
        case .doubleClick:     return "Double Click"
        case .browserBack:     return "Browser Back (⌘[)"
        case .browserForward:  return "Browser Forward (⌘])"
        case .spotlightSearch: return "Spotlight Search (⌘Space)"
        case .missionControl:  return "Mission Control"
        case .appExpose:       return "App Exposé"
        case .launchpad:       return "Launchpad"
        case .noAction:        return "No Action"
        }
    }
}

// MARK: - App Override Rule

struct AppOverrideRule: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var bundleID: String
    var appName: String
    var buttonID: ButtonID
    var action: ActionConfig
}

// MARK: - Chord Config

struct ChordConfig: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var buttons: [ButtonID]
    var enabled: Bool = false
}

// MARK: - Scroll Config

struct ScrollConfig: Codable, Sendable {
    enum Direction: String, Codable, Sendable { case natural, reversed }
    var direction: Direction = .natural
    var speedMultiplier: Double = 1.0
}

// MARK: - Scroll Action

enum ScrollAction: String, Codable, Hashable, CaseIterable, Sendable {
    case normal
    case zoomInOut
    case horizontal

    var displayName: String {
        switch self {
        case .normal:    return "Normal Scroll"
        case .zoomInOut: return "Zoom In/Out (⌘+/−)"
        case .horizontal: return "Horizontal Scroll"
        }
    }
}

// MARK: - Scroll App Override Rule

struct ScrollAppOverrideRule: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var bundleID: String
    var appName: String
    var scrollAction: ScrollAction = .normal
    var speedMultiplier: Double = 1.0
    var invertDirection: Bool = false
}

// MARK: - HUD Position

enum HUDPosition: String, Codable, CaseIterable, Sendable {
    case center
    case nearMenuBar

    var displayName: String {
        switch self {
        case .center:      return "Center of Screen"
        case .nearMenuBar: return "Near Menu Bar"
        }
    }
}

// MARK: - Top-level Preferences

struct TrackMasterPreferences: Codable, Sendable {
    var buttonMappings: [ButtonID: ActionConfig] = [
        .bottomLeft:  .leftClick,
        .bottomRight: .doubleClick,
        .topLeft:     .spotlightSearch,
        .topRight:    .rightClick,
    ]
    var appOverrides: [AppOverrideRule] = Self.defaultAppOverrides
    var chords: [ChordConfig] = [ChordConfig(buttons: [.bottomLeft, .bottomRight], enabled: true)]
    var scrollConfig: ScrollConfig = ScrollConfig()
    var scrollAppOverrides: [ScrollAppOverrideRule] = Self.defaultScrollOverrides
    var focusCycleOrder: [String] = []
    var focusHUDPosition: HUDPosition = .center
    var chordQuitSafetyDelay: TimeInterval? = nil
    var launchAtLogin: Bool = true

    private static var defaultAppOverrides: [AppOverrideRule] {
        [
            ("com.apple.Safari",             "Safari"),
            ("com.google.Chrome",            "Chrome"),
            ("org.mozilla.firefox",          "Firefox"),
            ("company.thebrowser.Browser",   "Arc"),
        ].map { AppOverrideRule(bundleID: $0.0, appName: $0.1, buttonID: .bottomRight, action: .browserBack) }
    }

    private static var defaultScrollOverrides: [ScrollAppOverrideRule] {
        [
            ScrollAppOverrideRule(bundleID: "com.adobe.LightroomClassicCC7", appName: "Lightroom Classic", scrollAction: .zoomInOut),
            ScrollAppOverrideRule(bundleID: "com.adobe.lightroom",           appName: "Adobe Lightroom",   scrollAction: .zoomInOut),
        ]
    }
}

// MARK: - Thread-safe config snapshot (for use on event-tap thread)

struct MappingSnapshot: Sendable {
    let buttonMappings: [ButtonID: ActionConfig]
    let appOverrides: [AppOverrideRule]
    let scrollOverrides: [ScrollAppOverrideRule]
    let chords: [ChordConfig]
    let chordQuitSafetyDelay: TimeInterval?

    func effectiveAction(button: ButtonID, bundleID: String) -> ActionConfig {
        if let override = appOverrides.first(where: { $0.bundleID == bundleID && $0.buttonID == button }) {
            return override.action
        }
        return buttonMappings[button] ?? .leftClick
    }

    func scrollOverride(for bundleID: String) -> ScrollAppOverrideRule? {
        scrollOverrides.first { $0.bundleID == bundleID }
    }

    var quitChord: ChordConfig? {
        chords.first { $0.buttons.sorted(by: { $0.rawValue < $1.rawValue }) == [.bottomLeft, .bottomRight].sorted(by: { $0.rawValue < $1.rawValue }) }
    }
}

// MARK: - PreferencesManager

@MainActor
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published var preferences: TrackMasterPreferences {
        didSet {
            save()
            rebuildSnapshot()
        }
    }

    private(set) var snapshot = MappingSnapshot(
        buttonMappings: [:], appOverrides: [], scrollOverrides: [], chords: [], chordQuitSafetyDelay: nil
    )

    private let defaults: UserDefaults
    private let storageKey = "preferences"

    private init() {
        let suite = UserDefaults(suiteName: "com.trackmaster.preferences") ?? .standard
        self.defaults = suite
        if let data = suite.data(forKey: "preferences"),
           let saved = try? JSONDecoder().decode(TrackMasterPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = TrackMasterPreferences()
        }
        rebuildSnapshot()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func rebuildSnapshot() {
        snapshot = MappingSnapshot(
            buttonMappings: preferences.buttonMappings,
            appOverrides: preferences.appOverrides,
            scrollOverrides: preferences.scrollAppOverrides,
            chords: preferences.chords,
            chordQuitSafetyDelay: preferences.chordQuitSafetyDelay
        )
    }
}
