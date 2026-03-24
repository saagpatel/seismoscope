import SwiftUI
import MetalKit

struct RibbonContainerView: UIViewRepresentable {
    let ribbonState: RibbonState

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
        return view
    }

    func updateUIView(_ uiView: MetalRibbonView, context: Context) {
        // RibbonState is @Observable — renderer polls it each frame.
        // No SwiftUI-driven updates needed.
    }

    final class Coordinator {
        var renderer: RibbonRenderer?
    }
}
