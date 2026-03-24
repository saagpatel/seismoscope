import Foundation
import Testing
@testable import SeismoscopeKit

@Suite("STALTADetector")
struct STALTADetectorTests {

    // Shared small-window configuration for fast tests
    private func makeConfig() -> STALTADetector.Configuration {
        STALTADetector.Configuration(staWindow: 15, ltaWindow: 450, threshold: 4.0, rearmRatio: 1.5)
    }

    // Helper: feed N samples of a fixed magnitude; returns collected triggers
    private func feed(
        detector: inout STALTADetector,
        count: Int,
        magnitude: Float,
        startTimestamp: TimeInterval = 0,
        sampleRate: Double = 100
    ) -> [TriggerEvent] {
        var triggers: [TriggerEvent] = []
        for i in 0..<count {
            let ts = startTimestamp + Double(i) / sampleRate
            if let event = detector.process(magnitude: magnitude, timestamp: ts, dominantAxis: "z") {
                triggers.append(event)
            }
        }
        return triggers
    }

    @Test func triggerOnImpulse() {
        var detector = STALTADetector(configuration: makeConfig())
        let config = makeConfig()

        // Fill with quiet noise to prime LTA
        var triggers = feed(detector: &detector, count: 500, magnitude: 0.001, startTimestamp: 0)
        #expect(triggers.isEmpty)

        // Burst — should produce exactly 1 trigger
        let burstStart = 500.0 / 100.0
        let burstTriggers = feed(detector: &detector, count: 30, magnitude: 0.02, startTimestamp: burstStart)
        triggers.append(contentsOf: burstTriggers)

        #expect(triggers.count == 1)

        // Onset timestamp must be within staWindow samples of burst start
        let staWindowSeconds = Double(config.staWindow) / 100.0
        if let event = triggers.first {
            #expect(event.onsetTimestamp >= burstStart)
            #expect(event.onsetTimestamp <= burstStart + staWindowSeconds + 0.01)
        }
    }

    @Test func noTriggerOnNoise() {
        var detector = STALTADetector(configuration: makeConfig())
        let triggers = feed(detector: &detector, count: 600, magnitude: 0.001)
        #expect(triggers.isEmpty)
    }

    @Test func rearmAfterTrigger() {
        var detector = STALTADetector(configuration: makeConfig())

        // Prime LTA with noise
        var triggers = feed(detector: &detector, count: 500, magnitude: 0.001, startTimestamp: 0)

        // First burst
        let burst1Start = 500.0 / 100.0
        triggers.append(contentsOf: feed(detector: &detector, count: 30, magnitude: 0.02,
                                         startTimestamp: burst1Start))

        // Re-arm gap (quiet noise)
        let gapStart = burst1Start + 30.0 / 100.0
        triggers.append(contentsOf: feed(detector: &detector, count: 100, magnitude: 0.001,
                                         startTimestamp: gapStart))

        // Second burst
        let burst2Start = gapStart + 100.0 / 100.0
        triggers.append(contentsOf: feed(detector: &detector, count: 30, magnitude: 0.02,
                                         startTimestamp: burst2Start))

        #expect(triggers.count == 2)
    }

    @Test func noDoubleTrigger() {
        var detector = STALTADetector(configuration: makeConfig())

        // Prime LTA
        var triggers = feed(detector: &detector, count: 500, magnitude: 0.001, startTimestamp: 0)

        // Sustained burst (60 samples) — should only fire once
        let burstStart = 500.0 / 100.0
        triggers.append(contentsOf: feed(detector: &detector, count: 60, magnitude: 0.02,
                                         startTimestamp: burstStart))

        #expect(triggers.count == 1)
    }

    @Test func fillingPhaseNoTrigger() {
        var detector = STALTADetector(configuration: makeConfig())

        // Feed only 400 samples — less than ltaWindow=450
        let triggers = feed(detector: &detector, count: 400, magnitude: 0.1)

        #expect(triggers.isEmpty)
        #expect(detector.currentRatio == 0)
    }
}
