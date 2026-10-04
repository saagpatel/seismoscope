#!/bin/bash
set -euo pipefail

# Run on a full Xcode host. No signing, live motion, or catalog requests are used.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
derived="${DERIVED:-.build/shots}"
booted_ids=()
override_ids=()

fail() {
    printf 'Screenshot capture failed: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    local result=$?
    local id
    trap - EXIT INT TERM
    # macOS Bash 3.2 treats an empty array as unset under nounset.
    for id in ${override_ids[@]+"${override_ids[@]}"}; do
        if ! xcrun simctl status_bar "$id" clear; then
            printf 'Could not clear status bar override for %s\n' "$id" >&2
            result=1
        fi
    done
    for id in ${booted_ids[@]+"${booted_ids[@]}"}; do
        if ! xcrun simctl shutdown "$id"; then
            printf 'Could not shut down simulator %s\n' "$id" >&2
            result=1
        fi
    done
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for tool in xcodebuild xcrun python3 sips; do
    command -v "$tool" >/dev/null || fail "Required tool is missing: $tool"
done

# Validate waits before touching a simulator. Per-shot values override SHOT_WAIT (seconds).
waits=()
for shot in 1 2 3 4; do
    wait_name="SHOT_WAIT_${shot}"
    wait_value="${!wait_name:-${SHOT_WAIT:-4}}"
    [[ "$wait_value" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "$wait_name must be nonnegative seconds"
    waits+=("$wait_value")
done

xcodebuild build -project Seismoscope.xcodeproj -scheme Seismoscope \
    -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO

app_path="$(python3 -c '
import pathlib, sys
apps = sorted((pathlib.Path(sys.argv[1]) / "Build/Products/Debug-iphonesimulator").glob("*.app"))
if len(apps) != 1:
    sys.exit(f"Expected one simulator app in {sys.argv[1]}, found {len(apps)}")
print(apps[0])
' "$derived")"
bundle_id="$(python3 -c '
import pathlib, plistlib, sys
with (pathlib.Path(sys.argv[1]) / "Info.plist").open("rb") as source:
    bundle_id = plistlib.load(source).get("CFBundleIdentifier")
if not isinstance(bundle_id, str) or not bundle_id:
    sys.exit("Built app Info.plist has no CFBundleIdentifier")
print(bundle_id)
' "$app_path")"

# Prefer an already booted device; otherwise choose the newest installed iOS runtime.
# Resolve both required names up front, so missing iPad support fails before captures.
selected_devices="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
selected = []
for name in ("iPhone 18 Pro Max", "iPad Pro 13-inch (M5)"):
    matches = [(runtime, d) for runtime, entries in devices.items()
               if "iOS" in runtime for d in entries
               if d["name"] == name and d.get("isAvailable", True)]
    if not matches:
        sys.exit(f"Required simulator is missing: {name}. Install its iOS runtime and create this device in Xcode.")
    matches.sort(key=lambda item: (item[1]["state"] == "Booted",
                                  tuple(int(n) for n in re.findall(r"\d+", item[0])),
                                  item[1]["udid"]), reverse=True)
    device = matches[0][1]
    state = device["state"]
    if state not in ("Booted", "Shutdown"):
        sys.exit(f"Simulator {name} is {state}; wait until it is Booted or Shutdown.")
    selected.append(device["udid"] + ":" + device["state"])
print(" ".join(selected))
')"
read -r phone_info tablet_info < <(printf '%s\n' "$selected_devices")

for device_index in 0 1; do
    if [[ "$device_index" == 0 ]]; then
        device_info="$phone_info"
        slug=iphone-18-pro-max
        expected_width=1320
        expected_height=2868
    else
        device_info="$tablet_info"
        slug=ipad-pro-13-inch-m5
        expected_width=2064
        expected_height=2752
    fi
    device_id="${device_info%%:*}"
    if [[ "${device_info#*:}" == Shutdown ]]; then
        booted_ids+=("$device_id")
        xcrun simctl boot "$device_id"
    fi
    xcrun simctl bootstatus "$device_id" -b
    override_ids+=("$device_id")
    xcrun simctl status_bar "$device_id" override --time 9:41 --dataNetwork wifi \
        --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
    xcrun simctl install "$device_id" "$app_path"
    xcrun simctl ui "$device_id" appearance light
    output_dir="screenshots/appstore/$slug"
    mkdir -p "$output_dir"

    for shot in 1 2 3 4; do
        # simctl terminate also fails when the app is not running (normal on the first shot).
        xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1 || true
        xcrun simctl launch "$device_id" "$bundle_id" -AppStoreScreenshot "$shot" \
            -AppleLanguages '(en)' -AppleLocale en_US
        sleep "${waits[$((shot - 1))]}"
        printf -v filename '%02d.png' "$shot"
        output="$output_dir/$filename"
        xcrun simctl io "$device_id" screenshot "$output"
        dimensions="$(sips -g pixelWidth -g pixelHeight "$output")"
        actual_width="$(printf '%s\n' "$dimensions" | awk '/pixelWidth:/ {print $2}')"
        actual_height="$(printf '%s\n' "$dimensions" | awk '/pixelHeight:/ {print $2}')"
        [[ "$actual_width" == "$expected_width" && "$actual_height" == "$expected_height" ]] || \
            fail "$output is ${actual_width}x${actual_height}; expected ${expected_width}x${expected_height}. Use portrait orientation."
        printf 'Captured %s (%sx%s)\n' "$output" "$actual_width" "$actual_height"
    done
done
