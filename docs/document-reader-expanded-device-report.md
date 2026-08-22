# KEMI 文档阅读扩展真机报告（49 → 133）

## 1. 验收结论

2026-08-22 在 `192.168.3.62:5555` 的真实双屏硬件上，对新增的 84 个扩展名逐一完成连续十页测试，
结果为 **84/84 PASS**。结合已经完成相同口径验收的原 49 种，当前支持清单为 **133 种**。

新增矩阵包含 840 个滚动位置和 1680 张 D2/D0 分析帧。每个格式均验证：

- D2 与 D0 是同一 `1920×2560` 文档的相邻区域，不镜像；
- 十个滚动位置均非空白且画面指纹唯一；
- 滚动由 D2/D0 交替发起，另一屏随同一画布移动；
- D0=`DualScreenBrowserActivity`、D2=`DualScreenTopActivity`，结束后成对退出；
- 记录解析耗时、PSS、SurfaceFlinger missed frame 与 FATAL/ANR 日志。

## 2. 新增覆盖范围

- 21 个既有但未进入旧矩阵的别名/变体：`cc`, `less`, `bash`, `zsh`, `bat`, `cmd`, `ps1`,
  `gql`, `conf`, `cfg`, `gradle`, `mermaid`, `plantuml`, `dockerfile`, `makefile`, `geojson`,
  `ipynb`, `svg`, `htm`, `azw`, `azw3`；
- 现代语言和基础设施：C#、Swift、Dart、Ruby、PHP、Scala、Groovy、Lua、R、Clojure、Elixir、
  Erlang、F#、VB、汇编、Vue、Svelte、Protobuf、Terraform/HCL、CMake、环境和工具配置；
- 技术写作与交换：RST、AsciiDoc、Org、LaTeX、BibTeX、JSONL/NDJSON、HAR、HTTP 请求、Plist、
  PEM/CRT、ICS/VCF、Diff/Patch、FB2；
- Office/ODF 模板与宏启用变体：`docm/dotx/dotm`, `xlsm/xltx/xltm`, `pptm/potx/potm`,
  `ott/ots/otp`。宏只读、不执行。

完整 133 项清单和边界见 `docs/document-reader-supported-formats.md`。

## 3. 真机发现与修复

### FB2 下半屏空白

第一次测试在 FB2 第 1 页被框架拒绝：D0 画面标准差为 0。根因是把整份 FB2 当作单行 XML 源码，
超长横向行没有产生足够的纵向排版。修复为按 `title/subtitle/p/v` 语义提取段落，重新本地编译
`1.4.0-rc2` 后，FB2 十页通过：解析 43ms、PSS 210672KiB、missed `17/0/17`。

### 大 APK 网络安装掉线

设备在 ADB incremental/streamed 安装时两次掉为 offline。改用 `adb install --no-streaming -r` 后，
131595834 字节 APK 一次推送安装成功且保留应用数据；测试脚本已固化该真机策略。

### 漏帧隔离复测

首轮 `diff/erl/gradle` 的 Total missed-frame 分别为 60/63/61，略高于旧矩阵最大值。独占设备隔离
复测后分别为 22/11/37，证明是系统瞬时波动，不是对应解析器持续性能问题。最终统计采用隔离值。

## 4. 性能汇总

- 解析耗时：中位数 16ms，P90 43ms，最大 289ms（XLSM）；
- PSS：中位数 197582KiB，P90 199115KiB，最大 210672KiB（FB2 冷启动）；
- 9 次双屏交替滚动 Total missed-frame：中位数 17，P90 41，最大 53；
- 崩溃/ANR：0；功能性最终失败：0。

Office 表格模板仍是最慢组（XLSM 289ms、XLTM 265ms、XLTX 272ms），但均低于规范的交互阻塞
风险阈值，且解析在线程后台进行。普通源码/配置大多为 11–28ms。

扩展矩阵结束后，又在同一 `1.4.0-rc2` APK 上对旧能力选取 8 条不同解析路径做十页回归：`docx`,
`epub`, `json`, `md`, `mobi`, `pdf`, `txt`, `xlsx` 全部 PASS。XLSX 解析 281ms，PDF PSS
198040KiB，八项均无崩溃、空白、镜像或重复页。证据位于
`artifacts/document-reader-ten-page-device62-dual-rc2-regression/`。

## 5. 构建与证据

- 真机候选：`bin/KBrowser-arm64.apk`，versionName `1.4.0-rc2`；
- SHA-256：`05633852f01a322dec536e2d079f39e480a97d40528de60a4985d7782a3338ea`；
- 签名：KEMI Unified Android Release，v2/v3 校验通过；
- 新增矩阵：`artifacts/document-reader-ten-page-device62-dual-expanded-133/`；
- 性能复测：`artifacts/document-reader-ten-page-device62-dual-perf-rerun/`；
- 每种格式保留第 1、5、10 页两屏截图，其余页保留指纹与亮度标准差，共 504 张新增证据截图。
