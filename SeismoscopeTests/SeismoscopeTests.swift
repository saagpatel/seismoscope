import Testing
import Foundation
@testable import Seismoscope

@MainActor
@Test func ribbonStateRetainsSignedSignalAlongsideMagnitude() {
    let state = RibbonState()
    state.appendSample(0.01, signedValue: -0.008, timestamp: 10)
    #expect(state.samples == [0.01])
    #expect(state.traceSamples.count == 1)
    #expect(state.traceSamples[0].value == -0.008)
    #expect(state.traceSamples[0].timestamp == 10)
    #expect(state.currentAcceleration == 10)
}

@MainActor
@Test func signedTraceHistoryTrimsWithMagnitudeHistory() {
    let state = RibbonState()
    for index in 0..<12_001 {
        state.appendSample(Float(index), signedValue: -Float(index), timestamp: Double(index) / 100)
    }
    #expect(state.traceSamples.count == state.samples.count)
    #expect(state.traceSamples.first?.value == -100)
    #expect(state.traceSamples.first?.timestamp == 1)
    #expect(state.traceSamples.last?.value == -12_000)
    #expect(state.traceSamples.last?.timestamp == 120)
}

@MainActor
@Test func ribbonStateAppendSample() {
    let state = RibbonState()
    state.appendSample(0.01)
    #expect(state.samples.count == 1)
    #expect(state.currentAcceleration == 10.0) // 0.01g * 1000 = 10 milli-g
}

@MainActor
@Test func ribbonStateCapsSamples() {
    let state = RibbonState()
    for i in 0..<13_000 {
        state.appendSample(Float(i) * 0.001)
    }
    #expect(state.samples.count == 12_000)
    #expect(abs((state.samples.first ?? 0) - 1.0) < 0.0001)
    #expect(abs((state.samples.last ?? 0) - 12.999) < 0.0001)
}

@MainActor
@Test func ribbonEventsRebaseAndExpireWithSamples() {
    let state = RibbonState()
    for index in 0..<12_000 { state.appendSample(Float(index)) }
    state.appendEvent(RibbonEvent(
        id: UUID(), sampleIndex: 0, label: "old", isConfirmed: false,
        tintColor: SIMD4<Float>(repeating: 0)
    ))
    state.appendEvent(RibbonEvent(
        id: UUID(), sampleIndex: 11_999, label: "new", isConfirmed: false,
        tintColor: SIMD4<Float>(repeating: 0)
    ))
    state.appendSample(12_000)
    #expect(state.activeEvents.count == 1)
    #expect(state.activeEvents[0].sampleIndex == 11_899)
    #expect(state.samples.count == 11_901)
}

@Test func lowPowerDetectorConfigurationPreservesTimingAndThreshold() {
    let fullPower = AccelerometerPipeline.detectorConfiguration(sampleRate: 100, threshold: 5.5)
    let lowPower = AccelerometerPipeline.detectorConfiguration(sampleRate: 50, threshold: 5.5)
    #expect(fullPower.staWindow == 150)
    #expect(fullPower.ltaWindow == 4_500)
    #expect(lowPower.staWindow == 75)
    #expect(lowPower.ltaWindow == 2_250)
    #expect(lowPower.threshold == 5.5)
}
