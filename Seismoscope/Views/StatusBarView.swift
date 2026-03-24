import SwiftUI

struct StatusBarView: View {
    let ribbonState: RibbonState

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                // Stability indicator
                Circle()
                    .fill(ribbonState.isStable ? .green : .orange)
                    .frame(width: 8, height: 8)

                Text(ribbonState.isStable ? "Stable" : "Place on stable surface")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Live acceleration
                Text(String(format: "%.1f mg", ribbonState.currentAcceleration))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Spacer()
        }
    }
}
