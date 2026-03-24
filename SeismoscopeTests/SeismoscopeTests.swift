import Testing
@testable import Seismoscope

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
}
