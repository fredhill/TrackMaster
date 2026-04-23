import SwiftUI

struct HUDView: View {
    let focusName: String
    let iconName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.primary)

            Text(focusName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minWidth: 180)
    }
}
