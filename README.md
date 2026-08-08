# KBrowser

KBrowser 是面向 KEMI 双屏 Android 设备的 Cromite/Chromium 浏览器移植项目。

目标是在 Display 0 与 Display 2 上把同一个网页呈现为连续的
`1920 x 2560` 逻辑视口，并保留完整浏览器能力，而不是依赖系统 WebView。

## 当前状态

- 已确认目标设备为 Android 12 / arm64。
- Display 0 与 Display 2 均为 `1920 x 1280 @ 60Hz`。
- 已建立可重复执行的真机预检闭环。
- 已固定 Cromite/Chromium 上游版本，使用 GitHub Actions + Chromium 自托管 runner 构建。

## 快速验证

```bash
./scripts/check-device.sh
```

完整开发流程见 [docs/development-plan.md](docs/development-plan.md)。

## CI 架构

- 普通 GitHub runner：校验脚本、上游版本和补丁队列。
- `self-hosted, linux, x64, chromium` runner：使用固定 Cromite 构建镜像编译 arm64 APK。
- APK、SHA-256 与构建 manifest 作为 Actions artifact 保存 14 天。
