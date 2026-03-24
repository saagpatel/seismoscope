import Foundation

// MARK: - USGS FDSN GeoJSON Response Types

struct USGSFeatureCollection: Codable {
    let features: [USGSFeature]
}

struct USGSFeature: Codable {
    let id: String
    let properties: USGSProperties
    let geometry: USGSGeometry
}

struct USGSProperties: Codable {
    let mag: Double?
    let place: String?
    let time: Int64     // epoch milliseconds
    let url: String?
}

struct USGSGeometry: Codable {
    let coordinates: [Double]   // [longitude, latitude, depth_km]
}

// MARK: - Error Types

enum USGSError: Error, LocalizedError, Sendable {
    case httpError(Int)
    case decodingError
    case networkError(URLError)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .httpError(let code):  return "USGS HTTP error \(code)"
        case .decodingError:        return "Failed to decode USGS response"
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        case .rateLimited:          return "USGS rate limited (429)"
        }
    }
}

// MARK: - Client Protocol

/// Enables MockUSGSClient for unit tests and debug injection.
protocol USGSClientProtocol: Sendable {
    func queryEvents(near region: RegionPreset, around date: Date) async throws -> [USGSFeature]
}
