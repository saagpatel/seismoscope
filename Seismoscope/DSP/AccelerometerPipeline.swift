@preconcurrency import CoreMotion
import Foundation
import os
import SeismoscopeKit

/// Manages the CMMotionManager → filter chain → STA/LTA pipeline.
/// Runs on a dedicated background DispatchQueue. Publishes via AsyncStream.
final class AccelerometerPipeline: @unchecked Sendable {
    static func detectorConfiguration(sampleRate: Double, threshold: Float) -> STALTADetector.Configuration {
        .init(
            staWindow: Int(sampleRate * 1.5),
            ltaWindow: Int(sampleRate * 45),
            threshold: threshold,
            rearmRatio: 1.5
        )
    }

    private let motionManager: CMMotionManager
    private let operationQueue: OperationQueue
    private let state: PipelineState

    let sampleStream: AsyncStream<AccelerometerSample>
    let triggerStream: AsyncStream<TriggerEvent>
    let stabilityStream: AsyncStream<Bool>

    private let sampleContinuation: AsyncStream<AccelerometerSample>.Continuation
    private let triggerContinuation: AsyncStream<TriggerEvent>.Continuation
    private let stabilityContinuation: AsyncStream<Bool>.Continuation

    // Thread-safe mailbox for threshold updates from the main actor.
    // The pipeline callback drains it at the top of each sample cycle.
    private let pendingThreshold = OSAllocatedUnfairLock<Float?>(initialState: nil)
    private let currentThreshold = OSAllocatedUnfairLock<Float>(initialState: 4)
    private let sampleInterval = OSAllocatedUnfairLock<TimeInterval>(initialState: 0.01)

    init() {
        self.motionManager = CMMotionManager()
        self.operationQueue = OperationQueue()
        self.operationQueue.name = "com.seismoscope.pipeline"
        self.operationQueue.qualityOfService = .userInteractive
        self.operationQueue.maxConcurrentOperationCount = 1
        self.state = PipelineState(sampleRate: 100)

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
        motionManager.accelerometerUpdateInterval = sampleInterval.withLock { $0 }
        motionManager.startAccelerometerUpdates(to: operationQueue) { [weak self] data, error in
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

    /// Updates the STA/LTA trigger threshold without restarting the pipeline.
    /// Safe to call from any thread; the update is applied before the next sample is processed.
    func updateThreshold(_ threshold: Float) {
        currentThreshold.withLock { $0 = threshold }
        pendingThreshold.withLock { $0 = threshold }
    }

    /// Switches between full-power (100Hz) and low-power (50Hz) accelerometer sampling.
    func setLowPowerMode(_ enabled: Bool) {
        let interval = enabled ? 0.02 : 0.01
        let sampleRate: Double = enabled ? 50 : 100
        sampleInterval.withLock { $0 = interval }
        motionManager.accelerometerUpdateInterval = interval
        operationQueue.addOperation { [state] in
            let threshold = self.currentThreshold.withLock { $0 }
            state.reconfigure(sampleRate: sampleRate, threshold: threshold)
        }
    }

    private func processSample(_ data: CMAccelerometerData) {
        // Apply any pending threshold update before processing
        if let t = pendingThreshold.withLock({ val -> Float? in let v = val; val = nil; return v }) {
            state.applyThreshold(t)
        }

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
    private var hpX: HighPassFilter
    private var hpY: HighPassFilter
    private var hpZ: HighPassFilter
    private var bpX: BandpassFilter
    private var bpY: BandpassFilter
    private var bpZ: BandpassFilter

    // STA/LTA detector
    private var detector: STALTADetector

    // Stability detection (inline)
    private var stabilityRmsBuffer: [Float]
    private var stabilityHead = 0
    private var stableCount = 0
    private var lastStableState = false
    private var stableSampleThreshold: Int

    init(sampleRate: Double) {
        hpX = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        hpY = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        hpZ = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        bpX = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        bpY = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        bpZ = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        detector = Self.makeDetector(sampleRate: sampleRate, threshold: 4)
        stabilityRmsBuffer = [Float](repeating: 0, count: Int(sampleRate * 2))
        stableSampleThreshold = Int(sampleRate * 3)
    }

    func reconfigure(sampleRate: Double, threshold: Float) {
        hpX = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        hpY = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        hpZ = HighPassFilter(cutoffHz: 0.05, sampleRate: sampleRate)
        bpX = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        bpY = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        bpZ = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: sampleRate)
        detector = Self.makeDetector(sampleRate: sampleRate, threshold: threshold)
        stabilityRmsBuffer = [Float](repeating: 0, count: Int(sampleRate * 2))
        stabilityHead = 0
        stableCount = 0
        lastStableState = false
        stableSampleThreshold = Int(sampleRate * 3)
    }

    private static func makeDetector(sampleRate: Double, threshold: Float) -> STALTADetector {
        STALTADetector(configuration: AccelerometerPipeline.detectorConfiguration(
            sampleRate: sampleRate,
            threshold: threshold
        ))
    }

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
        stabilityHead = (stabilityHead + 1) % stabilityRmsBuffer.count

        // RMS over 200-sample (2-second) window
        let rmsSquared = stabilityRmsBuffer.reduce(0, +) / Float(stabilityRmsBuffer.count)
        let rms = sqrt(rmsSquared)

        let wasStable = stableCount >= stableSampleThreshold
        if rms > 0.005 {
            stableCount = 0
        } else {
            stableCount = min(stableCount + 1, stableSampleThreshold + 1)
        }
        let isStable = stableCount >= stableSampleThreshold

        // Only emit on state change
        if isStable != wasStable {
            lastStableState = isStable
            continuation.yield(isStable)
        }
    }

    func applyThreshold(_ threshold: Float) {
        detector.updateThreshold(threshold)
    }

    private func dominantAxisFor(x: Float, y: Float, z: Float) -> String {
        let absX = abs(x), absY = abs(y), absZ = abs(z)
        if absX >= absY && absX >= absZ { return "x" }
        if absY >= absX && absY >= absZ { return "y" }
        return "z"
    }
}
