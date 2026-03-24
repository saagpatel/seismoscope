import Foundation
import QuartzCore
import SeismoscopeKit
import SwiftData
import simd

/// Bridges AccelerometerPipeline output to RibbonState on the main actor.
/// On trigger: persists a SeismicEvent to SwiftData, fires async USGS correlation.
@MainActor
final class EventCoordinator {
    private let pipeline: AccelerometerPipeline
    private let ribbonState: RibbonState
    private let modelContext: ModelContext
    private let usgsClient: any USGSClientProtocol
    private let region: RegionPreset

    private var sampleTask: Task<Void, Never>?
    private var triggerTask: Task<Void, Never>?
    private var stabilityTask: Task<Void, Never>?

    init(
        pipeline: AccelerometerPipeline,
        ribbonState: RibbonState,
        modelContext: ModelContext,
        usgsClient: any USGSClientProtocol = USGSClient(),
        region: RegionPreset = .defaultPreset
    ) {
        self.pipeline = pipeline
        self.ribbonState = ribbonState
        self.modelContext = modelContext
        self.usgsClient = usgsClient
        self.region = region
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
            for await trigger in pipeline.triggerStream {
                guard !Task.isCancelled else { break }
                await handleTrigger(trigger)
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

    // MARK: - Trigger Handling

    private func handleTrigger(_ trigger: TriggerEvent) async {
        let eventId = UUID()

        // Create and persist the SeismicEvent
        let seismicEvent = SeismicEvent(
            id: eventId,
            onsetTime: Date(timeIntervalSinceNow: -(CACurrentMediaTime() - trigger.onsetTimestamp)),
            peakAcceleration: trigger.peakAcceleration,
            dominantAxis: trigger.dominantAxis,
            staLtaRatio: trigger.staLtaRatio
        )
        modelContext.insert(seismicEvent)

        // Add a RibbonEvent (same UUID cross-references the SeismicEvent)
        let ribbonEvent = RibbonEvent(
            id: eventId,
            sampleIndex: ribbonState.samples.count,
            label: "Local vibration",
            isConfirmed: false,
            tintColor: SIMD4<Float>(0.5, 0.5, 0.5, 1)
        )
        ribbonState.activeEvents.append(ribbonEvent)

        // Fire USGS correlation asynchronously
        Task { [weak self] in
            await self?.correlate(seismicEvent: seismicEvent, ribbonEventId: eventId)
        }
    }

    // MARK: - USGS Correlation

    private func correlate(seismicEvent: SeismicEvent, ribbonEventId: UUID) async {
        do {
            let features = try await usgsClient.queryEvents(near: region, around: seismicEvent.onsetTime)
            if let match = USGSCorrelator.bestMatch(in: features, for: seismicEvent, near: region) {
                applyMatch(match, to: seismicEvent, ribbonEventId: ribbonEventId)
                return
            }
        } catch {
            // Log but treat as no-match so retry logic proceeds
            print("[EventCoordinator] USGS query error: \(error.localizedDescription)")
        }

        // Schedule retry if attempts remain
        if seismicEvent.retryCount < 3 {
            seismicEvent.retryCount += 1
            seismicEvent.lastRetryTime = Date()
            try? modelContext.save()

            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled else { return }
            await correlate(seismicEvent: seismicEvent, ribbonEventId: ribbonEventId)
        } else {
            // Exhausted retries — mark as timeout
            seismicEvent.correlationStatus = "timeout"
            try? modelContext.save()
        }
    }

    private func applyMatch(_ feature: USGSFeature, to event: SeismicEvent, ribbonEventId: UUID) {
        let coords = feature.geometry.coordinates
        let featureLat = coords.count > 1 ? coords[1] : 0
        let featureLon = coords.count > 0 ? coords[0] : 0
        let depthKm = coords.count > 2 ? Float(coords[2]) : nil

        event.correlationStatus = "matched"
        event.usgsEventId = feature.id
        event.usgsMagnitude = feature.properties.mag.map { Float($0) }
        event.usgsPlace = feature.properties.place
        event.usgsDepthKm = depthKm
        event.usgsDistanceKm = Float(USGSCorrelator.haversineKm(
            lat1: region.latitude, lon1: region.longitude,
            lat2: featureLat, lon2: featureLon
        ))
        event.usgsOriginTime = Date(timeIntervalSince1970: Double(feature.properties.time) / 1000.0)
        event.usgsEventURL = feature.properties.url
        try? modelContext.save()

        // Update the corresponding RibbonEvent label and tint
        if let index = ribbonState.activeEvents.firstIndex(where: { $0.id == ribbonEventId }) {
            let mag = event.usgsMagnitude.map { String(format: "M%.1f", $0) } ?? "M?"
            let place = event.usgsPlace ?? "Unknown location"
            ribbonState.activeEvents[index].label = "\(mag) — \(place)"
            ribbonState.activeEvents[index].isConfirmed = true
            ribbonState.activeEvents[index].tintColor = SIMD4<Float>(0.9, 0.2, 0.1, 1)
        }
    }
}
