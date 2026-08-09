# KBrowser

KBrowser 是面向 KEMI 双屏 Android 设备的 Iceraven/Fenix 浏览器移植项目。

目标是在 Display 0 与 Display 2 上把同一个网页呈现为连续的
`1920 x 2560` 逻辑视口，并保留完整浏览器能力，而不是依赖系统 WebView。

## 当前状态

- 已确认目标设备为 Android 12 / arm64。
- Display 0 与 Display 2 均为 `1920 x 1280 @ 60Hz`。
- 已建立可重复执行的真机预检闭环。
- 已固定 Iceraven/Fenix 上游提交，使用免费 GitHub 托管 runner 构建。

## 从 GitHub 完整本地编译

首次构建需要：Git、Git LFS、Bash、Python 3、wget、JDK 17、Android SDK、NDK
`29.0.14206865`，以及可访问 Maven/Gradle 依赖的网络。macOS 还需要 GNU sed
（`brew install gnu-sed wget`）。建议至少预留 8GB 内存和 20GB 磁盘空间。

```bash
git clone --recurse-submodules https://github.com/caucy2026/k-browser.git
cd k-browser
./scripts/prepare-source.sh
KBROWSER_VERSION_NAME=1.2.0-local ./scripts/build-local.sh
```

`prepare-source.sh` 会完成以下闭环：

1. 初始化所有递归子模块。
2. 校验 Iceraven 固定提交，防止在错误上游版本打补丁。
3. 执行 Iceraven 自身的 Android Components 准备步骤。
4. 按 `patches/series` 顺序应用 KBrowser 0001–0011 补丁。

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

## 真机快速验证

```bash
./scripts/check-device.sh
```

完整开发流程见 [docs/development-plan.md](docs/development-plan.md)。
目标设备的固定参数与性能约束见 [docs/hardware-profile.md](docs/hardware-profile.md)。

## CI 架构

- 第一个 job：校验脚本、上游提交和补丁队列。
- 第二个 job：JDK 17 + Android SDK + Gradle 编译 arm64 APK。
- APK、SHA-256 与构建 manifest 作为 Actions artifact 保存 14 天。
