import Foundation

#if DEBUG
/// The four states in APPSTORE-METADATA.md. Never compiled into Release.
enum AppStoreScreenshot: Int {
    case ribbonMilliG = 1
    case ribbonMMI
    case settingsRegion
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

    /// Precompute the existing noise/impulse modes without starting a timer or motion updates.
    /// The fixed 120-second history and renderer clock keep captures independent of launch delay.
    func prepareScreenshot(_ shot: AppStoreScreenshot) {
        stop()
        configuration.mode = shot == .ribbonMMI ? .impulse : .noise
        sampleCount = 0
        impulseTriggered = false
        var seed: UInt64 = 0x534549534D4F
        ribbonState?.samples = []
        ribbonState?.traceSamples = []
        ribbonState?.activeEvents = []

        for index in 0..<12_000 {
            if shot == .ribbonMMI && index == 9_000 {
                triggerImpulse()
            }
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let noise = Float(seed >> 40) / Float(0xFF_FFFF) * 2 - 1
            let sample = generateSample(randomValue: noise)
            ribbonState?.appendSample(
                abs(sample), signedValue: sample, timestamp: Double(index) / Double(sampleRate)
            )
            sampleCount += 1
        }
        // Both frozen histories end with quiet ambient samples, long after the impulse.
        ribbonState?.isStable = true
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
