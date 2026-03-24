# Seismoscope — Implementation Roadmap

## Architecture

### System Overview
```
[CMMotionManager @ 100Hz]
        ↓ raw CMAcceleration (x, y, z) — background DispatchQueue
[AccelerometerPipeline]
  ├── HighPassFilter     (removes gravity, cutoff 0.05Hz, 4-pole Butterworth)
  ├── BandpassFilter     (0.1–10Hz, 4-pole Butterworth)
  ├── CircularBuffer     (12,000 samples × 3 axes, os_unfair_lock)
  └── STALTADetector     (STA=150 samples, LTA=4500 samples, threshold=4.0)
        ↓ TriggerEvent on rising edge crossing
[EventCoordinator]
  ├── Creates SeismicEvent → SwiftData (status: "pending")
  ├── Publishes RibbonEvent → RibbonState @Observable
  └── Fires USGSQueryTask(async, retry ×3 every 120s)
        ↓ GeoJSON
[USGSCorrelator]
  ├── Match: |event.time - usgs.time| < 10min AND distance < 500km AND mag > 1.5
  └── Updates SeismicEvent → "matched" | "local" | "timeout"
[MetalRibbonView] ← polls RibbonState @Observable at 60fps
  ├── ScrollingTextureRenderer   (procedural parchment, MTLTexture 1024×1024)
  ├── TraceRenderer              (polyline, width ∝ |magnitude|, ink bleed blur)
  ├── TimeMarkerRenderer         (vertical lines every 60px, timestamps)
  └── EventAnnotationRenderer    (leader lines + cached MTLTexture labels)
[SwiftUI Shell]
  ├── RibbonContainerView        (UIViewRepresentable → MetalRibbonView)
  ├── StatusBarView              (stability indicator, live milli-g, MMI label)
  ├── SettingsView               (region picker, sensitivity slider, units toggle)
  └── EventDetailView            (sheet: tap annotation → full event data)
```

### File Structure
```
Seismoscope/
├── Seismoscope.xcodeproj
├── CLAUDE.md
├── IMPLEMENTATION-ROADMAP.md
├── Seismoscope/
│   ├── App/
│   │   ├── SeismoscopeApp.swift          # @main, SwiftData ModelContainer setup
│   │   └── AppState.swift                # @Observable global — stability, activeRegion, sensitivity
│   ├── Views/
│   │   ├── RibbonContainerView.swift     # UIViewRepresentable wrapping MetalRibbonView
│   │   ├── StatusBarView.swift           # isStable indicator, currentAccel, MMI label
│   │   ├── SettingsView.swift            # Region picker, sensitivity slider, units toggle
│   │   └── EventDetailView.swift         # Sheet on annotation tap
│   ├── Metal/
│   │   ├── MetalRibbonView.swift         # MTKView subclass, CADisplayLink render loop
│   │   ├── RibbonRenderer.swift          # MTLCommandBuffer assembly, render pass descriptors
│   │   ├── Shaders.metal                 # All MSL: parchment, trace, blur compute, markers
│   │   ├── TextureGenerator.swift        # One-time CPU parchment texture → MTLTexture
│   │   └── RibbonState.swift             # @Observable: samples [Float], activeEvents [RibbonEvent]
│   ├── DSP/
│   │   ├── AccelerometerPipeline.swift   # CMMotionManager → filter chain → CircularBuffer → STALTA
│   │   ├── StabilityDetector.swift       # RMS(>10Hz) rolling 2s window → isStable Bool
│   │   └── SyntheticDataSource.swift     # Sine/noise/impulse generator for Phase 0 testing
│   ├── USGS/
│   │   ├── USGSClient.swift              # URLSession FDSN wrapper; protocol for mocking
│   │   ├── USGSCorrelator.swift          # Time+distance matching, deferred retry coordinator
│   │   └── USGSModels.swift              # Codable structs for GeoJSON response
│   ├── Models/
│   │   ├── SeismicEvent.swift            # SwiftData @Model
│   │   └── RegionPreset.swift            # Codable struct + bundled city list
│   └── Resources/
│       ├── regions.json                  # 50 city presets with lat/lng
│       └── device_profiles.json          # modelIdentifier → thresholdMultiplier
├── SeismoscopeKit/
│   ├── Package.swift                     # platforms: [.iOS(.v17)], no dependencies
│   ├── Sources/SeismoscopeKit/
│   │   ├── ButterworthFilter.swift       # 4-pole IIR: HighPassFilter + BandpassFilter
│   │   ├── STALTADetector.swift          # STA/LTA trigger, re-arm logic
│   │   ├── CircularBuffer.swift          # Generic ring buffer, os_unfair_lock
│   │   └── SeismicClassifier.swift       # Waveform shape second-stage filter (onset slope)
│   └── Tests/SeismoscopeKitTests/
│       ├── ButterworthFilterTests.swift
│       ├── STALTADetectorTests.swift
│       └── CircularBufferTests.swift
└── SeismoscopeTests/
    └── USGSCorrelatorTests.swift
```

### Data Model (SwiftData)

```swift
// Seismoscope/Models/SeismicEvent.swift
import SwiftData
import Foundation

@Model
class SeismicEvent {
    var id: UUID
    var onsetTime: Date
    var duration: TimeInterval           // seconds, onset to sub-threshold
    var peakAcceleration: Float          // |vector magnitude| peak, in milli-g
    var dominantAxis: String             // "x" | "y" | "z"
    var staLtaRatio: Float               // ratio at trigger point
    var correlationStatus: String        // "pending" | "matched" | "local" | "timeout"
    var usgsEventId: String?
    var usgsMagnitude: Float?
    var usgsPlace: String?               // e.g. "47km NE of San Jose, CA"
    var usgsDistanceKm: Float?
    var usgsDepthKm: Float?
    var usgsOriginTime: Date?
    var usgsEventURL: String?            // USGS detail page URL
    var lastRetryTime: Date?
    var retryCount: Int                  // max 3

    init(
        id: UUID = UUID(),
        onsetTime: Date,
        duration: TimeInterval = 0,
        peakAcceleration: Float = 0,
        dominantAxis: String = "z",
        staLtaRatio: Float = 0,
        correlationStatus: String = "pending",
        retryCount: Int = 0
    ) {
        self.id = id
        self.onsetTime = onsetTime
        self.duration = duration
        self.peakAcceleration = peakAcceleration
        self.dominantAxis = dominantAxis
        self.staLtaRatio = staLtaRatio
        self.correlationStatus = correlationStatus
        self.retryCount = retryCount
    }
}
```

### Type Definitions

```swift
// Accelerometer pipeline output — flows from DSP layer to RibbonState
struct AccelerometerSample: Sendable {
    let timestamp: TimeInterval   // CMAccelerometerData.timestamp (device uptime)
    let x: Float                  // bandpass-filtered, gravity removed, in g
    let y: Float
    let z: Float
    var magnitude: Float { sqrt(x*x + y*y + z*z) }
    var milliG: Float { magnitude * 1000 }
}

// STA/LTA detector output
struct TriggerEvent: Sendable {
    let onsetTimestamp: TimeInterval
    let staLtaRatio: Float
    let dominantAxis: String             // "x" | "y" | "z" — highest variance axis
    let peakAcceleration: Float          // in milli-g
    let windowSamples: [Float]           // 10s of magnitude samples centered on onset
}

// Drives Metal annotation renderer
struct RibbonEvent: Identifiable {
    let id: UUID
    let sampleIndex: Int                 // index into RibbonState.samples where event starts
    var label: String                    // "M4.2 — San Jose, CA" or "Local vibration"
    var isConfirmed: Bool                // false = pending, true = resolved
    var tintColor: SIMD4<Float>          // warm red [1,0.2,0.1,1] for quake; gray [0.5,0.5,0.5,1] for local
}

// RibbonState — @Observable, consumed by MetalRibbonView at 60fps
@Observable
class RibbonState {
    var samples: [Float] = []            // magnitude trace, last 120s at 100Hz = 12,000 Floats max
    var activeEvents: [RibbonEvent] = []
    var currentAcceleration: Float = 0   // in milli-g, for StatusBarView
    var isStable: Bool = false
}

// RegionPreset — bundled + user-custom
struct RegionPreset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let name: String                     // "San Francisco, CA"
    let latitude: Double
    let longitude: Double
    var isCustom: Bool = false
}

// USGS API response shapes (Codable)
struct USGSFeatureCollection: Codable {
    let features: [USGSFeature]
}
struct USGSFeature: Codable {
    let id: String
    let properties: USGSProperties
    let geometry: USGSGeometry
}
struct USGSProperties: Codable {
    let mag: Double?
    let place: String?
    let time: Int64                      // epoch milliseconds
    let url: String?
}
struct USGSGeometry: Codable {
    let coordinates: [Double]            // [longitude, latitude, depth_km]
}

// USGSClient protocol — enables MockUSGSClient in tests and Debug injection
protocol USGSClientProtocol {
    func queryEvents(near region: RegionPreset, around date: Date) async throws -> [USGSFeature]
}
```

### API Contract

| Service | Endpoint | Method | Auth | Rate Limit | Purpose |
|---------|----------|--------|------|------------|---------|
| USGS FDSN | `https://earthquake.usgs.gov/fdsnws/event/1/query` | GET | None | ~1 req/sec recommended | Earthquake search by time + radius |

**Query parameters:**
```
format=geojson
starttime=<ISO8601: onset - 600 seconds>
endtime=<ISO8601: onset + 1800 seconds>
latitude=<RegionPreset.latitude>
longitude=<RegionPreset.longitude>
maxradiuskm=500
minmagnitude=1.5
orderby=time
limit=20
```

**Error handling:**
- HTTP 200 + empty features: no match yet — schedule retry
- HTTP 400: log + skip retry (bad parameters)
- HTTP 429: `Task.sleep(for: .seconds(60))` then retry once
- Timeout (>10s): mark attempt as failed, schedule next retry per normal cadence
- URLError (no network): schedule retry; show "Offline" indicator in StatusBarView

### Dependencies

```bash
# No external dependencies. All Apple system frameworks.
# Xcode 15.2+ required (Swift 5.9, @Observable macro, SwiftData stable)

# System frameworks to link in Xcode target (Build Phases → Link Binary With Libraries):
# CoreMotion.framework
# Metal.framework
# MetalKit.framework
# SwiftData.framework  (auto-linked on iOS 17+)

# SeismoscopeKit — add as local package:
# File → Add Package Dependencies → Add Local → select SeismoscopeKit/ folder
# No `swift package add` required
```

---

## Scope Boundaries

**In scope (v1):**
- Full Metal ribbon renderer with procedural parchment texture
- 100Hz CoreMotion pipeline with 4-pole Butterworth filter chain
- STA/LTA event detection with two-stage waveform shape classifier
- USGS FDSN Event API cross-reference with deferred retry correlation
- SwiftData event log (on-device only)
- Settings: region picker (50 presets + custom), sensitivity slider, units toggle, low-power mode
- Device profile table (modelIdentifier → STA/LTA threshold multiplier)
- SeismoscopeKit Swift Package, standalone, MIT licensed
- App Store submission (free, no IAP, no ads)

**Out of scope (v1):**
- Background motion recording — foreground only
- iCloud sync
- Distributed detection network / anonymized data sharing
- Apple Watch companion
- Spectral analysis view
- Event history archive with date navigation
- Push notifications

**Deferred to v1.1:**
- Background recording via `BGProcessingTask`
- Event history archive (scroll back days)
- Apple Watch complication

---

## Security & Credentials

- No credentials. USGS API is unauthenticated.
- No user data leaves the device. The only outbound call is the read-only USGS query (sends: region lat/lng, time window, minmagnitude). Never sends device ID, user info, or precise location.
- No CoreLocation. Region is user-configured via city picker — GPS is never accessed.
- SwiftData lives in app sandbox only (`~/Library/Application Support`). No iCloud sync in v1.
- **Required Info.plist key:**
  - `NSMotionUsageDescription`: `"Seismoscope uses your iPhone's accelerometer to detect ground vibrations and display them as a seismogram."`
  - No location, camera, microphone, or photo library keys needed.
- No background mode entitlements in v1.

---

## Phase 0: Metal Ribbon Renderer (Weeks 1–2)

**Objective:** Full Metal pipeline rendering at 60fps with synthetic sine wave input. Procedural parchment texture, variable-width ink trace, Gaussian blur bleed, time markers. No CoreMotion, no SwiftData, no USGS in this phase.

**Tasks:**

1. **Xcode project scaffold** — Create iOS App target (Swift, SwiftUI, minimum iOS 17.0). Add SeismoscopeKit as local package (File → Add Package Dependencies → Add Local). Link Metal + MetalKit frameworks. Add `SeismoscopeApp.swift` with placeholder `ModelContainer` commented out. Add `SyntheticDataSource.swift` with a configurable waveform generator (sine, white noise, impulse).
   **Acceptance:** `cmd+B` → zero errors, zero warnings on a clean checkout. App launches on simulator to a blank screen (no crash).

2. **Procedural parchment texture** — `TextureGenerator.swift`. Generate a 1024×1024 `MTLTexture` once at launch on the CPU. Algorithm: base color `RGB(242, 235, 200)`. Layer 1: multi-octave value noise (4 octaves, persistence 0.5, lacunarity 2.0) at 8% opacity for large-scale paper variation. Layer 2: high-frequency noise (scale ×16) at 12% opacity for grain. Write pixels to a `MTLBuffer`, blit to texture via `MTLBlitCommandEncoder`. Texture is immutable after creation.
   **Acceptance:** Texture visible in a standalone `MTKView` — looks like aged paper at 1× and 2× zoom. Does NOT look like a solid flat color or uniform gradient.

3. **Scrolling ribbon render loop** — `MetalRibbonView.swift` (MTKView subclass, `isPaused = false`, `enableSetNeedsDisplay = false`). `RibbonRenderer.swift` manages the `MTLCommandBuffer`. Each frame: translate the background texture leftward by `deltaTime × 1.0` pixels (1px/sec). Use texture coordinates to tile the 1024px-wide texture seamlessly — do not redraw it each frame. Time markers are a separate pass (see task 5).
   **Acceptance:** Parchment scrolls continuously at 60fps. No tearing. Xcode GPU Frame Capture shows < 2ms GPU frame time on a physical iPhone 14+.

4. **Trace renderer** — MSL vertex + fragment shaders in `Shaders.metal`. Input: `MTLBuffer` of `Float` magnitude values (updated each frame from `RibbonState.samples`). Output: polyline strip centered on the ribbon's midpoint. Vertex width: `clamp(abs(magnitude) × 400, 1.5, 8.0)` pixels. For samples where `abs(magnitude) > 0.005` (5 milli-g): apply a separate compute pass — 1D Gaussian blur (σ = 1.5px, 5-tap kernel) along the trace. Use a separate `MTLTexture` as blur target; composite onto ribbon in the final pass. Ink color: `RGB(20, 15, 10)` (near-black, warm).
   **Acceptance:** `SyntheticDataSource` set to 1Hz sine at 0.02g amplitude → trace draws a recognizable sine wave, ink bleed activates at peaks, line visibly thickens at peaks vs. troughs.

5. **Time markers** — Separate render pass. Thin vertical lines (0.5px wide, `RGBA(20,15,10,0.35)`) at every 60 pixels (= every 60 seconds of scroll). Timestamp labels use Core Text rendered to a cached `MTLTexture` per label string. Labels use SF Mono 9pt, positioned 4px above the trace midpoint. Label content: current wall-clock time minus elapsed offset (e.g., "14:32").
   **Acceptance:** Run app for 3 minutes → see 3 visible time markers at correct 1-minute intervals. Label text is legible at 1×.

6. **`SyntheticDataSource` completion** — Implement three modes: `sine(frequency: Float, amplitude: Float)`, `noise(amplitude: Float)`, `impulse(peakAmplitude: Float, duration: TimeInterval)`. Mode switchable at runtime via a debug `#if DEBUG` overlay button. Feed samples into `RibbonState` via a 100Hz timer (`DispatchSourceTimer` on background queue, fires every 10ms).
   **Acceptance:** Switch between all three modes — ribbon visually distinguishes them. Sine looks regular, noise looks chaotic, impulse shows a single spike then returns to flat.

**Verification Checklist:**
- [ ] `cmd+B` on clean clone → zero warnings, zero errors
- [ ] Launch on iOS 17+ simulator → no crash, blank parchment visible
- [ ] Launch on physical device → GPU trace < 2ms/frame (Instruments → GPU)
- [ ] Sine input (1Hz, 0.02g) → recognizable sine wave on ribbon
- [ ] Impulse input → single spike with ink bleed, returns to flat
- [ ] 3-minute run → exactly 3 time markers, correctly timestamped
- [ ] Parchment texture convincing — grain visible at 2× zoom

**Risks:**
- Gaussian blur pass tanks framerate → use a compute shader, not a render pass. Only blur the trace layer (not background). Fallback: drop blur, thicken line at high amplitude only.
- Core Text label rendering to MTLTexture is complex → build `TextLabelCache: [String: MTLTexture]` that caches by label string. Labels only change once per minute — regeneration cost is negligible.

---

## Phase 1: CoreMotion DSP Pipeline (Weeks 3–4)

**Objective:** Real 100Hz accelerometer data flowing through filter chain into the ribbon. STA/LTA triggering on desk taps. Stability detector working. Replace `SyntheticDataSource` with live `AccelerometerPipeline`.

**Tasks:**

1. **SeismoscopeKit: `ButterworthFilter`** — 4-pole IIR filter in Direct Form II Transposed structure. Implement `HighPassFilter(cutoffHz: Double, sampleRate: Double)` and `BandpassFilter(lowCutoffHz: Double, highCutoffHz: Double, sampleRate: Double)`. Compute coefficients via bilinear transform (pre-warp the analog cutoff frequencies: `ωd = 2π × fc / fs`, `ωa = 2 × fs × tan(ωd/2)`). Store 4 delay states per filter instance. `process(_ sample: Float) -> Float` — O(1) per sample. Document the exact coefficient math in comments with the transfer function.
   **Acceptance:** `swift test` → `ButterworthFilterTests.testBandpassFrequencyResponse`: feed 1,000 samples of 0.5Hz sine (amplitude 1.0, sampleRate 100Hz) through bandpass(0.1–10Hz) → output RMS within ±5% of input RMS. Feed 1,000 samples of 50Hz sine → output RMS < 1% of input RMS. `testHighPassFrequencyResponse`: DC offset 1.0 through highpass(0.05Hz) → output converges to < 0.01 after 500 samples.

2. **SeismoscopeKit: `CircularBuffer<T>`** — Generic ring buffer. Internal: `[T]` of fixed capacity, head index `Int`, `os_unfair_lock` for thread safety. `append(_ element: T)` — O(1). `last(_ n: Int) -> [T]` — returns most recent n elements in order, O(n). `count: Int` — current fill level.
   **Acceptance:** `CircularBufferTests.testConcurrentReadWrite`: 4 concurrent writers appending 2,500 Floats each, 2 concurrent readers calling `last(100)` in a loop. Run 100 iterations via `DispatchQueue.concurrentPerform`. No crashes, no data races (run with Thread Sanitizer enabled).

3. **SeismoscopeKit: `STALTADetector`** — STA/LTA on scalar (magnitude) stream. Parameters: `staWindow: Int = 150`, `ltaWindow: Int = 4500`, `threshold: Float = 4.0`, `rearmRatio: Float = 1.5`. State: maintains running STA and LTA via incremental update (subtract oldest, add newest — O(1) per sample using circular buffers for STA and LTA windows separately). Emits `TriggerEvent` on rising edge (ratio crosses threshold). Re-arms when ratio drops below `rearmRatio`. Does NOT emit multiple events for sustained high amplitude.
   **Acceptance:** `testTriggerOnImpulse`: 90s noise floor (amplitude 0.001g) followed by 3s burst (0.02g) → exactly 1 TriggerEvent, onset within ±2 samples of burst start. `testNoTriggerOnNoise`: 60s white noise at 0.001g → 0 TriggerEvents. `testRearm`: two separated 3s bursts, 10s apart → exactly 2 TriggerEvents.

4. **`AccelerometerPipeline`** — `CMMotionManager` on a background `DispatchQueue` (not main). `accelerometerUpdateInterval = 0.01` (100Hz). Each callback: extract `CMAccelerometerData.acceleration` → cast to Float → run through HighPassFilter(0.05Hz) per axis → run through BandpassFilter(0.1–10Hz) per axis → append to CircularBuffer → compute magnitude → feed magnitude to STALTADetector. Publish samples via `AsyncStream<AccelerometerSample>`. Publish triggers via `AsyncStream<TriggerEvent>`. Expose `start()` and `stop()` — call `stop()` in `scenePhase == .background`.
   **Acceptance:** Physical device, phone on desk, 60-second run → zero TriggerEvents. Firm desk tap → TriggerEvent emitted, onset within 500ms of tap.

5. **`StabilityDetector`** — Parallel to the main filter chain. Tap into the raw (high-pass only, pre-bandpass) samples. Compute RMS over a 200-sample (2-second) rolling window on the Z axis. If `RMS > 0.005g`, `isStable = false`; if `RMS ≤ 0.005g` for 300 consecutive samples (3 seconds), `isStable = true`. Publish `Bool` via `@Observable` property on `AppState`.
   **Acceptance:** Hold phone in hand → `isStable = false` within 1 second. Place flat on desk, wait 3 seconds → `isStable = true`. StatusBarView shows "Place phone on a stable surface" warning when false.

6. **Wire pipeline to ribbon** — `EventCoordinator` (actor or `@MainActor` class) subscribes to both `AsyncStream`s from `AccelerometerPipeline`. Sample stream: append `sample.magnitude` to `RibbonState.samples` on main actor (drop oldest when `samples.count > 12,000`). Trigger stream: create `SeismicEvent` in SwiftData (Phase 2 wires the full USGS flow; for now, set `correlationStatus = "local"` as placeholder), add `RibbonEvent` to `RibbonState.activeEvents`.
   **Acceptance:** Phone on desk → ribbon shows near-flat trace with micro-tremor visible. Walk past desk (3m) → trace deflects, returns to baseline within 5 seconds. Desk tap → spike visible on ribbon within 500ms.

**Verification Checklist:**
- [ ] `swift test` in SeismoscopeKit → all 7 unit tests pass (0 failures, 0 skips)
- [ ] Thread Sanitizer enabled, `testConcurrentReadWrite` → no data races
- [ ] Physical device, 60-second desk test → zero TriggerEvents logged
- [ ] Physical device, single firm desk tap → exactly 1 TriggerEvent, ribbon spike visible
- [ ] `isStable` transitions correct (hold → false in <1s, desk → true in <3s)
- [ ] Instruments → no memory leaks in pipeline after 5 minutes

**Risks:**
- IIR coefficients subtly wrong → verify against `scipy.signal.butter` in Python before implementing. Add a `debugFrequencyResponse() -> [(hz: Float, magnitude: Float)]` method to the filter for validation. Fallback: simple moving average difference (weaker frequency response but correct behavior).
- `AsyncStream` backpressure at 100Hz → use `AsyncStream(bufferingPolicy: .bufferingNewest(200))` to drop old samples rather than block.

---

## Phase 2: USGS Cross-Reference + Event Annotation (Weeks 5–6)

**Objective:** Detected events query USGS with deferred retry. Matched earthquakes annotated on ribbon with magnitude + place. Local vibrations labeled as such. `EventDetailView` shows full data on tap.

**Tasks:**

1. **SwiftData event store wiring** — Enable `ModelContainer` in `SeismoscopeApp.swift`. Update `EventCoordinator` to properly persist `SeismicEvent` via `ModelContext` (inject context via dependency). Fetch active events on app launch and restore `RibbonState.activeEvents` for any events in the last 120 seconds.
   **Acceptance:** Trigger 3 desk taps → stop app → relaunch → 3 `SeismicEvent` records in SwiftData store (verify in Xcode data browser or with a debug list view). Events within the last 120s appear on the ribbon after relaunch.

2. **`USGSClient`** — Conforms to `USGSClientProtocol`. Builds URL from query parameters table above. Sends `URLRequest` with 10-second timeout. Decodes `USGSFeatureCollection` via `JSONDecoder`. Throws `USGSError` enum: `httpError(Int)`, `decodingError`, `networkError(URLError)`, `rateLimited`. Implements HTTP 429 handling: `Task.sleep(for: .seconds(60))`, retry once, then throw `rateLimited`.
   **Acceptance:** Call with `RegionPreset(name: "San Jose", latitude: 37.33, longitude: -121.89)` and `date: Date()` → returns `[USGSFeature]` array without crash. Call with intentionally bad lat/lng → throws `httpError(400)`.

3. **`USGSCorrelator`** — Match algorithm on `[USGSFeature]` against a `SeismicEvent`. Match if ALL of: (a) `abs(feature.time_ms - event.onsetTime.ms) < 600_000` (10 minutes), (b) `feature.mag ?? 0 >= 1.5`, (c) Haversine distance from `RegionPreset` to feature coordinates < 500km. Haversine implementation inline (no external math). If match found: update `SeismicEvent` with all USGS fields, set `correlationStatus = "matched"`, update `RibbonEvent.label` and `tintColor`.
   **Acceptance:** Unit test — synthetic feature at onset +3min, 120km, M2.5 → match. Feature at onset +15min → no match. Feature at 600km → no match. Feature M1.0 → no match.

4. **Deferred retry coordinator** — In `EventCoordinator`. After initial query: if no match and `event.retryCount < 3`, `Task { await Task.sleep(for: .seconds(120)); retryCorrelation(event) }`. Increment `retryCount` and update `lastRetryTime` each attempt. After 3 attempts with no match: `event.correlationStatus = "timeout"`, `RibbonEvent` updates to "Local vibration" label.
   **Acceptance:** Unit test with `MockUSGSClient` returning empty on calls 1–2, match on call 3 → `correlationStatus` transitions `pending → pending → matched`. Verify via published `SeismicEvent` state.

5. **`EventAnnotationRenderer`** — New render pass in `RibbonRenderer`. For each `RibbonEvent` in `RibbonState.activeEvents`: draw a 0.5px vertical leader line from trace midpoint upward 24px at `sampleIndex` pixel offset. Render the label string to a `MTLTexture` via Core Text (cache by label string in `TextLabelCache`). Composite label texture above leader line. Animate opacity from 0→1 over 30 frames (0.5s at 60fps) on first appearance by tracking `framesSinceAdded` per event. Tint via `RibbonEvent.tintColor` as a uniform in the fragment shader.
   **Acceptance:** Inject a mock matched `SeismicEvent` via Debug Settings toggle → label "M4.2 — San Jose, CA" appears at correct sample position in warm red within 1 frame. Inject a local event → gray label "Local vibration". Fade-in animation is visible (not instantaneous).

6. **`EventDetailView`** — SwiftUI `sheet`. Triggered by `AppState.selectedEventId` when user taps an annotation (tap gesture on `RibbonContainerView` → find nearest `RibbonEvent` within 20px → set `selectedEventId`). Shows: onset time (formatted), duration (e.g. "4.2s"), peak acceleration (milli-g + plain language), correlation status. If matched: USGS magnitude, place, depth, distance, `Link("View on USGS", destination: usgsEventURL)`. If local/timeout: "No earthquake match found within 30 minutes."
   **Acceptance:** Tap matched event annotation → sheet slides up with correct USGS data. Tap local event → sheet shows local copy. `Link` opens Safari to USGS event page.

**Verification Checklist:**
- [ ] `swift test` → all 4 `USGSCorrelatorTests` pass
- [ ] Live USGS API call → decodes without crash
- [ ] Retry mock test: 3 attempts, match on attempt 3 → `correlationStatus = "matched"`
- [ ] Ribbon annotation at correct position for injected event
- [ ] Label fade-in animation visible
- [ ] `EventDetailView` correct for matched event and local event
- [ ] 30-minute desk session → no memory growth (Instruments → Leaks)
- [ ] SwiftData persists events across app restarts

**Risks:**
- Quiet seismic period during development (no real M2+ events) → build `MockUSGSClient` + Debug Settings toggle "Inject test earthquake". Use historical USGS queries for integration testing (e.g., `starttime=2024-03-18T14:00:00`, a date with known Bay Area activity).
- Tap gesture conflicting with ribbon scroll gesture → use `simultaneousGesture` modifier; prioritize tap only when a `RibbonEvent` is within 20px of tap location.

---

## Phase 3: Polish, Open Source, App Store (Weeks 7–8)

**Objective:** Complete settings UI, SeismoscopeKit standalone extraction, GitHub launch, App Store submission.

**Tasks:**

1. **`SettingsView` completion** — Region picker: `List` of 50 city presets from `regions.json` + "Custom Location" row that expands to lat/lng `TextField`s. Sensitivity slider: `Slider(value: $appState.staltaThreshold, in: 2.5...6.0, step: 0.5)` with labels "More sensitive" / "Less sensitive". Units toggle: `Toggle` between milli-g and plain language MMI. Low-power mode toggle: reduces CMMotionManager to 50Hz, pauses Metal render (sets `MTKView.isPaused = true`), continues STA/LTA logging only.
   **Acceptance:** Change region → next USGS query uses new coordinates (verify in network log). Adjust sensitivity slider → `STALTADetector.threshold` updates immediately (mid-session, no restart). Low-power toggle → MTKView.isPaused confirmed via Xcode view debugger.

2. **Device profile table** — `DeviceProfileLoader` reads `device_profiles.json` at app launch. Calls `UIDevice.current.value(forKey: "modelIdentifier") as? String` (works in simulator and on device). Looks up multiplier and applies: `effectiveThreshold = baseThreshold × multiplier`. Unknown models default to `multiplier = 1.5` (conservative). `device_profiles.json` includes at minimum: iPhone12,1 through iPhone16,2 and their Pro variants.
   **Acceptance:** Run on iPhone 12 simulator (fake modelIdentifier via launch argument `SIMULATED_MODEL=iPhone12,1`) → threshold is 1.5× the value shown on iPhone 14 Pro.

3. **SeismoscopeKit standalone extraction** — Verify `Package.swift` has no app-level imports. `swift build` from `SeismoscopeKit/` directory must succeed. `swift test` must pass. Write `SeismoscopeKit/README.md`: package description, API surface with usage examples for `ButterworthFilter`, `STALTADetector`, `CircularBuffer`, ASCII diagram of the STA/LTA algorithm, link to main app repo.
   **Acceptance:** `cd SeismoscopeKit && swift build` → `Build complete!`. `swift test` → all tests pass. Open `Package.swift` → zero `import Seismoscope` statements.

4. **App Store assets** — Generate screenshots: iPhone 6.7" (1290×2796px), iPhone 6.5" (1242×2688px), iPad 12.9" (2048×2732px). 3 screenshots each: (a) ribbon with a labeled M3.5 event annotation, (b) ribbon showing ambient building micro-seismicity with "Place phone on a stable surface" resolved, (c) `EventDetailView` with full USGS data. App Store description written. Privacy policy on GitHub Pages (`https://[username].github.io/seismoscope/privacy`) — content: no personal data collected, only outbound call is USGS read-only query.
   **Acceptance:** All required screenshot sizes exist as PNG. Privacy policy URL returns HTTP 200. App description ≤ 4,000 characters.

5. **GitHub repo** — Initialize repo `seismoscope` with MIT license. Top-level `README.md`: app description, GIF of ribbon in action (record with QuickTime), architecture diagram (copy from this doc), `SeismoscopeKit` link, STA/LTA explainer with ASCII timing diagram, Xcode build instructions. Add `SeismoscopeKit` as a git submodule or separate repo — decide before launch (recommendation: separate repo `seismoscope-kit`, referenced as SPM dependency via URL in the app).
   **Acceptance:** Repo public. `git clone [repo] && open Seismoscope.xcodeproj` → builds on Xcode 15.2+ without additional steps. README renders correctly on GitHub (no broken image links).

6. **TestFlight beta** — Archive for distribution. Submit to App Store Connect. Add 5 external testers across iPhone 12, 13, 14, 15 (request from community if needed). Collect: false positive rate per device, ribbon smoothness, crash reports (via Xcode Organizer).
   **Acceptance:** Build accepted by App Store Connect (not rejected). Zero crash reports after 5 cumulative tester-hours. At least 1 tester reports detecting a non-tap vibration event.

**Verification Checklist:**
- [ ] Settings changes apply live (no restart required for any setting)
- [ ] `cd SeismoscopeKit && swift build && swift test` → clean
- [ ] All App Store screenshot sizes generated (9 total: 3 sizes × 3 screens)
- [ ] Privacy policy URL `https://[username].github.io/seismoscope/privacy` → HTTP 200
- [ ] GitHub repo public, README renders, build instructions accurate
- [ ] TestFlight build accepted (no App Store Connect rejection email)
- [ ] Zero crash symbolications in Xcode Organizer after beta

---

## Testing Reference

### SeismoscopeKit Unit Tests (all automated)

| Test | Input | Expected Output |
|------|-------|----------------|
| `testBandpassFrequencyResponse` | 1,000 samples, 0.5Hz sine, amplitude 1.0 | Output RMS within ±5% of input |
| `testBandpassAttenuatesHighFreq` | 1,000 samples, 50Hz sine | Output RMS < 1% of input |
| `testHighPassRemovesDC` | DC offset 1.0, 500 samples | Output < 0.01 after 500 samples |
| `testTriggerOnImpulse` | 90s noise (0.001g) + 3s burst (0.02g) | Exactly 1 TriggerEvent, onset ±2 samples |
| `testNoTriggerOnNoise` | 60s white noise at 0.001g | 0 TriggerEvents |
| `testRearm` | Two 3s bursts, 10s apart | Exactly 2 TriggerEvents |
| `testConcurrentReadWrite` | 4 writers + 2 readers concurrent | No crashes, no races (TSAN) |

### Regression Baseline (established end of Phase 1)

Record a 10-minute accelerometer session on a desk to `Tests/Fixtures/desk_baseline.csv` (columns: timestamp, x_raw, y_raw, z_raw, x_filtered, y_filtered, z_filtered, magnitude, stalta_ratio, triggered). Any filter chain change must reproduce the same trigger events ±2 samples on this fixture. Add a `RegressionTests.swift` that loads and replays this fixture.
