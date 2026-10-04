import Testing
@testable import SeismoscopeKit

@Test func columnEnvelopesPreserveSignedExtremaAndPartialColumn() {
    let result = RibbonTrace.envelopes(samples: [1, -3, 2, -1, 4], samplesPerColumn: 2)
    #expect(result.count == 3)
    #expect(result[0].min == -3 && result[0].max == 1)
    #expect(result[1].min == -1 && result[1].max == 2)
    #expect(result[2].min == 4 && result[2].max == 4)
}

@Test func columnEnvelopesSupportFractionalSampleCounts() {
    let result = RibbonTrace.envelopes(samples: [0, -1, 2, -3, 4, -5], samplesPerColumn: 2.5)
    #expect(result.count == 3)
    #expect(result[0].min == -1 && result[0].max == 2)
    #expect(result[1].min == -3 && result[1].max == 4)
    #expect(result[2].min == -5 && result[2].max == -5)
}

@Test func columnEnvelopesHandleEmptyAndSingleSampleInput() {
    #expect(RibbonTrace.envelopes(samples: [Float](), samplesPerColumn: 25).isEmpty)
    let result = RibbonTrace.envelopes(samples: [-0.01], samplesPerColumn: 25)
    #expect(result.count == 1)
    #expect(result[0].min == -0.01 && result[0].max == -0.01)
    #expect(RibbonTrace.envelopes(samples: [1], samplesPerColumn: 0).isEmpty)
}

@Test func paperAndTraceShareSpeedAtBothSamplingRatesAndDisplayScales() {
    #expect(RibbonTimeScale.distance(elapsedTime: 10) == 40)
    for rate in [50.0, 100.0] {
        for scale in [1.0, 2.0, 3.0] {
            let pixels = RibbonTimeScale.distance(elapsedTime: 10, contentScale: scale)
            let columns = rate * 10 / RibbonTimeScale.samplesPerColumn(sampleRate: rate, contentScale: scale)
            #expect(abs(columns - pixels) < 0.000001)
            #expect(pixels / scale == 40)
        }
    }
}

@Test func timestampedColumnsPreserveGapsAndSamplingRateChanges() {
    let samples = [
        RibbonTraceSample(timestamp: 10, value: -1),
        RibbonTraceSample(timestamp: 10.01, value: 2), // 100 Hz
        RibbonTraceSample(timestamp: 10.03, value: -3), // 50 Hz
        RibbonTraceSample(timestamp: 10.50, value: 4) // gap
    ]
    let result = RibbonTrace.envelopes(samples: samples, pixelsPerSecond: 4)
    #expect(result.count == 2)
    #expect(result[0].column == 40 && result[0].min == -3 && result[0].max == 2)
    #expect(result[1].column == 42 && result[1].min == 4 && result[1].max == 4)
    // Appending a later sample must not move earlier extrema to different paper columns.
    let extended = RibbonTrace.envelopes(
        samples: samples + [RibbonTraceSample(timestamp: 10.75, value: -5)], pixelsPerSecond: 4
    )
    #expect(extended[0].column == result[0].column)
    #expect(extended[0].min == result[0].min && extended[0].max == result[0].max)
    #expect(extended[1].column == result[1].column)
}
