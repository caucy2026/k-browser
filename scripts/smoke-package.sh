#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$PROJECT_DIR/config/device.env"

ADB=${ADB:-"$PROJECT_DIR/.tools/platform-tools/adb"}
PACKAGE=${1:-}

[ -n "$PACKAGE" ] || { echo "Usage: $0 package.name" >&2; exit 2; }
[ -n "$KBROWSER_DEVICE" ] || { echo "FAIL: create config/device.local.env" >&2; exit 1; }

$ADB connect "$KBROWSER_DEVICE" >/dev/null
$ADB -s "$KBROWSER_DEVICE" shell pm path "$PACKAGE" | grep -q '^package:' || {
  echo "FAIL: package is not installed: $PACKAGE" >&2
  exit 1
}

$ADB -s "$KBROWSER_DEVICE" logcat -c
$ADB -s "$KBROWSER_DEVICE" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 2

PID=$($ADB -s "$KBROWSER_DEVICE" shell pidof "$PACKAGE" | tr -d '\r')
[ -n "$PID" ] || { echo "FAIL: package did not start: $PACKAGE" >&2; exit 1; }

if $ADB -s "$KBROWSER_DEVICE" logcat -d -v brief | grep -E "FATAL EXCEPTION|Process: $PACKAGE" >/dev/null; then
  echo "FAIL: fatal exception detected for $PACKAGE" >&2
  exit 1
fi

echo "Package: $PACKAGE"
echo "PID: $PID"
echo "PACKAGE SMOKE PASSED"
