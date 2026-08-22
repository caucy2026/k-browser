#!/bin/sh

# Ten-viewport, per-format hardware acceptance. A format only passes when all ten D2/D0 frame
# pairs are non-blank, non-mirrored and unique, both displays can originate scrolling, paired
# exit succeeds, and the process remains within the documented parse/memory limits.
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ADB="$PROJECT_DIR/.tools/platform-tools/adb"
ANALYZER="$PROJECT_DIR/scripts/analyze-screencap.py"
SERIAL=${1:-192.168.3.62:5555}
APK=${2:-"$PROJECT_DIR/bin/DualScreenBrowser-v1.3.0-arm64-release.apk"}
MODE=${3:-dual}
ONLY_EXT=${KBROWSER_ONLY_EXT:-}
ONLY_EXTS=${KBROWSER_ONLY_EXTS:-}
RESULTS_TAG=${KBROWSER_RESULTS_TAG:-}
SKIP_INSTALL=${KBROWSER_SKIP_INSTALL:-0}
FROM_EXT=${KBROWSER_FROM_EXT:-}
PACKAGE=io.github.forkmaintainers.iceraven
FIXTURES="$PROJECT_DIR/artifacts/document-fixtures"
DEVICE_HOST=${SERIAL%%:*}
DEVICE_SUFFIX=${DEVICE_HOST##*.}
RESULTS="$PROJECT_DIR/artifacts/document-reader-ten-page-device$DEVICE_SUFFIX-$MODE${RESULTS_TAG:+-$RESULTS_TAG}"
SUMMARY="$RESULTS/ten-page-results.csv"
FINGERPRINTS="$RESULTS/page-fingerprints.csv"
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/kbrowser-ten-page.XXXXXX")
STARTED=false
TEST_ACTIVE=false
cleanup() {
    if [ "$TEST_ACTIVE" = true ]; then
        "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE" >/dev/null 2>&1 || true
    fi
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$RESULTS"
python3 "$PROJECT_DIR/scripts/generate-document-fixtures.py"
"$ADB" connect "${SERIAL%:5555}" >/dev/null

foreground_packages() {
    "$ADB" -s "$SERIAL" shell dumpsys activity activities |
        sed -n 's/.*mResumedActivity:.* u0 \([^/ ]*\).*/\1/p' | sort -u
}

assert_device_available() {
    if [ "$MODE" = dual ]; then
        for active_package in $(foreground_packages); do
            case "$active_package" in
                ''|com.android.launcher3|"$PACKAGE") ;;
                *) echo "DEVICE BUSY DURING TEST: foreground=$active_package" >&2; exit 3 ;;
            esac
        done
    else
        active_d2=$("$ADB" -s "$SERIAL" shell dumpsys activity activities |
            sed -n '/Display #2/,/Display #0/p' |
            sed -n 's/.*mResumedActivity:.* u0 \([^/ ]*\).*/\1/p' | head -n 1)
        case "$active_d2" in
            ''|com.android.launcher3|"$PACKAGE") ;;
            *) echo "DEVICE BUSY DURING TEST: D2 foreground=$active_d2" >&2; exit 3 ;;
        esac
    fi
}

case "$MODE" in
    dual)
        assert_device_available
        # The vendor DFP reports Launcher before it has finished releasing the previous app's
        # display/GPU resources. Require a second stable-idle sample before installation/launch.
        sleep 3
        assert_device_available
        ;;
    single)
        d2_foreground=$("$ADB" -s "$SERIAL" shell dumpsys activity activities |
            sed -n '/Display #2/,/Display #0/p' |
            sed -n 's/.*mResumedActivity:.* u0 \([^/ ]*\).*/\1/p' | head -n 1)
        case "$d2_foreground" in
            ''|com.android.launcher3|"$PACKAGE") ;;
            *) echo "DEVICE BUSY: D2 foreground=$d2_foreground" >&2; exit 3 ;;
        esac
        ;;
    *) echo "MODE must be dual or single" >&2; exit 2 ;;
esac

[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 2; }
if [ "$SKIP_INSTALL" = 1 ]; then
    "$ADB" -s "$SERIAL" shell dumpsys package "$PACKAGE" | grep -q 'versionName=' || {
        echo "FAIL: KBROWSER_SKIP_INSTALL requested but package is not installed" >&2; exit 2;
    }
else
    # These head units intermittently drop TCP ADB during incremental/streamed installation of a
    # large Gecko APK. Push-install is slower but has proved stable and preserves app data.
    "$ADB" -s "$SERIAL" install --no-streaming -r "$APK" >/dev/null
fi
# This vendor image can retain a shell-owned suspended flag across an ADB reconnect/install. An
# Activity start then succeeds only into android.SuspendedAppActivity, which must never be counted
# as a browser frame. Clear the flag for our package explicitly after the verified installation.
"$ADB" -s "$SERIAL" shell cmd package unsuspend "$PACKAGE" >/dev/null
"$ADB" -s "$SERIAL" shell mkdir -p /sdcard/Download/kbrowser-documents
"$ADB" -s "$SERIAL" push "$FIXTURES"/. /sdcard/Download/kbrowser-documents/ >/dev/null
PACKAGE_UID=$("$ADB" -s "$SERIAL" shell dumpsys package "$PACKAGE" |
    sed -n 's/.*userId=\([0-9][0-9]*\).*/\1/p' | head -n 1)
[ -n "$PACKAGE_UID" ] || { echo "Cannot resolve package UID" >&2; exit 2; }
PRIVATE_FIXTURES="/data/user/0/$PACKAGE/cache/document-fixtures"
"$ADB" -s "$SERIAL" shell su 0 mkdir -p "$PRIVATE_FIXTURES"

mime_for() {
    case "$1" in
        txt|log|java|kt|kts|c|h|cc|cpp|hpp|go|rs|py|js|jsx|ts|tsx|css|scss|less|sh|bash|zsh|bat|cmd|ps1|sql|graphql|gql|md|markdown|mmd|mermaid|puml|plantuml|yaml|yml|toml|ini|conf|cfg|properties|gradle|dockerfile|makefile|cmake|mk|cs|swift|dart|rb|php|scala|groovy|lua|r|clj|cljs|ex|exs|erl|hrl|fs|fsx|vb|asm|s|vue|svelte|proto|tf|tfvars|hcl|env|editorconfig|gitignore|npmrc|lock|diff|patch|rst|adoc|asciidoc|tex|bib|org|http|pem|crt) echo text/plain ;;
        html|htm) echo text/html ;;
        xhtml) echo application/xhtml+xml ;;
        json|jsonl|ndjson|har) echo application/json ;;
        geojson) echo application/geo+json ;;
        ipynb) echo application/x-ipynb+json ;;
        xml|svg|plist|fb2) echo application/xml ;;
        csv) echo text/csv ;;
        rtf) echo application/rtf ;;
        pdf) echo application/pdf ;;
        doc) echo application/msword ;;
        xls) echo application/vnd.ms-excel ;;
        ppt) echo application/vnd.ms-powerpoint ;;
        docx|dotx) echo application/vnd.openxmlformats-officedocument.wordprocessingml.document ;;
        docm|dotm) echo application/vnd.ms-word.document.macroEnabled.12 ;;
        xlsx|xltx) echo application/vnd.openxmlformats-officedocument.spreadsheetml.sheet ;;
        xlsm|xltm) echo application/vnd.ms-excel.sheet.macroEnabled.12 ;;
        pptx|potx) echo application/vnd.openxmlformats-officedocument.presentationml.presentation ;;
        pptm|potm) echo application/vnd.ms-powerpoint.presentation.macroEnabled.12 ;;
        odt|ott) echo application/vnd.oasis.opendocument.text ;;
        ods|ots) echo application/vnd.oasis.opendocument.spreadsheet ;;
        odp|otp) echo application/vnd.oasis.opendocument.presentation ;;
        epub) echo application/epub+zip ;;
        mobi) echo application/x-mobipocket-ebook ;;
        *) echo application/octet-stream ;;
    esac
}

sf_counts() {
    "$ADB" -s "$SERIAL" shell dumpsys SurfaceFlinger |
        sed -n 's/.*Total missed frame count: \([0-9][0-9]*\).*/\1/p;
                s/.*HWC missed frame count: \([0-9][0-9]*\).*/\1/p;
                s/.*GPU missed frame count: \([0-9][0-9]*\).*/\1/p' |
        tr '\n' ' '
}

if [ -z "$FROM_EXT" ] || [ ! -s "$SUMMARY" ] || [ ! -s "$FINGERPRINTS" ]; then
    printf '%s\n' 'format,mode,pages,parseMs,pssKiB,totalMissedDelta,hwcMissedDelta,gpuMissedDelta,uniqueFrames,minD2Stdev,minD0Stdev,result' > "$SUMMARY"
    printf '%s\n' 'format,mode,page,d2Fingerprint,d2Stdev,d0Fingerprint,d0Stdev' > "$FINGERPRINTS"
fi

for file in "$FIXTURES"/*; do
    name=$(basename "$file")
    ext=${name##*.}
    if [ -n "$ONLY_EXT" ] && [ "$ext" != "$ONLY_EXT" ]; then
        continue
    fi
    if [ -n "$ONLY_EXTS" ]; then
        case " $ONLY_EXTS " in
            *" $ext "*) ;;
            *) continue ;;
        esac
    fi
    if [ -n "$FROM_EXT" ] && [ "$STARTED" = false ]; then
        [ "$ext" = "$FROM_EXT" ] || continue
        STARTED=true
    fi
    echo "TEN-PAGE START: $ext"
    assert_device_available
    # A device can be reclaimed between two pages. Resume must replace, not append to, an
    # incomplete format so the final CSV always represents exactly 49×10 accepted positions.
    awk -F, -v format="$ext" 'NR == 1 || $1 != format' "$SUMMARY" > "$TEMP_ROOT/summary-clean.csv"
    mv "$TEMP_ROOT/summary-clean.csv" "$SUMMARY"
    awk -F, -v format="$ext" 'NR == 1 || $1 != format' "$FINGERPRINTS" > "$TEMP_ROOT/fingerprints-clean.csv"
    mv "$TEMP_ROOT/fingerprints-clean.csv" "$FINGERPRINTS"
    mime=$(mime_for "$ext")
    private_file="$PRIVATE_FIXTURES/$name"
    "$ADB" -s "$SERIAL" shell su 0 cp "/sdcard/Download/kbrowser-documents/$name" "$private_file"
    "$ADB" -s "$SERIAL" shell su 0 chown "$PACKAGE_UID:$PACKAGE_UID" "$private_file"
    "$ADB" -s "$SERIAL" shell su 0 chmod 600 "$private_file"
    "$ADB" -s "$SERIAL" shell su 0 restorecon "$private_file"
    "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE"
    "$ADB" -s "$SERIAL" logcat -c
    set -- $(sf_counts)
    sf_total_before=${1:-0}; sf_hwc_before=${2:-0}; sf_gpu_before=${3:-0}
    single_extra=''
    if [ "$MODE" = single ]; then
        single_extra='--ez kbrowser.document.singleScreenDiagnostic true'
    fi
    # shellcheck disable=SC2086 -- optional diagnostic extra intentionally expands as two args.
    "$ADB" -s "$SERIAL" shell am start --display 2 -W -a android.intent.action.VIEW \
        -c android.intent.category.DEFAULT -p "$PACKAGE" -d "file://$private_file" -t "$mime" \
        $single_extra \
        > "$RESULTS/$ext-start.txt"
    TEST_ACTIVE=true
    if grep -q 'android/com.android.internal.app.SuspendedAppActivity' "$RESULTS/$ext-start.txt"; then
        echo "DEVICE BUSY DURING TEST: browser package was suspended by another test" >&2
        exit 3
    fi

    attempt=0
    current_log="$TEMP_ROOT/$ext-current.log"
    while [ "$attempt" -lt 30 ]; do
        log=$({ "$ADB" -s "$SERIAL" shell logcat -d -s KBrowserDocument:I KBrowserCompositor:I '*:S' || true; })
        printf '%s\n' "$log" > "$current_log"
        content_ready=false
        if [ "$ext" = pdf ]; then
            content_ready=true
        elif grep -q "DOCUMENT_READY format=$ext" "$current_log" &&
            grep -q 'DOCUMENT_LOADED loopback=true' "$current_log"; then
            content_ready=true
        fi
        surface_ready=false
        if [ "$MODE" = dual ]; then
            if grep -q 'Bound TOP output' "$current_log" &&
                grep -q 'Bound BOTTOM output' "$current_log" &&
                grep -q 'Received first 1920x2560 Gecko frame' "$current_log"; then
                surface_ready=true
            fi
        elif grep -q 'Bound TOP output' "$current_log" &&
            grep -q 'Received first 1920x1280 Gecko frame' "$current_log"; then
            surface_ready=true
        fi
        [ "$content_ready" = true ] && [ "$surface_ready" = true ] && break
        attempt=$((attempt + 1))
        sleep 0.5
    done
    cp "$current_log" "$RESULTS/$ext-document.log"
    [ "$surface_ready" = true ] || { echo "FAIL $ext: compositor first frame timeout" >&2; exit 1; }
    if [ "$ext" = pdf ]; then
        parse_ms=0
        # Gecko's first compositor frame is the native PDF.js shell. PDF page rasterization is
        # asynchronous, so the shell may be blank briefly even though Surface binding succeeded.
        sleep 4
    else
        grep -q "DOCUMENT_READY format=$ext" "$current_log" || { echo "FAIL $ext: no ready log" >&2; exit 1; }
        grep -q 'DOCUMENT_LOADED loopback=true' "$current_log" || { echo "FAIL $ext: no load log" >&2; exit 1; }
        parse_ms=$(sed -n "s/.*DOCUMENT_READY format=$ext .*parseMs=\([0-9][0-9]*\).*/\1/p" "$current_log" | tail -n 1)
        [ "${parse_ms:-999999}" -lt 1500 ] || { echo "FAIL $ext: parse ${parse_ms}ms" >&2; exit 1; }
    fi

    state=$("$ADB" -s "$SERIAL" shell dumpsys activity activities)
    printf '%s\n' "$state" > "$RESULTS/$ext-activities.txt"
    if [ "$MODE" = dual ]; then
        grep -q 'DualScreenTopActivity' "$RESULTS/$ext-activities.txt" || { echo "FAIL $ext: no D2 activity" >&2; exit 1; }
        grep -q 'DualScreenBrowserActivity' "$RESULTS/$ext-activities.txt" || { echo "FAIL $ext: no D0 activity" >&2; exit 1; }
    else
        grep -q 'SingleScreenBrowserActivity' "$RESULTS/$ext-activities.txt" || { echo "FAIL $ext: no D2 single activity" >&2; exit 1; }
    fi

    page=1
    previous_pair=''
    seen_pairs="$TEMP_ROOT/$ext-seen.txt"
    : > "$seen_pairs"
    min_d2_stdev=999
    if [ "$MODE" = dual ]; then min_d0_stdev=999; else min_d0_stdev=0; fi
    while [ "$page" -le 10 ]; do
        assert_device_available
        d2_png="$TEMP_ROOT/$ext-page$page-d2.png"
        d0_png="$TEMP_ROOT/$ext-page$page-d0.png"
        d2_small="$TEMP_ROOT/$ext-page$page-d2-small.png"
        d0_small="$TEMP_ROOT/$ext-page$page-d0-small.png"
        "$ADB" -s "$SERIAL" exec-out screencap -d 2 -p > "$d2_png"
        # Native downsampling reduces standard-library PNG analysis from ~2.1s to ~0.1s while
        # retaining the content crop and line-pattern differences used by the perceptual hash.
        sips -z 160 240 "$d2_png" --out "$d2_small" >/dev/null
        d2_analysis=$(python3 "$ANALYZER" "$d2_small" --crop 10,22,220,119 --step 1 --tsv)
        d2_fp=$(shasum -a 256 "$d2_png" | awk '{print $1}')
        d2_stdev=$(printf '%s\n' "$d2_analysis" | cut -f3)
        d0_fp=''; d0_stdev=0
        if [ "$MODE" = dual ]; then
            "$ADB" -s "$SERIAL" exec-out screencap -d 0 -p > "$d0_png"
            # Close the race where another project enters D0 between the pre-capture foreground
            # check and the second physical screenshot. Such a frame is external contamination,
            # not a blank browser page.
            assert_device_available
            sips -z 160 240 "$d0_png" --out "$d0_small" >/dev/null
            d0_analysis=$(python3 "$ANALYZER" "$d0_small" --crop 10,22,220,119 --step 1 --tsv)
            d0_fp=$(shasum -a 256 "$d0_png" | awk '{print $1}')
            d0_stdev=$(printf '%s\n' "$d0_analysis" | cut -f3)
            awk "BEGIN { exit !($d0_stdev >= 5.0) }" || {
                echo "FAIL $ext page $page: blank/flat D0 frame stdev=$d0_stdev" >&2; exit 1;
            }
            [ "$d2_fp" != "$d0_fp" ] || { echo "FAIL $ext page $page: mirrored displays" >&2; exit 1; }
        fi
        awk "BEGIN { exit !($d2_stdev >= 5.0) }" || {
            echo "FAIL $ext page $page: blank/flat D2 frame stdev=$d2_stdev" >&2; exit 1;
        }
        pair="$d2_fp:$d0_fp"
        if grep -Fqx "$pair" "$seen_pairs"; then
            echo "FAIL $ext page $page: repeated frame pair (document shorter than ten pages or scroll stuck)" >&2
            exit 1
        fi
        printf '%s\n' "$pair" >> "$seen_pairs"
        min_d2_stdev=$(awk "BEGIN { print ($d2_stdev < $min_d2_stdev) ? $d2_stdev : $min_d2_stdev }")
        min_d0_stdev=$(awk "BEGIN { print ($d0_stdev < $min_d0_stdev) ? $d0_stdev : $min_d0_stdev }")
        printf '%s,%s,%s,%s,%s,%s,%s\n' "$ext" "$MODE" "$page" "$d2_fp" "$d2_stdev" "$d0_fp" "$d0_stdev" >> "$FINGERPRINTS"
        case "$page" in
            1|5|10)
                cp "$d2_png" "$RESULTS/$ext-page$(printf '%02d' "$page")-d2.png"
                if [ "$MODE" = dual ]; then
                    cp "$d0_png" "$RESULTS/$ext-page$(printf '%02d' "$page")-d0.png"
                fi
                ;;
        esac
        previous_pair=$pair
        if [ "$page" -lt 10 ]; then
            if [ "$MODE" = single ] || [ $((page % 2)) -eq 1 ]; then source_display=2; else source_display=0; fi
            # This vendor build intermittently revokes shell input injection while another app
            # owns the other physical display. Availability was checked immediately above; use
            # the rooted input service so a D0 focus transition cannot abort a D2-only test.
            "$ADB" -s "$SERIAL" shell su 0 input touchscreen -d "$source_display" swipe 960 1150 960 190 520
            # The rooted vendor input service can return before its final motion frame has been
            # presented. One frame-latency margin prevents a false duplicate-page verdict.
            sleep 0.9
        fi
        page=$((page + 1))
    done

    meminfo=$("$ADB" -s "$SERIAL" shell dumpsys meminfo "$PACKAGE")
    printf '%s\n' "$meminfo" > "$RESULTS/$ext-meminfo.txt"
    pss=$(printf '%s\n' "$meminfo" | sed -n 's/.*TOTAL PSS:[ ]*\([0-9][0-9]*\).*/\1/p' | head -n 1)
    if [ -z "$pss" ]; then
        pss=$(printf '%s\n' "$meminfo" | awk '/TOTAL/{print $2; exit}')
    fi
    [ "${pss:-999999}" -lt 300000 ] || { echo "FAIL $ext: PSS ${pss}KiB" >&2; exit 1; }
    set -- $(sf_counts)
    sf_total_after=${1:-0}; sf_hwc_after=${2:-0}; sf_gpu_after=${3:-0}
    total_delta=$((sf_total_after - sf_total_before))
    hwc_delta=$((sf_hwc_after - sf_hwc_before))
    gpu_delta=$((sf_gpu_after - sf_gpu_before))
    "$ADB" -s "$SERIAL" shell logcat -d > "$RESULTS/$ext-logcat.txt"
    if grep -q 'FATAL EXCEPTION.*iceraven\|ANR in io.github.forkmaintainers.iceraven' "$RESULTS/$ext-logcat.txt"; then
        echo "FAIL $ext: crash or ANR" >&2
        exit 1
    fi
    if [ "$MODE" = dual ]; then
        # The target launcher maps a mouse secondary click to Android Back; the browser
        # intentionally treats Back within a 3-second mouse grace window as a context-menu
        # request. Wait beyond that hardware window before testing paired system Back.
        sleep 3.2
        "$ADB" -s "$SERIAL" shell su 0 input -d 2 keyevent 4
    else
        # This mode is a non-invasive format/performance pre-screen while D0 belongs to another
        # project. Display 2 is physically rotated and may share global mouse focus, so ADB screen
        # coordinates are not a reliable product exit assertion. Stop only our own diagnostic
        # package for per-format isolation; paired exit remains mandatory in the final dual run.
        "$ADB" -s "$SERIAL" shell am force-stop "$PACKAGE"
    fi
    exit_attempt=0
    while [ "$exit_attempt" -lt 12 ]; do
        after_exit=$("$ADB" -s "$SERIAL" shell dumpsys activity activities)
        printf '%s\n' "$after_exit" > "$RESULTS/$ext-after-exit.txt"
        if ! grep -q 'DualScreenBrowserActivity\|DualScreenTopActivity\|SingleScreenBrowserActivity' "$RESULTS/$ext-after-exit.txt"; then
            break
        fi
        exit_attempt=$((exit_attempt + 1))
        sleep 0.35
    done
    printf '%s\n' "$after_exit" > "$RESULTS/$ext-after-exit.txt"
    if grep -q 'DualScreenBrowserActivity\|DualScreenTopActivity\|SingleScreenBrowserActivity' "$RESULTS/$ext-after-exit.txt"; then
        echo "FAIL $ext: browser activity remains after D2 Back" >&2
        exit 1
    fi
    TEST_ACTIVE=false
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$ext" "$MODE" 10 "$parse_ms" "$pss" "$total_delta" "$hwc_delta" "$gpu_delta" 10 \
        "$min_d2_stdev" "$min_d0_stdev" PASS >> "$SUMMARY"
    echo "TEN-PAGE PASS: $ext parse=${parse_ms}ms pss=${pss}KiB missed=$total_delta/$hwc_delta/$gpu_delta"
done

echo "TEN-PAGE DEVICE TEST PASSED: $RESULTS"
