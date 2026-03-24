import Foundation

public struct TriggerEvent: Sendable {
    public let onsetTimestamp: TimeInterval
    public let staLtaRatio: Float
    public let dominantAxis: String
    public let peakAcceleration: Float    // milli-g
    public let windowSamples: [Float]

    public init(
        onsetTimestamp: TimeInterval,
        staLtaRatio: Float,
        dominantAxis: String,
        peakAcceleration: Float,
        windowSamples: [Float]
    ) {
        self.onsetTimestamp = onsetTimestamp
        self.staLtaRatio = staLtaRatio
        self.dominantAxis = dominantAxis
        self.peakAcceleration = peakAcceleration
        self.windowSamples = windowSamples
    }
}
