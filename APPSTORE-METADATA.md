# Seismoscope — App Store Connect Metadata

## Identity

| Field | Value |
|-------|-------|
| **Name** | Seismoscope |
| **Subtitle** | Your iPhone as a seismometer |
| **Bundle ID** | com.seismoscope.app |
| **SKU** | SEISMOSCOPE-001 |
| **Primary Category** | Utilities |
| **Secondary Category** | Education |
| **Age Rating** | 4+ |
| **Price** | Free |
| **Availability** | All territories |

---

## Keywords

```
seismometer,earthquake,accelerometer,seismograph,vibration,ground motion,USGS,science,physics
```

*(100 character limit — these are 88 characters)*

---

## Description

Your iPhone has a precision accelerometer sampling 100 times per second. Seismoscope uses it the way seismologists have used instruments since 1935 — to detect ground motion, record it as a scrolling waveform, and cross-reference detected events against the USGS earthquake catalog.

The display looks like a vintage drum seismograph: parchment-textured paper scrolling at one pixel per second, an ink trace that thickens and bleeds when amplitude spikes. When the app detects a vibration event, it automatically queries the USGS earthquake API and annotates the ribbon with magnitude and location if a match is found. If no match is found after three attempts, the event is labeled as a local vibration.

**Signal processing:**
• 100Hz CoreMotion pipeline — raw accelerometer data at maximum resolution
• 4-pole Butterworth bandpass filter (0.1–10Hz) — removes gravity, isolates ground motion frequencies
• STA/LTA event detection — the same algorithm used in professional seismograph networks
• Automatic re-arm — detects multiple separate events without manual reset

**The display:**
• Scrolling Metal ribbon renderer — procedurally generated parchment texture, 60fps
• Variable-width ink trace — line thickens proportionally to measured acceleration
• Gaussian blur "ink bleed" on high-amplitude signals — physically authentic
• Time markers — vertical lines at 60-second intervals with clock times
• Event annotations with fade-in — labeled with magnitude and location when matched

**USGS integration:**
• Automatic earthquake correlation — queries USGS FDSN Event API after any detected event
• Deferred retry — checks up to 3 times over 6 minutes (earthquakes may not appear in catalog immediately)
• Match criteria — within 500km and 10 minutes of detected onset, magnitude ≥ 1.5
• Full event detail — magnitude, depth, distance, and a link to the USGS event page

**Settings:**
• Region picker — 50 city presets, or enter custom coordinates
• Sensitivity slider — tune the STA/LTA threshold from more to less sensitive
• Units toggle — milli-g or plain-language MMI intensity scale
• Low-power mode — reduces to 50Hz sampling and pauses the Metal renderer

**No GPS. No accounts. No subscriptions.** Your region is set by city picker — Seismoscope never requests your location. The only outbound network call is a read-only earthquake query sent to the USGS API (which is public, unauthenticated, and free). No user data leaves your device.

The signal processing layer is published separately as SeismoscopeKit, an open-source Swift Package on GitHub.

---

## Promotional Text

*(Optional — appears above description, can be updated without new app version)*

```
Your iPhone as a vintage seismograph. 100Hz accelerometer → Butterworth filter → USGS earthquake correlation.
```

---

## Support URL

https://github.com/saagpatel/seismoscope/issues

---

## Privacy Policy URL

https://github.com/saagpatel/seismoscope/blob/main/PRIVACY.md

---

## Screenshots

### Required Sizes
- **6.7" Display** — 1290 × 2796 px (iPhone 16 Pro Max / iPhone 15 Pro Max)
- **6.5" Display** — 1242 × 2688 px (iPhone 11 Pro Max / iPhone XS Max)

### Screenshot Plan (4 screenshots per size)

| # | Screen | Simulator State | Headline Overlay |
|---|--------|-----------------|------------------|
| 1 | MetalRibbonView — event annotated | Parchment ribbon visible with a labeled earthquake annotation: "M3.5 — 47km NE of San Jose, CA" in warm red with leader line; time markers at left and right edges; trace showing the event spike then settling back to micro-tremor baseline | "Every tremor, recorded." |
| 2 | MetalRibbonView — ambient state | Ribbon in steady ambient state — subtle micro-tremor trace on parchment; StatusBarView at top showing "Stable • 0.3 milli-g • MMI I"; 3 time markers evenly spaced | "Your iPhone, always listening." |
| 3 | EventDetailView sheet | Sheet slid up over ribbon; "M3.5 Earthquake" header; details visible: onset time, duration, peak acceleration, location "47km NE of San Jose, CA", depth "8.2 km", distance "142 km", "View on USGS" link button | "Cross-referenced with the USGS earthquake catalog." |
| 4 | SettingsView | Region picker list visible with San Francisco selected; sensitivity slider in mid position; units toggle on "milli-g"; Low-power mode toggle visible at bottom | "Tune it for your location and sensitivity." |

### How to Take Screenshots
1. Open Xcode → Simulator → select iPhone 16 Pro Max
2. Build and run the Seismoscope target with `SyntheticDataSource` active in `#if DEBUG`
3. Use the impulse mode to generate a spike, then switch to the ambient noise mode for the steady-state screenshot
4. For the annotated screenshot, inject a test earthquake event via the Debug Settings toggle
5. **Xcode menu: Product → Simulator → Take Screenshot** (saves to Desktop)
   OR: `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
6. Repeat for iPhone XS Max (6.5") by switching simulator
7. Add marketing text overlays in Sketch, Figma, or Canva before uploading

*Note: The Metal ribbon renders more convincingly on a physical device — take final screenshots on hardware for App Store submission.*

---

## App Review Notes

```
Seismoscope uses the device accelerometer (CoreMotion) to detect ground vibrations and display them
as a scrolling seismogram. The only outbound network call is a read-only GET request to:
https://earthquake.usgs.gov/fdsnws/event/1/query
This is a public, unauthenticated API operated by the US Geological Survey. The query contains
only: region lat/lon (user-configured, not GPS), a time window, magnitude threshold, and radius.
No user PII is transmitted.

Required permissions:
- Motion & Fitness (NSMotionUsageDescription): "Seismoscope uses your iPhone's accelerometer to
  detect ground vibrations and display them as a seismogram."
  
No location permission required (region is set by city picker, not GPS).
No camera, microphone, photo library, or other permissions required.

To test core features:
1. Launch app — ribbon begins scrolling immediately at 1px/second
2. Place iPhone flat on a stable hard surface (desk, table)
3. After ~3 seconds the stability indicator shows "Stable"
4. Tap the desk firmly — a vibration spike appears on the ribbon
5. After 10–30 seconds, the app queries USGS; if no earthquake matches, the annotation reads "Local vibration"
6. In Settings, change the region to your location and adjust the sensitivity slider

No account, no credentials, no reviewer login required.
```

---

## Checklist Before Submission

- [ ] Bundle ID `com.seismoscope.app` registered in Apple Developer portal
- [ ] App icon 1024×1024 appears correctly in Xcode asset catalog (no warnings)
- [ ] `NSMotionUsageDescription` in Info.plist with plain-English string
- [ ] No location, camera, microphone, or photo library entitlements declared
- [ ] `PrivacyInfo.xcprivacy` present — Motion API declared, `NSPrivacyTracking = false`
- [ ] Network access restricted to `earthquake.usgs.gov` (consider App Transport Security if needed)
- [ ] Archive succeeds: `Product → Archive` with no errors
- [ ] Validate App passes with 0 errors
- [ ] All 8 screenshots uploaded (4 per required size: 6.7" + 6.5")
- [ ] Description, keywords, subtitle filled in App Store Connect
- [ ] Price set to Free in Pricing and Availability
- [ ] Age rating questionnaire complete (4+)
- [ ] Support URL and Privacy Policy URL provided (privacy policy must note: only outbound call is USGS query, no personal data)
- [ ] Privacy nutrition label: no data collected or linked to user; network usage explained
- [ ] `cd SeismoscopeKit && swift build && swift test` — all passing before submission
- [ ] TestFlight test complete: run app on desk for 5 minutes, verify tap detection, verify USGS query fires, verify event detail sheet
- [ ] Test on physical device — simulator does not provide real accelerometer data for final validation
- [ ] Submit for Review

## Copyright
© 2026 saagpatel
