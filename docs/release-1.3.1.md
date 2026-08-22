# 双屏浏览器 1.3.1 正式版

## 发布内容

- 49 种程序员/办公/电子书文档均完成连续十页真机验收；
- D2 与 D0 使用同一个 `1920×2560` 文档画布，分别显示相邻区域，不使用镜像或双页面状态同步；
- 优化 Markdown、旧 Office 正文提取和 XLSX 表格解析；
- 新增 980 帧量化脚本、断点续跑、外部抢占检测和可复现报告。

## 真机结果

测试设备：`192.168.3.62:5555`，Android 12 / arm64，双 `1920×1280@60Hz`。

- 49/49 格式 PASS，490 个不同页面位置，980 张 D2/D0 帧；
- 非 PDF 解析中位数 15ms，P90 30ms，最大 251ms（420 行 XLSX）；
- PSS 中位数 196603KiB，P90 201167KiB，最大 233539KiB（PDF）；
- 9 次两屏交替滚动 Total missed-frame 中位数 15，P90 33，最大 59；
- 无黑屏、镜像、重复页面、浏览器 FATAL EXCEPTION 或 ANR；D2 返回后两个浏览器 Activity 同时退出。

逐格式结果、无效抢占轮次和能力边界见
[document-reader-ten-page-device-report.md](document-reader-ten-page-device-report.md)。

## 构建与签名

```sh
./scripts/build-release.sh 1.3.1
```

正式产物：`bin/DualScreenBrowser-v1.3.1-arm64-release.apk`。签名证书固定为 KEMI Unified Android
Release，证书 SHA-256：
`C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`。

完整源码复现以 `build/upstream.env` 和 `patches/series` 为准；APK 校验值在最终构建后写入同名
`.sha256` 文件。
