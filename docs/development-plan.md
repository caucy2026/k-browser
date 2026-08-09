# KBrowser 轻量闭环开发流程

## 1. 目标与边界

### 最终目标

- 基于开源 Iceraven/Fenix 完整浏览器和独立 GeckoView 引擎，不使用系统 WebView。
- 普通模式具备地址栏、标签页、下载、文件上传、权限和 Cookie 等浏览器能力。
- 双屏模式启动 Display 2，并让一个网页形成 `1920 x 2560` 连续逻辑视口。
- Display 2 显示逻辑区域 `y=0..1279`，Display 0 显示 `y=1280..2559`。
- 当前阶段使用两个 GeckoSession 共享 URL、Cookie 与逻辑滚动位置；必须阻断程序化滚动反馈并按显示帧合并同步事件。
- 两屏触摸统一映射到连续逻辑坐标。

### 首版不做

- Google 账号同步。
- Widevine DRM 与 Netflix 等受保护内容承诺。
- 大规模 Web Platform Tests。
- 全机型适配；首版只保证当前 KEMI Android 12 真机。
- 一开始就做完整 Chromium compositor 改造。

## 2. 效率原则

1. 每一步只解决一个风险。
2. 每一步必须有一条可重复命令和明确的通过条件。
3. 当前闭环未通过，不进入下一阶段。
4. 本机依赖完整时必须优先本地增量编译，云端只处理本机缺失工具链或网络依赖的情况。
5. 优先真机冒烟，避免重型自动化测试。
6. 双屏框架与 Chromium 内核改造分开验证。
7. 先实现可丢弃原型，再进入单页面双 Surface 正式实现。

本地候选构建统一使用：

```bash
./scripts/build-local.sh
```

通过条件：输出 `LOCAL BUILD PASSED`，并生成 `bin/KBrowser-arm64.apk` 与 SHA-256。

双屏验收必须同时满足：`dumpsys activity` 中 D0 为
`DualScreenBrowserActivity`、D2 为 `DualScreenTopActivity`；长页面初始截图中 D0
必须承接 D2 下方恰好 1280px 的内容；在任一屏滚动时另一屏不得成为反馈源；从
D0 返回或按 HOME 后两个 Activity 都必须消失。

## 3. 固定设备基线

| 项目 | 基线 |
|---|---|
| ADB | 由本地 `config/device.local.env` 提供，不提交到 Git |
| Android | 12 / API 31 |
| ABI | arm64-v8a |
| GPU | Mali-G52 / OpenGL ES 3.2 |
| RAM | 约 6 GB |
| 主屏 | Display 0，1920 x 1280，60Hz |
| 副屏 | Display 2，1920 x 1280，60Hz |
| 目标逻辑视口 | 1920 x 2560 |

注意：副屏硬件存在 180 度方向配置，Android 当前已经提供逻辑坐标补偿。应用层必须通过触摸测试确认后再决定是否变换，禁止重复旋转。

## 4. 阶段与闭环

### M0：开发入口与真机基线

工作：

- 固定项目目录、ADB 路径和设备地址。
- 自动检测 Android、ABI、内存、GPU、Display 0/2、分辨率和显示状态。
- 保存可重复运行的基线命令。

检测：

```bash
./scripts/check-device.sh
```

通过条件：脚本退出码为 0，并打印 `DEVICE CHECK PASSED`。

### M1：原版 Iceraven/Fenix APK

工作：

- 以 Git submodule 固定 Iceraven 稳定提交。
- 在 GitHub `ubuntu-latest` 上构建 `app:assembleForkRelease`。
- 不修改双屏逻辑，先得到可安装 APK。

检测：

```bash
./scripts/install-apk.sh /absolute/path/to/KBrowser-arm64.apk
./scripts/smoke-package.sh io.github.forkmaintainers.iceraven
```

通过条件：安装成功、主 Activity 在 Display 0、进程存活、无启动崩溃。

### M2：KBrowser 产品壳

工作：

- 修改包名、名称、图标和默认主页。
- 保留地址栏、标签页、下载、文件上传和网站权限。
- 禁用不可用的 Google 服务入口。

轻量测试：

- 打开一个 HTTPS 页面。
- 输入搜索词并跳转。
- 打开第二个标签再切回。
- 下载一个小文件。
- 上传一个小文件。

通过条件：五项人工冒烟全部通过，logcat 无崩溃。

### M3：双屏 Activity 骨架

工作：

- 默认桌面图标必须直接启动双屏 Activity，不能依赖 ADB 或专用 URI。
- 主 Activity 固定 Display 0。
- 副屏 Activity 通过 `setLaunchDisplayId(2)` 启动。
- 副屏使用 `singleInstance`，两屏进入沉浸全屏。
- 先显示坐标网格，不接 Chromium 页面。
- 处理副屏缺失、重建、HOME、返回和误启动重定向。

检测：

```bash
./scripts/check-activity-displays.sh cn.newlink.kbrowser
```

通过条件：两块屏各有一个全屏窗口，显示 ID 正确，返回后没有孤立副屏窗口。

桌面启动闭环必须使用与用户一致的入口，禁止仅用组件名启动代替验收：

```bash
adb shell monkey -p io.github.forkmaintainers.iceraven -c android.intent.category.LAUNCHER 1
```

通过条件：解析出的 launcher 目标为 `DualScreenBrowserActivity`，Display 0/2 各有一个实例。

### M4：双页面同步原型

工作：

- 两屏临时使用两个页面实例。
- 同步 URL、Cookie、缩放和滚动位置。
- Display 0 的逻辑滚动偏移恒为 Display 2 加 1280。
- 此实现只用于验证交互，验证完成后可替换。

轻量测试页面：

- 静态长页面：验证接缝连续。
- 百度或 Bing：验证输入和导航。
- Bilibili 或 YouTube：验证视频播放。
- GitHub：验证复杂页面和登录 Cookie。

通过条件：静态页面接缝正确，四类冒烟页面可用；允许动画不同步，但不得崩溃。

### M5：单页面双 Surface

工作：

- 一个网页实例使用 `1920 x 2560` 逻辑视口。
- Chromium compositor 的同一帧裁切输出到两个 Android Surface。
- Display 2 取上半区域，Display 0 取下半区域。
- 副屏输入事件映射到连续坐标空间。
- 两屏共享焦点、选择、缩放和滚动状态。

分步闭环：

1. 静态色块跨屏位置正确。
2. 静态长网页接缝正确。
3. 单指滚动连续。
4. 点击和长按坐标正确。
5. 输入框和软键盘可用。
6. 视频与 Canvas 不重复执行。

通过条件：以上六项逐项通过；每次只排查当前项。

### M6：轻量网站回归与交付

只保留六个代表场景：

| 场景 | 建议站点 | 验证点 |
|---|---|---|
| 搜索 | 百度/Bing | 输入、跳转 |
| 视频 | Bilibili/YouTube | 播放、全屏、声音 |
| 百科 | 百度百科/维基百科 | 长页面、目录跳转 |
| 社区 | 知乎 | 无限滚动、弹层 |
| 开发 | MDN/GitHub | 文档、登录、复制 |
| 学术 | 知网/国家图书馆 | 检索、中文输入 |

每个场景只检查：加载、滚动、点击、输入、双屏接缝、无崩溃。总测试时间控制在 30 分钟以内。

## 5. 每次改动的统一闭环

```text
修改一个目标
  -> 编译相关最小目标
  -> 安装覆盖
  -> 清理 logcat
  -> 执行一个对应场景
  -> 检查窗口/截图/logcat
  -> 记录通过或失败原因
```

禁止把多个未验证的底层改动堆积后一次测试。

## 6. 提交要求

每个提交必须包含：

- 一个明确目标。
- 一条验证命令。
- 实际验证结果。
- 若为真机 UI 改动，至少保留 Display 0 和 Display 2 的截图路径。

推荐提交顺序：

```text
build: bootstrap Chromium arm64 build
feat: add KBrowser branding and package
feat: launch secondary activity on display 2
test: add dual-display activity smoke check
prototype: synchronize dual browser tabs
feat: split one compositor frame across displays
```

## 7. 当前下一步

1. 使用本地候选 `a12d81e-local`，不等待云端构建；APK 位于
   `bin/KBrowser-arm64.apk`，SHA-256 为
   `637b1a20194d16a1e7489a81540cf0d68c5f3c43cadcde9cde6d5e724c1d2b18`。
2. 设备空闲时只通过 LAUNCHER/桌面入口启动，确认 D0 为
   `DualScreenBrowserActivity`、D2 为 `DualScreenTopActivity`。
3. 从内置知识站进入 W3C 长页面，验证 D2 顶部和 D0 下方内容相差固定 1280px，
   不能镜像，也不能缺页。
4. 分别从 D2、D0 各滚动一次，录制两块物理屏，检查另一屏只跟随、不回传、
   不抖动。
5. 在 D0 分别执行返回和 HOME，确认两块屏的 Activity 同时消失；保存窗口状态、
   SurfaceFlinger 指标和崩溃日志。

2026-08-09 真机进度：本地 APK 已安装，已确认两个 Activity 分别位于 D0/D2；
W3C 初始双屏画面已留档。滚动测试期间真机被 KOffice 测试占用，因此该次滚动截图
作废，待设备空闲后从滚动步骤继续。

当前原型使用两个共享 GeckoRuntime 的 GeckoSession；它不是系统 WebView。两屏共享
Cookie 和逻辑滚动位置，Display 0 位置恒为 Display 2 加一个屏幕高度。后续 M5 再把两个页面
实例替换为单页面双 Surface，解决视频、Canvas 和页面内部瞬时状态重复的问题。
