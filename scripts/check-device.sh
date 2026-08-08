#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$PROJECT_DIR/config/device.env"

ADB=${ADB:-"$PROJECT_DIR/.tools/platform-tools/adb"}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$ADB" ] || fail "ADB not found at $ADB"
[ -n "$KBROWSER_DEVICE" ] || fail "KBROWSER_DEVICE is not configured; create config/device.local.env"

CONNECT_OUTPUT=$($ADB connect "$KBROWSER_DEVICE" 2>&1) || fail "cannot connect to $KBROWSER_DEVICE: $CONNECT_OUTPUT"
STATE=$($ADB -s "$KBROWSER_DEVICE" get-state 2>/dev/null || true)
[ "$STATE" = "device" ] || fail "ADB state is '$STATE'"

SDK=$($ADB -s "$KBROWSER_DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')
ABI=$($ADB -s "$KBROWSER_DEVICE" shell getprop ro.product.cpu.abi | tr -d '\r')
ANDROID=$($ADB -s "$KBROWSER_DEVICE" shell getprop ro.build.version.release | tr -d '\r')
MODEL=$($ADB -s "$KBROWSER_DEVICE" shell getprop ro.product.model | tr -d '\r')
MEM_KB=$($ADB -s "$KBROWSER_DEVICE" shell cat /proc/meminfo | tr -d '\r' | awk '/^MemTotal:/ {print $2; exit}')
DISPLAY_DUMP=$($ADB -s "$KBROWSER_DEVICE" shell dumpsys display | tr -d '\r')

[ "$SDK" -ge "$KBROWSER_MIN_SDK" ] || fail "SDK $SDK is below $KBROWSER_MIN_SDK"
[ "$ABI" = "$KBROWSER_ABI" ] || fail "ABI is $ABI, expected $KBROWSER_ABI"
case "$MEM_KB" in
  ''|*[!0-9]*) fail "cannot read total memory" ;;
esac

echo "$DISPLAY_DUMP" | grep -q "displayId=$KBROWSER_MAIN_DISPLAY" || fail "main display $KBROWSER_MAIN_DISPLAY missing"
echo "$DISPLAY_DUMP" | grep -q "displayId=$KBROWSER_SECONDARY_DISPLAY" || fail "secondary display $KBROWSER_SECONDARY_DISPLAY missing"

EXPECTED_SIZE="${KBROWSER_DISPLAY_WIDTH} x ${KBROWSER_DISPLAY_HEIGHT}"
MAIN_LINE=$(echo "$DISPLAY_DUMP" | grep "DisplayDeviceInfo" | grep "内置屏幕" | head -n 1)
SECONDARY_LINE=$(echo "$DISPLAY_DUMP" | grep "DisplayDeviceInfo" | grep "HDMI 屏幕" | head -n 1)

echo "$MAIN_LINE" | grep -q "$EXPECTED_SIZE" || fail "main display is not $EXPECTED_SIZE"
echo "$SECONDARY_LINE" | grep -q "$EXPECTED_SIZE" || fail "secondary display is not $EXPECTED_SIZE"

ON_COUNT=$(echo "$DISPLAY_DUMP" | grep -c "Display State=ON" || true)
[ "$ON_COUNT" -ge 2 ] || fail "both displays are not ON"

MEM_MB=$((MEM_KB / 1024))

echo "Device: $MODEL"
echo "Android: $ANDROID (SDK $SDK)"
echo "ABI: $ABI"
echo "RAM: ${MEM_MB} MB"
echo "Display $KBROWSER_MAIN_DISPLAY: ${KBROWSER_DISPLAY_WIDTH}x${KBROWSER_DISPLAY_HEIGHT} ON"
echo "Display $KBROWSER_SECONDARY_DISPLAY: ${KBROWSER_DISPLAY_WIDTH}x${KBROWSER_DISPLAY_HEIGHT} ON"
echo "Logical canvas: ${KBROWSER_DISPLAY_WIDTH}x$((KBROWSER_DISPLAY_HEIGHT * 2))"
echo "DEVICE CHECK PASSED"
