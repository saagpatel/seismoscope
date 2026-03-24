# Seismoscope

## Overview
iOS app (iPhone + iPad) that turns the device accelerometer into a vintage 1930s seismometer. Core loop: 100Hz CoreMotion → 4-pole Butterworth bandpass filter → STA/LTA event detector → Metal ribbon renderer → USGS earthquake cross-reference. The signal processing layer is extracted into a standalone Swift Package (SeismoscopeKit) and open-sourced separately. Portfolio project — the point is the full-stack DSP → rendering → live API correlation chain.

## Tech Stack
- Swift: 5.9+
- SwiftUI: iOS 17+ (minimum deployment target — SwiftData requires 17)
- CoreMotion: CMMotionManager at 100Hz, background queue
- Metal + MetalKit: 60fps ribbon renderer (MTKView subclass)
- SwiftData: On-device event log only, no iCloud sync
- URLSession: USGS FDSN Event API (no third-party HTTP libs)
- SeismoscopeKit: Local Swift Package — zero external dependencies, zero app imports

## Project Structure
```
Seismoscope/               ← Xcode project root
├── Seismoscope/           ← App target
│   ├── App/
│   ├── Views/
│   ├── Metal/
│   ├── DSP/
│   ├── USGS/
│   ├── Models/
│   └── Resources/
├── SeismoscopeKit/        ← Standalone Swift Package
│   ├── Sources/SeismoscopeKit/
│   └── Tests/SeismoscopeKitTests/
└── SeismoscopeTests/
```

## Development Conventions
- Swift strict concurrency (`Sendable`, `actor` where needed for CMMotionManager data pipeline)
- `@Observable` macro (not `ObservableObject`) for state — iOS 17+
- No third-party dependencies in either the app or SeismoscopeKit
- File naming: PascalCase for types and files, camelCase for functions/properties
- Unit tests for all DSP transforms before committing to SeismoscopeKit
- Conventional commits: `feat:`, `fix:`, `chore:`, `test:`

## Current Phase
**Phase 0: Metal Ribbon Renderer**
Build the ribbon with synthetic data. No CoreMotion, no USGS, no SwiftData in this phase.
See IMPLEMENTATION-ROADMAP.md for full task list and acceptance criteria.

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| iOS minimum | iOS 17.0 | SwiftData requires 17; 85%+ install base |
| Location permission | None — user picks city preset | Privacy-first; no CoreLocation |
| Background recording | Foreground-only in v1 | Avoids App Store background mode entanglement |
| STA/LTA defaults | STA=1.5s, LTA=45s, threshold=4.0 | Conservative — no false positives over tight sensitivity |
| Ribbon scroll rate | 1px/second (60px/minute) | Matches physical drum seismograph rhythm |
| Circular buffer | 120s × 100Hz = 12,000 samples/axis | 144KB total — trivial; covers full LTA window |
| Units | Dual: milli-g + plain language MMI label | Power users + general audience |

## Do NOT
- Do not use `ObservableObject` — use `@Observable` macro throughout
- Do not import SeismoscopeKit modules into other SeismoscopeKit modules — it must build standalone
- Do not request background motion processing in v1 — foreground only
- Do not add `CoreLocation` — region is user-configured via city picker, never GPS
- Do not use `localStorage`, `UserDefaults` for event data — SwiftData only
- Do not write Metal shaders that assume a fixed canvas size — use dynamic viewport
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
