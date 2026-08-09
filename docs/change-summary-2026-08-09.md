# 双屏浏览器近期改动与本地备份说明

记录日期：2026-08-09

## 1. 产品目标

- 应用名称为“双屏浏览器”，浏览内核使用 Iceraven/Fenix + GeckoView，不使用系统 WebView。
- 两块 `1920×1280` 物理屏组成一个 `1920×2560` 连续网页画布。
- Display 2 显示逻辑页面顶部 `logicalTop + 0…1279`；Display 0 显示下方
  `logicalTop + 1280…2559`。两屏不是镜像，也不是两个互不相关的网页。
- 任一屏都可以操作滚动；另一屏只跟随同一逻辑位置，不允许形成双向反馈和抖动。
- 双屏模式固定横屏、禁止应用层重复旋转；D0 退出或 HOME 时必须同步关闭 D2。

## 2. 代码改动

源码改动以 `patches/series` 为唯一可复现入口，按顺序应用到固定的 Iceraven 子模块提交。

| 补丁 | 主要内容 |
|---|---|
| `0001` | 桌面入口改为双屏浏览器；增加 Gecko 双屏 Activity、双 Session、URL 与滚动同步骨架。 |
| `0002` | 增加精简浏览器工具栏、地址栏、前进/后退/刷新/主页以及本地知识主页。 |
| `0003` | 针对 Mali-G52/60Hz 合并滚动回调、阻断程序性滚动反馈；移除购物入口，加入知识类站点和严格跟踪保护。 |
| `0004` | 精简主页布局，增加搜索；同步两屏的导航、地址、加载进度和工具栏状态。 |
| `0005` | Google Maven 改为可直接访问的仓库端点，提高本地构建可用性。 |
| `0006` | 修复 Gradle Python 环境缓存检查，使本地依赖复用可正常执行。 |
| `0007` | 修复复制模式：D0 总控与 D2 顶部拆为两个 Activity；按实际 Display 判定角色；D2 为第一页、D0 固定加 1280px；加入触摸源独占和统一退出。 |

`0007` 的关键类和配置：

- `DualScreenBrowserActivity`：D0 会话总控，`singleTask`。
- `DualScreenTopActivity`：D2 顶部显示，`singleInstance`。
- 通过 `DisplayManager.displays` 枚举显示；优先选择逻辑 Display 2，但不把数组下标当作 Display ID。
- 从任意启动器所在屏进入时，最终都重定向为 D0 总控 + D2 顶部显示。
- 滚动手势期间只有触摸源可发布逻辑位置，程序性跟随回调在保护窗口内被忽略。

## 3. 界面与默认站点

- 应用标题和首页统一为“双屏浏览器”。
- 顶部保留常用浏览器操作，D0 不重复显示接缝工具栏。
- 默认入口以知识和文档为主，包括百度百科、知乎、维基百科、MDN、W3C、
  中国知网、国家图书馆、MOOC、果壳、GitHub、开源中国等；购物网站已移除。
- 默认开启严格跟踪保护，并尽量拒绝 Cookie 横幅，减少广告、跟踪脚本和布局跳动。

## 4. 构建改动

- 新增并固定本地构建入口：`./scripts/build-local.sh`。
- 本机依赖完整时必须本地优先；只有本机缺少目标系统或工具链时才使用 GitHub Actions。
- 本地完整构建已通过，产物信息：
  - 源码提交：`a12d81e2e49d0dbcce1ed3c583a68906b937483e`
  - versionName：`a12d81e-local`
  - APK：`bin/KBrowser-arm64.apk`
  - SHA-256：`637b1a20194d16a1e7489a81540cf0d68c5f3c43cadcde9cde6d5e724c1d2b18`
  - APK v2/v3 签名验证通过。

## 5. 真机闭环状态

设备：`192.168.3.62:5555`

已完成：

- 安装本地 APK，并确认 `versionName=a12d81e-local`。
- 仅通过 LAUNCHER/桌面入口启动。
- `dumpsys activity` 确认 D0 为 `DualScreenBrowserActivity`，D2 为
  `DualScreenTopActivity`。
- 已抓取双屏首页和 W3C 页面初始截图，能够看到两屏内容不同而非镜像。

尚未判定通过：

- D2/D0 分别滚动后的连续接缝与无抖动验收。
- D0 返回/HOME 后双 Activity 同时退出。
- SurfaceFlinger missed frame 增量和双屏滚动视频。

原因：滚动测试期间 KOffice 开始占用真机，之后的桌面截图不属于浏览器结果，已明确作废。

## 6. `kemi-rd` 文档对当前实现的帮助

- `chip.md` 明确设备逻辑显示为 D0/D2、分辨率均为 `1920×1280`，且 Display ID
  不连续，必须枚举显示。
- 对交互型副屏，文档推荐真实双 Activity，而非 Presentation；这与当前拆分
  D0/D2 Activity 的方案一致。
- 副屏应使用 `singleInstance`，启动时需要防止被副屏启动器错误拉起；当前代码已实现角色重定向。
- 主副屏退出必须联动，并处理 HOME、重启、显示断开和 `finish/startActivity` 竞态。
- `cross-display-keyboard.md` 提醒后续地址栏跨屏输入要以目标 Activity/Insets 为状态真源，
  不能靠当前屏推测软键盘状态。
- `dscr.md` 区分逻辑 Display ID 与 SurfaceFlinger 物理显示 ID：当前设备逻辑为
  `0/2`，物理抓屏为 `0/1`，测试脚本不可混用。
- `ci-build.md` 要求本地可可靠构建的平台不等待云端，同时记录 commit、版本、APK 哈希和真机结果。

## 7. 当前技术边界

当前仍是两个共享 GeckoRuntime 的 GeckoSession，通过 URL、Cookie 与逻辑滚动同步形成连续视觉原型。
它尚不是“一个 DOM/一个 compositor 同时裁切到两个 Surface”的最终实现，因此视频、Canvas、
动态布局和严格逐帧一致性仍存在天然风险。最终无抖动目标需要进入单页面双 Surface 阶段，
在 Gecko/Android compositor 层输出同一帧的上下两个裁切区域。

## 8. 本地 Git 备份口径

- 源码、补丁、脚本和文档进入 Git。
- `bin/` 保留本地 APK 与 SHA-256，但不提交二进制。
- `test-results/` 保留真机截图、视频和日志，但不提交临时证据。
- `artifacts/git-backups/` 保存本地 Git bundle，目录已被忽略，不污染源码历史。

## 9. 正式 Release 补充

- 收藏首页新增 `https://kemi.newlinksz.com/kd/`，显示为“KEMI 知识库”。
- 正式 release 使用项目独立签名，不再使用 Android debug 或 CI 临时测试证书。
- release 证书 SHA-256 指纹：
  `73:D6:B0:55:B9:DC:06:59:D7:C0:A3:D9:D5:BB:49:E1:B8:C6:49:8A:A1:2C:DD:B2:A2:8C:64:9D:53:7B:11:76`。
- 私钥、证书和本地口令文件统一保存在忽略目录 `keystore/`；该目录必须离线备份，
  后续升级包必须继续使用同一证书，否则 Android 无法覆盖安装。
- 正式构建入口：`./scripts/build-release.sh <versionName>`。
