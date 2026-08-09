#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BROWSER_DIR="$PROJECT_DIR/browser"
. "$PROJECT_DIR/build/upstream.env"

command -v bash >/dev/null 2>&1 || {
  echo "FAIL: bash is required" >&2
  exit 1
}
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=$(command -v python3)
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=$(command -v python)
else
  echo "FAIL: Python 3 is required" >&2
  exit 1
fi

PREPARE_VENV="$PROJECT_DIR/.tools/prepare-venv"
if [ -x "$PREPARE_VENV/bin/python" ] && \
    "$PREPARE_VENV/bin/python" -c 'import yaml' >/dev/null 2>&1; then
  PYTHON_BIN="$PREPARE_VENV/bin/python"
elif ! "$PYTHON_BIN" -c 'import yaml' >/dev/null 2>&1; then
  "$PYTHON_BIN" -m venv "$PREPARE_VENV"
  "$PREPARE_VENV/bin/python" -m pip install --disable-pip-version-check 'PyYAML==6.0.2'
  PYTHON_BIN="$PREPARE_VENV/bin/python"
fi

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

"$PYTHON_BIN" "$PROJECT_DIR/scripts/prepare-iceraven.py" "$BROWSER_DIR"
"$PROJECT_DIR/scripts/apply-patches.sh" "$BROWSER_DIR"

echo "SOURCE PREPARE PASSED: $ICERAVEN_SHA + KBrowser patch series"
