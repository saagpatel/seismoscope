import Foundation
import SeismoscopeKit
import simd

/// Bridges AccelerometerPipeline output to RibbonState on the main actor.
@MainActor
final class EventCoordinator {
    private let pipeline: AccelerometerPipeline
    private let ribbonState: RibbonState
    private var sampleTask: Task<Void, Never>?
    private var triggerTask: Task<Void, Never>?
    private var stabilityTask: Task<Void, Never>?

    init(pipeline: AccelerometerPipeline, ribbonState: RibbonState) {
        self.pipeline = pipeline
        self.ribbonState = ribbonState
    }

    func start() {
        sampleTask = Task { [weak self] in
            guard let self else { return }
            for await sample in pipeline.sampleStream {
                guard !Task.isCancelled else { break }
                ribbonState.appendSample(sample.magnitude)
            }
        }

        triggerTask = Task { [weak self] in
            guard let self else { return }
            for await _ in pipeline.triggerStream {
                guard !Task.isCancelled else { break }
                let event = RibbonEvent(
                    id: UUID(),
                    sampleIndex: ribbonState.samples.count,
                    label: "Local vibration",
                    isConfirmed: false,
                    tintColor: SIMD4<Float>(0.5, 0.5, 0.5, 1)
                )
                ribbonState.activeEvents.append(event)
            }
        }

        stabilityTask = Task { [weak self] in
            guard let self else { return }
            for await isStable in pipeline.stabilityStream {
                guard !Task.isCancelled else { break }
                ribbonState.isStable = isStable
            }
        }
    }

    func stop() {
        sampleTask?.cancel()
        triggerTask?.cancel()
        stabilityTask?.cancel()
        pipeline.stop()
    }
}
