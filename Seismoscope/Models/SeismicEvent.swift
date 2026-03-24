import SwiftData
import Foundation

/// On-device event log entry. Created on trigger, updated as USGS correlation resolves.
@Model
final class SeismicEvent {
    var id: UUID
    var onsetTime: Date
    var duration: TimeInterval           // seconds, onset to sub-threshold; 0 until resolved
    var peakAcceleration: Float          // milli-g
    var dominantAxis: String             // "x" | "y" | "z"
    var staLtaRatio: Float
    var correlationStatus: String        // "pending" | "matched" | "local" | "timeout"

    // USGS fields — populated when correlationStatus == "matched"
    var usgsEventId: String?
    var usgsMagnitude: Float?
    var usgsPlace: String?               // e.g. "47km NE of San Jose, CA"
    var usgsDistanceKm: Float?
    var usgsDepthKm: Float?
    var usgsOriginTime: Date?
    var usgsEventURL: String?

    // Retry tracking
    var lastRetryTime: Date?
    var retryCount: Int                  // max 3

    init(
        id: UUID = UUID(),
        onsetTime: Date,
        duration: TimeInterval = 0,
        peakAcceleration: Float = 0,
        dominantAxis: String = "z",
        staLtaRatio: Float = 0,
        correlationStatus: String = "pending",
        retryCount: Int = 0
    ) {
        self.id = id
        self.onsetTime = onsetTime
        self.duration = duration
        self.peakAcceleration = peakAcceleration
        self.dominantAxis = dominantAxis
        self.staLtaRatio = staLtaRatio
        self.correlationStatus = correlationStatus
        self.retryCount = retryCount
    }
}
