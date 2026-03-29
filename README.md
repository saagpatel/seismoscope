# Seismoscope

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

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
open seismoscope.xcodeproj
```

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

CoreMotion pushes accelerometer samples to a ring buffer on a real-time thread. A `DSPProcessor` actor applies the filter chain and STA/LTA detection, emitting `SeismicEvent` values when threshold crossings occur. The Metal renderer reads the ring buffer directly via a shared `MTLBuffer`, avoiding any copy on the hot path. USGS correlation happens in a background `Task` with exponential backoff retries, writing results back to SwiftData where `@Query` observers in the detail view pick them up.

## License

MIT