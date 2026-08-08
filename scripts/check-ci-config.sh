#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$PROJECT_DIR/build/upstream.env"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "$CROMITE_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || fail "invalid CROMITE_VERSION"
echo "$CROMITE_SHA" | grep -Eq '^[0-9a-f]{40}$' || fail "invalid CROMITE_SHA"
[ "$CROMITE_IMAGE" = "uazo/cromite-build:$CROMITE_VERSION-$CROMITE_SHA" ] || fail "image does not match version and SHA"
[ -f "$PROJECT_DIR/patches/series" ] || fail "patches/series is missing"

while IFS= read -r PATCH || [ -n "$PATCH" ]; do
  case "$PATCH" in
    ''|'#'*) continue ;;
  esac
  [ -f "$PROJECT_DIR/$PATCH" ] || fail "missing patch listed in series: $PATCH"
done < "$PROJECT_DIR/patches/series"

echo "Cromite: $CROMITE_VERSION"
echo "Commit: $CROMITE_SHA"
echo "Image: $CROMITE_IMAGE"
echo "CI CONFIG CHECK PASSED"
