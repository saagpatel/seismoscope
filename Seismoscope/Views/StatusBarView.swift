import SwiftUI
import SeismoscopeKit

struct StatusBarView: View {
    let ribbonState: RibbonState
    let useMilliG: Bool
    let onSettingsTapped: () -> Void

    private var intensityNumeral: String {
        SeismicIntensity.romanNumeral(SeismicIntensity.modifiedMercalli(
            peakAccelerationMilliG: Double(ribbonState.currentAcceleration)
        ))
    }

    private var accelerationText: String {
        useMilliG
            ? String(format: "%.1f mg", ribbonState.currentAcceleration)
            : "MMI \(intensityNumeral)"
    }

    private var accelerationAccessibilityLabel: String {
        useMilliG
            ? String(format: "Acceleration %.1f milli-g", ribbonState.currentAcceleration)
            : "Modified Mercalli intensity \(intensityNumeral)"
    }

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                // Stability indicator
                Circle()
                    .fill(ribbonState.isStable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(ribbonState.isStable ? "Stable" : "Place on stable surface")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Live acceleration
                Text(accelerationText)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.primary)
                    .accessibilityLabel(accelerationAccessibilityLabel)

                // Settings button
            Button {
                    onSettingsTapped()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Spacer()
        }
    }
}
