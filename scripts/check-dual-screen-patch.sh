#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH="$PROJECT_DIR/patches/0001-add-dual-screen-browser-mode.patch"
grep -q 'DualScreenBrowserActivity' "$PATCH"
grep -q 'launchDisplayId = secondary.displayId' "$PATCH"
grep -q 'components.core.geckoRuntime' "$PATCH"
grep -q 'logicalTop + if (isSecondary) geckoView.height else 0' "$PATCH"
grep -q 'peer?.runOnUiThread' "$PATCH"
git -C "$PROJECT_DIR/browser" apply --check "$PATCH"
echo "DUAL SCREEN PATCH CHECK PASSED"
