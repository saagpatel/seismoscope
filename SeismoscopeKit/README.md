# SeismoscopeKit

A standalone Swift package providing the DSP primitives behind the [Seismoscope](https://github.com/seismoscope) iOS app. Zero external dependencies. iOS 17+, Swift 5.9+.

---

## What's in the box

| Type | Description |
|------|-------------|
| `HighPassFilter` | 4-pole Butterworth highpass (2 cascaded biquads) |
| `BandpassFilter` | 4-pole Butterworth bandpass (HP + LP cascade) |
| `STALTADetector` | STA/LTA event detector with configurable threshold and hysteresis |
| `CircularBuffer<T>` | Thread-safe generic ring buffer |
| `AccelerometerSample` | Filtered 3-axis sample value type |
| `TriggerEvent` | Seismic event trigger value type |

---

## Installation

```swift
// Package.swift
.package(url: "https://github.com/seismoscope/seismoscope-kit", from: "0.1.0")
```

---

## Usage

### Butterworth Filters

```swift
import SeismoscopeKit

// Remove gravity from raw accelerometer data
var highpass = HighPassFilter(cutoffHz: 0.05, sampleRate: 100)

// Isolate the 0.1–10Hz seismic band
var bandpass = BandpassFilter(lowCutoffHz: 0.1, highCutoffHz: 10, sampleRate: 100)

let rawZ: Float = 0.012  // g
let hpOut = highpass.process(rawZ)   // gravity removed
let bpOut = bandpass.process(hpOut)  // seismic band isolated
```

All filter types are value types (`struct`) with mutable state. Call `reset()` to clear filter memory when restarting a stream.

### STA/LTA Detector

Short-Term Average / Long-Term Average ratio — the standard algorithm for automated seismic phase picking.

```swift
import SeismoscopeKit

var detector = STALTADetector(configuration: .init(
    staWindow:  150,   // 1.5 s at 100 Hz
    ltaWindow:  4500,  // 45 s at 100 Hz
    threshold:  4.0,   // fire when STA/LTA ≥ 4
    rearmRatio: 1.5    // re-arm when ratio drops below 1.5
))

// Feed one sample per accelerometer update
if let trigger = detector.process(
    magnitude: sample.magnitude,
    timestamp: sample.timestamp,
    dominantAxis: "z"
) {
    print("Event detected! STA/LTA = \(trigger.staLtaRatio)")
}

// Update threshold without resetting filter state
detector.updateThreshold(3.5)
```

**How it works:**

```
Magnitude  ─────────────────╮╭─────────────────────────────────
                             ││  Burst
0.001 g     ████████████████ ██████████ ████████████████████████
                                         LTA fills (45 s)
STA/LTA     1.0 ─────────────────────────────────╮  threshold
                                                 ▲ 4.0
                                          TRIGGER╯
```

The detector stays in a **filling phase** for the first `ltaWindow` samples (45 s at 100 Hz) and will not fire during this period. After filling, it fires on the rising edge when `STA/LTA ≥ threshold` and re-arms once the ratio drops below `rearmRatio`.

### Circular Buffer

```swift
import SeismoscopeKit

let buffer = CircularBuffer<Float>(capacity: 12_000, defaultValue: 0)

buffer.append(0.003)
buffer.append(0.004)

let recent = buffer.last(100)  // last 100 samples, chronological order
print(buffer.count)            // 2
print(buffer.isFull)           // false
```

Thread-safe. Uses `NSLock` internally. `append` and `last(_:)` are both safe to call from concurrent queues.

---

## Running Tests

```bash
cd SeismoscopeKit
swift test
```

Tests cover: Butterworth frequency response (passband + stopband), highpass DC removal, circular buffer overflow and concurrency, STA/LTA trigger detection with impulse/noise/rearm scenarios.

---

## License

MIT. See [LICENSE](../LICENSE).
