import SwiftUI

struct ChordsView: View {
    @EnvironmentObject var prefs: PreferencesManager

    private var chordBinding: Binding<ChordConfig> {
        Binding(
            get: {
                prefs.preferences.chords.first ?? ChordConfig(buttons: [.bottomLeft, .bottomRight])
            },
            set: { newValue in
                if prefs.preferences.chords.isEmpty {
                    prefs.preferences.chords = [newValue]
                } else {
                    prefs.preferences.chords[0] = newValue
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                // Visual chord indicator
                ChordIndicatorView(buttons: [.bottomLeft, .bottomRight])
                    .padding(.vertical, 8)

                Text("Hold **Bottom-Left** and **Bottom-Right** simultaneously to quit the frontmost app (⌘Q).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Chord Settings") {
                Toggle("Enable Quit chord (⌘Q)", isOn: chordBinding.enabled)

                if chordBinding.wrappedValue.enabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("Safety delay", isOn: Binding(
                                get: { prefs.preferences.chordQuitSafetyDelay != nil },
                                set: { prefs.preferences.chordQuitSafetyDelay = $0 ? 0.5 : nil }
                            ))
                            Spacer()
                            if let delay = prefs.preferences.chordQuitSafetyDelay {
                                Text(String(format: "%.1fs", delay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        if prefs.preferences.chordQuitSafetyDelay != nil {
                            Slider(
                                value: Binding(
                                    get: { prefs.preferences.chordQuitSafetyDelay ?? 0.5 },
                                    set: { prefs.preferences.chordQuitSafetyDelay = $0 }
                                ),
                                in: 0.3...1.0,
                                step: 0.1
                            )
                        }

                        Text("With safety delay enabled, both buttons must be held for the set duration before Quit fires. This prevents accidental quits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}

// MARK: - Chord Indicator

struct ChordIndicatorView: View {
    let buttons: [ButtonID]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { idx, button in
                if idx > 0 {
                    Text("+")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: 80, height: 44)
                    .overlay(
                        Text(button.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                    )
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange, lineWidth: 2))
                .frame(width: 80, height: 44)
                .overlay(
                    Text("Quit App\n⌘Q")
                        .font(.system(size: 11, weight: .semibold))
                        .multilineTextAlignment(.center)
                )
        }
        .frame(maxWidth: .infinity)
    }
}
