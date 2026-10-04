import SwiftUI
import MetalKit
import QuartzCore
import SeismoscopeKit

struct RibbonContainerView: UIViewRepresentable {
    let ribbonState: RibbonState
    /// Called when the user taps near a ribbon event annotation.
    var onEventTapped: ((UUID) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MetalRibbonView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        let renderer = RibbonRenderer(device: device)
        renderer.ribbonState = ribbonState
        renderer.textLabelCache = TextLabelCache(device: device)
        context.coordinator.renderer = renderer

        let view = MetalRibbonView(frame: .zero, device: device)
        view.delegate = renderer
        updateAccessibility(for: view, context: context)

        // Tap gesture to detect annotation touches
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.ribbonState = ribbonState
        context.coordinator.onEventTapped = onEventTapped

        return view
    }

    func updateUIView(_ uiView: MetalRibbonView, context: Context) {
        context.coordinator.onEventTapped = onEventTapped
        context.coordinator.ribbonState = ribbonState
        updateAccessibility(for: uiView, context: context)
    }

    private func updateAccessibility(for view: MetalRibbonView, context: Context) {
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Live seismogram"
        let eventCount = ribbonState.activeEvents.count
        view.accessibilityValue = eventCount == 1 ? "1 detected event" : "\(eventCount) detected events"
        view.accessibilityHint = eventCount == 0
            ? "The waveform updates continuously."
            : "Use the available actions to open an event."
        view.accessibilityCustomActions = ribbonState.activeEvents.suffix(20).reversed().map { event in
            let label = String(event.label.prefix(120))
            return UIAccessibilityCustomAction(name: "Open \(label)") { [weak coordinator = context.coordinator] _ in
                coordinator?.onEventTapped?(event.id)
                return coordinator?.onEventTapped != nil
            }
        }
    }

    @MainActor final class Coordinator {
        var renderer: RibbonRenderer?
        var ribbonState: RibbonState?
        var onEventTapped: ((UUID) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view,
                  let state = ribbonState,
                  let callback = onEventTapped else { return }

            let tapX = Float(gesture.location(in: view).x)
            let viewWidth = Float(view.bounds.width)
            let now = CACurrentMediaTime()
            func distance(to event: RibbonEvent) -> Float {
                guard state.traceSamples.indices.contains(event.sampleIndex) else { return .infinity }
                let timestamp = state.traceSamples[event.sampleIndex].timestamp
                let x = viewWidth - Float(RibbonTimeScale.distance(elapsedTime: now - timestamp))
                return abs(x - tapX)
            }

            // Match the renderer's time scale, with a 20-point touch tolerance.
            let nearest = state.activeEvents.min { distance(to: $0) < distance(to: $1) }
            if let event = nearest, distance(to: event) <= 20 {
                callback(event.id)
            }
        }
    }
}
