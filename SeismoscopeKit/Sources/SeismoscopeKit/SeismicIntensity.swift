import Foundation

public enum SeismicIntensity {
    /// PGA-based Modified Mercalli estimate using Wald et al. (1999).
    /// Input is milli-g; the empirical relations require cm/s².
    public static func modifiedMercalli(peakAccelerationMilliG: Double) -> Int {
        guard peakAccelerationMilliG > 0 else { return 1 }
        guard peakAccelerationMilliG.isFinite else { return 12 }
        let pga = peakAccelerationMilliG * 0.980665
        let highIntensity = 3.66 * log10(pga) - 1.66
        let intensity = highIntensity >= 5 ? highIntensity : 2.20 * log10(pga) + 1
        return Int(min(max(intensity, 1), 12).rounded())
    }

    public static func romanNumeral(_ intensity: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
        return numerals[min(max(intensity, 1), 12) - 1]
    }
}
