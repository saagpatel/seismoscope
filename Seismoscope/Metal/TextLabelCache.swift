import Metal
import CoreText
import CoreGraphics

/// Renders text strings to MTLTextures via Core Text, with an LRU cache.
/// Labels change once per minute — regeneration cost is negligible.
@MainActor
final class TextLabelCache {
    private let device: MTLDevice
    private var cache: [(key: String, texture: MTLTexture)] = []
    private let maxEntries = 20

    init(device: MTLDevice) {
        self.device = device
    }

    func texture(for label: String) -> MTLTexture? {
        // Check cache (LRU: move to end on access)
        if let index = cache.firstIndex(where: { $0.key == label }) {
            let entry = cache.remove(at: index)
            cache.append(entry)
            return entry.texture
        }

        // Render new label texture
        guard let texture = renderLabel(label) else { return nil }

        // Evict oldest if at capacity
        if cache.count >= maxEntries {
            cache.removeFirst()
        }
        cache.append((key: label, texture: texture))

        return texture
    }

    private func renderLabel(_ text: String) -> MTLTexture? {
        let font = CTFontCreateWithName("SFMono-Regular" as CFString, 9, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        let width = Int(ceil(bounds.width)) + 4  // padding
        let height = Int(ceil(bounds.height)) + 4
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Clear to transparent
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw text
        context.textPosition = CGPoint(x: 2, y: 2 - bounds.origin.y)
        CTLineDraw(line, context)

        guard let data = context.data else { return nil }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.storageMode = .shared
        desc.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        let region = MTLRegion(origin: .init(x: 0, y: 0, z: 0),
                               size: .init(width: width, height: height, depth: 1))
        texture.replace(region: region, mipmapLevel: 0,
                        withBytes: data, bytesPerRow: bytesPerRow)

        return texture
    }
}
