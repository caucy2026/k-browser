# 双屏浏览器 1.3.0 正式版发布记录

发布日期：2026-08-22

## 版本结论

- 版本号：`1.3.0`
- 包名：`io.github.forkmaintainers.iceraven`
- 架构：`arm64-v8a`
- 可复现补丁范围：`0001–0020 + 0025–0035`
- APK：`bin/DualScreenBrowser-v1.3.0-arm64-release.apk`
- 当前候选 SHA-256：`511671213748781ac509f17de737dff5e116b3d528857371f9901aa6c2c73fc7`

## 新增能力

- 通过文件管理器 `ACTION_VIEW` 打开本地程序员文档；转换全程离线且在后台线程执行。
- 结构化支持文本/源码/配置、Markdown、CSV/TSV、HTML、现代 Office、ODF、EPUB、RTF 和未加密 MOBI。
- PDF 使用 Gecko 原生查看器；DOC/XLS/PPT 提供明确边界的正文兼容提取。
- 文档与网页共用同一套双屏连续画布、滚动、复制、朗读和同步退出能力。
- 增加输入、解压、字符数和表格限制，阻止宏/脚本/远程跟踪与 ZIP bomb。

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
PDF 原生显示，解析中位数 9ms、最大 121ms；Markdown 实际滚动、朗读提取 6158 字和下一段预取通过。
详细证据与能力边界见 `docs/document-reader-device63-report.md`。

整机 D0/D2 同时空闲后，还需执行报告中的 `dual` 命令补齐本次文档内容的双屏拼接取证；测试脚本会在
检测到其他前台应用时主动退出，不能用抢占其他项目换取假闭环。

## 校验命令

```sh
./scripts/build-release.sh 1.3.0
shasum -a 256 bin/DualScreenBrowser-v1.3.0-arm64-release.apk
bash scripts/test-documents-device.sh \
  192.168.3.63:5555 bin/DualScreenBrowser-v1.3.0-arm64-release.apk single
```
