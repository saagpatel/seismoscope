/// ButterworthFilter.swift — SeismoscopeKit
///
/// 4-pole Butterworth filter implemented as two cascaded biquad sections
/// in Direct Form II Transposed (DFT-II) structure.
///
/// ## Theory
///
/// A 4th-order Butterworth filter has maximally flat magnitude response in the
/// passband with no ripple. It is realised by cascading two 2nd-order (biquad)
/// sections, each with a distinct Q value derived from the pole positions of the
/// continuous-time prototype:
///
///   Q₁ = 1 / (2 × cos(π/8))  ≈ 0.54120  (outer pole pair)
///   Q₂ = 1 / (2 × cos(3π/8)) ≈ 1.30656  (inner pole pair)
///
/// Each biquad is designed using the bilinear transform from the analog prototype.
/// The bilinear transform maps the s-plane to the z-plane via:
///   s → (2/T) × (z−1)/(z+1)
///
/// giving the standard second-order section transfer function:
///   H(z) = (b0 + b1·z⁻¹ + b2·z⁻²) / (1 + a1·z⁻¹ + a2·z⁻²)
///
/// Coefficients are prewarped at the target cutoff frequency:
///   ω₀ = 2π × fc / fs   (digital frequency, radians/sample)
///
/// ## Direct Form II Transposed recurrence
///
///   y[n]  = b0·x[n] + w1[n-1]
///   w1[n] = b1·x[n] − a1·y[n] + w2[n-1]
///   w2[n] = b2·x[n] − a2·y[n]
///
/// This form offers superior numerical stability compared to Direct Form I
/// and requires only two delay elements per section (minimal state).

import Foundation

// MARK: - Q values for 4th-order Butterworth biquad sections

private let butterworthQ1: Double = 1.0 / (2.0 * cos(.pi / 8.0))   // ≈ 0.54120
private let butterworthQ2: Double = 1.0 / (2.0 * cos(3.0 * .pi / 8.0)) // ≈ 1.30656

// MARK: - Coefficient computation helpers

/// Shared denominator terms for both highpass and lowpass biquads.
/// Returns (a0, a1_unnorm, a2_unnorm) before normalisation by a0.
private func denominatorCoeffs(omega0: Double, alpha: Double) -> (a0: Double, a1: Double, a2: Double) {
    let a0 =  1.0 + alpha
    let a1 = -2.0 * cos(omega0)
    let a2 =  1.0 - alpha
    return (a0, a1, a2)
}

/// Compute normalised biquad coefficients for a **highpass** section.
///
/// - Parameters:
///   - cutoffHz: Cutoff frequency in Hz.
///   - sampleRate: Sample rate in Hz.
///   - q: Quality factor (pole Q).
/// - Returns: Normalised (b0, b1, b2, a1, a2) coefficients (a0 divided out).
private func highpassCoeffs(cutoffHz: Double, sampleRate: Double, q: Double)
    -> (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float)
{
    let omega0 = 2.0 * .pi * cutoffHz / sampleRate
    let alpha  = sin(omega0) / (2.0 * q)

    let (a0, a1_raw, a2_raw) = denominatorCoeffs(omega0: omega0, alpha: alpha)

    let cosOmega = cos(omega0)
    let b0 =  (1.0 + cosOmega) / 2.0
    let b1 = -(1.0 + cosOmega)
    let b2 =  (1.0 + cosOmega) / 2.0

    return (
        b0: Float(b0 / a0),
        b1: Float(b1 / a0),
        b2: Float(b2 / a0),
        a1: Float(a1_raw / a0),
        a2: Float(a2_raw / a0)
    )
}

/// Compute normalised biquad coefficients for a **lowpass** section.
///
/// Same denominator as highpass; only the numerator changes.
private func lowpassCoeffs(cutoffHz: Double, sampleRate: Double, q: Double)
    -> (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float)
{
    let omega0 = 2.0 * .pi * cutoffHz / sampleRate
    let alpha  = sin(omega0) / (2.0 * q)

    let (a0, a1_raw, a2_raw) = denominatorCoeffs(omega0: omega0, alpha: alpha)

    let cosOmega = cos(omega0)
    let b0 = (1.0 - cosOmega) / 2.0
    let b1 =  1.0 - cosOmega
    let b2 = (1.0 - cosOmega) / 2.0

    return (
        b0: Float(b0 / a0),
        b1: Float(b1 / a0),
        b2: Float(b2 / a0),
        a1: Float(a1_raw / a0),
        a2: Float(a2_raw / a0)
    )
}

// MARK: - Biquad

/// A single second-order IIR section (biquad) in Direct Form II Transposed.
///
/// All coefficient fields are normalised (a0 divided out). The delay state
/// variables `w1` and `w2` hold the transposed delay line values.
public struct Biquad: Sendable {

    // Numerator coefficients (normalised)
    public var b0: Float
    public var b1: Float
    public var b2: Float

    // Denominator coefficients (normalised, a0 = 1 implicit)
    public var a1: Float
    public var a2: Float

    // Delay state (Direct Form II Transposed)
    public var w1: Float = 0
    public var w2: Float = 0

    public init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    /// Process one sample through this biquad section.
    ///
    /// Direct Form II Transposed recurrence:
    ///   y  = b0·x + w1
    ///   w1 = b1·x − a1·y + w2
    ///   w2 = b2·x − a2·y
    @inline(__always)
    public mutating func process(_ x: Float) -> Float {
        let y  = b0 * x + w1
        w1 = b1 * x - a1 * y + w2
        w2 = b2 * x - a2 * y
        return y
    }

    /// Reset delay state to zero (clears filter memory).
    public mutating func reset() {
        w1 = 0
        w2 = 0
    }
}

// MARK: - HighPassFilter

/// A 4th-order Butterworth highpass filter composed of two cascaded biquad sections.
///
/// The two sections use the distinct Q values required to produce a maximally-flat
/// 4th-order Butterworth response:
///   - Stage 1: Q₁ ≈ 0.54120  (1 / (2 cos(π/8)))
///   - Stage 2: Q₂ ≈ 1.30656  (1 / (2 cos(3π/8)))
public struct HighPassFilter: Sendable {

    private var stage1: Biquad
    private var stage2: Biquad

    /// Create a 4th-order Butterworth highpass filter.
    ///
    /// - Parameters:
    ///   - cutoffHz: −3 dB cutoff frequency in Hz.
    ///   - sampleRate: Sample rate of the signal in Hz.
    public init(cutoffHz: Double, sampleRate: Double) {
        let c1 = highpassCoeffs(cutoffHz: cutoffHz, sampleRate: sampleRate, q: butterworthQ1)
        let c2 = highpassCoeffs(cutoffHz: cutoffHz, sampleRate: sampleRate, q: butterworthQ2)
        stage1 = Biquad(b0: c1.b0, b1: c1.b1, b2: c1.b2, a1: c1.a1, a2: c1.a2)
        stage2 = Biquad(b0: c2.b0, b1: c2.b1, b2: c2.b2, a1: c2.a1, a2: c2.a2)
    }

    /// Process one sample through both cascaded stages.
    @inline(__always)
    public mutating func process(_ sample: Float) -> Float {
        stage2.process(stage1.process(sample))
    }

    /// Reset both stages (clears all filter memory).
    public mutating func reset() {
        stage1.reset()
        stage2.reset()
    }
}

// MARK: - BandpassFilter

/// A 4th-order Butterworth bandpass filter.
///
/// Implemented as four cascaded biquad sections:
///   - Two highpass biquads at `lowCutoffHz`  (blocks below the low cutoff)
///   - Two lowpass  biquads at `highCutoffHz` (blocks above the high cutoff)
///
/// Each pair uses the Butterworth Q values for a maximally-flat 4th-order response
/// at the respective cutoff edge.
public struct BandpassFilter: Sendable {

    private var hp1: Biquad
    private var hp2: Biquad
    private var lp1: Biquad
    private var lp2: Biquad

    /// Create a 4th-order Butterworth bandpass filter.
    ///
    /// - Parameters:
    ///   - lowCutoffHz:  Lower −3 dB edge frequency in Hz.
    ///   - highCutoffHz: Upper −3 dB edge frequency in Hz.
    ///   - sampleRate:   Sample rate of the signal in Hz.
    public init(lowCutoffHz: Double, highCutoffHz: Double, sampleRate: Double) {
        let hc1 = highpassCoeffs(cutoffHz: lowCutoffHz,  sampleRate: sampleRate, q: butterworthQ1)
        let hc2 = highpassCoeffs(cutoffHz: lowCutoffHz,  sampleRate: sampleRate, q: butterworthQ2)
        let lc1 = lowpassCoeffs( cutoffHz: highCutoffHz, sampleRate: sampleRate, q: butterworthQ1)
        let lc2 = lowpassCoeffs( cutoffHz: highCutoffHz, sampleRate: sampleRate, q: butterworthQ2)

        hp1 = Biquad(b0: hc1.b0, b1: hc1.b1, b2: hc1.b2, a1: hc1.a1, a2: hc1.a2)
        hp2 = Biquad(b0: hc2.b0, b1: hc2.b1, b2: hc2.b2, a1: hc2.a1, a2: hc2.a2)
        lp1 = Biquad(b0: lc1.b0, b1: lc1.b1, b2: lc1.b2, a1: lc1.a1, a2: lc1.a2)
        lp2 = Biquad(b0: lc2.b0, b1: lc2.b1, b2: lc2.b2, a1: lc2.a1, a2: lc2.a2)
    }

    /// Process one sample through all four cascaded stages (HP → HP → LP → LP).
    @inline(__always)
    public mutating func process(_ sample: Float) -> Float {
        lp2.process(lp1.process(hp2.process(hp1.process(sample))))
    }

    /// Reset all four stages (clears all filter memory).
    public mutating func reset() {
        hp1.reset()
        hp2.reset()
        lp1.reset()
        lp2.reset()
    }
}
