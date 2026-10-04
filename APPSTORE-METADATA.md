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
| 1 | Main ribbon | Fixed-seed ambient Noise samples on parchment, frozen signed envelope, actual sample-derived `mg` readout, `Stable`; Debug controls hidden | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Motion on a paper ribbon." |
| 2 | Main ribbon, MMI readout | Existing Impulse mode with a fixed-seed quiet background and one impulse at 90 seconds in the frozen 120-second history; milli-g disabled, actual sample-derived `MMI I (est.)` readout, `Stable`; Debug controls hidden | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "An acceleration-based intensity estimate." |
| 3 | Settings, Region | Settings opened at the top, showing `Region` and the city rows that fit; San Francisco selected, with its checkmark only if visible | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Choose a region for catalog checks." |
| 4 | Settings, lower controls | Settings scrolled to `Sensitivity`, showing `Threshold` at `4.0×`, `Show acceleration in milli-g` on, and `Low-power mode` off; confirm composition on each size | 6.9-inch iPhone 1320 x 2868; 13-inch iPad 2064 x 2752 | Simulator | "Adjust sensitivity and sampling." |

### How to Take Screenshots

1. On a full Xcode host, install the iOS simulator runtime and create devices named exactly `iPhone 18 Pro Max` and `iPad Pro 13-inch (M5)`. Keep them in portrait orientation, with the default text size. The script fails clearly if a required device is missing or dimensions differ.
2. Run `scripts/capture-screenshots.sh` from any directory. It builds Debug once without signing, installs the built app, uses light appearance and English, sets the status bar to 9:41 with full Wi-Fi and battery, and launches each planned state. No motion permissions or catalog requests are triggered. There is no onboarding flow to bypass.
3. The script waits four seconds per state. Override all waits with `SHOT_WAIT`, or individual waits with `SHOT_WAIT_1` through `SHOT_WAIT_4` (seconds); for example, `SHOT_WAIT_4=6 scripts/capture-screenshots.sh`. `DERIVED` overrides the default `.build/shots` build directory.
4. Find the eight dimension-checked PNGs in `screenshots/appstore/iphone-18-pro-max/01.png` through `04.png` and `screenshots/appstore/ipad-pro-13-inch-m5/01.png` through `04.png`. Inspect the real UI, especially the Settings scroll composition, before uploading. The script clears status bar overrides on exit and shuts down only devices it booted. A previously booted simulator remains booted.
5. Add the listed headline overlays outside the app UI if desired. The script captures raw app UI and does not add overlays. Preserve captured readings and labels. Generated captures and screenshot build products are gitignored; the dispatcher uploads them.

The plan requires no earthquake match, clock labels, fixed marker count, or event
injection. The four planned states use no camera, LiDAR, Bluetooth, or live
accelerometer input, so there are no `OPERATOR: capture on device` rows. Event
annotations and matched Event Detail are not planned screenshots; no synthetic
event or USGS match is injected for these four states. The fixed render clock and
seeded existing Noise/Impulse generator avoid time and randomness drift. Settings
start from deterministic defaults; screenshot-mode event storage is in memory.
Release contains no screenshot mode and still needs a physical device for live
motion and detection review.

## App Review Notes

```text
Seismoscope displays filtered device motion while the app is in the foreground.
No account, credentials, or reviewer login are required.

Automatic catalog requests use HTTPS GET at:
https://earthquake.usgs.gov/fdsnws/event/1/query
The query fields are format=geojson, starttime, endtime, latitude, longitude,
maxradiuskm=500, minmagnitude=1.5, orderby=time, and limit=20. Coordinates come
from San Francisco until you select a city or enter custom coordinates.
The search window runs from 10 minutes
before detected onset to 30 minutes after it; matching uses a time difference
under 10 minutes. Raw accelerometer samples and stored event history are not
uploaded. View on USGS opens the matched event's USGS web page.

The app declares NSMotionUsageDescription for accelerometer use. It does not
request location, camera, microphone, or photo-library access.

On a physical iPhone or iPad:
1. Launch the app. Sampling starts automatically when an accelerometer is
   available. There is no Start Recording button.
2. Tap the gear button (accessibility label: Settings). Under Region, select
   a city near the area you want to search. Custom Location reveals Lat and
   Lon fields; enter valid coordinates and tap Apply if using that option.
   Until you choose a region, catalog requests use the San Francisco preset.
   The Region footer explains that the coordinates are sent to USGS.
3. Scroll past the city list to Sensitivity. Threshold has More sensitive and
   Less sensitive labels. Leave Low-power mode off for this test. Tap Done.
4. Place the device on a quiet, hard surface and leave the app in the foreground
   for at least 60 seconds. Detection requires 45 seconds of samples after
   startup or a sampling-rate change. Stable appears only after the filtered
   stability signal stays quiet for three seconds; launch-to-Stable time varies.
5. Gently tap the desk near the device. Motion can appear on the trace without
   crossing the event threshold. If needed, lower Threshold toward More
   sensitive and try again after the motion settles.
6. A detected event initially has a Local vibration annotation. Tap near it to
   open Event Detail, which shows Detection fields including Onset, Peak,
   Dominant Axis, and STA/LTA Ratio. It does not show a recorded duration.
7. If a correlation slot is available, the catalog query starts at detection.
   Event Detail may show Checking USGS earthquake catalog… when opened.
   While the annotation is still visible, close the sheet with Done and reopen
   it to load the latest stored result. A qualifying catalog event shows Earthquake
   matched and USGS Earthquake Data. View on USGS appears when a valid link is
   available. A desk tap usually has no catalog match; none is guaranteed for
   the reviewer's chosen region and time. The Local vibration ribbon label is
   not a conclusion that catalog checks have finished.
8. Unmatched checks can retry three times with a two-minute wait each. Network
   failures or rate limiting can extend the wait. The app checks up to four
   events concurrently; additional detections skip the query while slots are
   occupied. Delayed results can outlast the visible annotation; there is no
   separate history screen for reopening it later. The timeout message counts
   the initial check plus retries. Events skipped by the cap show Not checked
   (too many events at once). Keep the app in the
   foreground; backgrounding cancels checks.
9. In Settings, turn off Show acceleration in milli-g and tap Done. The status
   readout changes from mg to an MMI Roman numeral marked (est.), with an
   Estimated Modified Mercalli intensity VoiceOver label. Turning it on
   restores mg. Low-power mode lowers requested sampling to 50 Hz; it does
   not pause rendering and restarts the detector's warmup.

On a simulator without an accelerometer, the Release build has no live motion
input. Settings remain available. Debug-only Sine, Noise, and Impulse controls
produce samples for display inspection, without detection or catalog checks.
Use a physical device to review live detection. Matching a catalog event is
a time-and-region comparison, not scientific validation of the device signal.
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
