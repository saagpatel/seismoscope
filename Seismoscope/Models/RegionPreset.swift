import Foundation

/// A geographic region used to scope USGS earthquake queries.
struct RegionPreset: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    var isCustom: Bool = false

    /// Default region for initial launch — user configures in Phase 3 Settings.
    static let defaultPreset = RegionPreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "San Francisco, CA",
        latitude: 37.7749,
        longitude: -122.4194
    )
}
