# KBrowser 轻量闭环开发流程

## 1. 目标与边界

### 最终目标

- 基于开源 Iceraven/Fenix 完整浏览器和独立 GeckoView 引擎，不使用系统 WebView。
- 普通模式具备地址栏、标签页、下载、文件上传、权限和 Cookie 等浏览器能力。
- 双屏模式启动 Display 2，并让一个网页形成 `1920 x 2560` 连续逻辑视口。
- Display 2 显示逻辑区域 `y=0..1279`，Display 0 显示 `y=1280..2559`。
- 当前实现只使用一个 GeckoSession、一个 DOM 和一个 `1920 x 2560` Gecko 合成帧；应用 EGL 合成器把同一帧上下两半分别输出到 D2/D0。
- 两屏触摸统一送入同一个 PanZoomController；D0 的触摸 Y 坐标固定增加 1280px。

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
7. 双 Session 同步原型已经作废，验收只认可单页面双 Surface 实现。

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

- 默认桌面图标必须进入双屏路由 Activity，不能依赖 ADB 或专用 URI；路由最终建立 D0 总控和 D2 顶部。
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

通过条件：解析出的 launcher 目标为 `DualScreenLaunchActivity`；无论从 D0 或 D2 点击，最终
Display 0 为 `DualScreenBrowserActivity`、Display 2 为 `DualScreenTopActivity`。

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

### M5：单页面双 Surface（已实现，真机核心闭环通过）

工作：

- 一个网页实例使用 `1920 x 2560` 逻辑视口。
- Gecko compositor 的同一帧经 SurfaceTexture/EGL 裁切输出到两个 Android Surface。
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

## 7. 当前状态与下一步

1. 本地候选 `1.1.0-rc1` 已完整 release 构建并安装到 62 真机。
2. LAUNCHER 首次打开时，D2 显示主页上半段，D0 无缝承接下半段，未出现镜像或缺页。
3. W3C 长页面分别从 D2、D0 滚动均驱动同一个 GeckoSession；两屏持续显示同一帧的相邻区域。
4. HOME 后 D0/D2 同时回到启动器，logcat 未发现 FATAL EXCEPTION。
5. 下一步补充输入框、长按选择、视频/Canvas 和 SurfaceFlinger 指标的轻量验收，再发布正式 1.1.0。

核心架构已从双 Session 同步切换为单 GeckoSession + 单 SurfaceTexture + 双 EGL
window surface。两屏不再交换滚动位置，因此不存在程序化滚动反馈环；视频、Canvas、
动态 DOM 也只执行一次。
