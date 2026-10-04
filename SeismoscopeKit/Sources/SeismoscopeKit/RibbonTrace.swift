import Foundation

/// Display timing only; independent of the detector's sample rate and windows.
public enum RibbonTimeScale {
    public static let pointsPerSecond: Double = 4

    public static func distance(elapsedTime: Double, contentScale: Double = 1) -> Double {
        elapsedTime * pointsPerSecond * contentScale
    }

    public static func samplesPerColumn(sampleRate: Double, contentScale: Double = 1) -> Double {
        sampleRate / distance(elapsedTime: 1, contentScale: contentScale)
    }
}

public struct RibbonTraceSample: Sendable {
    public let timestamp: TimeInterval
    public let value: Float

    public init(timestamp: TimeInterval, value: Float) {
        self.timestamp = timestamp
        self.value = value
    }
}

public struct RibbonColumnEnvelope: Sendable {
    public let column: Int
    public let min: Float
    public let max: Float
}

public enum RibbonTrace {
    /// Reduces uniformly spaced samples, including a final partial column.
    public static func envelopes(
        samples: [Float], samplesPerColumn: Double
    ) -> [(min: Float, max: Float)] {
        guard samplesPerColumn.isFinite, samplesPerColumn >= 1 else { return [] }
        return reduceColumns(samples.enumerated().map {
            (column: Int(floor(Double($0.offset) / samplesPerColumn)), value: $0.element)
        }).map { (min: $0.min, max: $0.max) }
    }

    /// Absolute time bins keep old ink fixed to the paper as new samples arrive.
    /// Timestamps also preserve gaps and changes between 100 Hz and 50 Hz input.
    public static func envelopes(
        samples: [RibbonTraceSample], pixelsPerSecond: Double
    ) -> [RibbonColumnEnvelope] {
        guard pixelsPerSecond.isFinite, pixelsPerSecond > 0 else { return [] }
        return reduceColumns(samples.map {
            (column: Int(floor($0.timestamp * pixelsPerSecond)), value: $0.value)
        })
    }

    private static func reduceColumns(
        _ samples: [(column: Int, value: Float)]
    ) -> [RibbonColumnEnvelope] {
        var result: [RibbonColumnEnvelope] = []
        for sample in samples {
            if let last = result.last, last.column == sample.column {
                result[result.count - 1] = RibbonColumnEnvelope(
                    column: last.column,
                    min: Swift.min(last.min, sample.value),
                    max: Swift.max(last.max, sample.value)
                )
            } else {
                result.append(RibbonColumnEnvelope(
                    column: sample.column, min: sample.value, max: sample.value
                ))
            }
        }
        return result
    }
}
