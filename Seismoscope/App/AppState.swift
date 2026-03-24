import Foundation
import Observation

/// Single source of truth for user-configurable settings.
/// All properties persist to UserDefaults and are observed by the main scene.
@Observable @MainActor final class AppState {

    // MARK: - Settings

    var region: RegionPreset {
        didSet { persistRegion() }
    }

    var staLtaThreshold: Float {
        didSet { UserDefaults.standard.set(staLtaThreshold, forKey: Keys.threshold) }
    }

    var useMilliG: Bool {
        didSet { UserDefaults.standard.set(useMilliG, forKey: Keys.useMilliG) }
    }

    var lowPowerMode: Bool {
        didSet { UserDefaults.standard.set(lowPowerMode, forKey: Keys.lowPowerMode) }
    }

    // MARK: - Available Presets (loaded once from regions.json)

    let presets: [RegionPreset] = {
        guard
            let url = Bundle.main.url(forResource: "regions", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return [.defaultPreset] }

        struct Preset: Decodable { let name: String; let latitude: Double; let longitude: Double }
        guard let decoded = try? JSONDecoder().decode([Preset].self, from: data) else {
            return [.defaultPreset]
        }
        return decoded.map { RegionPreset(name: $0.name, latitude: $0.latitude, longitude: $0.longitude) }
    }()

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Restore region
        if let data = defaults.data(forKey: Keys.region),
           let saved = try? JSONDecoder().decode(RegionPreset.self, from: data) {
            self.region = saved
        } else {
            self.region = .defaultPreset
        }

        // Restore threshold (device-calibrated default on first launch)
        if defaults.object(forKey: Keys.threshold) != nil {
            self.staLtaThreshold = defaults.float(forKey: Keys.threshold)
        } else {
            self.staLtaThreshold = 4.0 * DeviceProfileLoader.thresholdMultiplier()
        }

        self.useMilliG = defaults.object(forKey: Keys.useMilliG) != nil
            ? defaults.bool(forKey: Keys.useMilliG)
            : true

        self.lowPowerMode = defaults.bool(forKey: Keys.lowPowerMode)
    }

    // MARK: - Private

    private func persistRegion() {
        guard let data = try? JSONEncoder().encode(region) else { return }
        UserDefaults.standard.set(data, forKey: Keys.region)
    }

    private enum Keys {
        static let region       = "appstate.region"
        static let threshold    = "appstate.staLtaThreshold"
        static let useMilliG    = "appstate.useMilliG"
        static let lowPowerMode = "appstate.lowPowerMode"
    }
}
