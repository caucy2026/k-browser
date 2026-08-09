#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BROWSER_DIR="$PROJECT_DIR/browser"
. "$PROJECT_DIR/build/upstream.env"

command -v bash >/dev/null 2>&1 || {
  echo "FAIL: bash is required" >&2
  exit 1
}
command -v wget >/dev/null 2>&1 || {
  echo "FAIL: wget is required" >&2
  exit 1
}

PREPARE_BIN=$(mktemp -d "${TMPDIR:-/tmp}/kbrowser-prepare.XXXXXX")
if command -v python >/dev/null 2>&1; then
  :
elif command -v python3 >/dev/null 2>&1; then
  ln -s "$(command -v python3)" "$PREPARE_BIN/python"
else
  echo "FAIL: Python 3 is required" >&2
  exit 1
fi

if [ "$(uname -s)" = Darwin ]; then
  command -v gsed >/dev/null 2>&1 || {
    echo "FAIL: GNU sed is required on macOS; install it with: brew install gnu-sed" >&2
    exit 1
  }
  ln -s "$(command -v gsed)" "$PREPARE_BIN/sed"
fi
PATH="$PREPARE_BIN:$PATH"
export PATH

git -C "$PROJECT_DIR" submodule update --init --recursive

ACTUAL_SHA=$(git -C "$BROWSER_DIR" rev-parse HEAD)
[ "$ACTUAL_SHA" = "$ICERAVEN_SHA" ] || {
  echo "FAIL: browser is $ACTUAL_SHA, expected $ICERAVEN_SHA" >&2
  exit 1
}

if [ -f "$BROWSER_DIR/app/src/main/java/org/mozilla/fenix/dualscreen/DualScreenBrowserActivity.kt" ]; then
  echo "SOURCE PREPARE PASSED: KBrowser patches are already applied"
  exit 0
fi

[ -z "$(git -C "$BROWSER_DIR" status --porcelain)" ] || {
  echo "FAIL: browser source has partial or unrelated changes; use a fresh clone" >&2
  exit 1
}

(
  cd "$BROWSER_DIR"
  ./automation/iceraven/patch_android_components.sh
)
"$PROJECT_DIR/scripts/apply-patches.sh" "$BROWSER_DIR"

echo "SOURCE PREPARE PASSED: $ICERAVEN_SHA + KBrowser patch series"
