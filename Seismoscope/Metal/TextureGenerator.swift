import Metal

/// Generates a tileable 1024x1024 parchment texture with multi-octave value noise.
/// Called once at launch; the resulting MTLTexture is immutable.
enum TextureGenerator {

    static func generateParchmentTexture(device: MTLDevice) -> MTLTexture {
        let width = 1024
        let height = 1024
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 255, count: width * height * bytesPerPixel)

        // Base parchment color: RGB(242, 235, 200)
        let baseR: Float = 242
        let baseG: Float = 235
        let baseB: Float = 200

        for y in 0..<height {
            for x in 0..<width {
                let nx = Float(x) / Float(width)
                let ny = Float(y) / Float(height)

                // Layer 1: Large-scale paper variation
                let largeNoise = tiledFBM(x: nx, y: ny, octaves: 4,
                                          persistence: 0.5, lacunarity: 2.0,
                                          tileSize: 1.0)
                let largeContrib = (largeNoise - 0.5) * 0.08 * 255

                // Layer 2: High-frequency grain (scale x16)
                let grainNoise = tiledFBM(x: nx * 16, y: ny * 16, octaves: 2,
                                          persistence: 0.5, lacunarity: 2.0,
                                          tileSize: 16.0)
                let grainContrib = (grainNoise - 0.5) * 0.12 * 255

                let r = UInt8(clamping: Int(baseR + largeContrib + grainContrib))
                let g = UInt8(clamping: Int(baseG + largeContrib + grainContrib * 0.9))
                let b = UInt8(clamping: Int(baseB + largeContrib + grainContrib * 0.7))

                let offset = (y * width + x) * bytesPerPixel
                pixels[offset]     = b  // BGRA format
                pixels[offset + 1] = g
                pixels[offset + 2] = r
                pixels[offset + 3] = 255
            }
        }

        // Create texture
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.storageMode = .shared
        desc.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: desc) else {
            fatalError("Failed to create parchment texture")
        }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: width, height: height, depth: 1))
        texture.replace(region: region, mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: width * bytesPerPixel)

        return texture
    }

    // MARK: - Tileable Value Noise

    /// Fractional Brownian motion with tiling support.
    private static func tiledFBM(x: Float, y: Float, octaves: Int,
                                  persistence: Float, lacunarity: Float,
                                  tileSize: Float) -> Float {
        var total: Float = 0
        var amplitude: Float = 1.0
        var frequency: Float = 1.0
        var maxAmplitude: Float = 0

        for _ in 0..<octaves {
            total += tiledValueNoise(x: x * frequency, y: y * frequency,
                                     period: tileSize * frequency) * amplitude
            maxAmplitude += amplitude
            amplitude *= persistence
            frequency *= lacunarity
        }

        return total / maxAmplitude
    }

    /// 2D value noise that tiles seamlessly at the given period.
    private static func tiledValueNoise(x: Float, y: Float, period: Float) -> Float {
        let xi = Int(floor(x)) % Int(period)
        let yi = Int(floor(y)) % Int(period)
        let xf = x - floor(x)
        let yf = y - floor(y)

        let period_i = max(1, Int(period))
        let x0 = ((xi % period_i) + period_i) % period_i
        let y0 = ((yi % period_i) + period_i) % period_i
        let x1 = (x0 + 1) % period_i
        let y1 = (y0 + 1) % period_i

        let v00 = hash2D(x0, y0)
        let v10 = hash2D(x1, y0)
        let v01 = hash2D(x0, y1)
        let v11 = hash2D(x1, y1)

        let sx = smoothstep(xf)
        let sy = smoothstep(yf)

        let i0 = lerp(v00, v10, sx)
        let i1 = lerp(v01, v11, sx)
        return lerp(i0, i1, sy)
    }

    /// Deterministic hash returning a value in [0, 1].
    private static func hash2D(_ x: Int, _ y: Int) -> Float {
        var h = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        return Float(abs(h) % 65536) / 65535.0
    }

    private static func smoothstep(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }
}
