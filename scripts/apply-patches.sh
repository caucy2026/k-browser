#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHROMIUM_SRC=${1:-}
SERIES="$PROJECT_DIR/patches/series"

[ -d "$CHROMIUM_SRC/.git" ] || [ -f "$CHROMIUM_SRC/.git" ] || {
  echo "Usage: $0 /absolute/path/to/chromium/src" >&2
  exit 2
}

while IFS= read -r PATCH || [ -n "$PATCH" ]; do
  case "$PATCH" in
    ''|'#'*) continue ;;
  esac

  PATCH_PATH="$PROJECT_DIR/$PATCH"
  [ -f "$PATCH_PATH" ] || {
    echo "FAIL: missing patch: $PATCH" >&2
    exit 1
  }

  git -C "$CHROMIUM_SRC" apply --check "$PATCH_PATH"
  git -C "$CHROMIUM_SRC" apply "$PATCH_PATH"
  echo "Applied: $PATCH"
done < "$SERIES"

echo "PATCH APPLY PASSED"
