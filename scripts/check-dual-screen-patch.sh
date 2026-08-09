#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PATCH="$PROJECT_DIR/patches/0001-add-dual-screen-browser-mode.patch"
UI_PATCH="$PROJECT_DIR/patches/0002-add-browser-chrome-and-home.patch"
grep -q 'DualScreenBrowserActivity' "$PATCH"
grep -q 'android:targetActivity=".dualscreen.DualScreenBrowserActivity"' "$PATCH"
grep -q 'launchDisplayId = secondary.displayId' "$PATCH"
grep -q 'components.core.geckoRuntime' "$PATCH"
grep -q 'logicalTop + if (isSecondary) geckoView.height else 0' "$PATCH"
grep -q 'peer?.runOnUiThread' "$PATCH"
grep -q '双屏浏览器' "$UI_PATCH"
grep -q '输入网址或搜索内容' "$UI_PATCH"
grep -q 'www.baidu.com' "$UI_PATCH"
grep -q 'www.bilibili.com' "$UI_PATCH"
grep -q 'www.zhihu.com' "$UI_PATCH"
git -C "$PROJECT_DIR/browser" apply --check "$PATCH"
echo "DUAL SCREEN PATCH CHECK PASSED"
