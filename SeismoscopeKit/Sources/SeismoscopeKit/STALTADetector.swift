import Foundation

public struct STALTADetector: Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// Number of samples in the short-term average window (default 150 = 1.5s at 100Hz)
        public var staWindow: Int
        /// Number of samples in the long-term average window (default 4500 = 45s at 100Hz)
        public var ltaWindow: Int
        /// STA/LTA ratio above which a trigger fires
        public var threshold: Float
        /// STA/LTA ratio below which the detector re-arms after a trigger
        public var rearmRatio: Float

        public init(
            staWindow: Int = 150,
            ltaWindow: Int = 4500,
            threshold: Float = 4.0,
            rearmRatio: Float = 1.5
        ) {
            self.staWindow = staWindow
            self.ltaWindow = ltaWindow
            self.threshold = threshold
            self.rearmRatio = rearmRatio
        }
    }

    // MARK: - State

    private var config: Configuration

    private var staSum: Float = 0
    private var ltaSum: Float = 0
    private var staBuffer: [Float]
    private var ltaBuffer: [Float]
    private var staHead: Int = 0
    private var ltaHead: Int = 0

    private var sampleCount: Int = 0
    private var isArmed: Bool = true
    private var peakMagnitude: Float = 0

    private var magnitudeHistory: [Float]
    private var historyHead: Int = 0
    private let historyCapacity = 1000

    // MARK: - Init

    public init(configuration: Configuration = .init()) {
        self.config = configuration
        self.staBuffer = [Float](repeating: 0, count: configuration.staWindow)
        self.ltaBuffer = [Float](repeating: 0, count: configuration.ltaWindow)
        self.magnitudeHistory = [Float](repeating: 0, count: 1000)
    }

    // MARK: - Processing

    /// Feed one sample. Returns a TriggerEvent when the STA/LTA ratio crosses the threshold.
    public mutating func process(
        magnitude: Float,
        timestamp: TimeInterval,
        dominantAxis: String
    ) -> TriggerEvent? {

        let absMag = abs(magnitude)

        // 2. Update magnitude history ring
        magnitudeHistory[historyHead] = absMag
        historyHead = (historyHead + 1) % historyCapacity

        // 3. Track peak
        peakMagnitude = max(peakMagnitude, absMag)

        // 4. Update STA ring
        staSum -= staBuffer[staHead]
        staBuffer[staHead] = absMag
        staSum += absMag
        staHead = (staHead + 1) % config.staWindow

        // 5. Update LTA ring
        ltaSum -= ltaBuffer[ltaHead]
        ltaBuffer[ltaHead] = absMag
        ltaSum += absMag
        ltaHead = (ltaHead + 1) % config.ltaWindow

        // 6. Increment count
        sampleCount += 1

        // 7. Filling phase guard
        if sampleCount < config.ltaWindow {
            return nil
        }

        // 8. Compute LTA average
        let ltaAvg = ltaSum / Float(config.ltaWindow)
        guard ltaAvg > 1e-10 else { return nil }

        // 9. Compute ratio
        let ratio = (staSum / Float(config.staWindow)) / ltaAvg

        // 10. Fire trigger
        if isArmed && ratio >= config.threshold {
            let samples = buildWindowSamples()
            let event = TriggerEvent(
                onsetTimestamp: timestamp,
                staLtaRatio: ratio,
                dominantAxis: dominantAxis,
                peakAcceleration: peakMagnitude * 1000,
                windowSamples: samples
            )
            isArmed = false
            peakMagnitude = 0
            return event
        }

        // 11. Re-arm
        if !isArmed && ratio < config.rearmRatio {
            isArmed = true
            peakMagnitude = 0
        }

        return nil
    }

    // MARK: - Public mutation

    /// Update the trigger threshold mid-session without resetting filter state.
    public mutating func updateThreshold(_ threshold: Float) {
        config.threshold = threshold
    }

    // MARK: - Public computed properties

    /// Returns the current STA/LTA ratio, or 0 during the LTA filling phase.
    public var currentRatio: Float {
        guard sampleCount >= config.ltaWindow else { return 0 }
        let ltaAvg = ltaSum / Float(config.ltaWindow)
        guard ltaAvg > 1e-10 else { return 0 }
        return (staSum / Float(config.staWindow)) / ltaAvg
    }

    // MARK: - Private helpers

    /// Read the last `min(sampleCount, historyCapacity)` samples from the ring in chronological order.
    private func buildWindowSamples() -> [Float] {
        let count = min(sampleCount, historyCapacity)
        var result = [Float]()
        result.reserveCapacity(count)

        // historyHead points to the next write slot, so the oldest kept sample
        // in the ring is at historyHead (when the ring is full).
        let startIndex = historyHead // oldest sample slot
        for i in 0..<count {
            let index = (startIndex + i) % historyCapacity
            result.append(magnitudeHistory[index])
        }
        return result
    }
}
