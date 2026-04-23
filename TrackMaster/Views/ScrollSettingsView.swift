import SwiftUI

struct ScrollSettingsView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var showAddSheet = false
    @State private var selectedID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Default Scroll Behavior") {
                    Picker("Direction", selection: $prefs.preferences.scrollConfig.direction) {
                        Text("Natural (content follows finger)").tag(ScrollConfig.Direction.natural)
                        Text("Reversed (traditional)").tag(ScrollConfig.Direction.reversed)
                    }

                    HStack {
                        Text("Speed multiplier")
                        Slider(value: $prefs.preferences.scrollConfig.speedMultiplier, in: 0.5...3.0, step: 0.25)
                        Text(String(format: "%.2fx", prefs.preferences.scrollConfig.speedMultiplier))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Scroll Modifiers (hold button + scroll ring)") {
                    ScrollModifierRow(button: .bottomLeft, action: "System Volume")
                    ScrollModifierRow(button: .bottomRight, action: "App Switcher (⌘Tab)")
                    ScrollModifierRow(button: .topRight,    action: "Cycle Focus Profiles")
                }
            }
            .formStyle(.grouped)

            Divider()

            // Per-app overrides table
            Text("Per-App Scroll Overrides")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            List(selection: $selectedID) {
                ForEach(prefs.preferences.scrollAppOverrides) { rule in
                    ScrollOverrideRow(rule: rule)
                        .tag(rule.id)
                }
                .onDelete { prefs.preferences.scrollAppOverrides.remove(atOffsets: $0) }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 140)

            HStack(spacing: 8) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                Button {
                    if let id = selectedID,
                       let idx = prefs.preferences.scrollAppOverrides.firstIndex(where: { $0.id == id }) {
                        prefs.preferences.scrollAppOverrides.remove(at: idx)
                        selectedID = nil
                    }
                } label: { Image(systemName: "minus") }
                .disabled(selectedID == nil)
                Spacer()
            }
            .padding(8)
            .background(.bar)
        }
        .sheet(isPresented: $showAddSheet) {
            AddScrollOverrideSheet { prefs.preferences.scrollAppOverrides.append($0) }
        }
        .padding(16)
    }
}

// MARK: - Modifier Row

struct ScrollModifierRow: View {
    let button: ButtonID
    let action: String

    var body: some View {
        HStack {
            Text("Hold \(button.displayName)")
                .foregroundStyle(.secondary)
            Spacer()
            Text(action)
        }
    }
}

// MARK: - Override Row

struct ScrollOverrideRow: View {
    let rule: ScrollAppOverrideRule

    var body: some View {
        HStack {
            Text(rule.appName)
            Spacer()
            Text(rule.scrollAction.displayName)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1fx", rule.speedMultiplier))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - Add Sheet

struct AddScrollOverrideSheet: View {
    let onAdd: (ScrollAppOverrideRule) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var bundleID = ""
    @State private var appName  = ""
    @State private var action: ScrollAction = .zoomInOut
    @State private var speed = 1.0
    @State private var invert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Scroll Override").font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("App Name:")
                    TextField("e.g. Lightroom", text: $appName).frame(width: 200)
                }
                GridRow {
                    Text("Bundle ID:")
                    TextField("com.adobe.lightroom", text: $bundleID).frame(width: 200)
                }
                GridRow {
                    Text("Scroll Action:")
                    Picker("", selection: $action) {
                        ForEach(ScrollAction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 200)
                }
                GridRow {
                    Text("Speed:")
                    HStack {
                        Slider(value: $speed, in: 0.5...3.0, step: 0.25).frame(width: 140)
                        Text(String(format: "%.2fx", speed)).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Direction:")
                    Toggle("Invert scroll direction", isOn: $invert)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    onAdd(ScrollAppOverrideRule(bundleID: bundleID,
                                                appName: appName.isEmpty ? bundleID : appName,
                                                scrollAction: action,
                                                speedMultiplier: speed,
                                                invertDirection: invert))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bundleID.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
