# 双屏浏览器 1.3.0 正式版发布记录

发布日期：2026-08-22

## 版本结论

- 版本号：`1.3.0`
- 包名：`io.github.forkmaintainers.iceraven`
- 架构：`arm64-v8a`
- 可复现补丁范围：`0001–0020 + 0025–0035`
- APK：`bin/DualScreenBrowser-v1.3.0-arm64-release.apk`
- 源码提交：`1339471a438ed28d75e71187c13a720fb0d19d0f`
- 正式 APK SHA-256：`c77706a256deaf0bacee607b31f15d96c36652b9aef0569752b355e7fef4c7c3`

## 新增能力

- 通过文件管理器 `ACTION_VIEW` 打开本地程序员文档；转换全程离线且在后台线程执行。
- 结构化支持文本/源码/配置、Markdown、CSV/TSV、HTML、现代 Office、ODF、EPUB、RTF 和未加密 MOBI。
- PDF 使用 Gecko 原生查看器；DOC/XLS/PPT 提供明确边界的正文兼容提取。
- 文档与网页共用同一套双屏连续画布、滚动、复制、朗读和同步退出能力。
- 增加输入、解压、字符数和表格限制，阻止宏/脚本/远程跟踪与 ZIP bomb。
- PalmDOC/MOBI 使用固定上限 O(n) 回溯缓冲，针对车机避免大电子书平方级复制开销。

## 构建与签名

本地正式构建完成 4215 个 Gradle 任务，R8 与资源优化成功。签名验证结果：

- APK Signature Scheme v2：通过；
- APK Signature Scheme v3：通过；
- 证书：`CN=KEMI Unified Android Release, OU=Software, O=KEMI, L=Shenzhen, ST=Guangdong, C=CN`；
- 证书 SHA-256：
  `C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`。

私钥仍只保存在仓库外 `/Users/kemi/coding/priv/pem/kemi-unified-release`，禁止提交 GitHub。

## 真机结果

63 副屏在不抢占主屏 NativeGPU 的前提下完成 49 个格式样例。48 个离线转换格式逐项日志隔离通过，
PDF 原生显示，解析中位数 9ms、最大 86ms；Markdown 实际滚动、朗读提取 6158 字和下一段预取通过。
62 整机完成相同 49 格式双屏矩阵，解析中位数 7ms、最大 75ms、总 PSS 212090KiB；D2/D0 显示同一
`1920×2560` 页面相邻区域，两屏分别滚动后行号仍连续，无镜像和反馈抖动。Markdown 的 TOP/BOTTOM
Surface、首帧、308 段朗读及 D2 退出联动关闭 D0 均通过，未发现崩溃或 ANR。详细证据与能力边界见
`docs/document-reader-device63-report.md`。

## 校验命令

```sh
./scripts/build-release.sh 1.3.0
shasum -a 256 bin/DualScreenBrowser-v1.3.0-arm64-release.apk
bash scripts/test-documents-device.sh \
  192.168.3.63:5555 bin/DualScreenBrowser-v1.3.0-arm64-release.apk single
bash scripts/test-documents-device.sh \
  192.168.3.62:5555 bin/DualScreenBrowser-v1.3.0-arm64-release.apk dual
```
