#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$PROJECT_DIR/config/device.env"

ADB=${ADB:-"$PROJECT_DIR/.tools/platform-tools/adb"}
PACKAGE=${1:-}

[ -n "$PACKAGE" ] || { echo "Usage: $0 package.name" >&2; exit 2; }
[ -n "$KBROWSER_DEVICE" ] || { echo "FAIL: create config/device.local.env" >&2; exit 1; }

WINDOWS=$($ADB -s "$KBROWSER_DEVICE" shell dumpsys window windows | tr -d '\r')

echo "$WINDOWS" | grep -E "displayId=$KBROWSER_MAIN_DISPLAY.*$PACKAGE|$PACKAGE.*displayId=$KBROWSER_MAIN_DISPLAY" >/dev/null || {
  echo "FAIL: no $PACKAGE window on display $KBROWSER_MAIN_DISPLAY" >&2
  exit 1
}

echo "$WINDOWS" | grep -E "displayId=$KBROWSER_SECONDARY_DISPLAY.*$PACKAGE|$PACKAGE.*displayId=$KBROWSER_SECONDARY_DISPLAY" >/dev/null || {
  echo "FAIL: no $PACKAGE window on display $KBROWSER_SECONDARY_DISPLAY" >&2
  exit 1
}

echo "Main display: $KBROWSER_MAIN_DISPLAY"
echo "Secondary display: $KBROWSER_SECONDARY_DISPLAY"
echo "ACTIVITY DISPLAY CHECK PASSED"
