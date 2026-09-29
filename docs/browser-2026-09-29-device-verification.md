# KEMI 浏览器 2026-09-29 源码与实机验证

仓库保留固定的 Iceraven 上游子模块和 `patches/series`，不提交已展开的 `browser/` 工作树。当前队列为 0001–0020、0025–0053，共 49 个补丁。测试包为 Android arm64 `forkRelease` 1.0.1（versionCode 101），使用仓库外的用户指定测试证书签名；APK SHA-256 为 `20d6c9dd4735ba89310c6872ebffc640386695efe5ee00559776b97361add346`。APK、证书和密码均不进入 Git。

## 可复现性

- `app:assembleForkRelease` 构建成功；APK v2/v3 签名及 16 KiB zipalign 检查通过。
- 从 `build/upstream.env` 固定的 Iceraven 提交创建干净工作树，运行 `scripts/prepare-iceraven.py` 后依次执行 `git apply --ignore-whitespace --check` 和 `git apply --ignore-whitespace`：49/49 补丁通过。
- 将重放结果与已编译、已实测工作树逐文件比较：44 个补丁涉及路径内容一致（忽略 Windows 的 CRLF/LF 差异）。
- Windows 检出的上游 Android Components 文件可能为 CRLF；`scripts/apply-patches.sh` 使用 `--ignore-whitespace` 以兼容该情况，仍逐补丁先检查再应用。

## 设备验证

设备：KEMI Vibe Pads S1，Android 12。通过 VibeKits ID `9756068916` 的 ADB 桥接安装；直连 `192.168.1.78:5555` 在本次测试中不可达。`pm install -r` 返回 `Success`，设备上安装的 `base.apk` 哈希与测试包一致。

| 检查项 | 结果 |
| --- | --- |
| 香港繁体导航栏 | 显示“↻ 刷新”，设备首选语言为 `zh-Hant-HK`。[截图](evidence/browser-2026-09-29/download-dialog.png) |
| TXT 下载记录 | 点击整行弹出系统打开方式选择器；KEMI 浏览器不是 `text/plain` 的候选应用。[截图](evidence/browser-2026-09-29/txt-system-chooser.png) |
| PDF 下载记录 | 直接在 KEMI Office 的 `PdfViewerActivity` 打开，并显示正文；没有选择窗。[截图](evidence/browser-2026-09-29/pdf-koffice.png) |
| 下载弹窗 | 标题、完成进度、删除按钮和右上角关闭按钮可见；关闭后回到网页。[截图](evidence/browser-2026-09-29/download-dialog.png) |
| 普通网页返回 | 从 `https://www.oschina.net/` 点顶部“上一页”回主页，浏览器进程保留。 |
| MCJS 页面与返回 | `https://mcjs-mirror.144449.xyz/1.8.8/` 加载到 `Mobile Browser Detected / Launch EaglercraftX` 入口，点顶部“上一页”回主页，浏览器进程保留。[入口](evidence/browser-2026-09-29/mcjs-entry.png)、[返回](evidence/browser-2026-09-29/mcjs-return.png) |

前一候选包还验证过下载进度自动更新、暂停/继续和断点续传，以及 MCJS 单人 3D 世界加载、触屏画面变化和暂停菜单；这两项没有在 2026-09-29 的最终包上重复长流程测试。[先前下载进度](evidence/browser-2026-09-29/download-progress-previous-build.png)、[先前 3D 场景](evidence/browser-2026-09-29/mcjs-world-previous-build.png)。本轮没有观察到失败项。

仍需设备使用者手测：实体键鼠的 WASD、转视角、放置方块及长时间游戏；物理屏幕边缘侧滑返回；原反馈截图中“孙鑫晶／新华社记者”的同一条百科视频长时间播放和刷新续播。该视频网址在截图中被截断，无法唯一定位，代表视频通过不能代替这条视频验收。台湾繁体资源已从 APK 核对，但本轮未切换设备全局语言单独查看界面。
