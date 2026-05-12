# Seismoscope — Portfolio Disposition

**Status:** Release Frozen (iOS App Store) — SwiftUI iOS
accelerometer-based seismometer on `origin/main`, with full App
Store submission scaffolding (`APPSTORE-METADATA.md`, fastlane
`deliver`, DEVELOPMENT_TEAM, Privacy Manifest, scheme generation,
copyright + ExportOptions, privacy policy, archive prep, AI-
generated final icon). Classified as **Utilities** (primary) +
**Education** (secondary) at **Free**. Reads from **USGS
earthquake API** for cross-reference. **Ninth iOS App Store
cluster member.** Joins the local-first + third-party-API-read
sub-class with Tide Engine (NOAA + WorldTides) — second cluster
member to live in this sub-class.

> Disposition uses strict `origin/main` verification.

---

## Verification posture

This repo has **only `origin`** (`saagpatel/Seismoscope`) — no
`legacy-origin` remote. Clean.

Specifically verified on `origin/main`:

- Tip: `379268d` chore: replace placeholder icon with AI-generated
  app icon
- Substantive App Store prep commits:
  - `379268d` AI-generated app icon (final)
  - `89b02c9` fastlane deliver config
  - `bedad17` gradient placeholder (intermediate)
  - `decc875` app store archive prep
  - `1d87e88` privacy policy + metadata URLs
  - `b4b9775` copyright + ExportOptions
  - `a713ed0` App Store Connect metadata
  - `b175d44` App Store prep — DEVELOPMENT_TEAM, Privacy Manifest,
    scheme generation
- App Store identity:
  - Name: **Seismoscope**, Subtitle: **Your iPhone as a seismometer**
  - Bundle ID: `com.seismoscope.app`
  - Categories: **Utilities** + **Education**
  - Age Rating: 4+, **Price: Free**, All territories
- Default branch: `main`

---

## Current state in one paragraph

Seismoscope turns the iPhone into a working seismometer using the
built-in accelerometer. Captures ground motion at high sample
rate, computes seismograph-style traces, and cross-references
**USGS earthquake feed** for nearby seismic events. Per memory:
Phases 0-3 complete. Local-first + USGS-API-read sub-class
(matches Tide Engine's pattern: data lives on device, third-party
API enriches with reference data). Free pricing keeps it
accessible for educational use (Education secondary category).

---

## Why "Release Frozen (iOS App Store)" — ninth cluster member

Standard cluster signature with AI-generated final icon + fastlane
deliver. Distinct from siblings:

- **Accelerometer Required Reason** — Apple's Required Reason API
  may apply to motion data; verify `PrivacyInfo.xcprivacy`
  declares Core Motion usage (similar to RoomTone's UserDefaults
  declaration).
- **USGS earthquake API** = third-party-read dependency (no
  operator-run backend).
- **Education-category secondary** = potential App Store editorial
  pickup for science-classroom use.

---

## Cluster taxonomy update

| Cluster | Count | Notes |
|---|---|---|
| **iOS App Store** | **9** | 6 local-first + 1 cloud-backed + 2 local-first+API-read (Tide Engine + **Seismoscope**) |

---

## Unblock trigger (operator)

1. **App Store Connect record** + Free tier.
2. **Core Motion Required Reason API declaration** — verify
   `PrivacyInfo.xcprivacy` matches actual accelerometer usage.
3. **USGS API rate limits + outage posture** — graceful
   degradation when USGS feed is unreachable (physics + local
   trace still works).
4. **Education editorial pitch** — if operator wants App Store
   editorial pickup, the classroom-use angle is the lead.
5. **Submit for Review.**

Estimated operator time: ~3-4 hours.

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store, local-first + API read)` |
| Distribution channel | **App Store Connect** — Utilities + Education, Free |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Submission, (b) USGS API breaking change, (c) Core Motion Required Reason API expansion, or (d) v1.1 scope |
| Co-batch with | iOS App Store cluster — **now 9 repos** |
| Sub-shape | **Local-first + third-party API read** (alongside Tide Engine) |
| Special concern | **USGS API graceful degradation.** Physics + local trace must work without network — verify. |
| Special concern | **Core Motion Required Reason API audit.** Accelerometer use may need declaration in PrivacyInfo.xcprivacy. |

---

## Reactivation procedure

1. Verify branch tracking.
2. Review stash `r14-seismoscope-stash` (CLAUDE.md + .claude/ +
   .codex/ + AGENTS.md).
3. Open Xcode; confirm DEVELOPMENT_TEAM.
4. **Audit PrivacyInfo.xcprivacy for Core Motion Required Reason
   declaration.**
5. Run XCTest.
6. Test USGS API behavior with network disabled.

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `379268d` chore: replace placeholder icon with AI-generated app icon |
| Default branch | `main` |
| Build system | iOS / Swift / SwiftUI / **Core Motion (accelerometer)** / XCTest |
| Bundle ID | `com.seismoscope.app` |
| App Store category | Utilities + Education |
| Price | **Free** |
| Phases shipped | 0-3 per memory |
| API dependency | **USGS earthquake feed** (third-party read, no operator backend) |
| Migration state | No `legacy-origin` remote |
| Distinguishing feature | **Ninth iOS App Store cluster member; second local-first+API-read sub-class member** alongside Tide Engine. |
