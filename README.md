# KBrowser

KBrowser 是面向 KEMI 双屏 Android 设备的 Iceraven/Fenix 浏览器移植项目。

目标是在 Display 0 与 Display 2 上把同一个网页呈现为连续的
`1920 x 2560` 逻辑视口，并保留完整浏览器能力，而不是依赖系统 WebView。

## 当前状态

- 已确认目标设备为 Android 12 / arm64。
- Display 0 与 Display 2 均为 `1920 x 1280 @ 60Hz`。
- 已建立可重复执行的真机预检闭环。
- 已固定 Iceraven/Fenix 上游提交，使用免费 GitHub 托管 runner 构建。

## 快速验证

```bash
./scripts/check-device.sh
```

完整开发流程见 [docs/development-plan.md](docs/development-plan.md)。
目标设备的固定参数与性能约束见 [docs/hardware-profile.md](docs/hardware-profile.md)。

## CI 架构

- 第一个 job：校验脚本、上游提交和补丁队列。
- 第二个 job：JDK 17 + Android SDK + Gradle 编译 arm64 APK。
- APK、SHA-256 与构建 manifest 作为 Actions artifact 保存 14 天。
