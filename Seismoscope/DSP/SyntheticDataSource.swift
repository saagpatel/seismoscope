import Foundation

#if DEBUG
/// The four states in APPSTORE-METADATA.md. Never compiled into Release.
enum AppStoreScreenshot: Int {
    case ribbonMilliG = 1
    case ribbonMMI
    case eventDetail
    case settingsControls

    static let frameTime: TimeInterval = 120

    static let requested: AppStoreScreenshot? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppStoreScreenshot") else { return nil }
        guard arguments.indices.contains(index + 1),
              let number = Int(arguments[index + 1]),
              let shot = AppStoreScreenshot(rawValue: number) else {
            fatalError("-AppStoreScreenshot requires a number from 1 through 4")
        }
        return shot
    }()
}

/// Generates synthetic waveform data for Phase 0 testing.
/// Feeds samples into RibbonState at 100Hz.
@MainActor
final class SyntheticDataSource {

    enum Mode: String, CaseIterable, Sendable {
        case sine
        case noise
        case impulse
    }

    struct Configuration: Sendable {
        var mode: Mode = .sine
        var sineFrequency: Float = 1.0       // Hz
        var sineAmplitude: Float = 0.02      // g
        var noiseAmplitude: Float = 0.005    // g
        var impulseAmplitude: Float = 0.05   // g
        var impulseDuration: TimeInterval = 0.5  // seconds
    }

    var configuration = Configuration()
    private weak var ribbonState: RibbonState?
    private var task: Task<Void, Never>?
    private var sampleCount: Int = 0
    private var impulseTriggered = false
    private var impulseSampleStart: Int = 0
    private let sampleRate: Float = 100.0

    init(ribbonState: RibbonState) {
        self.ribbonState = ribbonState
    }

    func start() {
        stop()
        sampleCount = 0
        impulseTriggered = false

        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let sample = self.generateSample()
                self.ribbonState?.appendSample(abs(sample), signedValue: sample)
                self.sampleCount += 1
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func triggerImpulse() {
        impulseTriggered = true
        impulseSampleStart = sampleCount
    }

    /// Precompute quiet noise or a synthetic earthquake without timers or motion updates.
    /// The fixed 120-second history and renderer clock keep captures independent of launch delay.
    /// Returns the matched fixture record for the caller's in-memory SwiftData store.
    func prepareScreenshot(_ shot: AppStoreScreenshot) -> SeismicEvent? {
        stop()
        let hasEvent = shot == .ribbonMMI || shot == .eventDetail
        let onsetIndex = 5_000
        let duration: TimeInterval = 50
        // At the renderer's gain this is a roughly 3–4 point quiet-table wobble.
        configuration.noiseAmplitude = 0.00008
        sampleCount = 0
        impulseTriggered = false
        var seed: UInt64 = 0x534549534D4F
        ribbonState?.samples = []
        ribbonState?.traceSamples = []
        ribbonState?.activeEvents = []
        var peak: Float = 0

        for index in 0..<12_000 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let noise = Float(seed >> 40) / Float(0xFF_FFFF) * 2 - 1
            let elapsed = Float(index - onsetIndex) / sampleRate
            var sample = configuration.noiseAmplitude * noise
            if hasEvent && elapsed >= 0 && elapsed < Float(duration) {
                sample += screenshotEarthquakeSample(elapsed: elapsed)
                peak = max(peak, abs(sample))
            }
            ribbonState?.appendSample(
                abs(sample), signedValue: sample, timestamp: Double(index) / Double(sampleRate)
            )
            sampleCount += 1
        }
        // The record ends at 100 seconds; the final 20 seconds are quiet again.
        ribbonState?.isStable = true
        guard hasEvent else { return nil }

        let event = SeismicEvent(
            onsetTime: Date(timeIntervalSince1970: 1_705_320_000),
            duration: duration,
            peakAcceleration: peak * 1000,
            dominantAxis: "z",
            staLtaRatio: 5.8
        )
        // Synthetic catalog fixture, not a claim about a measured or historical earthquake.
        // No URL is provided because this fixture has no real USGS event page.
        let fixture = USGSFeature(
            id: "screenshot-fixture",
            properties: USGSProperties(
                mag: 3.2, place: "San Jose, CA",
                time: 1_705_319_990_000, url: nil
            ),
            geometry: USGSGeometry(coordinates: [-121.89, 37.33, 8.0])
        )
        let region = RegionPreset.defaultPreset
        guard let match = USGSCorrelator.bestMatch(in: [fixture], for: event, near: region) else {
            fatalError("Screenshot fixture must satisfy USGS matching criteria")
        }
        event.correlationStatus = "matched"
        event.usgsEventId = match.id
        event.usgsMagnitude = match.properties.mag.map { Float($0) }
        event.usgsPlace = match.properties.place
        event.usgsDepthKm = Float(match.geometry.coordinates[2])
        event.usgsDistanceKm = Float(USGSCorrelator.haversineKm(
            lat1: region.latitude, lon1: region.longitude,
            lat2: match.geometry.coordinates[1], lon2: match.geometry.coordinates[0]
        ))
        event.usgsOriginTime = Date(timeIntervalSince1970: Double(match.properties.time) / 1000)
        let magnitude = event.usgsMagnitude.map { String(format: "M%.1f", $0) } ?? "M?"
        ribbonState?.appendEvent(RibbonEvent(
            id: event.id,
            sampleIndex: onsetIndex,
            label: "\(magnitude) — \(event.usgsPlace ?? "Unknown location")",
            isConfirmed: true,
            tintColor: SIMD4<Float>(0.9, 0.2, 0.1, 1)
        ))
        return event
    }

    private func screenshotEarthquakeSample(elapsed: Float) -> Float {
        // Small P-wave onset, S-wave arrival eight seconds later, then a decaying coda.
        let pWave = 0.00065 * min(elapsed / 2, 1) * exp(-elapsed / 10)
            * sin(2 * .pi * 1.2 * elapsed)
        let sTime = max(elapsed - 8, 0)
        let sEnvelope = 0.0045 * min(sTime / 2, 1) * exp(-sTime / 13)
        let sWave = sEnvelope * (
            0.65 * sin(2 * .pi * 2.1 * sTime) + 0.35 * sin(2 * .pi * 3.7 * sTime)
        )
        // Taper the last five seconds into the ambient background without a hard edge.
        let taper = min(max((50 - elapsed) / 5, 0), 1)
        return (pWave + sWave) * taper
    }

    private func generateSample(randomValue: Float? = nil) -> Float {
        switch configuration.mode {
        case .sine:
            let t = Float(sampleCount) / sampleRate
            return configuration.sineAmplitude * sin(2 * .pi * configuration.sineFrequency * t)

        case .noise:
            return configuration.noiseAmplitude * (randomValue ?? Float.random(in: -1...1))

        case .impulse:
            if impulseTriggered {
                let elapsed = Float(sampleCount - impulseSampleStart) / sampleRate
                if elapsed < Float(configuration.impulseDuration) {
                    let envelope = 1.0 - (elapsed / Float(configuration.impulseDuration))
                    return configuration.impulseAmplitude * envelope * sin(2 * .pi * 8 * elapsed)
                }
            }
            return 0.0005 * (randomValue ?? Float.random(in: -1...1))
        }
    }
}
#endif
