#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION_NAME=${1:-1.0.0}
KEYSTORE_DIR="$PROJECT_DIR/keystore"
KEYSTORE_PATH="$KEYSTORE_DIR/kbrowser-release.jks"
SIGNING_PROPERTIES="$KEYSTORE_DIR/release-signing.properties"

[ -f "$KEYSTORE_PATH" ] || {
  echo "FAIL: release keystore not found: $KEYSTORE_PATH" >&2
  exit 1
}
[ -f "$SIGNING_PROPERTIES" ] || {
  echo "FAIL: signing properties not found: $SIGNING_PROPERTIES" >&2
  exit 1
}

# This ignored local file exports KBROWSER_KEYSTORE_PASSWORD,
# KBROWSER_KEY_PASSWORD and KBROWSER_KEY_ALIAS.
set -a
. "$SIGNING_PROPERTIES"
set +a

: "${KBROWSER_KEYSTORE_PASSWORD:?missing store password}"
: "${KBROWSER_KEY_PASSWORD:?missing key password}"
: "${KBROWSER_KEY_ALIAS:?missing key alias}"

KBROWSER_VERSION_NAME="$VERSION_NAME" \
KBROWSER_KEYSTORE_PATH="$KEYSTORE_PATH" \
  "$PROJECT_DIR/scripts/build-local.sh"

RELEASE_APK="$PROJECT_DIR/bin/DualScreenBrowser-v${VERSION_NAME}-arm64-release.apk"
cp "$PROJECT_DIR/bin/KBrowser-arm64.apk" "$RELEASE_APK"

SDK_DIR=${KBROWSER_ANDROID_SDK_ROOT:-"$PROJECT_DIR/.tools/android-sdk"}
JAVA_DIR=${KBROWSER_JAVA_HOME:-"$PROJECT_DIR/.tools/jdk17/Contents/Home"}
export JAVA_HOME="$JAVA_DIR"
APKSIGNER=$(find "$SDK_DIR/build-tools" -type f -name apksigner -print | sort -V | tail -n 1)
[ -x "$APKSIGNER" ] || {
  echo "FAIL: apksigner not found under $SDK_DIR/build-tools" >&2
  exit 1
}

"$APKSIGNER" verify --verbose --print-certs "$RELEASE_APK"
shasum -a 256 "$RELEASE_APK" > "$RELEASE_APK.sha256"
APK_SHA256=$(awk '{print $1}' "$RELEASE_APK.sha256")
SOURCE_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)
CERT_SHA256=$(openssl x509 -in "$KEYSTORE_DIR/kbrowser-release-cert.pem" \
  -noout -fingerprint -sha256 | sed 's/^.*=//')
{
  printf 'versionName=%s\n' "$VERSION_NAME"
  printf 'sourceCommit=%s\n' "$SOURCE_COMMIT"
  printf 'apkSha256=%s\n' "$APK_SHA256"
  printf 'certificateSha256=%s\n' "$CERT_SHA256"
} > "$RELEASE_APK.manifest.txt"
echo "RELEASE BUILD PASSED: $RELEASE_APK"
