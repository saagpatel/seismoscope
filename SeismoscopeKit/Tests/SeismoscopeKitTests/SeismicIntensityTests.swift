import Foundation
import Testing
@testable import SeismoscopeKit

@Test func tinyPGAClampsToIntensityIAndLargePGAClampsToXII() {
    for milliG in [0.0, 1e-12, 0.001] {
        #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: milliG) == 1)
    }
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: 1e12) == 12)
    #expect(SeismicIntensity.romanNumeral(1) == "I")
    #expect(SeismicIntensity.romanNumeral(12) == "XII")
}

@Test func waldRelationsMeetAtIntensityVCrossover() {
    let crossoverPGA = pow(10, (5 + 1.66) / 3.66) // cm/s²
    for pga in [crossoverPGA * 0.999, crossoverPGA, crossoverPGA * 1.001] {
        #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: pga / 0.980665) == 5)
    }
    // At 100 cm/s² the high-intensity branch rounds to VI; the low branch would give V.
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: 100 / 0.980665) == 6)
    #expect(SeismicIntensity.romanNumeral(5) == "V")
}

@Test func intensityRoundsToNearestIntegerOnBothBranches() {
    let lowBoundary = pow(10, (4.5 - 1) / 2.20)
    let highBoundary = pow(10, (5.5 + 1.66) / 3.66)
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: lowBoundary * 0.999 / 0.980665) == 4)
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: lowBoundary * 1.001 / 0.980665) == 5)
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: highBoundary * 0.999 / 0.980665) == 5)
    #expect(SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: highBoundary * 1.001 / 0.980665) == 6)
}

@Test func intensityIsMonotonicAcrossPGAInputRange() {
    var previous = 1
    for step in -1_000...1_000 {
        let intensity = SeismicIntensity.modifiedMercalli(peakAccelerationMilliG: pow(10, Double(step) / 100))
        #expect(intensity >= previous)
        #expect((1...12).contains(intensity))
        previous = intensity
    }
}

@Test func everyIntensityHasItsRomanNumeral() {
    let expected = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
    #expect((1...12).map { SeismicIntensity.romanNumeral($0) } == expected)
}
