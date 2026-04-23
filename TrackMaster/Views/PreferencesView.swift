import SwiftUI

enum PrefTab: String, CaseIterable, Identifiable {
    case buttons    = "Buttons"
    case perApp     = "Per-App Rules"
    case chords     = "Chords"
    case scroll     = "Scroll"
    case focus      = "Focus"
    case about      = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .buttons: return "square.grid.2x2"
        case .perApp:  return "app.badge"
        case .chords:  return "hand.tap"
        case .scroll:  return "scroll"
        case .focus:   return "moon"
        case .about:   return "info.circle"
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var selection: PrefTab = .buttons

    var body: some View {
        NavigationSplitView {
            List(PrefTab.allCases, selection: $selection) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selection {
                case .buttons: ButtonsView()
                case .perApp:  PerAppRulesView()
                case .chords:  ChordsView()
                case .scroll:  ScrollSettingsView()
                case .focus:   FocusView()
                case .about:   AboutView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 680, minHeight: 480)
    }
}
