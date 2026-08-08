# Cromite/Chromium Android 构建入口

KBrowser 以持续维护的 Cromite Chromium 补丁体系为上游。版本、提交和构建镜像固定在
`build/upstream.env`，KBrowser 自己只维护 `patches/series` 中的增量补丁。

## 构建机

Chromium Android 全量构建由 GitHub Actions 调度到带 `chromium` 标签的 Linux x86_64
自托管 runner，不在当前 macOS 控制机上强行构建，也不在磁盘不足的普通 GitHub runner
上重复获取完整源码。

最低建议：

- Linux x86_64
- 16 GB RAM，推荐 32 GB
- 150 GB 可用磁盘，推荐 250 GB
- 稳定网络

先运行：

```bash
./scripts/check-build-host.sh
```

只有输出 `BUILD HOST CHECK PASSED` 才继续。

## CI Runner 要求

- GitHub runner 标签：`self-hosted`, `linux`, `x64`, `chromium`
- Docker 可用
- 持久目录：`/storage/kbrowser/out`
- 能拉取 `build/upstream.env` 中固定的 Cromite 构建镜像

普通 `ubuntu-latest` 只运行 `validate` job。实际构建流程见
`.github/workflows/build-android.yml`。

## 补丁工作流

1. 在 Chromium 源码树中完成一个最小修改。
2. 导出为 `patches/<name>.patch`。
3. 把路径追加到 `patches/series`。
4. 本地运行 `./scripts/check-ci-config.sh`。
5. 推送候选提交，由 Actions 顺序应用补丁并编译 `chrome_public_apk`。

闭环：

```bash
./scripts/install-apk.sh /absolute/path/to/KBrowser-arm64.apk
./scripts/smoke-package.sh org.chromium.chrome
```

通过后才开始改包名和双屏代码。
