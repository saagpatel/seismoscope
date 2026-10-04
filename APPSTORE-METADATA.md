# Seismoscope App Store Connect Metadata

## Identity

Store settings below are intended submission values. Confirm them in the existing store record before submission.

| Field | Value |
|-------|-------|
| **Name** | Seismoscope |
| **Subtitle** | Motion on a paper ribbon |
| **Bundle ID** | com.seismoscope.app |
| **SKU** | SEISMOSCOPE-001 |
| **Primary Category** | Utilities |
| **Secondary Category** | Education |
| **Age Rating** | 4+ |
| **Price** | Free |
| **Availability** | All territories |

## Keywords

```text
seismometer,earthquake,accelerometer,seismograph,vibration,ground motion,USGS,science,physics
```

## Description

Watch device motion take shape on a paper ribbon. Seismoscope uses your iPhone or iPad's accelerometer to draw a seismogram and compare detected vibrations with the USGS earthquake catalog.

The display takes its cues from a drum seismograph: parchment texture, a scrolling ink trace, and a blur effect on stronger signals. The trace draws the filtered vertical-axis signal as a signed envelope. Paper, trace, and event annotations share a speed of 4 points per second.

Signal processing:
• Requests accelerometer samples at 100 Hz
• Gravity-removal highpass followed by a 0.1-10 Hz Butterworth bandpass with four cascaded second-order sections
• STA/LTA detection compares short-term and long-term signal levels
• Automatic re-arm allows separate events to be detected

Earthquake catalog checks:
• Detected events first appear on the ribbon as "Local vibration"
• A match updates the annotation with magnitude and location when available
• Matching uses your selected region, a distance under 500 km, an onset-time difference under 10 minutes, and magnitude 1.5 or greater
• Up to four catalog checks per event: an initial check and three retries, with a two-minute wait before each retry. Rate limiting can add a request and a delay
• Up to four events can be checked at once. Further detections are stored without a catalog query while those slots are occupied
• Motion recording runs while the app is in the foreground. Moving it to the background stops sampling and cancels outstanding catalog checks

Tap an event annotation to open Event Detail. See onset time, peak acceleration, dominant axis, and STA/LTA ratio. Matched events can also show magnitude, location, depth, distance, origin time, and a View on USGS link. A catalog match is a comparison of time and region, rather than proof of what caused the device to move.

Settings:
• Choose from 50 city presets or enter custom coordinates
• Adjust the detection threshold with the sensitivity slider
• Show filtered acceleration in milli-g or an estimated Modified Mercalli Intensity (MMI) in Roman numerals. The estimate applies the Wald et al. (1999) acceleration relations to the live readout
• Low-power mode requests 50 Hz sampling. The ribbon continues rendering

No GPS, accounts, or subscriptions. Raw motion samples and stored event history stay on your device. Catalog requests send your selected region coordinates and an event-time search window to USGS. Opening View on USGS visits an event page. No analytics, advertising, or tracking.

## Promotional Text

```text
Watch motion on a vintage paper ribbon. Explore filtered accelerometer signals and compare detected vibrations with the USGS earthquake catalog.
```

## Field Lengths

Python character counts include spaces, punctuation, and description line breaks. Markdown headings and code fences are excluded.

| Field | Characters | Limit |
|-------|------------|-------|
| Name | 11 | 30 |
| Subtitle | 24 | 30 |
| Promotional text | 144 | 170 |
| Keywords | 93 | 100 |
| Description | 2513 | 4000 |

## Support URL

https://github.com/saagpatel/seismoscope/issues

## Privacy Policy URL

https://github.com/saagpatel/seismoscope/blob/main/PRIVACY.md

## Screenshots

### Required Sizes

- **6.9-inch iPhone:** 1320 x 2868 px
- **13-inch iPad:** 2064 x 2752 px. Both device families are enabled (`TARGETED_DEVICE_FAMILY = 1,2`).

### Screenshot Plan (4 screenshots per size)

| # | Screen | Capture State | Headline Overlay |
|---|--------|---------------|------------------|
| 1 | Main ribbon | Physical device in foreground with motion samples visible on parchment; status shows the actual `mg` value and either `Stable` or `Place on stable surface` | "Motion on a paper ribbon." |
| 2 | Main ribbon, MMI readout | In Settings, turn off `Show acceleration in milli-g`, then tap `Done`; capture the ribbon with its actual `MMI` Roman numeral | "An acceleration-based intensity estimate." |
| 3 | Settings, Region | Top of Settings showing `Region` and the city rows that fit on screen; capture the actual selected checkmark if visible | "Choose a region for catalog checks." |
| 4 | Settings, lower controls | Scroll past the region list to show `Sensitivity`, `Threshold`, `Show acceleration in milli-g`, and `Low-power mode`; confirm the composition on each device size | "Adjust sensitivity and sampling." |

### How to Take Screenshots

1. On a full Xcode host, run the Release build on supported physical iPhone and iPad hardware. Use portrait orientation and confirm captures have the required pixel dimensions.
2. Keep the app in the foreground on a stable surface. Capture the live ribbon and its actual readings. If using a gentle desk tap to show motion, capture the resulting trace without adding an earthquake label.
3. Open the gear button (`Settings` accessibility label). Scroll past the 50 city presets to reach the display toggle. Turn off `Show acceleration in milli-g`, tap `Done`, and capture the MMI readout.
4. Reopen Settings to capture the region list and, separately, the lower controls. Capture only controls that actually fit on screen.
5. Add the listed headline overlays outside the app UI. Preserve the captured readings and labels. Upload four captures for each required size, eight total.

The plan requires no earthquake match, clock labels, fixed marker count, or event injection. A Release simulator without an accelerometer shows no live motion. A Debug simulator offers `Sine`, `Noise`, and `Impulse` sample controls, but these do not create detected events or USGS matches. Use physical Release captures for the store images; exclude Debug controls.

## App Review Notes

```text
Seismoscope displays filtered device motion while the app is in the foreground.
No account, credentials, or reviewer login are required.

Automatic catalog requests use HTTPS GET at:
https://earthquake.usgs.gov/fdsnws/event/1/query
The query fields are format=geojson, starttime, endtime, latitude, longitude,
maxradiuskm=500, minmagnitude=1.5, orderby=time, and limit=20. Coordinates come
from the selected city or custom entry. The search window runs from 10 minutes
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
   separate history screen for reopening it later. The timeout message's count
   is the retry counter and excludes the initial query. Keep the app in the
   foreground; backgrounding cancels checks.
9. In Settings, turn off Show acceleration in milli-g and tap Done. The status
   readout changes from mg to an estimated MMI Roman numeral. Turning it on
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
- [ ] Confirm support and privacy URLs are accessible and the policy explains selected coordinates, event-time queries, local motion/history, and USGS page navigation
- [ ] Reconcile App Privacy answers with the manifest's Precise Location and Other Data Types for App Functionality, neither linked to identity nor used for tracking; qualify USGS handling/retention before finalizing answers
- [ ] On physical iPhone and iPad, verify foreground motion, post-warmup detection, event detail, actual catalog-check outcomes, the mg/MMI switch, and 50 Hz low-power sampling with rendering continuing
- [ ] In TestFlight, follow the review steps and record detection and catalog outcomes without requiring an earthquake match
- [ ] Submit for Review after the remaining readiness gates are met

## Copyright

© 2026 saagpatel
