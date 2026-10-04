# Seismoscope App Store readiness: 2026-10-04

**Partial: upload readiness is not established.** Configuration fixes are ready
for review, but unit tests and the unsigned Release build have not run: this
machine currently has no full Xcode install. The store-copy truth pass has resolved the 16 recorded guideline 2.3 metadata findings against current source.
No signing, archive, export, upload, Keychain access, or store/developer API calls
were performed. Changes were committed by the dispatcher after review; build and unit tests still need a full Xcode install.

Store facts below were supplied from the existing record on 2026-10-04, not
queried by this worker. Repository-root `AGENTS.md` is absent; the supplied
instructions, nearest parent instructions, `CLAUDE.md`, `README.md`,
`APPSTORE-METADATA.md`, `PRIVACY.md`, and this report were read for the copy pass.
Configuration/build check results below are retained from the prior readiness
pass; they were not rerun during this documentation-only task.

| Item | Status | Evidence |
| --- | --- | --- |
| 1. Bundle identifiers and references | FIXED | `project.yml` retains app ID `com.seismoscope.app`; tests now use `com.seismoscope.app.tests`; prefix and the queue label in `Seismoscope/DSP/AccelerometerPipeline.swift:39` use the app namespace. Regenerated tracked project confirms both configurations. No extensions, entitlements, app groups, keychain groups, custom defaults suites, or background-task identifiers were found. `APPSTORE-METADATA.md` and `fastlane/Appfile` already have the correct ID; README now documents it. |
| 2. Build number and version | FIXED | Project-level `CURRENT_PROJECT_VERSION: "3"` in `project.yml` is inherited by both targets in Debug and Release; no conflicting target override remains. `MARKETING_VERSION` remains `1.0`. Lane values are version `1.0`, build `3`. Supplied store version is `1.0`, PREPARE_FOR_SUBMISSION; highest consumed build is 2, expired. |
| 3. Export compliance | FIXED | Generated Info.plist setting `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` is present in both app configurations. Source search found no custom cryptography; networking uses system URLSession HTTPS in `Seismoscope/USGS/USGSClient.swift`. Built Info.plist confirmation awaits a successful build. |
| 4. Distribution lane | FIXED | Added root `distkit.ios.config.sh` with the same keys as the supplied Redact template, this app's identity, manual lane signing, and `Seismoscope App Store` profile. Signing identity and ASC public identifiers were compared verbatim. `ExportOptions.plist` stays gitignored per this repo's signing policy; `ExportOptions.plist.example` (Team ID placeholder) documents it. Added `dist-receipts/` ignore. README documents the lane. No credentials were added or accessed. |
| 4. Signing/export prerequisites | OPERATOR | Preserve the reference's automatic export setting despite manual archive/lane signing, as requested. Confirm this combination and that the existing distribution identity, team, profile, and issuer lookup are usable before executing the lane. No signing qualification was performed. |
| 5. Privacy resource and required reasons | FIXED | `Seismoscope/Resources/PrivacyInfo.xcprivacy` is in the generated app resources phase. `AppState.swift:15`, `:44`, `:72` use app-only UserDefaults: corrected SDK-wrapper reason `C56D.1` to `CA92.1`. Added `35F9.1` for renderer elapsed timing (`RibbonRenderer.swift:145`, `:161`); retained `8FFB.1` for absolute event onset conversion (`EventCoordinator.swift:86`). Conservatively retain boot-time reasons for `CACurrentMediaTime`/motion uptime usage even though no direct `systemUptime` or `mach_absolute_time` calls were found. Reason meanings checked against [Apple's required-reason documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). |
| 5. Other required-reason API search | PASS | Searched app and package sources for UserDefaults/AppStorage, file creation/modification timestamps, attributesOfItem, stat/fstat/statfs, systemUptime/mach_absolute_time/CACurrentMediaTime, disk-space APIs, and activeInputModes. No file timestamp, disk-space, or active-keyboard-list usage found. Setting a text field's keyboard type is not querying active keyboards. No extension exists. |
| 5. Collected data and tracking | PASS | Manifest conservatively retains Precise Location and Other Data Types for App Functionality, both not linked and not tracking; tracking is false and domains empty. `USGSClient.swift:63`-`:76` sends selected/custom region coordinates and the detection-time window; `PRIVACY.md` describes this, USGS page navigation, and local-only raw motion/history. No analytics, advertising, accounts, identifiers, or third-party SDK collection found. |
| App Privacy label answers | OPERATOR | Answers implied by the retained manifest: data collected **yes**; **Precise Location** and **Other Data Types**, purpose **App Functionality**, linked to identity **no**, used for tracking **no**. Raw accelerometer samples and stored event history remain on device. Confirm USGS handling/retention before finalizing answers: code cannot establish server retention, and custom coordinates can represent precise location. The metadata checklist now requires reconciliation with the retained manifest, rather than a blanket no-data-collected answer. [Apple's collection definition](https://developer.apple.com/app-store/app-privacy-details/) depends on retention beyond servicing a request. |
| 6. Usage strings | PASS | Sole usage key is `NSMotionUsageDescription`, with a plain-English accelerometer purpose matching `CMMotionManager.startAccelerometerUpdates` (`AccelerometerPipeline.swift:64`). No location, camera, microphone, photo library, notification, or tracking permission requests/strings found. Core Motion is not a separate required-reason manifest category. |
| 7. App Store icon | PASS | `Assets.xcassets/AppIcon.appiconset/Contents.json` references `AppIcon-1024.png` for ios-marketing. `sips -g pixelWidth -g pixelHeight -g hasAlpha` reports 1024 × 1024 and `hasAlpha: no`. No icon modification or artwork creation needed. |
| 8. Release hygiene | FIXED | Wrapped synthetic source type, state, startup/cleanup, and fallback in `#if DEBUG` in `SyntheticDataSource.swift` and `SeismoscopeApp.swift`; existing debug overlay remains guarded. USGS `print` in `EventCoordinator.swift:134` is now DEBUG-only. Release no longer fabricates motion when an accelerometer is unavailable. No other production print/mock/injection routes found. Parse checks passed for both compilation conditions; Release compilation remains unverified. |
| 8. Shared archive scheme | PASS | Generated `Seismoscope.xcscheme` archives Release with only `Seismoscope` marked buildForArchiving. `SeismoscopeTests` is test-only. XcodeGen added test debugger/launcher attributes and regenerated configuration references; no development target was added to archive. |
| 9. Metadata accuracy | FIXED | Store copy, privacy wording, screenshot plan, review steps, and checklist now reflect current source; the 16 guideline 2.3 findings below are FIXED. This is a source-based copy correction, not App Review or device acceptance. |
| 2.3: waveform/spike and one-pixel-per-second trace | FIXED | Changed the description to a signed filtered vertical-axis envelope at 4 points/second; commit `6db3e63` implements timestamped envelopes and shared paper/trace/annotation timing in `RibbonTrace.swift`, `RibbonRenderer.swift`, and `EventCoordinator.swift`; `2cc8020` adds regression tests, whose execution remains unverified here. |
| 2.3: precision, maximum resolution, historical/physical authenticity | FIXED | Removed precision, maximum-resolution, 1935 comparison, professional-equivalence, and physical-authenticity claims; copy describes requested sampling, device motion, parchment texture, and a blur effect without asserting scientific qualification. |
| 2.3: four-pole bandpass | FIXED | Replaced the four-pole claim with a 0.1-10 Hz Butterworth bandpass made of four cascaded second-order sections, after a separate gravity-removal highpass, matching `ButterworthFilter.swift` and `AccelerometerPipeline.swift`. |
| 2.3: time markers with clock times | FIXED | Removed clock-time and 60-second-marker claims and fixed three-marker screenshot scenes; `RibbonRenderer.swift` still has an empty `renderTimeMarkerLabels` stub, so the plan relies on no clock labels or marker count. |
| 2.3: three attempts/checks and local label after exhaustion | FIXED | Copy now describes an initial check plus three retries with two-minute waits, possible rate-limit requests/delays, and Local vibration as the initial annotation rather than an exhaustion result, matching `EventCoordinator.swift:99`, `:126`-`:152` and `USGSClient.swift:41`-`:45`. |
| 2.3: query after any detection | FIXED | Removed the promise of a query after any detection; description and review notes state the four-event correlation cap and background cancellation, matching `EventCoordinator.swift:21`, `:65`-`:71`, `:105`-`:109` and `SeismoscopeApp.swift:54`-`:55`. |
| 2.3: milli-g/MMI units toggle | FIXED | Reworded MMI as an acceleration-based estimate shown in Roman numerals and removed the simultaneous mg/MMI screenshot; commit `e2b47ed` wires the setting to `StatusBarView.swift` and Wald et al. (1999) relations in `SeismicIntensity.swift`; `2cc8020` adds conversion tests, whose execution remains unverified here. |
| 2.3: low-power pauses Metal | FIXED | Removed the renderer-pausing claim; description and review notes state requested 50 Hz sampling with continued rendering, matching `AccelerometerPipeline.swift:81`-`:90` and `MetalRibbonView.swift:14`-`:20`. |
| 2.3: no user data leaves/only outbound call | FIXED | Replaced blanket no-data-leaves/only-call claims with local raw motion/history, transmitted selected coordinates and event-time queries, plus View on USGS page navigation; updated `PRIVACY.md` and the App Privacy checklist without assuming USGS retention. |
| 2.3: query contains only listed fields/network restriction | FIXED | Review notes now list all nine query fields from `USGSClient.swift:67`-`:76`; removed the enforced-host-restriction checklist claim and distinguish automatic API requests from user-selected USGS page visits. |
| 2.3: separately published SeismoscopeKit | FIXED | Removed the separate-publication claim; `project.yml` embeds a local package and `SeismoscopeKit/README.md` does not establish a standalone published package. |
| 2.3: detail screenshot header/duration | FIXED | Replaced the fabricated matched-detail screenshot with supported ribbon/settings states; review notes use Event Detail and actual Detection labels, omit duration, and make matched fields conditional, matching `EventDetailView.swift:21`, `:44`-`:51`, `:73`, `:89`-`:111`. |
| 2.3: debug screenshot/injection workflow | FIXED | Removed the nonexistent Settings earthquake-injection toggle; plan uses physical Release captures and explains Debug Sine/Noise/Impulse as display-only samples with no events/catalog checks, matching `SeismoscopeApp.swift:123`-`:145` and `SyntheticDataSource.swift:41`-`:47`. |
| 2.3: “always listening” | FIXED | Removed the always-listening and every-tremor headlines; copy and review steps explicitly require foreground operation, matching the background stop in `SeismoscopeApp.swift:54`-`:55`. |
| 2.3: reviewer timing procedure | FIXED | Replaced guaranteed launch/stability/query timings with automatic startup, at least 60 seconds foreground wait for the 45-second detector warmup, conditional detection, exact controls, and detail-sheet reopening only while an annotation remains visible; notes disclose that delayed results can outlast annotations and the timeout count excludes the initial query; no earthquake match is promised. |
| 2.3: keyword count | FIXED | Corrected the unchanged keyword string to Python's measured 93 characters and added measured counts for all five limited fields in `APPSTORE-METADATA.md`. |
| 9. Supported source claims | PASS | Requested 100/50 Hz sampling, 0.1-10 Hz filtering, STA/LTA/rearm, Metal/parchment/variable thickness/blur/fade-in, 500 km/10 minute/magnitude ≥1.5 correlation, USGS detail fields, 50 presets/custom coordinates/sensitivity, and local SwiftData are present in DSP, Metal, USGS, Views, and Models sources. No GPS, accounts, subscriptions, camera, microphone, or photo-library workflows found. This is static source evidence, not hardware acceptance. |
| Screenshots and device support | OPERATOR | `TARGETED_DEVICE_FAMILY` is `1,2`, minimum iOS 17: capture 6.9-inch iPhone **1320×2868** and 13-inch iPad **2064×2752** screenshots. Metadata now plans four supported ribbon/settings states at each required size, eight captures total. Existing `screenshots/screenshot-1.png` and `fastlane/screenshots/en-US/iPhone6.7-01.png` are duplicate 1290×2796 images with DEBUG controls. Replace with physical Release captures; Settings region and lower controls are separate scenes, and actual composition still needs capture verification. |
| Store name and record | OPERATOR | Supplied current record name is **Seismoscope** (possibly a placeholder). Operator must confirm intended final name and retain the existing `com.seismoscope.app` record. Dispatcher owns any store-version alignment; marketing version was not changed. |
| Remaining store metadata/actions | OPERATOR | Confirm subtitle, SKU, Utilities/Education categories, age rating 4+, Free price, territories, copyright, support/privacy URL availability, and actual metadata entry. Source cannot establish those store settings; metadata now labels them as intended submission values. Metadata URLs already point to repository issues and `PRIVACY.md`; no placeholder replacement needed. No live URL availability check was run. |
| Physical-device and TestFlight behavior | NOT RUN | No live motion, scientific validation, calibration, rendering, persistence/restart, battery, or TestFlight acceptance test was performed. Operator must perform the metadata checklist's device checks before asserting them. |
| Signed archive/validation/upload/submission | OPERATOR | Dispatcher performs these after review, successful local checks, signing qualification, screenshot preparation, and metadata/privacy reconciliation. None was attempted. |
| XcodeGen generation | PASS | `xcodegen generate` exited 0. Immediate `git status --short` showed only the intended project/config/source/doc changes and new lane files; final status includes this report. Tracked project and shared scheme regenerated; no workspace-file diff. |
| Simulator availability | FAIL | `xcrun simctl list devices available` exited 72: `xcrun: error: unable to find utility "simctl", not a developer tool or in PATH`. No available simulator could be selected; the documented iPhone 17 default was retained only for the attempted test command. No simulator workaround attempted. |
| Canonical package/app tests | FAIL | `make test` with temporary scratch/cache/config/security paths and DerivedData exited 2 in the package step: **`sandbox-exec: sandbox_apply: Operation not permitted`**. No tests ran. App step was then attempted independently with `make test-app`, also exit 2: `xcode-select: error: tool 'xcodebuild' requires Xcode`; active developer selection is CommandLineTools. No sandbox bypass or developer-directory mutation attempted. |
| Unsigned Release build/type-check | FAIL | Required generic iOS Release `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` exited 1: `xcode-select: error: tool 'xcodebuild' requires Xcode`; active developer selection is CommandLineTools. Compilation, linkage, generated app Info.plist, and resource packaging remain unverified. |
| Plist/privacy lint | PASS | `plutil -lint ExportOptions.plist Seismoscope/Resources/PrivacyInfo.xcprivacy Seismoscope.xcodeproj/project.pbxproj` exited 0; all three OK. No other plist/xcprivacy was touched. |
| Lane shell syntax | PASS | `bash -n distkit.ios.config.sh` exited 0. Lane was not executed or sourced. |
| Swift syntax in Release/Debug | PASS | `swiftc -frontend -parse` on the four changed Swift files, once without and once with `-D DEBUG`, both exited 0. Parsing does not prove iOS type-checking or runtime behavior. |
| Configuration readback | PASS | One-off Python/plutil assertions confirmed both IDs, inherited build 3, unchanged marketing version, export-compliance setting, sole motion usage key, privacy resource/reasons, app-only Release archive scheme, exact lane keys/public values, reference-identical export plist, and ignore rules. Initial heredoc invocation failed with `zsh:1: can't create temp file for here document: operation not permitted`; rerun with `python3 -c` passed, without changing execution permissions. |
| Diff hygiene | PASS | `git diff --check` exited 0. No feature/UI/refactor/dependency changes; release-only simulation/log guards are the hygiene fixes requested by item 8. No git-writing commands used. |

Current copy-only verification: Python measured Name **11/30**, Subtitle
**24/30**, Promotional text **144/170**, Keywords **93/100**, and Description
**2513/4000** characters, including internal description line breaks. The Name
row is unchanged. All 16 guideline 2.3 rows are FIXED; `git diff --check` passes,
and a search for U+2014/U+2013 in all three changed Markdown files finds none.
No Swift or plist files changed, so plain/DEBUG Swift parse and plist lint are
not applicable to this diff. No Xcode, simulator, Makefile, or SwiftPM checks
were run in this copy pass. Physical screenshot capture remains an operator gate.

Prior readiness-pass verification commands used the documented Makefile commands with argument
overrides so scratch data stayed under `$TMPDIR`; no Makefile changes were
needed. The test invocation below shows the same argument values in a reusable
form. It intentionally preserves SwiftPM sandboxing and disables Keychain use.

```sh
mkdir -p "$TMPDIR/spm-cache" "$TMPDIR/spm-config" "$TMPDIR/spm-security" \
  "$TMPDIR/clang-cache" "$TMPDIR/swift-cache"
task_spm_args="SeismoscopeKit --scratch-path \"$TMPDIR/spm-build\" --cache-path \"$TMPDIR/spm-cache\" --config-path \"$TMPDIR/spm-config\" --security-path \"$TMPDIR/spm-security\" --manifest-cache local --disable-keychain"
task_xcode_args="Seismoscope.xcodeproj -derivedDataPath \"$TMPDIR/dd\""
CLANG_MODULE_CACHE_PATH="$TMPDIR/clang-cache" \
  SWIFT_MODULECACHE_PATH="$TMPDIR/swift-cache" \
  make test SIMULATOR='iPhone 17' SWIFT_PACKAGE="$task_spm_args" \
  XCODE_PROJECT="$task_xcode_args"
make test-app SIMULATOR='iPhone 17' XCODE_PROJECT="$task_xcode_args"
xcodebuild -project Seismoscope.xcodeproj -scheme Seismoscope \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$TMPDIR/dd" CODE_SIGNING_ALLOWED=NO build
```

Conservative choices for review: preserve the reference export plist's automatic
signing while requesting manual lane signing; retain the existing transmitted-data
declarations until server retention is qualified; retain boot-time declarations
for indirect uptime-based timing. Factual metadata and reviewer instructions are now corrected against source;
physical capture, Xcode verification, and operator submission gates remain open.
