import SwiftUI
import MetalKit

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
        // RibbonState is @Observable — renderer polls it each frame.
        // No SwiftUI-driven updates needed.
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
            let sampleCount = state.samples.count

            // The rightmost sample (newest) is at pixel viewWidth.
            // Sample at index i is at pixel: viewWidth - Float(sampleCount - 1 - i)
            // So the tapped sample index ≈ sampleCount - 1 - (viewWidth - tapX)
            let tappedSampleIndex = Int(Float(sampleCount - 1) - (viewWidth - tapX))

            // Find nearest active event within 20px
            let nearest = state.activeEvents.min {
                abs($0.sampleIndex - tappedSampleIndex) < abs($1.sampleIndex - tappedSampleIndex)
            }

            if let event = nearest, abs(event.sampleIndex - tappedSampleIndex) <= 20 {
                callback(event.id)
            }
        }
    }
}
