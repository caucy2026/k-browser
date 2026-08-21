# 双屏浏览器 1.2.4 正式版发布记录

发布日期：2026-08-21

## 版本结论

- 正式版本号：`1.2.4`
- Android 包名：`io.github.forkmaintainers.iceraven`
- `versionCode`：`2016180002`
- 架构：`arm64-v8a`
- 正式源码提交：`8a4ee3850eea74d863cb7c921dfa9fffc170d894`
- 可复现补丁范围：`0001–0020 + 0025–0034`

`1.2.4` 是稳定正式版，不是 RC 或 CI 测试版。`1.2.3` 在真机检查中发现首页较长标签会换行或被省略，
因此没有作为最终交付版本；该问题在 `1.2.4` 中闭环修复。

## 本次改动

### 首页内容

- 新增 `KEMI Top 100`，地址为 `https://kemi-chat.newlinksz.com:21121/km100`。
- 新增 `GitHub Top 300`，地址为 `https://kemi-chat.newlinksz.com:21121/top300`。
- “双屏浏览器”主页标题固定为单行显示。
- 所有收藏标签固定为单行显示，禁止因空格或中英文混排自动换行。
- 收藏卡片左右内边距调整为 `16px`，主标签字号调整为 `22px`，兼顾车机可读性和四列完整展示。
- 增加网格子项收缩和溢出保护，避免较长标签破坏四列布局。

### 可复现源码

- `0033-add-kemi-project-ranking-sites.patch`：增加两个 KEMI 开源项目标签并固定主页标题为单行。
- `0034-keep-home-site-labels-on-one-line.patch`：统一收藏标签的单行布局和车机字号。
- 两个补丁均已加入 `patches/series`，其他开发者从固定上游源码按顺序应用即可复现。

## 正式 APK

- 文件：`bin/DualScreenBrowser-v1.2.4-arm64-release.apk`
- SHA-256：`a0b065c4af3db0331dd0b06d28bed1ffca8297fd6ce21f44b59b431d45cf2239`
- 校验文件：`bin/DualScreenBrowser-v1.2.4-arm64-release.apk.sha256`
- 构建清单：`bin/DualScreenBrowser-v1.2.4-arm64-release.apk.manifest.txt`

正式包使用 KEMI 统一 Android 正式证书签名：

- 证书主体：`CN=KEMI Unified Android Release, OU=Software, O=KEMI, L=Shenzhen, ST=Guangdong, C=CN`
- 证书 SHA-256：`C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`
- APK Signature Scheme：v2、v3 验证通过。

私钥和口令不进入 Git 仓库。正式签名资产仅保存在仓库外的
`/Users/kemi/coding/priv/pem/kemi-unified-release`，应继续采用加密离线备份。

## 63 真机闭环结果

测试设备：`192.168.3.63:5555`

- 无损覆盖安装成功，设备报告 `versionName=1.2.4`。
- Display 2 运行 `DualScreenTopActivity`，显示同一网页的上半区。
- Display 0 运行 `DualScreenBrowserActivity`，显示同一网页的下半区。
- 合成器日志出现 `Bound TOP output`、`Bound BOTTOM output` 和
  `Received first 1920x2560 Gecko frame`。
- “KEMI 知识库”“中国大学MOOC”“KEMI Top 100”“GitHub Top 300”均完整单行显示，
  没有换行或省略号。
- 冷启动日志未发现 `FATAL EXCEPTION`。

本地验收截图保存在忽略提交的 `artifacts/1.2.4-device63/`，避免把真机临时证据和大文件混入源码仓库。

## 构建与校验

```sh
./scripts/build-release.sh 1.2.4
shasum -a 256 bin/DualScreenBrowser-v1.2.4-arm64-release.apk
.tools/android-sdk/build-tools/36.0.0/aapt dump badging \
  bin/DualScreenBrowser-v1.2.4-arm64-release.apk
```

安装时使用覆盖升级，不卸载应用、不清除用户数据：

```sh
.tools/platform-tools/adb -s 192.168.3.63:5555 install -r \
  bin/DualScreenBrowser-v1.2.4-arm64-release.apk
```

## 交付注意事项

- 对外测试和正式安装只使用带版本名的正式 APK，不使用 `KBrowser-arm64.apk` 中间产物或 CI 测试签名包。
- 升级包必须继续使用同一 KEMI 正式证书，否则 Android 会拒绝覆盖安装。
- GitHub 只备份源码、补丁、构建脚本和文档；正式 APK 应作为 Release 附件发布，不直接提交到 Git 历史。
