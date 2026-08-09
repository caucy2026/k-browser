#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BROWSER_SRC=${1:-}
SERIES="$PROJECT_DIR/patches/series"

[ -d "$BROWSER_SRC/.git" ] || [ -f "$BROWSER_SRC/.git" ] || {
  echo "Usage: $0 /absolute/path/to/iceraven-browser" >&2
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

  git -C "$BROWSER_SRC" apply --check "$PATCH_PATH"
  git -C "$BROWSER_SRC" apply "$PATCH_PATH"
  echo "Applied: $PATCH"
done < "$SERIES"

echo "PATCH APPLY PASSED"
