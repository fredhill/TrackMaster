import SwiftUI

struct FocusView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var newModeName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section {
                    Text("TrackMaster cycles through Focus modes when you hold **Top-Right** and scroll the ring. \"Focus Off\" is always the first entry in the cycle.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Section("Shortcut Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TrackMaster uses the Shortcuts app to change Focus modes. Create a Shortcut named exactly:")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("TrackMaster - Set Focus")
                            .font(.system(.body, design: .monospaced))
                            .padding(6)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                        Text("The shortcut should accept text input (the Focus mode name) and activate that Focus mode. Use \"off\" as the input to disable Focus.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Open Shortcuts App") {
                            NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("HUD Position") {
                    Picker("Show overlay", selection: $prefs.preferences.focusHUDPosition) {
                        ForEach(HUDPosition.allCases, id: \.self) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Focus cycle order editor
            Text("Focus Cycle Order")
                .font(.headline)
                .padding(.horizontal, 16)

            Text("Add the names of your Focus modes below. \"Focus Off\" is always first.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            List {
                // Fixed first entry
                HStack {
                    Image(systemName: "moon.zzz").foregroundStyle(.secondary)
                    Text("Focus Off").foregroundStyle(.secondary)
                    Spacer()
                    Text("Fixed").font(.caption).foregroundStyle(.tertiary)
                }

                ForEach(prefs.preferences.focusCycleOrder, id: \.self) { name in
                    HStack {
                        Image(systemName: "moon").foregroundStyle(Color.accentColor)
                        Text(name)
                        Spacer()
                    }
                }
                .onMove { prefs.preferences.focusCycleOrder.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { prefs.preferences.focusCycleOrder.remove(atOffsets: $0) }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: 160)

            HStack(spacing: 8) {
                TextField("Focus mode name (e.g. Work)", text: $newModeName)
                    .frame(width: 240)
                    .onSubmit { addMode() }
                Button("Add", action: addMode)
                    .disabled(newModeName.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func addMode() {
        let name = newModeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !prefs.preferences.focusCycleOrder.contains(name) else { return }
        prefs.preferences.focusCycleOrder.append(name)
        newModeName = ""
    }
}
