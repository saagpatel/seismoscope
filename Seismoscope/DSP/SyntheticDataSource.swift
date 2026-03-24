import Foundation

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
                self.ribbonState?.appendSample(sample)
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

    private func generateSample() -> Float {
        switch configuration.mode {
        case .sine:
            let t = Float(sampleCount) / sampleRate
            return configuration.sineAmplitude * sin(2 * .pi * configuration.sineFrequency * t)

        case .noise:
            return configuration.noiseAmplitude * Float.random(in: -1...1)

        case .impulse:
            if impulseTriggered {
                let elapsed = Float(sampleCount - impulseSampleStart) / sampleRate
                if elapsed < Float(configuration.impulseDuration) {
                    let envelope = 1.0 - (elapsed / Float(configuration.impulseDuration))
                    return configuration.impulseAmplitude * envelope * sin(2 * .pi * 8 * elapsed)
                }
            }
            return 0.0005 * Float.random(in: -1...1)
        }
    }
}
