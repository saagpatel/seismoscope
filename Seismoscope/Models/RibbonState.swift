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
    private let maxActiveEvents = 100

    func appendSample(_ magnitude: Float) {
        samples.append(magnitude)
        if samples.count > maxSamples {
            // Trim one second at a time instead of shifting 12,000 elements at 100 Hz.
            let removedCount = min(samples.count, 100)
            samples.removeFirst(removedCount)
            activeEvents = activeEvents.compactMap { event in
                guard event.sampleIndex >= removedCount else { return nil }
                var rebased = event
                rebased.sampleIndex -= removedCount
                return rebased
            }
        }
        currentAcceleration = magnitude * 1000 // milli-g
    }

    func appendEvent(_ event: RibbonEvent) {
        activeEvents.append(event)
        if activeEvents.count > maxActiveEvents {
            activeEvents.removeFirst(activeEvents.count - maxActiveEvents)
        }
    }
}

struct RibbonEvent: Identifiable, Sendable {
    let id: UUID
    var sampleIndex: Int
    var label: String
    var isConfirmed: Bool
    var tintColor: SIMD4<Float>
}
