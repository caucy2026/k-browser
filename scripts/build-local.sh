#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BROWSER_DIR="$PROJECT_DIR/browser"
JAVA_DIR=${KBROWSER_JAVA_HOME:-"$PROJECT_DIR/.tools/jdk17/Contents/Home"}
SDK_DIR=${KBROWSER_ANDROID_SDK_ROOT:-"$PROJECT_DIR/.tools/android-sdk"}
VERSION_NAME=${KBROWSER_VERSION_NAME:-"$(git -C "$PROJECT_DIR" rev-parse --short HEAD)-local"}
KEYSTORE_PATH=${KBROWSER_KEYSTORE_PATH:-"$PROJECT_DIR/.tools/kbrowser-debug.keystore"}
KEYSTORE_PASSWORD=${KBROWSER_KEYSTORE_PASSWORD:-android}
KEY_ALIAS=${KBROWSER_KEY_ALIAS:-androiddebugkey}
KEY_PASSWORD=${KBROWSER_KEY_PASSWORD:-$KEYSTORE_PASSWORD}

export KBROWSER_KEYSTORE_PASSWORD="$KEYSTORE_PASSWORD"
export KBROWSER_KEY_PASSWORD="$KEY_PASSWORD"

[ -x "$JAVA_DIR/bin/java" ] || {
  echo "FAIL: JDK 17 not found: $JAVA_DIR" >&2
  exit 1
}
[ -d "$SDK_DIR/platforms" ] || {
  echo "FAIL: Android SDK not found: $SDK_DIR" >&2
  exit 1
}
[ -f "$BROWSER_DIR/app/src/main/java/org/mozilla/fenix/dualscreen/DualScreenBrowserActivity.kt" ] || {
  echo "FAIL: browser patches are not applied; run scripts/apply-patches.sh first" >&2
  exit 1
}
grep -q 'dl.google.com/dl/android/maven2' "$BROWSER_DIR/mozconfig.json" || {
  echo "FAIL: direct Google Maven endpoint patch is not applied" >&2
  exit 1
}

PSL_PATH="$BROWSER_DIR/netwerk/dns/effective_tld_names.dat"
PSL_FALLBACK="$PSL_PATH.DS_Store"
if [ ! -f "$PSL_PATH" ] && [ -f "$PSL_FALLBACK" ]; then
  cp "$PSL_FALLBACK" "$PSL_PATH"
fi
if [ ! -f "$PSL_PATH" ]; then
  FIREFOX_VERSION=$(tr '.' '_' < "$BROWSER_DIR/version.txt")
  PSL_URL="https://raw.githubusercontent.com/mozilla-firefox/firefox/refs/tags/FIREFOX-ANDROID_${FIREFOX_VERSION}_RELEASE/netwerk/dns/effective_tld_names.dat"
  mkdir -p "$(dirname "$PSL_PATH")"
  curl --ipv4 --fail --location --retry 5 --retry-delay 2 \
    --output "$PSL_PATH.part" "$PSL_URL"
  mv "$PSL_PATH.part" "$PSL_PATH"
fi
[ -f "$PSL_PATH" ] || {
  echo "FAIL: Firefox public suffix list is missing: $PSL_PATH" >&2
  exit 1
}

export JAVA_HOME="$JAVA_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export GRADLE_OPTS='-Dorg.gradle.jvmargs=-XX:MaxMetaspaceSize=2g -Xms1g -Xmx6g -XX:+HeapDumpOnOutOfMemoryError'

cd "$BROWSER_DIR"
./gradlew app:assembleForkRelease \
  -PversionName="$VERSION_NAME" \
  --stacktrace --no-daemon --console=plain

APK_PATH=$(find gradle/build/app/outputs/apk app/build/outputs/apk -type f -iname '*arm64-v8a*.apk' -print 2>/dev/null | head -n 1)
[ -n "$APK_PATH" ] || APK_PATH=$(find gradle/build/app/outputs/apk app/build/outputs/apk -type f -iname '*.apk' -print 2>/dev/null | head -n 1)
[ -n "$APK_PATH" ] || {
  echo "FAIL: build completed without an APK" >&2
  exit 1
}

mkdir -p "$PROJECT_DIR/bin"
if printf '%s\n' "$APK_PATH" | grep -q -- '-unsigned\.apk$'; then
  APKSIGNER=$(find "$SDK_DIR/build-tools" -type f -name apksigner -print | sort -V | tail -n 1)
  [ -x "$APKSIGNER" ] || {
    echo "FAIL: apksigner not found under $SDK_DIR/build-tools" >&2
    exit 1
  }
  if [ ! -f "$KEYSTORE_PATH" ]; then
    mkdir -p "$(dirname "$KEYSTORE_PATH")"
    "$JAVA_DIR/bin/keytool" -genkeypair -noprompt \
      -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" \
      -alias "$KEY_ALIAS" -keypass "$KEY_PASSWORD" \
      -dname 'CN=KBrowser Local Build,O=KEMI,C=CN' \
      -keyalg RSA -keysize 2048 -validity 10000
  fi
  "$APKSIGNER" sign \
    --ks "$KEYSTORE_PATH" --ks-pass env:KBROWSER_KEYSTORE_PASSWORD \
    --ks-key-alias "$KEY_ALIAS" --key-pass env:KBROWSER_KEY_PASSWORD \
    --out "$PROJECT_DIR/bin/KBrowser-arm64.apk" "$APK_PATH"
  "$APKSIGNER" verify --verbose "$PROJECT_DIR/bin/KBrowser-arm64.apk"
else
  cp "$APK_PATH" "$PROJECT_DIR/bin/KBrowser-arm64.apk"
fi
shasum -a 256 "$PROJECT_DIR/bin/KBrowser-arm64.apk" > "$PROJECT_DIR/bin/KBrowser-arm64.apk.sha256"
echo "LOCAL BUILD PASSED: $PROJECT_DIR/bin/KBrowser-arm64.apk"
