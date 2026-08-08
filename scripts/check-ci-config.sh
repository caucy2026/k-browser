#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$PROJECT_DIR/build/upstream.env"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "$ICERAVEN_SHA" | grep -Eq '^[0-9a-f]{40}$' || fail "invalid ICERAVEN_SHA"
[ -f "$PROJECT_DIR/patches/series" ] || fail "patches/series is missing"
[ -f "$PROJECT_DIR/.gitmodules" ] || fail ".gitmodules is missing"
grep -q 'fork-maintainers/iceraven-browser.git' "$PROJECT_DIR/.gitmodules" || fail "unexpected browser submodule"

if [ -d "$PROJECT_DIR/browser/.git" ] || [ -f "$PROJECT_DIR/browser/.git" ]; then
  ACTUAL_SHA=$(git -C "$PROJECT_DIR/browser" rev-parse HEAD)
  [ "$ACTUAL_SHA" = "$ICERAVEN_SHA" ] || fail "browser is $ACTUAL_SHA, expected $ICERAVEN_SHA"
fi

while IFS= read -r PATCH || [ -n "$PATCH" ]; do
  case "$PATCH" in
    ''|'#'*) continue ;;
  esac
  [ -f "$PROJECT_DIR/$PATCH" ] || fail "missing patch listed in series: $PATCH"
done < "$PROJECT_DIR/patches/series"

echo "Iceraven commit: $ICERAVEN_SHA"
echo "CI CONFIG CHECK PASSED"
