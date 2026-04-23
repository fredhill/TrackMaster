import SwiftUI

struct ButtonsView: View {
    @EnvironmentObject var prefs: PreferencesManager
    @State private var selectedButton: ButtonID? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Context badge
            HStack {
                Spacer()
                Text("All Apps")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.tertiary, in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Trackball diagram
            TrackballDiagramView(
                mappings: prefs.preferences.buttonMappings,
                selectedButton: $selectedButton
            )
            .frame(width: 320, height: 260)

            Divider()

            // Action picker for selected button
            if let button = selectedButton {
                HStack {
                    Text("\(button.displayName):")
                        .frame(width: 110, alignment: .trailing)
                    Picker("", selection: actionBinding(for: button)) {
                        ForEach(ActionConfig.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
                .padding(.bottom, 8)
            } else {
                Text("Select a button on the diagram to change its action.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.bottom, 8)
            }
        }
        .padding(24)
    }

    private func actionBinding(for button: ButtonID) -> Binding<ActionConfig> {
        Binding(
            get: { prefs.preferences.buttonMappings[button] ?? .leftClick },
            set: { prefs.preferences.buttonMappings[button] = $0 }
        )
    }
}

// MARK: - Trackball Diagram

struct TrackballDiagramView: View {
    let mappings: [ButtonID: ActionConfig]
    @Binding var selectedButton: ButtonID?

    var body: some View {
        ZStack {
            // Device body
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

            // Scroll ring (decorative arc around ball)
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 8)
                .frame(width: 148, height: 148)

            // Ball
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.7, green: 0.2, blue: 0.2),
                                 Color(red: 0.45, green: 0.08, blue: 0.08)],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Button zones + pill labels
            Group {
                ButtonZoneView(
                    button: .topLeft,
                    action: mappings[.topLeft] ?? .spotlightSearch,
                    alignment: .topLeading,
                    pillAlignment: .topLeading,
                    isSelected: selectedButton == .topLeft
                ) { selectedButton = .topLeft }

                ButtonZoneView(
                    button: .topRight,
                    action: mappings[.topRight] ?? .rightClick,
                    alignment: .topTrailing,
                    pillAlignment: .topTrailing,
                    isSelected: selectedButton == .topRight
                ) { selectedButton = .topRight }

                ButtonZoneView(
                    button: .bottomLeft,
                    action: mappings[.bottomLeft] ?? .leftClick,
                    alignment: .bottomLeading,
                    pillAlignment: .bottomLeading,
                    isSelected: selectedButton == .bottomLeft
                ) { selectedButton = .bottomLeft }

                ButtonZoneView(
                    button: .bottomRight,
                    action: mappings[.bottomRight] ?? .doubleClick,
                    alignment: .bottomTrailing,
                    pillAlignment: .bottomTrailing,
                    isSelected: selectedButton == .bottomRight
                ) { selectedButton = .bottomRight }
            }
        }
    }
}

// MARK: - Button Zone

struct ButtonZoneView: View {
    let button: ButtonID
    let action: ActionConfig
    let alignment: Alignment
    let pillAlignment: Alignment
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: alignment) {
                // Tappable corner zone
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : (isHovered ? Color.accentColor.opacity(0.1) : Color.clear))
                    .frame(width: 72, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .onHover { isHovered = $0 }
                    .onTapGesture { onTap() }

                // Pill label
                Text(action.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .frame(maxWidth: 80)
                    .offset(pillOffset(for: alignment, in: geo.size))
            }
        }
    }

    private func pillOffset(for alignment: Alignment, in size: CGSize) -> CGSize {
        switch alignment {
        case .topLeading:     return CGSize(width: -50, height: -40)
        case .topTrailing:    return CGSize(width:  50, height: -40)
        case .bottomLeading:  return CGSize(width: -50, height:  40)
        case .bottomTrailing: return CGSize(width:  50, height:  40)
        default:              return .zero
        }
    }
}
