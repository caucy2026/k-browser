#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$PROJECT_DIR/config/device.env"

ADB=${ADB:-"$PROJECT_DIR/.tools/platform-tools/adb"}
APK=${1:-}

[ -n "$APK" ] || { echo "Usage: $0 /absolute/path/to/app.apk" >&2; exit 2; }
[ -n "$KBROWSER_DEVICE" ] || { echo "FAIL: create config/device.local.env" >&2; exit 1; }
[ -f "$APK" ] || { echo "FAIL: APK not found: $APK" >&2; exit 1; }
[ -x "$ADB" ] || { echo "FAIL: ADB not found: $ADB" >&2; exit 1; }

$ADB connect "$KBROWSER_DEVICE" >/dev/null
$ADB -s "$KBROWSER_DEVICE" install -r "$APK"

echo "APK INSTALL PASSED"
