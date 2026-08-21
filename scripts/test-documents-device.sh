#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ADB="$PROJECT_DIR/.tools/platform-tools/adb"
SERIAL=${1:-192.168.3.63:5555}
APK=${2:-"$PROJECT_DIR/bin/DualScreenBrowser-v1.3.0-arm64-release.apk"}
MODE=${3:-dual}
FROM_EXT=${KBROWSER_FROM_EXT:-}
FIXTURES="$PROJECT_DIR/artifacts/document-fixtures"
DEVICE_HOST=${SERIAL%%:*}
DEVICE_SUFFIX=${DEVICE_HOST##*.}
RESULTS="$PROJECT_DIR/artifacts/document-reader-device$DEVICE_SUFFIX-$MODE"
PACKAGE=io.github.forkmaintainers.iceraven
STARTED=false

mkdir -p "$RESULTS"
python3 "$PROJECT_DIR/scripts/generate-document-fixtures.py"
"$ADB" connect "${SERIAL%:5555}" >/dev/null

FOREGROUND=$("$ADB" -s "$SERIAL" shell dumpsys activity activities | sed -n 's/.*mResumedActivity:.* u0 \([^/ ]*\).*/\1/p' | head -n 1)
if [ "$MODE" = dual ]; then
    case "$FOREGROUND" in
        ''|com.android.launcher3|"$PACKAGE") ;;
        *) echo "DEVICE BUSY: foreground=$FOREGROUND" >&2; exit 3 ;;
    esac
fi

[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 2; }
"$ADB" -s "$SERIAL" install -r "$APK"
"$ADB" -s "$SERIAL" shell mkdir -p /sdcard/Download/kbrowser-documents
"$ADB" -s "$SERIAL" push "$FIXTURES"/. /sdcard/Download/kbrowser-documents/ >/dev/null
PACKAGE_UID=$("$ADB" -s "$SERIAL" shell dumpsys package "$PACKAGE" | sed -n 's/.*userId=\([0-9][0-9]*\).*/\1/p' | head -n 1)
[ -n "$PACKAGE_UID" ] || { echo "Cannot resolve package UID" >&2; exit 2; }
PRIVATE_FIXTURES="/data/user/0/$PACKAGE/cache/document-fixtures"
"$ADB" -s "$SERIAL" shell su 0 mkdir -p "$PRIVATE_FIXTURES"
"$ADB" -s "$SERIAL" logcat -c

mime_for() {
    case "$1" in
        txt|log|java|kt|kts|c|h|cpp|hpp|go|rs|py|js|jsx|ts|tsx|css|scss|sh|sql|graphql|md|markdown|mmd|puml|yaml|yml|toml|ini|properties) echo text/plain ;;
        html) echo text/html ;;
        xhtml) echo application/xhtml+xml ;;
        json) echo application/json ;;
        xml) echo application/xml ;;
        csv) echo text/csv ;;
        rtf) echo application/rtf ;;
        pdf) echo application/pdf ;;
        doc) echo application/msword ;;
        xls) echo application/vnd.ms-excel ;;
        ppt) echo application/vnd.ms-powerpoint ;;
        docx) echo application/vnd.openxmlformats-officedocument.wordprocessingml.document ;;
        xlsx) echo application/vnd.openxmlformats-officedocument.spreadsheetml.sheet ;;
        pptx) echo application/vnd.openxmlformats-officedocument.presentationml.presentation ;;
        odt) echo application/vnd.oasis.opendocument.text ;;
        ods) echo application/vnd.oasis.opendocument.spreadsheet ;;
        odp) echo application/vnd.oasis.opendocument.presentation ;;
        epub) echo application/epub+zip ;;
        mobi) echo application/x-mobipocket-ebook ;;
        *) echo application/octet-stream ;;
    esac
}

for FILE in "$FIXTURES"/*; do
    NAME=$(basename "$FILE")
    EXT=${NAME##*.}
    if [ -n "$FROM_EXT" ] && [ "$STARTED" = false ]; then
        [ "$EXT" = "$FROM_EXT" ] || continue
        STARTED=true
    fi
    MIME=$(mime_for "$EXT")
    PRIVATE_FILE="$PRIVATE_FIXTURES/$NAME"
    "$ADB" -s "$SERIAL" shell su 0 cp "/sdcard/Download/kbrowser-documents/$NAME" "$PRIVATE_FILE"
    "$ADB" -s "$SERIAL" shell su 0 chown "$PACKAGE_UID:$PACKAGE_UID" "$PRIVATE_FILE"
    "$ADB" -s "$SERIAL" shell su 0 chmod 600 "$PRIVATE_FILE"
    "$ADB" -s "$SERIAL" shell su 0 restorecon "$PRIVATE_FILE"
    URI="file://$PRIVATE_FILE"
    "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE"
    "$ADB" -s "$SERIAL" logcat -c
    SINGLE_EXTRA=""
    if [ "$MODE" = single ]; then
        SINGLE_EXTRA="--ez kbrowser.document.singleScreenDiagnostic true"
    fi
    # shellcheck disable=SC2086 -- the optional pair is intentionally expanded as two arguments.
    "$ADB" -s "$SERIAL" shell am start --display 2 -W -a android.intent.action.VIEW \
        -c android.intent.category.DEFAULT -p "$PACKAGE" -d "$URI" -t "$MIME" \
        $SINGLE_EXTRA > "$RESULTS/$EXT-start.txt"
    sleep 2
    STATE=$("$ADB" -s "$SERIAL" shell dumpsys activity activities)
    printf '%s\n' "$STATE" > "$RESULTS/$EXT-activities.txt"
    if [ "$MODE" = single ]; then
        printf '%s\n' "$STATE" | grep -q 'SingleScreenBrowserActivity'
    else
        printf '%s\n' "$STATE" | grep -q 'displayId=0\|Display #0'
        printf '%s\n' "$STATE" | grep -q 'DualScreenBrowserActivity'
        printf '%s\n' "$STATE" | grep -q 'DualScreenTopActivity'
    fi
    "$ADB" -s "$SERIAL" shell logcat -d -s KBrowserDocument:I KBrowserLaunch:I '*:S' > "$RESULTS/$EXT-document.log"
    if [ "$EXT" = pdf ]; then
        "$ADB" -s "$SERIAL" exec-out screencap -d 2 -p > "$RESULTS/pdf-display2.png"
    else
        grep -q "DOCUMENT_READY format=$EXT" "$RESULTS/$EXT-document.log"
        grep -q 'DOCUMENT_LOADED loopback=true' "$RESULTS/$EXT-document.log"
        if grep -q "parse failed format=$EXT\|read failed format=$EXT" "$RESULTS/$EXT-document.log"; then
            echo "FAIL: parser reported an error for $NAME" >&2
            exit 1
        fi
    fi
done

# Representative continuity and input checks after the matrix.
"$ADB" -s "$SERIAL" shell input -d 2 swipe 960 1040 960 300 450
sleep 1
"$ADB" -s "$SERIAL" exec-out screencap -d 2 -p > "$RESULTS/display2-after-d2-scroll.png"
if [ "$MODE" = dual ]; then
    "$ADB" -s "$SERIAL" exec-out screencap -d 0 -p > "$RESULTS/display0-after-d2-scroll.png"
    "$ADB" -s "$SERIAL" shell input -d 0 swipe 960 1040 960 300 450
    sleep 1
    "$ADB" -s "$SERIAL" exec-out screencap -d 2 -p > "$RESULTS/display2-after-d0-scroll.png"
    "$ADB" -s "$SERIAL" exec-out screencap -d 0 -p > "$RESULTS/display0-after-d0-scroll.png"
fi
"$ADB" -s "$SERIAL" shell dumpsys meminfo "$PACKAGE" > "$RESULTS/meminfo.txt"
"$ADB" -s "$SERIAL" shell input -d 2 keyevent 4
sleep 1
"$ADB" -s "$SERIAL" shell dumpsys activity activities > "$RESULTS/after-exit-activities.txt"
if grep -q 'DualScreenBrowserActivity\|DualScreenTopActivity\|SingleScreenBrowserActivity' "$RESULTS/after-exit-activities.txt"; then
    echo "FAIL: paired activities remain after Display 2 back" >&2
    exit 1
fi
"$ADB" -s "$SERIAL" logcat -d > "$RESULTS/logcat.txt"
if grep -q 'FATAL EXCEPTION.*iceraven\|ANR in io.github.forkmaintainers.iceraven' "$RESULTS/logcat.txt"; then
    echo "FAIL: crash or ANR detected" >&2
    exit 1
fi
echo "DOCUMENT DEVICE TEST PASSED: $RESULTS"
