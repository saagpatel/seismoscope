# Seismoscope

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](https://www.swift.org) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](./LICENSE) [![CI](https://github.com/saagpatel/seismoscope/actions/workflows/ci.yml/badge.svg)](https://github.com/saagpatel/seismoscope/actions/workflows/ci.yml)

> A 1930s seismometer in your pocket — now with earthquake cross-referencing

Seismoscope turns your iPhone into a real seismograph. Raw accelerometer data passes through a Butterworth filter chain and an STA/LTA event detector; detected events are automatically cross-referenced against the USGS earthquake catalog. The waveform scrolls as a GPU-rendered Metal ribbon.

## Features

- **100 Hz accelerometer sampling** with high-pass gravity removal and a 0.1–10 Hz bandpass filter
- **STA/LTA event detection** — standard seismological algorithm, configurable threshold, device-calibrated on first launch
- **USGS catalog correlation** — queries the USGS FDSN Event API and matches detections within a 10-minute / 500 km window
- **Metal ribbon display** — GPU-accelerated scrolling waveform at 60 fps with tappable event annotations
- **Per-event detail** — onset time, peak acceleration, STA/LTA ratio, and USGS earthquake metadata when matched
- **Low-power mode** — drops to 50 Hz to extend battery life
- **SwiftData persistence** — event log survives app restarts; unresolved correlations retry up to 3 times

## Quick Start

### Prerequisites
- Xcode 16+
- iOS 17.0+ device (accelerometer required; simulator will not show real data)

### Installation
```bash
git clone https://github.com/saagpatel/seismoscope
cd seismoscope
open Seismoscope.xcodeproj
```

### Code signing
Signing uses a local, gitignored config so no Team ID is committed. Set it up once:
```bash
cp Signing.local.xcconfig.example Signing.local.xcconfig
# edit Signing.local.xcconfig and set DEVELOPMENT_TEAM to your Apple Developer Team ID
```
`Signing.xcconfig` (committed) holds non-secret defaults and optionally includes your local file; the project reads both via XcodeGen `configFiles`.

### Usage
Deploy to a physical device. Place the phone on a stable surface and tap **Start Recording**. Detected events appear as annotations on the waveform; tap any to see USGS match details.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6.0, strict concurrency |
| UI | SwiftUI |
| Waveform | Metal (custom compute + render pipeline) |
| DSP | Custom Butterworth + STA/LTA in Swift |
| Data | USGS FDSN Event REST API |
| Persistence | SwiftData |

## Architecture

CoreMotion pushes accelerometer samples into an `AccelerometerPipeline` on a background queue. A private `PipelineState` object applies the filter chain and feeds the `STALTADetector`, yielding `TriggerEvent` values via `AsyncStream`. The `EventCoordinator` (`@MainActor` class) bridges these streams to the main actor, appending magnitudes to `RibbonState.samples` and persisting `SeismicEvent` records to SwiftData on each trigger. The Metal renderer copies the current samples into a triple-buffered `MTLBuffer` each frame. USGS correlation happens in a background `Task` with fixed 120-second retry intervals (up to 3 attempts), writing results back to SwiftData; `EventDetailView` fetches the updated record on appearance via `FetchDescriptor`.

## License

MIT