import UIKit

/// Loads per-device STA/LTA threshold multipliers from `device_profiles.json`.
/// Unknown models default to 1.5 (conservative — avoids false positives on untested hardware).
enum DeviceProfileLoader {

    /// Returns the threshold multiplier for the current device.
    static func thresholdMultiplier() -> Float {
        let modelId = modelIdentifier()
        return multipliers[modelId] ?? 1.5
    }

    // MARK: - Private

    private static let multipliers: [String: Float] = {
        guard
            let url = Bundle.main.url(forResource: "device_profiles", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(ProfileFile.self, from: data)
        else {
            return [:]
        }
        return decoded.devices
    }()

    private static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? ""
            }
        }
    }

    private struct ProfileFile: Decodable {
        let devices: [String: Float]
    }
}
