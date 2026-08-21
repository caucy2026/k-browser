# KBrowser 改动记录

本文记录 KEMI 双屏浏览器相对固定 Iceraven/Fenix 上游的定制内容。可复现源码以
`build/upstream.env` 指定的上游提交和 `patches/series` 的顺序为准。

## 1.3.0 正式版：离线程序员文档阅读（2026-08-22）

- 新增本地离线文档入口，覆盖 49 个真机样例：常用源码/配置、Markdown、CSV/TSV、HTML/XHTML、
  DOCX/XLSX/PPTX、ODT/ODS/ODP、EPUB、RTF、未加密 MOBI、旧 Office 兼容提取和 Gecko 原生 PDF。
- 文档复用同一个 GeckoSession 与双屏 `1920×2560` 连续画布；Display 2 为顶部，Display 0 为相邻下页，
  不创建两个解析页面互相同步。
- 解析在后台线程完成，加入输入、ZIP、输出字符和表格行列上限；本地 HTML 清理不可信脚本，文档不上传。
- PalmDOC/MOBI 回溯解压改为固定上限增量缓冲，避免大文件反复复制已有输出导致平方级 CPU/内存开销。
- 私有缓存由仅绑定 `127.0.0.1` 的只读随机令牌服务提供给 Gecko，使已有可见首行朗读、高亮和自动滚动
  可以直接复用于文档。
- 63 Display 2 完成 49 项隔离真机矩阵：48 项转换耗时中位数 9ms、最大 86ms，PDF 原生显示；
  Markdown 滚动和 6158 字/302 段朗读通过，未发现解析失败、崩溃或 ANR。
- 新增格式规范、49 样例生成器、单双屏防抢占测试脚本和真机报告；准确记录 DRM、OCR、旧 Office
  版式和图表在线渲染的能力边界。

## 1.2.4 正式版：首页标签单行显示（2026-08-21）

- 首页全部收藏标签强制单行显示，修复“KEMI 知识库”在真机窄 CSS 视口换行的问题。
- 缩小卡片左右内边距、适配主标签字号并增加溢出保护，保持四列布局稳定且文字完整。
- 正式产物：`bin/DualScreenBrowser-v1.2.4-arm64-release.apk`。

## 1.2.3 正式版：首页开源项目标签（2026-08-21）

- 默认首页新增“KEMI Top 100”和“GitHub Top 300”，分别指向
  `https://kemi-chat.newlinksz.com:21121/km100` 与
  `https://kemi-chat.newlinksz.com:21121/top300`。
- 主页“双屏浏览器”标题禁止自动换行，在车机横屏布局中保持一行显示。
- 新增可复现补丁 `0033-add-kemi-project-ranking-sites.patch`。
- 使用 KEMI 统一正式证书构建，正式产物为
  `bin/DualScreenBrowser-v1.2.3-arm64-release.apk`。

## 1.2.2-rc2：网页语音播报（2026-08-15）

- D2 和单屏工具栏新增“朗读/暂停/继续”，并提供独立停止浮层；双屏仍只创建一个进程级播放器，
  不会因两个 Activity 产生重复播报。
- 内置特权 WebExtension 从当前可见语义块开始提取正文，按自然标点分段、预取下一段，并高亮及平滑跟随当前段。
- 优先读取系统 `Settings.Global["iflytek_params"]` 中预置的讯飞参数，绝不硬编码或输出凭据；云端不可用时
  降级 Android `TextToSpeech`。暂停使用“停流并重建当前段”，规避目标固件 AudioTrack 假恢复。
- 页面跳转、主页、返回、双屏统一退出和会话销毁均停止播放；generation 屏障丢弃迟到的网络/音频回调。
- 62 真机 W3C 页面提取 4022 字、分为 50 段，首个 PCM 361ms；验证下一段预取、高亮跟随、暂停续播、
  手动停止和换页停止。内部主页提取 189 字，首个 PCM 355ms。未发现浏览器 `FATAL EXCEPTION`。
- 修复“当前段落可见但段首已滚出 D2 时仍从隐藏段首朗读”：使用 DOM Range 行框定位 D2 工具栏下方
  第一条实际可见文字，并保存块内字符游标；后续按朗读行自动平滑滚动，重复文字和暂停续读不回跳。
- 可复现补丁新增 `0031-add-webpage-read-aloud.patch` 和
  `0032-start-read-aloud-at-first-visible-line.patch`，完整说明见 `docs/webpage-read-aloud.md`。
- 正式签名候选 APK：`bin/DualScreenBrowser-v1.2.2-rc2-arm64-release.apk`，SHA-256：
  `af6e9ecfd0429b55d6fc73158423681dd8cde340e72bf8a56f180838a6107f5d`；已覆盖安装到 63 并确认版本，
  设备被其他测试应用占用时没有抢占前台或虚报真机声音验收。

## 1.2.1 正式版（2026-08-11）

- 修复从 Display 2 点击普通图标后看似闪退：新增独立 `DualScreenLaunchActivity`，先移除副屏
  launcher 任务，再延迟从 Application Context 在 Display 0 创建双屏总控，避开车机 ROM 的跨屏
  task/window 归属竞态。
- 双屏内部创建 D2 配对 Activity 时短暂屏蔽 `onUserLeaveHint`，内部任务切换不再误触发统一退出。
- 修复首次系统返回被误判为近期鼠标右键：验证鼠标时间戳已初始化后才计算时间差，避免
  `Long.MIN_VALUE` 算术溢出。
- 63 真机完成 D0/D2 双屏启动、D0/D2 单屏启动、W3C 长页两屏分别滚动、D0/D2 返回同步退出；
  均未发现浏览器 `FATAL EXCEPTION`。
- 可复现补丁新增 `0030-route-launches-across-displays.patch`；完整设计和验收记录见
  `docs/dual-single-screen-architecture.md`。
- 正式 APK：`bin/DualScreenBrowser-v1.2.1-arm64-release.apk`，SHA-256：
  `d4d88472c2d1155dad63d6263afe1229ba81ee038988d34f0fb2221b59484f5c`。
- 为其他项目补充 `docs/multi-display-browser-lessons.md`，集中记录双 Session 抖动、Surface 恢复黑屏、
  跨屏 task affinity、IME、右键/Back、剪贴板、逻辑/物理显示 ID 和测试假通过等经验及适用边界。

## 1.2.0 正式版（2026-08-11）

当前正式基线，APK 位于本地忽略目录 `bin/`，不提交到 GitHub。

### 双屏渲染与硬件适配

- 目标硬件固定为 Android 12、arm64、Display 0/2，单屏 `1920×1280@60Hz`。
- 使用一个 GeckoSession、一个 DOM 和一张 `1920×2560` Gecko 合成帧。
- Display 2 显示页面顶部 `0–1279`，Display 0 显示紧邻的 `1280–2559`；不是镜像或两个网页同步模拟。
- 单 EGL 合成线程依次提交两块 Surface；两屏事件进入同一个 PanZoom，不再同步两个页面的
  scrollY，因而避免双向反馈和抖动。当前验收为一次由一块屏完成一个手势，不承诺两屏同时多点触摸。
- Surface 生命周期重绑定，覆盖冷启动、HOME 后恢复和 retained `singleInstance` 副屏 Activity。
- 双屏模式固定横屏并禁止旋转。

### 双屏生命周期与操作

- 默认点击桌面图标进入双屏模式。
- 长按应用图标提供“单屏模式”快捷入口，使用独立 `SingleScreenBrowserActivity`；单双屏共用同一套
  KEMI 主页、收藏、工具栏和隐私设置，单屏模式不会创建 D2 Activity。
- 后退、前进、刷新、主页、地址输入和页面跳转共享同一会话，不会在两屏分叉。
- 从任意屏执行系统返回、工具栏退出或离开应用，另一屏同步退出并释放共享会话。
- 任意一块屏均可滚动同一页面，另一屏按相邻裁切区域连续更新。
- 鼠标右键不再触发双屏退出；标准 Gecko 右键可识别链接、文字和媒体，车机将右键降级成 Android Back 时也会显示通用网页菜单。

### 界面、站点与网页兼容

- 应用名称为“双屏浏览器”，采用原 Iceraven 轮廓和明亮蓝色配色。
- D2 保留精简工具栏；D0 不重复显示工具栏，减少双屏接缝干扰。
- 地址栏实时更新并显示加载进度；工具栏按
  `后退 / 前进 / 刷新 | 地址栏 | 打开 / 主页 / 退出` 分组，导航按钮使用 `92×56dp` 有效点击区域，
  解决车机触摸目标过小以及“前进/前往”语义重复的问题。
- 地址栏为空、只含空格、残留 `about:blank` 或内部主页地址时，点击“打开”或键盘 Go 会进入
  `https://kemi.newlinksz.com/kd/`；普通启动和“主页”仍进入 KEMI 定制主页。
- 主页以知识、文档和学习站点为主，包含百度、百度百科、知乎、天涯社区、MDN、W3C、
  中国知网、国家图书馆、中国大学 MOOC、果壳、开源中国和 KEMI 知识库。
- 天涯收藏固定为 `https://www.tianya.net/index.html`。
- 接管网页 `target=_blank` 新窗口请求，在当前共享 GeckoSession 打开，避免点击无响应或两屏分叉。
- 为跨屏共享 Surface 恢复 Gecko 原生 `InputConnection`；触摸任意屏网页输入框时，将输入焦点绑定到该屏真实 Activity，软键盘和按键事件直接交给同一 GeckoSession。
- 右键通用菜单提供打开/复制链接、复制链接文字、打开/复制媒体地址，以及后退、前进、刷新、主页和复制当前网址。
- 网页文字选区在右键菜单抢焦点前预保存，并明确写入 Android `ClipboardManager`；复制不依赖输入框焦点，
  输入法剪贴板和其他 App 可以读取，系统剪贴板为空时“粘贴”保持禁用。
- 默认启用严格跟踪保护；购物站和境内访问不稳定的默认入口已移除。
- 移除 Firefox/Iceraven 注册、账户推广、首次引导、Pocket、赞助推荐、默认浏览器横幅、遥测和 Nimbus 远程实验，
  保留 Gecko 作为 MPL 开源网页引擎，界面统一使用 KEMI 品牌。

### 构建与发布

- 本地构建优先，GitHub Actions 仅用于干净环境回归和临时候选产物。
- 固定上游提交，支持递归子模块、隔离 Python/PyYAML 环境和
  0001–0020 + 0025–0029 补丁顺序重放；0025 合并并取代开发过程中的 0021–0024。
- 本地脚本自动发现 JDK 17、Android SDK，执行 arm64 Release、R8、资源优化和签名校验。
- 唯一正式签名资产存放在仓库外 `/Users/kemi/coding/priv/pem/kemi-unified-release`，目录包含 JKS、
  密码配置、PEM 和指纹，必须整体加密离线备份，禁止上传 GitHub。
- 正式签名别名为 `kemi-unified-release`，证书 SHA-256 为
  `C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`。
- 此证书是后续所有 KEMI Android APK 的唯一正式身份；安装过旧/过渡证书版本的设备首次迁移需要卸载旧包，
  之后统一证书版本才能持续覆盖升级。
- 1.2.0 本地构建完成 4215 个 Gradle 任务，并通过 APK Signature Scheme v2/v3 校验。

### 真机验证

- 192.168.3.62：验证双屏连续页面、两屏滚动、统一退出、单屏模式、常用知识站和天涯站内跳转。
- 192.168.3.63：验证 rc5 工具栏比例、D0/D2 Activity、同一张 `1920×2560` Gecko 首帧。
- 天涯两篇帖子和帖子第 2 页可正常打开；部分栏目由天涯自身提示分阶段恢复，不属于浏览器故障。
- 百度、知乎、MDN 和 KEMI 知识库完成轻量加载回归，未发现 `FATAL EXCEPTION`。
- 192.168.3.63：主页搜索框、screensaver 账号框和密码框均在 Display 2 弹出软键盘并实际接收输入；IME client、focused window 和 input target 均属于 Display 2 的真实 Activity。
- 192.168.3.62：Display 2 模拟车机“鼠标活动后 Back”路径，通用右键菜单正常出现且 D0/D2 保持运行；菜单关闭后普通返回仍同步退出两屏。
- 63 Display 0 单屏验证空地址点击“打开”后实际进入 KEMI 知识库，日志无浏览器 `FATAL EXCEPTION`；
  副屏已有应用未被停止或覆盖。
- 正式 APK：`bin/DualScreenBrowser-v1.2.0-arm64-release.apk`，SHA-256：
  `6f2ff012c5f4cf52061ea04242da3098d765fed889043e323fe3ab2d60c505ef`。

## 补丁索引

| 补丁 | 内容 |
| --- | --- |
| 0001 | 建立双屏浏览器入口、D0/D2 Activity、基础导航与滚动协调 |
| 0002 | 增加浏览器工具栏、地址输入和中文主页 |
| 0003 | 平滑滚动、知识站主页和严格跟踪保护 |
| 0004 | 精简界面并同步两屏导航状态 |
| 0005 | 使用可稳定访问的 Google Maven 直连端点 |
| 0006 | 修复 Python 环境缓存检查，提升本地/CI 可复现性 |
| 0007 | 强制扩展显示角色和统一生命周期 |
| 0008 | 增加 KEMI 知识库收藏入口 |
| 0009 | 改为一张 Gecko 画布跨两块物理显示裁切输出 |
| 0010 | 修复 Activity 保留/恢复后的 Surface 重绑定与副屏黑屏 |
| 0011 | 优化工具栏、知识站、蓝色图标和 KEMI 硬件参数 |
| 0012 | 增加桌面长按“单屏模式”快捷入口 |
| 0013 | 恢复原图标轮廓并处理 `target=_blank` 站内链接 |
| 0014 | 任意屏返回、退出、HOME 时同步关闭另一屏 |
| 0015 | 收紧“前往/退出”按钮比例和间距 |
| 0016 | 为共享 Gecko Surface 恢复网页输入连接、软键盘和硬键事件转发 |
| 0017 | 增加标准鼠标右键菜单，并兼容车机将右键降级为 Android Back |
| 0018 | 为右键菜单增加图标、复制粘贴和系统剪贴板状态 |
| 0019 | 修复网页选区复制逻辑，并锁定双屏方向 |
| 0020 | 在硬件右键/Back 转换过程中保存网页选区 |
| 0025 | 合并干净开源界面、系统剪贴板和统一单屏主页，取代开发补丁 0021–0024 |
| 0026 | 放大并统一浏览导航按钮和工具栏比例 |
| 0027 | 分离历史“前进”和地址“打开”操作，重排主页与退出 |
| 0028 | 空地址默认打开 KEMI 知识库 |
| 0029 | 清理 Gecko `about:blank`/内部主页残留后再执行默认知识库导航 |
| 0030 | 从任意显示安全路由双屏启动，并修复内部切屏/首次返回误退出逻辑 |
| 0031 | 增加闭环网页语音播报、讯飞流式 PCM、系统降级、预取、暂停续播及页面跟随 |
| 0032 | 从 D2 第一条实际可见文字起读，并按字符行框自动滚动且避免重复短语回跳 |
| 0033 | 增加 KEMI 项目排行主页标签并保持标题单行 |
| 0034 | 保持首页全部收藏标签单行 |
| 0035 | 增加离线程序员文档解析、文件 Intent、私有只读页面服务和单双屏文档接入 |

## 仓库备份规则

- GitHub 保存：补丁、脚本、配置、README、CHANGELOG 和开发文档。
- GitHub 不保存：`bin/` APK、`test-results/` 截图/视频、`.tools/`、仓库外 `priv/pem` 私钥和设备本地配置。
- `browser/` 远端只保存固定上游子模块指针；开发机的补丁展开状态显示为 `m browser` 属于预期。
- 其他开发者克隆后运行 `./scripts/prepare-source.sh`，即可恢复全部定制源码。
