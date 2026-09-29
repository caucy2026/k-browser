# KBrowser

KBrowser 是面向 KEMI 双屏 Android 设备的 Iceraven/Fenix 浏览器移植项目。

目标是在 Display 0 与 Display 2 上把同一个网页呈现为连续的
`1920 x 2560` 逻辑视口，并保留完整浏览器能力，而不是依赖系统 WebView。

## 当前状态

- 已确认目标设备为 Android 12 / arm64。
- Display 0 与 Display 2 均为 `1920 x 1280 @ 60Hz`。
- 双屏模式只使用一个 GeckoSession 和一张 `1920 x 2560` Gecko 合成帧：Display 2
  显示顶部，Display 0 显示紧接其后的底部，不是两个网页互相复制。
- 任意屏返回、退出或离开都会同步结束另一屏；默认双屏，长按图标可进入单屏模式。
- D2/单屏工具栏提供网页朗读：从 D2 工具栏下方第一条实际可见文字开始、当前行高亮跟随、下一段预取，
  支持暂停、继续和停止；读到屏幕末尾自动平滑滚动，换页或退出立即停止语音。
- 已固定 Iceraven/Fenix 上游提交，本地构建优先，GitHub Actions 用作干净环境回归。
- 当前可复现补丁入口为 0001–0020 + 0025–0055。
- 当前源码的 `forkRelease` 为 `1.0.3 (103)`；最新实机验证版本仍为 `1.0.2 (102)`。
- 最新 `forkRelease` 设备测试包为 `1.0.2 (102)`，已在 KEMI Vibe Pads S1 上安装验证；
  本轮结果见下方更新记录。此前 `1.0.1` 的详细结果见
  [实机验证记录](docs/browser-2026-09-29-device-verification.md)。测试证书、APK 和密码不提交到 GitHub。
- 当前正式版本为 `1.3.1`，产物为
  `bin/DualScreenBrowser-v1.3.1-arm64-release.apk`；使用 KEMI 统一正式证书签名。
- 49 种真机样例覆盖常用源码/配置、Markdown、表格、Office/ODF、EPUB/MOBI、RTF、HTML 与 PDF；
  精确支持边界见 `docs/programmer-document-reader-spec.md`，实测数据见
  `docs/document-reader-ten-page-device-report.md`。1.3.1 已完成 49 种×连续10页×D2/D0 的 980 帧矩阵。
- KEMI 构建不显示 Firefox/Iceraven 注册、首次引导、Pocket/赞助内容或默认浏览器推广；
  Gecko 仅作为开源网页引擎保留。

## 最新更新：1.0.3 文档打开候选版（2026-09-29）

- 下载记录中的 PDF、DOC/DOCX、TXT、PPT/PPTX、XLS/XLSX 及常见 ODF、RTF、CSV 等文档，
  优先直接交给 KEMI Office；未安装或无法启动时，才显示系统打开方式选择器。
- 对未声明相应 MIME 关联的 KEMI Office 版本，常见非 PDF 文档还会尝试其文档 Activity，
  避免 TXT 等格式因系统关联缺失而直接弹选择器。PDF 仍使用原有的专用打开路径。
- 新增可重放补丁 0055，`forkRelease` 提升至 `1.0.3 (103)`。本地增量构建通过，
  测试 APK 通过 16 KiB 对齐与 v2/v3 验签。设备 `192.168.1.78` 当前离线，
  DOC/TXT/PPT 直开及未安装 KEMI Office 的回退路径尚待实机验证。

## 上一版：1.0.2 设备测试版（2026-09-29）

- 将补丁队列扩展至 0054，修复 Windows 检出上游源码时 Gecko 版本号混入换行符导致的构建失败；
  从 GitHub 全新克隆后，50 个补丁按序应用，本地 `app:assembleForkRelease` 编译通过，
  [GitHub Actions 构建](https://github.com/caucy2026/k-browser/actions/runs/36544920251)也通过。
- 本轮浏览器改动涵盖双屏网页与游戏视口、网页返回主页、繁体导航“刷新”、下载列表与进度、
  PDF 优先 KEMI Office 打开，以及 TXT 不再由浏览器内置打开。
- 已在 `192.168.1.78` 的 KEMI Vibe Pads S1（Android 12）安装 `1.0.2 (102)` 并实测：
  双屏主页、普通网页返回、MCJS 游戏网站入口与返回、下载列表、PDF 直接打开、TXT 系统选择器、
  DOCX 使用 KEMI Office 打开均通过；浏览器进程保持运行。
- MCJS 游戏、下载暂停/继续与自动刷新及删除、收起软键盘后浏览器保持运行、实体边缘侧滑返回，
  均已由设备使用者手动验收通过；本轮自动化只验证了 MCJS 网站入口与返回。原反馈视频的长时间播放
  与刷新续播尚未完成验证，不能记为通过。
- 另对一条微博视频只读观察约 15 分半，画面持续推进至播放器结尾，浏览器进程未退出，抽样日志未见
  `ERR_DECODE`；这条视频与原反馈的百度百科视频不同，不能代替原视频复测。
- 设备测试 APK 使用仓库外的用户指定测试证书；[CI 预发布包](https://github.com/caucy2026/k-browser/releases/tag/ci-c577868266e92ea5e98077daef303241ad14aa60)
  使用不同的 CI 测试证书，覆盖安装前须确认签名一致。完整版本记录见 [CHANGELOG.md](CHANGELOG.md)。

## 从 GitHub 完整本地编译

首次构建需要：Git、Git LFS、Bash、Python 3、JDK 17、Android SDK、NDK
`29.0.14206865`，以及可访问 Maven/Gradle 依赖的网络。Linux 和 macOS 使用同一套
准备脚本，不要求额外安装 GNU sed 或 wget。建议至少预留 8GB 内存和 20GB 磁盘空间。

```bash
git clone --recurse-submodules https://github.com/caucy2026/k-browser.git
cd k-browser
./scripts/prepare-source.sh
KBROWSER_VERSION_NAME=1.2.0-local ./scripts/build-local.sh
```

正式发布使用机器外置私钥目录，不把私钥提交到 Git：

```sh
./scripts/build-release.sh 1.3.0
```

唯一的 KEMI Android 正式签名资产保存在 `/Users/kemi/coding/priv/pem/kemi-unified-release`，该目录可以
整体独立加密备份或迁移。完整说明保存在 `pem/README-APK正式签名.md`。可通过
`KBROWSER_RELEASE_SIGNING_DIR` 显式指定该完整签名目录的备份副本。

`prepare-source.sh` 会完成以下闭环：

1. 初始化所有递归子模块。
2. 校验 Iceraven 固定提交，防止在错误上游版本打补丁。
3. 执行 Iceraven 自身的 Android Components 准备步骤。
4. 按 `patches/series` 顺序应用全部 KBrowser 补丁。

如果系统 Python 尚未安装 PyYAML，脚本会在被忽略的 `.tools/prepare-venv` 中创建独立
虚拟环境并安装固定版本，不修改系统 Python。

`build-local.sh` 会依次寻找 `KBROWSER_JAVA_HOME`、`JAVA_HOME` 和系统 JDK 17；Android
SDK 会依次寻找 `KBROWSER_ANDROID_SDK_ROOT`、`ANDROID_SDK_ROOT`、`ANDROID_HOME`、
Android Studio 默认目录及项目 `.tools`。如果没有自动找到，可以显式指定：

```bash
KBROWSER_JAVA_HOME=/absolute/path/to/jdk17 \
KBROWSER_ANDROID_SDK_ROOT=/absolute/path/to/android-sdk \
./scripts/build-local.sh
```

成功条件：命令输出 `LOCAL BUILD PASSED`，并生成：

- `bin/KBrowser-arm64.apk`
- `bin/KBrowser-arm64.apk.sha256`

构建会自动为未签名 APK 生成本机测试证书；正式发布必须改用离线保存的正式证书。
已准备过的源码再次执行 `prepare-source.sh` 会安全跳过，不会重复打补丁。

2026-08-11 已验证 0001–0020 + 0025–0030 能在固定的干净上游提交上按序完整重放；随后本地完成
4215 个 Gradle 任务、R8、资源优化、APK 打包以及 v2/v3 签名校验。首次无增量构建
约需 9 分钟，增量构建通常更快，实际时间取决于网络与机器性能。

## 仓库结构与备份边界

- `browser/`：固定版本的 Iceraven 上游子模块；开发机可保持补丁展开状态，不提交脏子模块指针。
- `patches/series`：KBrowser 改动的唯一顺序入口，其他机器从这里恢复完整定制源码。
- `scripts/prepare-source.sh`：初始化递归子模块并应用全部补丁。
- `scripts/build-local.sh`：本机 arm64 构建、签名、校验和 `bin/` 产物输出。
- `docs/`：硬件约束、开发流程、改动记录和真机结论。
- `bin/`、`test-results/`、`.tools/`：本地构建产物、测试证据和工具，均被 Git 忽略。
- `/Users/kemi/coding/priv/pem/kemi-unified-release`：仓库外唯一正式签名目录，必须整体加密离线备份，
  不能上传 GitHub；仓库内不再保存任何正式 JKS 或密码配置。

## 真机快速验证

```bash
./scripts/check-device.sh
```

完整开发流程见 [docs/development-plan.md](docs/development-plan.md)。
目标设备的固定参数与性能约束见 [docs/hardware-profile.md](docs/hardware-profile.md)。
双屏/单屏实现、跨屏启动路由及最终验收见
[docs/dual-single-screen-architecture.md](docs/dual-single-screen-architecture.md)。
供其他项目复用的方案选择、底层细节、失败案例和踩坑清单见
[docs/multi-display-browser-lessons.md](docs/multi-display-browser-lessons.md)。
网页正文提取、讯飞流式 TTS、系统降级、状态机和真机闭环见
[docs/webpage-read-aloud.md](docs/webpage-read-aloud.md)。
文档格式级别、安全上限和“支持”的严格定义见
[docs/programmer-document-reader-spec.md](docs/programmer-document-reader-spec.md)，自动样例和真机步骤见
[docs/document-reader-ten-page-test-plan.md](docs/document-reader-ten-page-test-plan.md)，49 种连续十页结果见
[docs/document-reader-ten-page-device-report.md](docs/document-reader-ten-page-device-report.md)。
版本与全部定制内容见 [CHANGELOG.md](CHANGELOG.md)。

## CI 架构

- 第一个 job：校验脚本、上游提交和补丁队列。
- 第二个 job：JDK 17 + Android SDK + Gradle 编译 arm64 APK。
- APK、SHA-256 与构建 manifest 作为 Actions artifact 保存 14 天。
