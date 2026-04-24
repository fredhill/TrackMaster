import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PerAppRulesView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var selection: UUID? = nil
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selection) {
                ForEach(prefs.preferences.appOverrides) { rule in
                    PerAppRuleRow(rule: rule)
                        .tag(rule.id)
                }
                .onMove { from, to in
                    prefs.preferences.appOverrides.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    prefs.preferences.appOverrides.remove(atOffsets: offsets)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            Divider()

            HStack(spacing: 8) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
                Button {
                    if let id = selection,
                       let idx = prefs.preferences.appOverrides.firstIndex(where: { $0.id == id }) {
                        prefs.preferences.appOverrides.remove(at: idx)
                        selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)

                Spacer()

                Text("Rules are evaluated top-to-bottom. First match wins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.bar)
        }
        .sheet(isPresented: $showAddSheet) {
            AddAppOverrideSheet { newRule in
                prefs.preferences.appOverrides.append(newRule)
            }
        }
        .padding(16)
    }
}

// MARK: - Row

struct PerAppRuleRow: View {
    let rule: AppOverrideRule

    var body: some View {
        HStack(spacing: 12) {
            appIcon(for: rule.bundleID)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName).font(.body)
                Text(rule.bundleID).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(rule.buttonID.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(rule.action.displayName)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }

    private func appIcon(for bundleID: String) -> some View {
        let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
        let icon: NSImage = path.flatMap { NSImage(contentsOfFile: $0 + "/Contents/Resources/AppIcon.icns") }
            ?? NSWorkspace.shared.icon(for: UTType.applicationBundle)
        return Image(nsImage: icon).resizable().scaledToFit()
    }
}

// MARK: - Add Sheet

struct AddAppOverrideSheet: View {
    let onAdd: (AppOverrideRule) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var bundleID = ""
    @State private var appName  = ""
    @State private var button: ButtonID  = .bottomRight
    @State private var action: ActionConfig = .browserBack

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add App Override").font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("App Name:")
                    TextField("e.g. Safari", text: $appName).frame(width: 200)
                }
                GridRow {
                    Text("Bundle ID:")
                    TextField("com.apple.Safari", text: $bundleID).frame(width: 200)
                }
                GridRow {
                    Text("Button:")
                    Picker("", selection: $button) {
                        ForEach(ButtonID.allCases, id: \.self) { b in
                            Text(b.displayName).tag(b)
                        }
                    }.labelsHidden().frame(width: 200)
                }
                GridRow {
                    Text("Action:")
                    Picker("", selection: $action) {
                        ForEach(ActionConfig.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a)
                        }
                    }.labelsHidden().frame(width: 200)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let rule = AppOverrideRule(bundleID: bundleID, appName: appName.isEmpty ? bundleID : appName,
                                               buttonID: button, action: action)
                    onAdd(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(bundleID.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
