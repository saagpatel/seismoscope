import MetalKit
import simd

@MainActor
final class RibbonRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let parchmentPipeline: MTLRenderPipelineState
    private let tracePipeline: MTLRenderPipelineState
    private let blurPipeline: MTLComputePipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let labelPipeline: MTLRenderPipelineState
    private let parchmentTexture: MTLTexture

    private var ribbonTexture: MTLTexture?
    private var traceTexture: MTLTexture?
    private var traceBlurredTexture: MTLTexture?

    private var uniformBuffers: [MTLBuffer]
    private var traceVertexBuffers: [MTLBuffer]
    private let bufferSemaphore = DispatchSemaphore(value: 3)
    private var bufferIndex = 0
    private let traceBufferCapacity = 8000

    private var scrollOffset: Float = 0
    private var previousTime: CFTimeInterval = 0
    private var startTime: CFTimeInterval = 0
    private var viewportSize: SIMD2<Float> = .zero

    var ribbonState: RibbonState?
    var textLabelCache: TextLabelCache?

    init(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.commandQueue = queue

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal shader library")
        }

        // Parchment pipeline
        let parchmentDesc = MTLRenderPipelineDescriptor()
        parchmentDesc.vertexFunction = library.makeFunction(name: "parchmentVertex")
        parchmentDesc.fragmentFunction = library.makeFunction(name: "parchmentFragment")
        parchmentDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.parchmentPipeline = try! device.makeRenderPipelineState(descriptor: parchmentDesc)

        // Trace pipeline (alpha blending)
        let traceDesc = MTLRenderPipelineDescriptor()
        traceDesc.vertexFunction = library.makeFunction(name: "traceVertex")
        traceDesc.fragmentFunction = library.makeFunction(name: "traceFragment")
        traceDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        traceDesc.colorAttachments[0].isBlendingEnabled = true
        traceDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        traceDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        traceDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        traceDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        self.tracePipeline = try! device.makeRenderPipelineState(descriptor: traceDesc)

        // Blur compute pipeline
        guard let blurFunction = library.makeFunction(name: "gaussianBlurHorizontal") else {
            fatalError("Failed to load gaussianBlurHorizontal compute function")
        }
        self.blurPipeline = try! device.makeComputePipelineState(function: blurFunction)

        // Composite pipeline
        let compositeDesc = MTLRenderPipelineDescriptor()
        compositeDesc.vertexFunction = library.makeFunction(name: "compositeVertex")
        compositeDesc.fragmentFunction = library.makeFunction(name: "compositeFragment")
        compositeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.compositePipeline = try! device.makeRenderPipelineState(descriptor: compositeDesc)

        // Label pipeline (alpha blending)
        let labelDesc = MTLRenderPipelineDescriptor()
        labelDesc.vertexFunction = library.makeFunction(name: "labelVertex")
        labelDesc.fragmentFunction = library.makeFunction(name: "labelFragment")
        labelDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        labelDesc.colorAttachments[0].isBlendingEnabled = true
        labelDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        labelDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        labelDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        labelDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        self.labelPipeline = try! device.makeRenderPipelineState(descriptor: labelDesc)

        // Generate parchment texture once
        self.parchmentTexture = TextureGenerator.generateParchmentTexture(device: device)

        // Triple-buffered uniforms
        let uniformSize = MemoryLayout<RibbonUniforms>.stride
        self.uniformBuffers = (0..<3).map { _ in
            device.makeBuffer(length: uniformSize, options: .storageModeShared)!
        }

        // Triple-buffered trace vertex buffers
        let vertexSize = traceBufferCapacity * MemoryLayout<TraceVertex>.stride
        self.traceVertexBuffers = (0..<3).map { _ in
            device.makeBuffer(length: vertexSize, options: .storageModeShared)!
        }

        super.init()
    }

    private func updateScroll() {
        let now = CACurrentMediaTime()
        if startTime == 0 { startTime = now }
        if previousTime > 0 {
            let deltaTime = Float(now - previousTime)
            scrollOffset += deltaTime * 1.0 // 1 px/sec
            scrollOffset = fmod(scrollOffset, 1024.0)
        }
        previousTime = now
    }

    private func updateUniforms() {
        var uniforms = RibbonUniforms(
            scrollOffset: scrollOffset,
            scrollRate: 1.0,
            viewportSize: viewportSize,
            traceYCenter: 0.5,
            time: Float(CACurrentMediaTime() - startTime),
            padding0: 0,
            padding1: 0
        )
        let buffer = uniformBuffers[bufferIndex]
        memcpy(buffer.contents(), &uniforms, MemoryLayout<RibbonUniforms>.stride)
    }

    private func generateTraceVertices() -> Int {
        guard let state = ribbonState else { return 0 }
        let samples = state.samples
        guard !samples.isEmpty else { return 0 }

        let visibleCount = min(samples.count, Int(viewportSize.x) + 2)
        let startIndex = max(0, samples.count - visibleCount)
        let vertexCount = visibleCount * 2

        guard vertexCount <= traceBufferCapacity else { return 0 }

        let buffer = traceVertexBuffers[bufferIndex]
        let vertices = buffer.contents().bindMemory(to: TraceVertex.self, capacity: vertexCount)

        let yCenter: Float = 0.0
        let pxToNDC_x: Float = 2.0 / viewportSize.x
        let pxToNDC_y: Float = 2.0 / viewportSize.y
        let subPixelOffset = fmod(scrollOffset, 1.0)

        for i in 0..<visibleCount {
            let magnitude = samples[startIndex + i]
            let pixelX = viewportSize.x - Float(visibleCount - 1 - i) - subPixelOffset
            let ndcX = pixelX * pxToNDC_x - 1.0

            let widthPx = min(max(abs(magnitude) * 400.0, 1.5), 8.0)
            let halfWidthNDC = (widthPx / 2.0) * pxToNDC_y

            let vi = i * 2
            vertices[vi] = TraceVertex(
                position: SIMD2<Float>(ndcX, yCenter + halfWidthNDC),
                alpha: 1.0,
                padding: 0
            )
            vertices[vi + 1] = TraceVertex(
                position: SIMD2<Float>(ndcX, yCenter - halfWidthNDC),
                alpha: 1.0,
                padding: 0
            )
        }

        return vertexCount
    }

    private func needsBlur() -> Bool {
        guard let state = ribbonState else { return false }
        let visibleCount = min(state.samples.count, Int(viewportSize.x) + 2)
        let startIndex = max(0, state.samples.count - visibleCount)
        let end = state.samples.count
        guard startIndex < end else { return false }
        return state.samples[startIndex..<end].contains { abs($0) > 0.005 }
    }

    private func rebuildOffscreenTextures(width: Int, height: Int) {
        guard width > 0, height > 0 else { return }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.storageMode = .private
        desc.usage = [.renderTarget, .shaderRead]

        ribbonTexture = device.makeTexture(descriptor: desc)
        traceTexture = device.makeTexture(descriptor: desc)

        desc.usage = [.shaderWrite, .shaderRead]
        traceBlurredTexture = device.makeTexture(descriptor: desc)
    }
}

extension RibbonRenderer: MTKViewDelegate {
    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MainActor.assumeIsolated {
            viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
            rebuildOffscreenTextures(width: Int(size.width), height: Int(size.height))
        }
    }

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            drawFrame(in: view)
        }
    }

    private func drawFrame(in view: MTKView) {
        guard bufferSemaphore.wait(timeout: .now() + .milliseconds(16)) == .success else { return }
        guard let drawable = view.currentDrawable,
              let ribbonTex = ribbonTexture,
              let traceTex = traceTexture,
              let blurTex = traceBlurredTexture else {
            bufferSemaphore.signal()
            return
        }

        updateScroll()
        updateUniforms()
        let vertexCount = generateTraceVertices()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            bufferSemaphore.signal()
            return
        }

        let currentBufferIndex = bufferIndex

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.bufferSemaphore.signal()
        }

        let uniformBuffer = uniformBuffers[currentBufferIndex]

        // Pass 1: Parchment background → ribbonTexture
        let parchmentPassDesc = MTLRenderPassDescriptor()
        parchmentPassDesc.colorAttachments[0].texture = ribbonTex
        parchmentPassDesc.colorAttachments[0].loadAction = .dontCare
        parchmentPassDesc.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: parchmentPassDesc) {
            encoder.setRenderPipelineState(parchmentPipeline)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(parchmentTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        // Pass 2: Trace polyline → traceTexture
        let tracePassDesc = MTLRenderPassDescriptor()
        tracePassDesc.colorAttachments[0].texture = traceTex
        tracePassDesc.colorAttachments[0].loadAction = .clear
        tracePassDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        tracePassDesc.colorAttachments[0].storeAction = .store

        if vertexCount > 0, let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: tracePassDesc) {
            encoder.setRenderPipelineState(tracePipeline)
            encoder.setVertexBuffer(traceVertexBuffers[currentBufferIndex], offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount)
            encoder.endEncoding()
        } else if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: tracePassDesc) {
            // Clear the trace texture even when no vertices
            encoder.endEncoding()
        }

        // Pass 3: Blur compute (conditional)
        let blurApplied: Bool
        if needsBlur(), let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(blurPipeline)
            encoder.setTexture(traceTex, index: 0)
            encoder.setTexture(blurTex, index: 1)
            let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadgroups = MTLSize(
                width: (traceTex.width + 15) / 16,
                height: (traceTex.height + 15) / 16,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
            blurApplied = true
        } else {
            blurApplied = false
        }

        // Pass 4: Composite → drawable
        let compositePassDesc = MTLRenderPassDescriptor()
        compositePassDesc.colorAttachments[0].texture = drawable.texture
        compositePassDesc.colorAttachments[0].loadAction = .dontCare
        compositePassDesc.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: compositePassDesc) {
            encoder.setRenderPipelineState(compositePipeline)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(ribbonTex, index: 0)
            encoder.setFragmentTexture(blurApplied ? blurTex : traceTex, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

            // Labels rendered here in Session 5
            if let cache = textLabelCache {
                renderTimeMarkerLabels(encoder: encoder, cache: cache)
            }

            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()

        bufferIndex = (bufferIndex + 1) % 3
    }

    private func renderTimeMarkerLabels(encoder: MTLRenderCommandEncoder, cache: TextLabelCache) {
        // Time marker labels will be implemented in Session 5
        // Each visible marker gets a cached text texture rendered as a quad
    }
}
