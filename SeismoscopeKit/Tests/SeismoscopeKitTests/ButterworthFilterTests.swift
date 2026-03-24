import Testing
import Foundation
@testable import SeismoscopeKit

// MARK: - Test Helpers

func rms(_ samples: [Float]) -> Float {
    sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
}

func generateSine(frequency: Float, amplitude: Float, sampleRate: Float, count: Int) -> [Float] {
    (0..<count).map { amplitude * sin(2 * .pi * frequency * Float($0) / sampleRate) }
}

// MARK: - ButterworthFilter Tests

@Test func bandpassPassesMidband() {
    // 0.5 Hz sine well within the 0.1–10 Hz passband at 100 Hz sample rate
    let sr: Float = 100
    let input = generateSine(frequency: 0.5, amplitude: 1.0, sampleRate: sr, count: 1000)
    var filter = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10.0, sampleRate: Double(sr))

    var output: [Float] = []
    for sample in input {
        output.append(filter.process(sample))
    }

    let inputRMS = rms(Array(input.dropFirst(200)))
    let outputRMS = rms(Array(output.dropFirst(200)))

    // Output RMS should be within ±5% of input RMS after settling
    #expect(abs(outputRMS - inputRMS) / inputRMS < 0.05,
            "Midband signal should pass with <5% RMS deviation; inputRMS=\(inputRMS) outputRMS=\(outputRMS)")
}

@Test func bandpassAttenuatesHighFreq() {
    // 45 Hz is well above the 10 Hz cutoff (using 45 Hz to avoid Nyquist aliasing at 100 Hz SR)
    let sr: Float = 100
    let input = generateSine(frequency: 45, amplitude: 1.0, sampleRate: sr, count: 1000)
    var filter = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10.0, sampleRate: Double(sr))

    let output = input.map { filter.process($0) }

    let inputRMS = rms(input)
    let outputRMS = rms(output)

    // Output RMS should be less than 1% of input RMS (strong stopband attenuation)
    #expect(outputRMS < inputRMS * 0.01,
            "High-frequency signal should be strongly attenuated; inputRMS=\(inputRMS) outputRMS=\(outputRMS)")
}

@Test func highPassRemovesDC() {
    // DC offset of 1.0 should be blocked by highpass(1 Hz) at 100 Hz SR.
    // At 1 Hz cutoff the time constant is ~16 samples, so 500 samples gives
    // ~31 time constants — well into steady-state with negligible DC leakage.
    let sr: Float = 100
    var filter = HighPassFilter(cutoffHz: 1.0, sampleRate: Double(sr))

    var lastOutput: Float = 0
    for _ in 0..<500 {
        lastOutput = filter.process(1.0)
    }

    // After 500 samples the transient has fully decayed — steady-state output near zero
    #expect(abs(lastOutput) < 0.01,
            "DC should be removed by highpass; last output=\(lastOutput)")
}

@Test func highPassPassesSeismic() {
    // 1 Hz sine is well above the 0.05 Hz cutoff — should pass with minimal attenuation
    let sr: Float = 100
    let input = generateSine(frequency: 1.0, amplitude: 1.0, sampleRate: sr, count: 1000)
    var filter = HighPassFilter(cutoffHz: 0.05, sampleRate: Double(sr))

    var output: [Float] = []
    for sample in input {
        output.append(filter.process(sample))
    }

    let inputRMS = rms(Array(input.dropFirst(200)))
    let outputRMS = rms(Array(output.dropFirst(200)))

    // Output RMS within ±5% of input RMS after settling
    #expect(abs(outputRMS - inputRMS) / inputRMS < 0.05,
            "1 Hz seismic signal should pass highpass(0.05 Hz); inputRMS=\(inputRMS) outputRMS=\(outputRMS)")
}

@Test func resetClearsState() {
    let sr: Float = 100
    let input = generateSine(frequency: 1.0, amplitude: 1.0, sampleRate: sr, count: 100)
    var filter = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10.0, sampleRate: Double(sr))

    // First pass
    let firstRun = input.map { filter.process($0) }

    // Reset and second pass with identical input
    filter.reset()
    let secondRun = input.map { filter.process($0) }

    // Both runs should produce identical output (within floating-point tolerance)
    for (i, (a, b)) in zip(firstRun, secondRun).enumerated() {
        #expect(abs(a - b) < 1e-6,
                "After reset, outputs should be identical; sample \(i): first=\(a) second=\(b)")
    }
}
