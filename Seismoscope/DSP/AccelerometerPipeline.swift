@preconcurrency import CoreMotion
import Foundation
import SeismoscopeKit

/// Manages the CMMotionManager → filter chain → STA/LTA pipeline.
/// Runs on a dedicated background DispatchQueue. Publishes via AsyncStream.
final class AccelerometerPipeline: @unchecked Sendable {
    private let motionManager: CMMotionManager
    private let queue = DispatchQueue(label: "com.seismoscope.pipeline", qos: .userInteractive)
    private let state: PipelineState

    let sampleStream: AsyncStream<AccelerometerSample>
    let triggerStream: AsyncStream<TriggerEvent>
    let stabilityStream: AsyncStream<Bool>

    private let sampleContinuation: AsyncStream<AccelerometerSample>.Continuation
    private let triggerContinuation: AsyncStream<TriggerEvent>.Continuation
    private let stabilityContinuation: AsyncStream<Bool>.Continuation

    init() {
        self.motionManager = CMMotionManager()
        self.state = PipelineState()

        let (sampleStream, sampleContinuation) = AsyncStream<AccelerometerSample>
            .makeStream(bufferingPolicy: .bufferingNewest(200))
        let (triggerStream, triggerContinuation) = AsyncStream<TriggerEvent>
            .makeStream(bufferingPolicy: .bufferingNewest(10))
        let (stabilityStream, stabilityContinuation) = AsyncStream<Bool>
            .makeStream(bufferingPolicy: .bufferingNewest(1))

        self.sampleStream = sampleStream
        self.triggerStream = triggerStream
        self.stabilityStream = stabilityStream
        self.sampleContinuation = sampleContinuation
        self.triggerContinuation = triggerContinuation
        self.stabilityContinuation = stabilityContinuation
    }

    func start() {
        motionManager.accelerometerUpdateInterval = 0.01 // 100Hz
        motionManager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            self.processSample(data)
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        sampleContinuation.finish()
        triggerContinuation.finish()
        stabilityContinuation.finish()
    }

    private func processSample(_ data: CMAccelerometerData) {
        let rawX = Float(data.acceleration.x)
        let rawY = Float(data.acceleration.y)
        let rawZ = Float(data.acceleration.z)
        let timestamp = data.timestamp

        state.process(
            rawX: rawX, rawY: rawY, rawZ: rawZ,
            timestamp: timestamp,
            sampleContinuation: sampleContinuation,
            triggerContinuation: triggerContinuation,
            stabilityContinuation: stabilityContinuation
        )
    }
}

// MARK: - Pipeline State (mutable, accessed from CMMotionManager callback queue)

private final class PipelineState: @unchecked Sendable {
    // Per-axis filter chains
    private var hpX = HighPassFilter(cutoffHz: 0.05, sampleRate: 100)
    private var hpY = HighPassFilter(cutoffHz: 0.05, sampleRate: 100)
    private var hpZ = HighPassFilter(cutoffHz: 0.05, sampleRate: 100)
    private var bpX = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: 100)
    private var bpY = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: 100)
    private var bpZ = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: 100)

    // STA/LTA detector
    private var detector = STALTADetector()

    // Stability detection (inline)
    private var stabilityRmsBuffer = [Float](repeating: 0, count: 200)
    private var stabilityHead = 0
    private var stableCount = 0
    private var lastStableState = false

    func process(
        rawX: Float, rawY: Float, rawZ: Float,
        timestamp: TimeInterval,
        sampleContinuation: AsyncStream<AccelerometerSample>.Continuation,
        triggerContinuation: AsyncStream<TriggerEvent>.Continuation,
        stabilityContinuation: AsyncStream<Bool>.Continuation
    ) {
        // Step 1: Highpass — remove gravity
        let hpXOut = hpX.process(rawX)
        let hpYOut = hpY.process(rawY)
        let hpZOut = hpZ.process(rawZ)

        // Step 2: Stability detection on Z axis (pre-bandpass)
        updateStability(hpZOut: hpZOut, continuation: stabilityContinuation)

        // Step 3: Bandpass — isolate 0.1–10Hz seismic band
        let bpXOut = bpX.process(hpXOut)
        let bpYOut = bpY.process(hpYOut)
        let bpZOut = bpZ.process(hpZOut)

        // Step 4: Create and publish sample
        let sample = AccelerometerSample(
            timestamp: timestamp,
            x: bpXOut,
            y: bpYOut,
            z: bpZOut
        )
        sampleContinuation.yield(sample)

        // Step 5: Compute magnitude and dominant axis
        let magnitude = sample.magnitude
        let dominantAxis = dominantAxisFor(x: bpXOut, y: bpYOut, z: bpZOut)

        // Step 6: Feed STA/LTA detector
        if let trigger = detector.process(
            magnitude: magnitude,
            timestamp: timestamp,
            dominantAxis: dominantAxis
        ) {
            triggerContinuation.yield(trigger)
        }
    }

    private func updateStability(
        hpZOut: Float,
        continuation: AsyncStream<Bool>.Continuation
    ) {
        // Store squared value for RMS computation
        stabilityRmsBuffer[stabilityHead] = hpZOut * hpZOut
        stabilityHead = (stabilityHead + 1) % 200

        // RMS over 200-sample (2-second) window
        let rmsSquared = stabilityRmsBuffer.reduce(0, +) / 200.0
        let rms = sqrt(rmsSquared)

        let wasStable = stableCount >= 300
        if rms > 0.005 {
            stableCount = 0
        } else {
            stableCount = min(stableCount + 1, 301)
        }
        let isStable = stableCount >= 300

        // Only emit on state change
        if isStable != wasStable {
            lastStableState = isStable
            continuation.yield(isStable)
        }
    }

    private func dominantAxisFor(x: Float, y: Float, z: Float) -> String {
        let absX = abs(x), absY = abs(y), absZ = abs(z)
        if absX >= absY && absX >= absZ { return "x" }
        if absY >= absX && absY >= absZ { return "y" }
        return "z"
    }
}
