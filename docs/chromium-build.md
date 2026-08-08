# Iceraven/Fenix Android 构建入口

KBrowser 以持续维护的 Iceraven（Firefox Android/Fenix 分支）为上游，使用独立 GeckoView
引擎而不是系统 WebView。上游以 Git submodule 固定，提交写入 `build/upstream.env`，KBrowser
只维护 `patches/series` 中的双屏增量补丁。

## GitHub 构建环境

构建使用 GitHub 托管的 `ubuntu-latest`、JDK 17、Android SDK 和 Gradle。GeckoView 由依赖
仓库获取，不需要在每次候选中编译完整 Gecko/Chromium 内核。

最低建议：

实际流程见 `.github/workflows/build-android.yml`。

## 补丁工作流

1. 在 `browser` 子模块源码中完成一个最小修改。
2. 导出为 `patches/<name>.patch`。
3. 把路径追加到 `patches/series`。
4. 本地运行 `./scripts/check-ci-config.sh`。
5. 推送候选提交，由 Actions 顺序应用补丁并编译 `app:assembleForkRelease`。

闭环：

```bash
./scripts/install-apk.sh /absolute/path/to/KBrowser-arm64.apk
./scripts/smoke-package.sh io.github.forkmaintainers.iceraven
```

通过后才开始改包名和双屏代码。
