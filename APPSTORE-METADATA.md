# Seismoscope App Store Connect Metadata

## Identity

Store settings below are intended submission values. Confirm them in the existing store record before submission.

| Field | Value |
|-------|-------|
| **Name** | Seismoscope |
| **Subtitle** | A seismograph in your pocket |
| **Bundle ID** | com.seismoscope.app |
| **SKU** | SEISMOSCOPE-001 |
| **Primary Category** | Utilities |
| **Secondary Category** | Education |
| **Age Rating** | 4+ |
| **Price** | Free |
| **Availability** | All territories |

## Keywords

```text
seismometer,earthquake,accelerometer,vibration,tremor,seismic,quake,USGS,ground,motion
```

## Description

Watch your phone's movements take shape on a paper ribbon. Seismoscope uses your iPhone or iPad's accelerometer to draw a seismogram and compare detected vibrations with the USGS earthquake catalog.

The display is modeled on a drum seismograph: parchment scrolling steadily under an ink trace, with a bleed effect that spreads on stronger signals. The trace shows filtered motion through the screen, so a quiet table draws a thin line and stronger shaking draws a wider one.

Signal processing:
• Reads the accelerometer up to 100 times a second
• Strips gravity, then keeps the 0.1 to 10 Hz band with a Butterworth bandpass
• STA/LTA triggering: a short running average against a long one, firing when the ratio jumps
• Re-arms after each event, so one session can capture many

Earthquake catalog checks:
• Detected events first appear on the ribbon as "Local vibration"
• A match updates the annotation with magnitude and location when available
• Matching uses the search region, a distance under 500 km, an onset-time difference under 10 minutes, and magnitude 1.5 or greater

New earthquakes can take a few minutes to reach the catalog, so if the first check finds nothing the app tries three more times, two minutes apart (up to four events at a time). Recording and catalog checks run while the app is in the foreground.

Tap an event annotation to open Event Detail. See onset time, peak acceleration, dominant axis, and STA/LTA ratio. Matched events can also show magnitude, location, depth, distance, origin time, and a View on USGS link. A catalog match compares time and region; it does not prove what moved your device.

Settings:
• Choose from 50 city presets or enter custom coordinates
• Adjust the detection threshold with the sensitivity slider
• Read the live level in milli-g, or as an estimated Modified Mercalli intensity (I to XII) derived from acceleration using the Wald et al. (1999) relations
• Low-power mode halves the sampling rate to 50 Hz

Seismoscope never asks for your location and has no accounts, ads, analytics, or tracking. Catalog checks send region coordinates (San Francisco until you choose a city or enter coordinates) and an event-time window to USGS. Motion data and event history stay on your device. Tapping View on USGS opens the event page in your browser.

## Promotional Text

```text
Set your phone on a desk and watch it draw a seismogram on scrolling parchment. When it detects a jolt, it checks the USGS catalog for a matching earthquake.
```

## Field Lengths

Python character counts include spaces, punctuation, and description line breaks. Markdown headings and code fences are excluded.

| Field | Characters | Limit |
|-------|------------|-------|
| Name | 11 | 30 |
| Subtitle | 28 | 30 |
| Promotional text | 157 | 170 |
| Keywords | 86 | 100 |
| Description | 2308 | 4000 |

## Support URL

https://github.com/saagpatel/seismoscope/issues

## Privacy Policy URL

https://github.com/saagpatel/seismoscope/blob/main/PRIVACY.md

## Screenshots

### Required Sizes

- **6.9-inch iPhone:** 1320 x 2868 px
- **13-inch iPad:** 2064 x 2752 px. Both device families are enabled (`TARGETED_DEVICE_FAMILY = 1,2`).

### Screenshot Plan (4 screenshots per size)

The `n` column maps directly to the Debug-only launch argument
`-AppStoreScreenshot <n>`. Each row is captured at both required sizes; no row
requires device-only hardware because the ribbon uses the existing Debug
synthetic source. These are display fixtures, not measured earthquakes.

| n | Screen | Capture State | Device Sizes | Capture | Headline Overlay |
|---|--------|---------------|--------------|---------|------------------|
| 1 | Main ribbon | Fixed-seed quiet-table noise (0.00008 g amplitude) on parchment, a thin frozen signed wobble, actual sample-derived `mg` readout, `Stable`; Debug controls hidden | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Motion on a paper ribbon." |
| 2 | Main ribbon, MMI readout | Synthetic 50-second earthquake from 50–100 seconds in the frozen 120-second history: small P-wave, larger S-wave, decaying coda, matched `M3.2 — San Jose, CA` fixture annotation; milli-g disabled, quiet-tail `MMI I (est.)` readout, `Stable`; Debug controls hidden | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "An acceleration-based intensity estimate." |
| 3 | Event Detail | Existing Event Detail sheet for the same matched fixture: earthquake match badge, 50-second detection with sample-derived peak, and USGS fixture magnitude, place, depth, distance, and origin time; no link to a fabricated event page | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Explore an earthquake match." |
| 4 | Settings, lower controls | Settings scrolled to `Sensitivity`, showing `Threshold` at `4.0×`, `Show acceleration in milli-g` on, and `Low-power mode` off; confirm composition on each size | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Adjust sensitivity and sampling." |

### How to Take Screenshots

1. On a full Xcode host, install the iOS simulator runtime and create devices named exactly `iPhone 18 Pro Max` and `iPad Pro 13-inch (M5)`. Keep them in portrait orientation, with the default text size. The script fails clearly if a required device is missing or dimensions differ.
2. Run `scripts/capture-screenshots.sh` from any directory. It builds Debug once without signing, installs the built app, uses light appearance and English, sets the status bar to 9:41 with full Wi-Fi and battery, and launches each planned state. Before capturing each device, it launches once, waits two seconds, and terminates to clear the cross-app status-bar back link. Termination tolerates an app that is not running. No motion permissions or catalog requests are triggered. There is no onboarding flow to bypass.
3. The script waits four seconds per state. Override all waits with `SHOT_WAIT`, or individual waits with `SHOT_WAIT_1` through `SHOT_WAIT_4` (seconds); for example, `SHOT_WAIT_4=6 scripts/capture-screenshots.sh`. `DERIVED` overrides the default `.build/shots` build directory.
4. Find the eight dimension-checked PNGs in `screenshots/appstore/iphone-18-pro-max/01.png` through `04.png` and `screenshots/appstore/ipad-pro-13-inch-m5/01.png` through `04.png`. Inspect the real UI, especially the Settings scroll composition, before uploading. The script clears status bar overrides on exit and shuts down only devices it booted. A previously booted simulator remains booted.
5. Add the listed headline overlays outside the app UI if desired. The script captures raw app UI and does not add overlays. Preserve captured readings and labels. Generated captures and screenshot build products are gitignored; the dispatcher uploads them.

The four planned states use no camera, LiDAR, Bluetooth, or live accelerometer
input, so there are no `OPERATOR: capture on device` rows. Shots 2 and 3 seed the
same synthetic earthquake record and local USGS-format catalog fixture; the
existing correlator validates the match without a network request. Magnitude and
place are fixture values, not evidence of a measured or historical earthquake.
The fixed render clock and seeded Debug waveform avoid time and randomness drift.
Settings start from deterministic defaults; screenshot-mode event storage is in memory.
Release contains no screenshot mode and still needs a physical device for live
motion and detection review.

## App Review Notes

```text
Seismoscope draws filtered device motion as a seismogram while the app is in the foreground. No account or login is required.

Network: catalog checks are HTTPS GET requests to https://earthquake.usgs.gov/fdsnws/event/1/query with a region latitude and longitude, a 500 km radius, minimum magnitude 1.5, and a time window around the detection. The region is San Francisco until you pick a city or enter custom coordinates. Raw motion samples and event history are not uploaded. View on USGS opens the matched event's page in the browser.

Permissions: Motion only (NSMotionUsageDescription). No location, camera, microphone, or photo access.

To review on a physical iPhone or iPad:
1. Launch the app. Sampling starts automatically.
2. Tap the gear button (Settings). Under Region, pick a city, or use Custom Location to enter coordinates and tap Apply. Tap Done.
3. Place the device on a quiet, hard surface and leave the app in the foreground for at least 60 seconds; detection needs 45 seconds of samples after launch.
4. Tap the desk firmly near the device. If nothing registers, lower Threshold toward More sensitive in Settings and try again.
5. A detected event shows a Local vibration label on the ribbon. Tap it to open Event Detail (Onset, Peak, Dominant Axis, STA/LTA Ratio).
6. The app checks the USGS catalog at detection and retries up to three times, two minutes apart, if nothing matches. A desk tap normally has no catalog match. If a real earthquake matches, Event Detail shows Earthquake matched with magnitude, location, depth and distance. Close and reopen the sheet to see the latest result. Keep the app in the foreground; backgrounding cancels pending checks.
7. In Settings, turn off Show acceleration in milli-g: the readout switches from mg to an estimated Modified Mercalli intensity (for example MMI II (est.)).

A simulator has no live accelerometer, so please review on a device. A catalog match compares time and region; it does not prove what moved the device.
```

## Checklist Before Submission

- [ ] Confirm the existing `com.seismoscope.app` store record and intended identity settings
- [ ] Confirm the 1024 x 1024 app icon appears correctly in the asset catalog
- [ ] Verify the built Info.plist includes `NSMotionUsageDescription` and no unused permission strings
- [ ] Verify `PrivacyInfo.xcprivacy` is packaged, tracking is false, and required-reason entries match API usage; Core Motion is covered by the usage string, not a separate required-reason category
- [ ] Review USGS request fields and the `View on USGS` navigation path; do not claim an enforced network host restriction
- [ ] Run repository package tests, app tests, and an unsigned Release build on a full Xcode host; record actual results
- [ ] Archive and validate successfully after signing is qualified
- [ ] Capture and upload eight accurate screenshots: four at 1320 x 2868 for iPhone and four at 2064 x 2752 for iPad; exclude Debug controls
- [ ] Enter the checked description, promotional text, keywords, and subtitle in App Store Connect
- [ ] Confirm Free pricing, territories, and age rating questionnaire answers in the store record
- [ ] Confirm support and privacy URLs are accessible and the policy explains region coordinates (San Francisco by default), event-time queries, local motion/history, USGS page navigation, and ordinary network information such as the device IP address
- [ ] Reconcile App Privacy answers with the manifest's Precise Location and Other Data Types for App Functionality, neither linked to identity nor used for tracking; qualify USGS handling/retention before finalizing answers
- [ ] On physical iPhone and iPad, verify foreground motion, post-warmup detection, event detail, actual catalog-check outcomes, the mg/MMI switch, and 50 Hz low-power sampling with rendering continuing
- [ ] In TestFlight, follow the review steps and record detection and catalog outcomes without requiring an earthquake match
- [ ] Submit for Review after the remaining readiness gates are met

## Copyright

© 2026 saagpatel
