import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomInput = false
    @State private var customLatText = ""
    @State private var customLonText = ""

    var body: some View {
        NavigationStack {
            Form {
                regionSection
                sensitivitySection
                displaySection
                batterySection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var regionSection: some View {
        Section {
            ForEach(appState.presets) { preset in
                Button {
                    appState.region = preset
                    showCustomInput = false
                } label: {
                    HStack {
                        Text(preset.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if appState.region.name == preset.name && !appState.region.isCustom {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Custom entry
            Button {
                showCustomInput.toggle()
                if showCustomInput {
                    customLatText = appState.region.isCustom
                        ? String(format: "%.4f", appState.region.latitude) : ""
                    customLonText = appState.region.isCustom
                        ? String(format: "%.4f", appState.region.longitude) : ""
                }
            } label: {
                HStack {
                    Text("Custom Location")
                        .foregroundStyle(.primary)
                    Spacer()
                    if appState.region.isCustom {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }

            if showCustomInput {
                customCoordinateFields
            }
        } header: {
            Text("Region")
        } footer: {
            Text("Determines the area searched when correlating with USGS earthquake data.")
                .font(.caption)
        }
    }

    private var customCoordinateFields: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Lat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                TextField("e.g. 37.33", text: $customLatText)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("Lon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                TextField("e.g. -121.89", text: $customLonText)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))
            }
            Button("Apply") {
                guard
                    let lat = Double(customLatText),
                    let lon = Double(customLonText),
                    (-90...90).contains(lat),
                    (-180...180).contains(lon)
                else { return }
                appState.region = RegionPreset(
                    name: String(format: "%.2f°, %.2f°", lat, lon),
                    latitude: lat,
                    longitude: lon,
                    isCustom: true
                )
                showCustomInput = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var sensitivitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Threshold")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f×", appState.staLtaThreshold))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $appState.staLtaThreshold,
                    in: 2.5...6.0,
                    step: 0.5
                )
                HStack {
                    Text("More sensitive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Less sensitive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Sensitivity")
        } footer: {
            Text("Higher values require stronger shaking to register an event. Device-calibrated on first launch.")
                .font(.caption)
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Toggle("Show acceleration in milli-g", isOn: $appState.useMilliG)
        }
    }

    private var batterySection: some View {
        Section {
            Toggle("Low-power mode", isOn: $appState.lowPowerMode)
        } header: {
            Text("Battery")
        } footer: {
            Text("Reduces accelerometer sampling from 100Hz to 50Hz. Extends battery life at the cost of slightly reduced event timing precision.")
                .font(.caption)
        }
    }
}
