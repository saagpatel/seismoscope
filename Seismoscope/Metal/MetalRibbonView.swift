import MetalKit

final class MetalRibbonView: MTKView {
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        isOpaque = true
    }
}
