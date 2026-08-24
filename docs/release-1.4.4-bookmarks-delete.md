# 双屏浏览器 1.4.4-bookmarks-delete 测试发布记录

日期：2026-08-24

## 本轮改动

### 收藏夹界面

- 将原有 Android `AlertDialog.setItems()` 的纯标题列表改为 KEMI 蓝色主题面板。
- 顶部显示“收藏夹”和页面数量；每一项使用 82dp 高的触摸卡片，包含星标、标题、站点域名和“打开”。
- 大量收藏可滚动浏览；无收藏时提供统一的空状态说明。
- 所有数据继续来自 Fenix Places 的 Mobile 根目录，未迁移或复制用户书签。

### 删除操作

- 每张收藏卡片右侧增加红色低强调“删除”键。
- 点击后先显示确认对话框；确认后在后台调用 `bookmarksStorage.deleteNode(guid)`。
- 删除成功关闭旧列表、重新读取 Places 数据并刷新收藏夹；失败时显示明确提示。

## 构建与签名

| 项目 | 值 |
| --- | --- |
| versionName | `1.4.4-bookmarks-delete` |
| ABI | arm64-v8a |
| APK | `bin/KBrowser-arm64.apk` |
| SHA-256 | `6da6cf8fef3350918e14a56f940e9e4234bbc28cde45ddf4655c6fa61e3eb6a9` |
| 签名 | 用户指定的 `/Users/kemi/coding/priv/debug.keystore`，alias `androiddebugkey` |
| 签名校验 | APK Signature Scheme v2 / v3 通过 |

本轮 APK 是可覆盖当前 63 测试机的调试签名构建。它不是 Android ROM 的 platform 签名，也不能标为
KEMI Unified 正式发布版；若需正式渠道发布，必须使用独立、受控的正式发布证书并完成对应验收。

## 63 真机安装闭环

- 设备：`192.168.3.63:5555`。
- 安装方式：`adb install --no-incremental -r`，避免车机大 APK 增量安装的媒体存储失败。
- 安装后版本：versionCode `2016180530`，versionName `1.4.4-bookmarks-delete`。
- 从 LAUNCHER 入口启动后，D0 为 `DualScreenBrowserActivity`，D2 为
  `DualScreenTopActivity`；两块屏幕均创建对应 Activity。

## 回归范围

- Kotlin `forkRelease` 编译通过；收藏卡片、删除确认、Places 删除调用和列表刷新均纳入本次编译。
- 本轮完成安装与双屏启动验证；收藏实际删除后的用户交互体验由设备测试者继续确认。

## 可复现源码

收藏夹改动保存为 `patches/0037-redesign-bookmarks-with-delete.patch`，并在
`patches/series` 中紧跟文档阅读扩展补丁。其他机器以固定上游提交执行
`./scripts/prepare-source.sh` 后可重放相同代码。
