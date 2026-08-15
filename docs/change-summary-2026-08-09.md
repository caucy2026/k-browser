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
| `0007` | 修复复制模式：D0 总控与 D2 顶部拆为两个 Activity；按实际 Display 判定角色；D2 为第一页、D0 固定加 1280px；加入早期触摸源保护和统一退出。 |
| `0008` | 收藏页加入 KEMI 知识库。 |
| `0009` | 废弃双 Session 追帧同步；一个 GeckoSession 渲染 1920×2560 帧，由共享 EGL 合成器同时裁切到 D2/D0；两屏触摸进入同一 PanZoomController。 |
| `0010` | 修复副屏 `singleInstance` 复用黑屏：在 `onNewIntent/onResume` 重新绑定存活 Surface，并复用已缓存的 Gecko 首帧。 |
| `0011` | 优化车机操作体验：放大首排按钮和地址栏、增加双屏联动退出；重写首页体验文案，加入天涯社区并移除境内访问不稳定入口；更新蓝色双屏图标，并针对 1920×1280@60Hz/Mali-G52 明确硬件加速和帧率。 |

`0007` 的关键类和配置：

- `DualScreenBrowserActivity`：D0 会话总控，`singleTask`。
- `DualScreenTopActivity`：D2 顶部显示，`singleInstance`。
- 通过 `DisplayManager.displays` 枚举显示；优先选择逻辑 Display 2，但不把数组下标当作 Display ID。
- 从任意启动器所在屏进入时，最终都重定向为 D0 总控 + D2 顶部显示。
- `0007` 时使用双 Session 和逻辑位置保护；该路径已被 `0009` 的单 Session 共享 PanZoom 取代。
  当前两屏事件调用虽串行化，但没有对两屏同时按下实现跨 Activity 手势所有权锁。

## 3. 界面与默认站点

- 应用标题和首页统一为“双屏浏览器”。
- 顶部保留常用浏览器操作，D0 不重复显示接缝工具栏。
- 默认入口以知识和文档为主，包括百度、百度百科、知乎、天涯社区、MDN、W3C、
  中国知网、国家图书馆、MOOC、果壳、开源中国和 KEMI 知识库；购物网站和境内访问不稳定入口已移除。
- 首页体验文案精简为“一页跨双屏，内容自然衔接，双屏都能流畅操作”，不再显示实现说明。
- 首排按钮按车机触控放大并增加“退出”，退出动作统一结束 D0/D2 两个 Activity。
- 启动图标改为偏蓝色的上下双屏造型。
- 默认开启严格跟踪保护，并尽量拒绝 Cookie 横幅，减少广告、跟踪脚本和布局跳动。

## 4. 构建改动

- 新增并固定本地构建入口：`./scripts/build-local.sh`。
- 本机依赖完整时必须本地优先；只有本机缺少目标系统或工具链时才使用 GitHub Actions。
- 本地完整构建已通过，产物信息：
  - 候选版本：`1.2.0-rc2`
  - APK：`bin/KBrowser-arm64.apk`
  - SHA-256：`e3e6ab2bdcf2e6338cbfaddda19aa568f15c07ca4d3350d602b54443f7884c40`
  - APK v2/v3 签名验证通过。

### 4.1 单屏快捷模式（0012）

- 普通点击桌面图标仍默认启动双屏总控，现有 D0/D2 拼接行为不变。
- 长按应用图标新增第一项“单屏模式”，使用独立蓝色单屏图标。
- 选择后直接启动标准 `HomeActivity`，只在当前显示运行，不创建 D2 Activity，
  不启用 `1920×2560` 双屏裁切。
- 单屏模式的退出和任务生命周期独立，不影响默认双屏入口。
- 本地 release 构建 4215 个任务通过；lint 为 0 错误、0 警告；APK 反编译确认
  `open_single_screen` 指向 `org.mozilla.fenix.HomeActivity`。

## 5. 真机闭环状态

设备：`192.168.3.62:5555`

已完成：

- 安装本地 APK，并确认 `versionName=a12d81e-local`。
- 仅通过 LAUNCHER/桌面入口启动。
- `dumpsys activity` 确认 D0 为 `DualScreenBrowserActivity`，D2 为
  `DualScreenTopActivity`。
- 已抓取双屏首页和 W3C 页面初始截图，能够看到两屏内容不同而非镜像。

单页面候选 `1.1.0-rc1` 已完成核心闭环：首次打开连续、W3C 初始接缝连续、
D2/D0 分别滑动均控制同一页面、HOME 后两屏 Activity 同时退出，且无崩溃日志。
SurfaceFlinger 指标、输入选择和视频/Canvas 仍作为正式 1.1.0 前的轻量补充项。

`0010` 真机回归已通过：3 次进程冷启动、2 次 HOME 后 Activity 复用共 5 轮，
D2 每轮均非黑屏；日志显示冷启动收到 `1920x2560` 首帧，复用轮以
`cachedFrame=true` 重新绑定 TOP Surface。W3C 页面从 D2、D0 各滑动一次后，两屏仍为
同一页面相邻区域，未发现 FATAL EXCEPTION。

### 1.2.0-rc1 界面与硬件优化回归（2026-08-10）

- 本地 APK 已成功覆盖安装到 `192.168.3.62:5555`，仅通过 LAUNCHER monkey 启动。
- 冷启动确认 D2 为 `DualScreenTopActivity`，合成器绑定 TOP/BOTTOM，并收到首个
  `1920x2560` Gecko 帧；D2 没有黑屏。
- 首页实机确认旧的 Display 说明已移除，新体验文案、放大的首排按钮、“退出”、
  天涯社区与 KEMI 知识库入口均已进入 APK；GitHub/Wikipedia 不再预置。
- W3C 初始截图确认 D2/D0 显示同一页面的相邻上下区域，而非镜像。
- 在继续执行 D0 滑动时 KOffice 重新占用主屏；被覆盖的截图已作废并立即停止输入。
  因此 HOME 恢复、D0/D2 各自完整滑动、站点加载及退出联动仍需设备再次空闲后补测，
  当前不得标记为完整通过。

### 1.2.0-rc2 单屏快捷模式（2026-08-10）

- 本地 release 编译、资源收缩、R8、打包及 v2/v3 签名验证通过。
- APK 静态闭环通过：默认 LAUNCHER alias 仍指向 `DualScreenBrowserActivity`；
  长按快捷菜单已包含“单屏模式”，目标为标准 `HomeActivity`。
- 真机检查时 D2 正被 WPS 文档占用，按测试互斥约定未安装、未抢占；需设备空闲后补充
  “普通点击=双屏、长按单屏模式=仅当前屏”的启动和退出证据。

### 1.2.0-rc4 导航与统一退出回归（2026-08-10）

- 本地 release 构建 4215 个任务通过，APK v2/v3 签名验证通过；SHA-256 为
  `13ad1314406462e6a3158b22e10d3a97b201787b317658af7f7251757522e684`。
- 恢复原 Iceraven 图标轮廓，只把前景、渐变和背景调整为更明亮的蓝色系。
- 天涯收藏地址固定为 `https://www.tianya.net/index.html`；双屏专用会话接管
  `target=_blank` 请求，在当前共享 GeckoSession 打开，避免站内帖子点击无响应或分叉。
- 双屏真机确认天涯首页及两篇帖子均成功跳转；D2/D0 显示同一帖子页面的相邻区域，
  从两屏分别滑动后仍保持同页连续输出。
- D2 单屏模式确认天涯两篇帖子和帖子第 2 页可打开；未开放栏目会显示天涯自身的
  “历史数据与互动功能将分步恢复”提示，不属于浏览器故障。
- D0 返回、D2 返回、D2 工具栏退出、D0 HOME 四条路径逐项重启验证，均使 D0/D2
  两个 Activity 同时消失并回到启动器。
- D2 单屏轻量回归通过：百度加载首页、知乎加载登录页、MDN 加载中文开发文档、
  KEMI 知识库加载开发者平台；主屏 Winlator 在整个单屏回归中保持前台。
- 本轮 logcat 未发现 `FATAL EXCEPTION` 或 `AndroidRuntime` 崩溃。

### 1.2.0-rc5 工具栏比例优化（2026-08-10）

- 将“前往”和“退出”由 `76×58dp` 收紧为 `64×48dp`，与左侧导航按钮保持同一宽度。
- 两个强调按钮分别增加 `4dp` 左间距，避免蓝色背景连成过大的色块，同时保留车机触控面积。
- 本地完整构建通过（4215 个任务），APK v2/v3 签名校验通过。
- 63 真机收起远程控制侧栏后验证：工具栏完整显示、按钮比例协调，D0/D2 双屏 Activity 同时运行。
- APK SHA-256：`39a9b8ba4fa3e5ce3f3e6488419e7f352b39e6f0229df57cb9badab561b833b1`。

### 1.2.0-rc6 网页输入与软键盘修复（2026-08-10）

- 根因是双屏合成改用普通 `SurfaceView` 后，只转发了 Gecko 触摸事件，没有暴露 Gecko
  `SessionTextInput` 的 Android `InputConnection`；网页虽然收到点击，输入法却找不到文本编辑目标。
- 增加 `GeckoInputSurface`，将 `onCreateInputConnection`、返回键前置事件和完整硬键事件交给
  同一个 GeckoSession 的 `SessionTextInput`。
- 每次任意屏 `ACTION_DOWN` 都把 Gecko 文本输入 view 切换到实际触摸屏的 Surface，并请求真实
  Activity 焦点，符合 `kemi-rd/md/cross-display-keyboard.md` 的目标窗口输入原则。
- 63 真机验证：首页搜索框可弹出软键盘并输入 `rc6input`；
  `https://www.newlinksz.cn/screensaver/main/login` 的账号、密码框均可弹出软键盘并分别接收输入。
- `dumpsys input_method` 确认 client、focused window 和 IME input target 均在 Display 2，
  `mInputShown=true`；logcat 未发现 `FATAL EXCEPTION`。
- 本地完整构建通过（4215 个任务），APK v2/v3 签名校验通过；APK SHA-256：
  `8f0142cbf26953fec7b3e7755bd22d7b6bc9b597ca84431af35cfc8bf3ba991e`。

### 1.2.0-rc7 鼠标右键通用菜单（2026-08-10）

- 鼠标右键不再调用双屏退出；标准 Gecko context element 可提供链接、链接文字和媒体地址。
- 通用菜单包含打开/复制链接、复制链接文字、打开/复制媒体、后退、前进、刷新、主页和复制网址。
- 增加鼠标 hover、滚轮等 generic motion 到同一 `1920×2560` Gecko 坐标空间的转发。
- 针对车机输入栈把鼠标右键降级为普通 Android Back 的情况：最近 3 秒存在鼠标活动时，
  Back 显示右键菜单；超过判定窗口的系统/键盘返回仍执行 D0/D2 联动退出。
- 62 真机通过模拟“Display 2 鼠标移动 + keyboard Back”复现降级路径：菜单正常出现，
  两个浏览器 Activity 均保持；菜单关闭后普通返回使两屏回到原前台应用/启动器。
- 本地构建 4215 个任务通过，APK v2/v3 签名通过，未发现 `FATAL EXCEPTION`；APK SHA-256：
  `2dc6605652afb2cc511eb59ac7e471b8ead894d1ce4968e51668a0aa5dfb6afa`。

### 1.2.0-rc8 复制粘贴与方向锁定（2026-08-10）

- 右键菜单每项增加图标，并补充“复制所选内容”“粘贴”。
- “复制所选内容”始终可操作；通过 Gecko `SelectionActionDelegate` 取得网页正文选区后直接写入
  Android 剪贴板，不再错误依赖输入框焦点或 `InputConnection`。
- “粘贴”仅在系统剪贴板存在非空文本时启用；无可粘贴内容时保持灰色，避免无效点击。
- 双屏两个 Activity 在 Manifest 横屏声明之外，额外在创建和恢复时强制请求横屏；双屏会话运行期间
  不响应传感器或其他应用引起的方向切换，始终保持当前 `1920×1280×2` 拼接布局。
- 本地完整 release 构建通过（4215 个任务），APK v2/v3 签名校验通过。
- 最终候选已在 63 使用非增量流式安装成功：D0/D2 Activity 同时运行，配置方向保持
  `orientation=2`（横屏）；右键菜单确认“复制所选内容”为 `enabled=true`。
- Android 12 剪贴板已用 `clearPrimaryClip` 清空，随后返回键验证 D0/D2 同步退出；准备重新启动
  检查粘贴置灰时 63 网络 ADB 再次进入 `offline`，未修改或抢占正在运行 Winlator 的 62。

### 1.2.0-rc9 硬件右键下保留网页选区（2026-08-10）

- 修复左键选中文字后，右键菜单提示“请选择要复制的内容”：车机把右键转换为 Android Back，
  Gecko 会在 Activity 显示菜单前隐藏视觉选区，旧逻辑同时清除了已捕获文字。
- 现在只记录非空 Gecko 选区，右键隐藏事件不再清除；复制完成或页面开始跳转时再清空，避免旧选区串页。
- 本地完整 release 构建 4215 个任务通过，APK v2/v3 签名通过。
- 63 非增量安装成功，`versionName=1.2.0-rc9`；普通桌面入口启动后 D0/D2 Activity 同时运行，
  启动日志未发现 `FATAL EXCEPTION`。

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

当前已经是一个 DOM、一个 GeckoSession 和一个 Gecko compositor 输出。Gecko 先渲染
`1920×2560` 到 SurfaceTexture，应用的单 EGL 线程在取得下一帧前依次提交上下两个裁切区域。
该结构消除了两个页面之间的 URL、滚动和动态状态同步，也从根源上移除了反馈抖动。

## 8. 本地 Git 备份口径

- 源码、补丁、脚本和文档进入 Git。
- `bin/` 保留本地 APK 与 SHA-256，但不提交二进制。
- `test-results/` 保留真机截图、视频和日志，但不提交临时证据。
- `artifacts/git-backups/` 保存本地 Git bundle，目录已被忽略，不污染源码历史。

## 9. 正式 Release 补充

- 收藏首页新增 `https://kemi.newlinksz.com/kd/`，显示为“KEMI 知识库”。
- 正式 release 使用项目独立签名，不再使用 Android debug 或 CI 临时测试证书。
- 唯一正式证书 SHA-256 指纹：
  `C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`。
- 私钥、密码配置、PEM 和指纹统一保存在仓库外
  `/Users/kemi/coding/priv/pem/kemi-unified-release`；该目录必须整体加密离线备份，后续所有 KEMI APK
  统一使用同一证书。仓库内旧 `keystore/` 与两套过渡证书已经删除。
- 安装过旧/过渡证书 APK 的设备首次切换统一证书时必须卸载旧包；统一证书建立安装基线后，后续版本保持同一
  包名、递增 `versionCode` 和同一证书即可覆盖升级。
- 正式构建入口：`./scripts/build-release.sh <versionName>`。

## 10. 当前备份点

- 源码以 `main` 最新提交为准，补丁序列可在固定上游提交上完整重放。
- 正式 APK：`bin/DualScreenBrowser-v1.2.1-arm64-release.apk`，SHA-256 为
  `d4d88472c2d1155dad63d6263afe1229ba81ee038988d34f0fb2221b59484f5c`；通用路径
  `bin/KBrowser-arm64.apk` 指向同一构建内容。
- `browser` 子模块工作树保持补丁展开状态；唯一可复现来源是固定上游提交和
  `patches/series` 的 0001–0020 + 0025–0030 顺序，不直接提交展开后的子模块指针。
- 完整 Git bundle 存放在忽略目录 `artifacts/git-backups/`，生成后必须执行
  `git bundle verify`。

### 1.2.0-rc16 干净开源界面（2026-08-10）

- 禁用首次启动、持续引导和服务条款推广弹窗，并移除 Firefox/Mozilla 账户注册菜单与设置入口。
- 禁用 Pocket 内容推荐、Contile、Firefox Suggest 的赞助/非赞助远程推荐和默认浏览器横幅。
- 遥测、营销遥测、每日使用 Ping、Nimbus 实验与远程 rollout 在 KEMI 构建中强制关闭；每次启动
  重新应用，避免升级安装继承旧版开关。
- 单屏界面的上游品牌资源覆盖为“KEMI 双屏浏览器”；Gecko 继续作为 MPL 开源渲染引擎，
  不表示产品从属于 Firefox。
- 本地完整 release 构建 4215 个任务通过，lint 0 错误/0 警告，APK v2/v3 签名验证通过；
  SHA-256：`6d85345838d06613200896131a8934e7d82161f0b18826143ad4f22eaed8473c`。
- 62、63 在构建完成时均未建立 ADB 连接，因此本条只记录构建闭环，不把界面真机检查标记为通过。

### 1.2.0-rc17 系统剪贴板与输入法缓冲区（2026-08-10）

- 修复旧逻辑把 Gecko“已接收复制命令”误判为系统剪贴板已经写入的问题。
- 缓存最后一次非空 Gecko 网页选区，避免车机把鼠标右键转换为 Back 后，视觉选区先隐藏而丢失文字。
- 单屏和双屏均通过 `ClipboardManager.setPrimaryClip(ClipData.newPlainText(...))` 直接写入 Android
  系统主剪贴板，输入法剪贴板及其他应用可以读取同一份数据。
- 无缓存选区时才回退 Gecko/InputConnection 复制，并延迟 300ms 检查系统剪贴板时间戳；未真正写入时
  才显示“请先选择要复制的内容”。
- 本地完整 release 构建 4215 个任务通过，APK v2/v3 签名验证通过；SHA-256：
  `5b487e32696cfdf31404714471c5388bf7a010b4a471ff66423d70f67276e10f`。
- 构建后 62 连接超时、63 为 Host down，真机输入法剪贴板验证仍待设备恢复，未虚报通过。

### 1.2.0-rc19 单屏主页统一与鼠标选区预保存（2026-08-11）

- “单屏模式”不再进入上游 `HomeActivity`，改为独立的 `SingleScreenBrowserActivity`；它与默认双屏
  共用 KEMI 主页、知识站收藏、精简工具栏、地址栏和跟踪保护，仅把 Gecko 画布切换为单块
  `1920×1280`，不会创建 D2 Activity。
- 修复鼠标右键菜单抢焦点后网页选区消失的问题：在弹出 Android 菜单前，趁 Gecko 仍持有焦点发送
  一次标准 `Ctrl+C`，仅当系统剪贴板时间戳确实变化时缓存非空文本；用户点击“复制所选内容”时再把
  该文本明确写入 Android `ClipboardManager`，因此输入法剪贴板及其他 App 都能读取。
- 保留 Gecko `SelectionActionDelegate` 的非空选区缓存作为首选来源；没有选区时不会拿旧剪贴板冒充，
  “粘贴”仍只在系统剪贴板存在内容时启用。
- 将 0021–0024 的历史开发补丁整理为可从 0020 基线一次应用的 `0025` 综合补丁。`patches/series`
  现在使用 0001–0020 + 0025，已在干净固定上游副本通过 `git apply --check` 并逐文件比对展开源码，
  解决旧的中间补丁计数不完整、其他同事无法从头恢复的问题。
- 本机完整 `forkRelease` 构建通过 4215 个任务，APK Signature Scheme v2/v3 校验通过；rc19 APK
  SHA-256 为 `5e6e096700f5e3adba835731a7bc46e192cfa6a4dbfac1a8961bf7e8e93d4fdb`。再次连接后
  192.168.3.62/63 仍未出现在 ADB 设备列表，真机交互验证待设备恢复后执行。

### 1.2.0-rc20 浏览控制区易用性调整（2026-08-11）

- 后退、前进、刷新、主页由单独的小符号改为“图标＋中文”按钮，统一为 `92×56dp` 的有效点击区域；
  前往和退出保持同高、宽度收敛为 `72dp`，地址栏继续弹性占据剩余空间。
- 普通导航按钮使用浅蓝灰底色和细边框，主操作使用品牌蓝；两种按钮都有明确按下状态，圆角、间距和
  字号统一，兼顾车机鼠标操作、触摸命中率与整排视觉协调。
- 工具栏高度调整为 `80dp` 并使用对称内边距，未改变双屏 `1920×2560` 的页面拼接与 1280px 接缝逻辑。
- 本地完整 `forkRelease` 构建 4215 个任务通过，APK v2/v3 签名验证通过；rc20 SHA-256 为
  `dd4e6c89adf12b06576f658a5561c8ce5704352c528241b676a2dafb1d37c88f`。62/63 当前未连接，
  因此保留真机触控体验验证项，不以编译成功代替真机通过。

### 1.2.0-rc21 浏览操作重新分组（2026-08-11）

- 解决“前进”和“前往”在同一排容易被看成两个前进按钮的问题：左侧历史操作仅保留后退、前进、刷新；
  地址栏后的提交动作明确改名为“打开”。
- 主页移动到地址操作之后；退出改为普通浅色按钮，仅“打开”保留品牌蓝主操作样式。布局顺序调整为
  `后退 / 前进 / 刷新 | 地址栏 | 打开 / 主页 / 退出`，功能分区和视觉层级更清楚。
- 本地 `forkRelease` 构建及 APK v2/v3 签名验证通过，rc21 SHA-256 为
  `cdb300886ab7e6d99abcd6a37d3dbb683d46d22b5394873c1046a208a9875736`；已通过设备临时目录覆盖安装到
  `192.168.3.63:5555`，包管理器返回 `Success`，保留原有应用数据。

### 1.2.0-rc22 空地址默认知识库（2026-08-11）

- 地址栏内容为空或只有空格时，点击“打开”或使用键盘 Go 动作会直接进入
  `https://kemi.newlinksz.com/kd/`；输入网址和搜索关键词的原有解析逻辑不变。
- 浏览器普通启动仍显示 KEMI 定制主页，“主页”按钮仍返回定制主页，避免改变已经确认的单双屏主页体验。
- rc22 正式签名 APK 已释放到 `bin/KBrowser-arm64.apk`，SHA-256 为
  `d278e7184c698f95d5c5345eb41ac0f92496c941fb3977299050b801d4154925`；已覆盖安装到
  `192.168.3.63:5555`，包管理器返回 `Success`。

### 1.2.0-rc23 清理 Gecko 内部空白地址（2026-08-11）

- 在 63 单屏真机复现发现，视觉上的“空地址”实际残留 Gecko 冷启动阶段的 `about:blank`；主页加载后
  旧逻辑跳过内部主页地址更新，因而没有清掉该值，点击“打开”会再次进入空白页。
- 主页或 `about:blank` 的位置变化现在都会把地址栏明确清空；提交时空字符串、`about:blank` 和内部
  `resource://` 主页地址都统一解析为 KEMI 知识库，从显示层和提交层同时闭环。
- rc23 release 已释放到 `bin/KBrowser-arm64.apk`，SHA-256 为
  `32d2b143c92462c1a8cb07ad859945dfc25bc8dba91462244901d5dbcd5e8d4e`，并覆盖安装到 63。
- 63 Display 0 单屏真机验证：启动后的 `EditText` 无 text 属性，证明地址栏确实为空；点击坐标落在
  “打开”按钮后等待加载，地址栏变为 `https://kemi.newlinksz.com/kd/`。最近 1200 行日志无浏览器
  `FATAL EXCEPTION`，副屏原有应用未被停止或覆盖。

### KEMI 正式发布签名（2026-08-11）

- 用户决定废弃并删除此前两套证书，重新生成唯一完整的 KEMI Android 统一正式证书。JKS、随机密码配置、PEM、
  指纹和详细手册集中在 `/Users/kemi/coding/priv/pem/kemi-unified-release`，该目录可整体独立加密备份或迁移。
- 私有目录权限为 700，JKS、密码配置和证书权限为 600。私钥和密码不进入任何应用 Git 仓库。
- 统一正式证书 SHA-256 指纹为
  `C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`。
- `scripts/build-release.sh` 默认只读取 `pem/kemi-unified-release`；缺少任何关键文件时立即失败。只有迁移完整
  备份时才通过 `KBROWSER_RELEASE_SIGNING_DIR` 指定其他目录。
- `1.2.0` 正式构建 4215 个任务通过，APK v2/v3 签名验证通过；签名者 DN 和证书 SHA-256 均与
  `/Users/kemi/coding/priv/pem/kemi-unified-release` 的正式证书一致。正式 APK SHA-256 为
  `6f2ff012c5f4cf52061ea04242da3098d765fed889043e323fe3ab2d60c505ef`。
- `bin/KBrowser-arm64.apk` 已更新为正式签名包，并另存为
  `bin/DualScreenBrowser-v1.2.0-arm64-release.apk`；对应 `.sha256` 和 `.manifest.txt` 同步生成。

## 11. 最近改动交接摘要（2026-08-10 至 2026-08-11）

- 鼠标与剪贴板：`1be1954`–`7455c3f` 增加通用右键菜单、图标化复制粘贴、硬件 Back 兼容、网页选区
  预保存和 Android 系统剪贴板写入；复制不依赖输入框焦点，空剪贴板时粘贴禁用。
- 干净开源界面：`7486186` 移除上游账户注册、首次引导、Pocket/赞助推荐、遥测和远程实验入口；Gecko
  继续作为 MPL 开源网页引擎，产品界面统一为 KEMI。
- 单双屏一致性：`1f383d3` 让单屏模式使用 KEMI 自有 Activity 和主页，并把开发补丁 0021–0024 合并为
  可重放的 0025；1.2.1 再增加跨屏安全启动补丁 0030，当前唯一补丁入口为 0001–0020 + 0025–0030。
- 车机工具栏：`22e870b`、`4aea5af` 放大导航点击区域并拆分“前进/打开”语义，当前布局为
  `后退 / 前进 / 刷新 | 地址栏 | 打开 / 主页 / 退出`。
- 默认导航：`99e96b9`、`54572fe` 让空地址、`about:blank` 和内部主页残留统一进入 KEMI 知识库；63
  单屏真机已验证地址和页面实际变化，日志无浏览器崩溃。
- 正式发布：`c8f88f7`–`708bb2b` 建立本地正式发布脚本、外置密钥目录和统一证书闭环。正式 1.2.1
  完成 4215 个任务并通过 APK v2/v3 验签，APK SHA-256 为
  `d4d88472c2d1155dad63d6263afe1229ba81ee038988d34f0fb2221b59484f5c`。
- GitHub 备份边界：源码、补丁、构建脚本、README、CHANGELOG 和 docs 提交到 `main`；`bin/`、真机证据、
  工具链以及 `/Users/kemi/coding/priv/pem` 签名私钥不上传。`browser` 显示为 `m` 是本机补丁展开状态，
  不代表需要提交子模块指针。

## 12. 1.2.1 跨屏启动与最终验收（2026-08-11）

- 副屏启动看似闪退并非 Java 崩溃。车机 ROM 会把 LAUNCHER 任务绑定到发起显示，旧实现再把同一
  `DualScreenBrowserActivity` 任务从 D2 搬到 D0，WindowManager 报告窗口属于错误显示并隐藏任务。
- 新增 `DualScreenLaunchActivity` 作为无 Gecko 的轻量路由入口，并使用独立 task affinity。从 D2
  启动时先移除路由任务，等待 400ms 释放显示归属，再从 Application Context 在 D0 创建总控；总控随后
  正常创建 D2 顶部 Activity。从 D0 启动时直接进入同一总控流程。
- 双屏内部创建配对 Activity 的 750ms 窗口内忽略 `onUserLeaveHint`，避免 ROM 把内部跨屏任务切换误判
  为用户退出；真正返回、工具栏退出或离开仍通过 `DualScreenCoordinator.exitAll()` 同时结束两屏。
- 修复首次系统返回误进鼠标菜单：旧的 `Long.MIN_VALUE` 初始时间参与减法会溢出，导致“近期鼠标活动”
  恒为真；现在先确认时间戳已初始化，再计算 3 秒保护窗口。
- 改动已整理为 `0030-route-launches-across-displays.patch`，并在固定上游 + 0001–0020 + 0025–0029
  的干净临时副本上通过 `git apply --check`、实际应用和逐文件一致性比较。
- 本机正式 `1.2.1` 构建完成 4215 个 Gradle 任务、R8、资源优化和 APK v2/v3 验签。APK：
  `bin/DualScreenBrowser-v1.2.1-arm64-release.apk`；SHA-256：
  `d4d88472c2d1155dad63d6263afe1229ba81ee038988d34f0fb2221b59484f5c`。
- 63 真机最终通过 D0/D2 双屏启动、D0/D2 单屏启动、W3C 长页面两屏分别滚动、D0/D2 系统返回同步
  退出；日志显示双屏收到 `1920×2560` 首帧、单屏收到 `1920×1280` 首帧，未发现浏览器
  `FATAL EXCEPTION`。
- 双屏/单屏完整技术说明与验收矩阵已独立整理到 `docs/dual-single-screen-architecture.md`。

## 13. 网页语音播报（2026-08-15）

- 新增进程级网页朗读控制器、内置 GeckoView 内容扩展、自然分段器、讯飞 AIUI 流式 PCM 引擎和 Android
  系统 TTS 降级；双屏两 Activity 共用一个播放器。
- 从当前可见语义块开始，当前段高亮跟随，只预取下一段；暂停时停流并重建当前段，停止/换页/退出使用
  generation 屏障阻止迟到回调。
- 凭据只从系统 `Settings.Global["iflytek_params"]` 读取，不硬编码、不写日志；只在用户主动朗读时外发正文。
- 真机修复内容脚本缺少 `nativeMessagingFromContent`、`geckoViewAddons` 导致“扩展已安装但无法连接”的问题；
  内部主页另走原生 HTML 纯文本兜底。
- 62 W3C 公开页面验证：4022 字/50 段，首 PCM 361ms，预取、高亮、暂停续播、停止和换页停止均通过；
  主页 189 字/6 段，首 PCM 355ms。完整技术说明见 `docs/webpage-read-aloud.md`。
- 改动整理为 `0031-add-webpage-read-aloud.patch`，补丁入口更新为 0001–0020 + 0025–0031。
