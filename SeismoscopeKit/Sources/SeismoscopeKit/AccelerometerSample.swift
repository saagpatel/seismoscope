import Foundation

public struct AccelerometerSample: Sendable {
    public let timestamp: TimeInterval
    public let x: Float
    public let y: Float
    public let z: Float
    public var magnitude: Float { sqrt(x * x + y * y + z * z) }
    public var milliG: Float { magnitude * 1000 }

    public init(timestamp: TimeInterval, x: Float, y: Float, z: Float) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }
}
