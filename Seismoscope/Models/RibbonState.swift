import Foundation
import simd

@Observable
@MainActor
final class RibbonState {
    var samples: [Float] = []
    var activeEvents: [RibbonEvent] = []
    var currentAcceleration: Float = 0
    var isStable: Bool = false

    private let maxSamples = 12_000

    func appendSample(_ magnitude: Float) {
        samples.append(magnitude)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        currentAcceleration = magnitude * 1000 // milli-g
    }
}

struct RibbonEvent: Identifiable, Sendable {
    let id: UUID
    let sampleIndex: Int
    var label: String
    var isConfirmed: Bool
    var tintColor: SIMD4<Float>
}
