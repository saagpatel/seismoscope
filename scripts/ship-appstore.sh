#!/usr/bin/env bash
#
# ship-appstore.sh — archive Seismoscope and upload it to App Store Connect.
#
# This is the one-command ship path. It assumes the operator-gated prerequisites
# below are already done; it will NOT create portal records for you.
#
# ── ONE-TIME PREREQUISITES (do these before the first run) ───────────────────
#   0. Full Xcode installed and selected:
#        sudo xcode-select -s /Applications/Xcode.app
#   1. Bundle id `com.seismoscope.app` registered in the Apple Developer portal.
#   2. Distribution provisioning profile "Seismoscope App Store" installed.
#      (This one is ALREADY installed on this machine — Seismoscope is the
#      least-friction app to ship first.)
#   3. App record created in App Store Connect for `com.seismoscope.app`, with the
#      metadata from APPSTORE-METADATA.md / fastlane/metadata pasted in.
#      Seismoscope is FREE, so it only needs the free distribution agreement —
#      no Paid Applications / banking + tax agreement required.
#   4. App Store Connect API key downloaded once from
#      App Store Connect → Users and Access → Integrations → App Store Connect API.
#      Then export these before running (the .p8 lives wherever you saved it):
#        export ASC_KEY_ID=XXXXXXXXXX
#        export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#        export ASC_KEY_PATH="$HOME/.appstoreconnect/private/AuthKey_XXXXXXXXXX.p8"
#
# ── RUN ──────────────────────────────────────────────────────────────────────
#        bash scripts/ship-appstore.sh
#
# Screenshots are uploaded separately in App Store Connect. Seismoscope is
# currently UNIVERSAL (TARGETED_DEVICE_FAMILY=1,2): you will need the iPhone 6.9"
# (1320x2868) set AND an iPad 13" (2048x2732) set. If you decide to ship
# iPhone-only, set TARGETED_DEVICE_FAMILY=1 in project.yml first and the iPad
# set is no longer required.
#
# For a RESUBMISSION, bump the build number first so ASC accepts a new binary:
#        agvtool next-version -all      # or edit CURRENT_PROJECT_VERSION in project.yml
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Seismoscope"
ARCHIVE="build/${SCHEME}.xcarchive"
EXPORT_DIR="build/export"

: "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect API key id)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (App Store Connect API issuer id)}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH (path to the AuthKey_*.p8 file)}"

echo "==> [1/3] regenerating Xcode project from project.yml"
xcodegen generate

echo "==> [2/3] archiving $SCHEME (Release, generic iOS device, distribution-signed)"
xcodebuild \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  clean archive

echo "==> [3/3] exporting + uploading to App Store Connect"
# ExportOptions.plist already sets method=app-store-connect, destination=upload,
# so -exportArchive uploads the binary directly instead of writing a local .ipa.
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH"

echo "==> done. Build is uploading; watch App Store Connect → TestFlight for processing,"
echo "    then attach screenshots + submit for review in the app's ASC page."
