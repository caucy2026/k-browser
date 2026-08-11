# Android 多显示浏览器实施与踩坑手册

更新日期：2026-08-11

本文面向需要把一个交互式网页跨两块 Android Display 连续显示的项目。内容来自 KEMI 双屏浏览器在
Android 12 车机、Display 0/2、`1920×1280@60Hz`、Mali-G52 上的实际实现与真机排错。

本文不是通用 Android 多窗口教程。它重点解释哪些方案看似简单却会失败、失败发生在哪一层、如何设计
可闭环的实现和测试。KEMI 当前实现的组件和最终验收见
[`dual-single-screen-architecture.md`](dual-single-screen-architecture.md)。

## 1. 先固定不可变约束

开始编码前必须写清以下参数，不能运行时凭经验猜测：

| 项目 | KEMI 基线 | 可移植项目必须确认的内容 |
| --- | --- | --- |
| Android 逻辑显示 | D0、D2 | Display ID 是否固定、是否连续、是否支持触摸 |
| 单屏尺寸 | `1920×1280` | 真实逻辑尺寸、系统栏、cutout、缩放密度 |
| 页面拼接顺序 | D2 在上，D0 在下 | 物理安装顺序不一定等于 ID 顺序 |
| 连续视口 | `1920×2560` | 接缝方向、固定偏移和浏览器 CSS viewport |
| 刷新率 | 60Hz | 两块面板是否同频、SurfaceFlinger 合成策略 |
| 方向 | 固定横屏 | 系统是否已经补偿外屏 180° 旋转和触摸 |
| GPU | Mali-G52 / GLES 3.2 | External OES、EGL window/pbuffer 支持情况 |

最重要的第一条原则：Display ID 是系统标识，不是数组下标，也不代表物理位置。必须枚举
`DisplayManager.displays` 并按实际 `displayId`、尺寸和产品配置匹配角色。

## 2. 经过验证的核心架构

### 2.1 一个网页实例，而不是两个浏览器互相追踪

KEMI 双屏模式只有一个 `GeckoSession`、一个 DOM、一个 JavaScript 世界和一个页面历史。Gecko 把
`1920×2560` 页面渲染到应用提供的离屏 Surface；应用合成器再把同一张纹理裁成上下两块，分别提交给
D2 和 D0。

这带来几个关键性质：

- URL、Cookie、登录、表单、焦点、媒体、Canvas 和动画天然只有一份。
- 两块屏不会交换 scrollY，也不存在“程序性跟随滚动再次触发回调”的反馈环。
- 任一屏触摸都进入同一个 `PanZoomController`，另一屏只是显示同一新帧的相邻区域。
- 两块输出在取得下一张 Gecko 帧前都使用同一纹理内容，不会出现应用层面的上下半帧版本差异。

注意：同一纹理源保证的是内容帧一致，不等于两个独立面板的扫描线、VSync 相位或物理曝光严格锁相。
如果项目要求跨面板逐扫描线同步，必须由显示控制器、HWC/SurfaceFlinger 或专用硬件链路提供保证，不能
只靠两个 `eglSwapBuffers()` 推断已经实现。

### 2.2 两个真实 Activity 只负责 Android 输出和输入

- D0 `DualScreenBrowserActivity`：共享会话总控和页面下半区输出。
- D2 `DualScreenTopActivity`：页面上半区 Surface、工具栏与副屏输入。
- `DualScreenCoordinator`：唯一会话、Surface 槽位、模式切换和统一退出。
- `DualScreenSharedCompositor`：唯一 EGL 线程和单帧双输出。

交互式副屏不要优先采用 `Presentation`。Presentation 适合被动展示，但浏览器需要独立窗口焦点、软键盘、
返回键、鼠标上下文菜单和可独立接收触摸的生命周期，真实 Activity 更可控。

## 3. EGL/Surface 实现中最容易漏掉的细节

### 3.1 离屏输入 Surface

实现顺序必须稳定：

1. 在专用 `HandlerThread` 初始化 EGLDisplay、EGLConfig 和 GLES2 Context。
2. 创建 1×1 pbuffer，使没有输出窗口时仍可 `eglMakeCurrent`、更新 OES 纹理和管理资源。
3. 创建 `GL_TEXTURE_EXTERNAL_OES` 和 `SurfaceTexture`。
4. 在 Gecko 开始生产前调用 `setDefaultBufferSize(1920, canvasHeight)`。
5. 将 `SurfaceTexture` 包装成 Surface，交给 `GeckoDisplay.surfaceChanged()`。
6. 每个 Activity 的 SurfaceView Surface 分别转成 EGL window surface。

如果没有 pbuffer，某一块输出 Surface 尚未创建或刚销毁时，`updateTexImage()` 和 GL 资源管理可能没有
current context；如果默认 buffer size 设置过晚，生产者可能先按错误尺寸分配缓冲区。

### 3.2 SurfaceTexture 的 Y 方向不是直觉坐标

Android BufferQueue/SurfaceTexture 会提供 producer transform matrix，通常包含 Y 翻转。KEMI 真机上视觉
顶部对应采样坐标 `v=0.5…1.0`，视觉底部对应 `v=0…0.5`。不能只按 OpenGL 纹理坐标直觉写死上下半区。

正确流程是：

- 每帧调用 `getTransformMatrix()`。
- 在 vertex shader 中把裁切坐标乘 producer transform。
- 用带有明显上下文字/色块的测试图确认角色，不能只看两屏“都有画面”。

### 3.3 同一线程依次提交两个输出

一次 `onFrameAvailable` 只执行一次 `updateTexImage()`，随后使用同一纹理先后绘制 TOP、BOTTOM，再等待
下一帧。不要为每块屏各建一个消费线程并分别调用 `updateTexImage()`；那会让两个消费者无法共享同一
SurfaceTexture 状态，且可能各自取得不同生产帧。

### 3.4 Surface 重建与副屏黑屏

`singleTask`/`singleInstance` Activity 可能保留 Java 实例，但 Gecko/EGL 会话已经重建；此时 SurfaceView
未必再次回调 `surfaceCreated()`。如果只在首次创建时绑定 Surface，HOME 恢复或任务复用后副屏会黑屏。

KEMI 的闭环做法：

- `onNewIntent()` 和 `onResume()` 都检查 `holder.surface.isValid` 并重新注册。
- 合成器按 Surface 对象身份判断是否需要重建 EGLSurface。
- 已经收到 Gecko 帧时保留纹理内容；新的输出 Surface 绑定后以 `updateTexture=false` 立即重绘缓存帧。
- Surface 销毁时只释放对应 EGL window surface，不能连带提前销毁共享输入纹理。

### 3.5 释放顺序

关闭会话时先通知 Gecko `surfaceDestroyed()` 并 `releaseDisplay()`，再关闭 GeckoSession，最后在 EGL 线程
销毁两个 window surface、SurfaceTexture、输入 Surface、shader/program、pbuffer、context 和 display。
跨线程直接释放当前仍在使用的 EGL/Surface 对象很容易产生间歇性黑屏或 native 错误。

## 4. Android 多显示任务与启动陷阱

### 4.1 不要从副屏把同一个 launcher 任务直接搬到主屏

旧实现让 LAUNCHER alias 直接指向 D0 总控 Activity。用户在 D2 点击图标后，车机 ROM 先把 task/window
归属绑定到 D2；Activity 随后用 `launchDisplayId=0` 再启动同类总控。系统日志出现“window 在 D0，
但应属于 D2”，然后隐藏两个任务。用户看到的是闪退，但没有 Java `FATAL EXCEPTION`。

可复用解法：

- LAUNCHER 指向不创建重资源的路由 Activity。
- 路由使用独立 task affinity，与浏览器总控任务隔离。
- 若从副屏发起，先 `finishAndRemoveTask()`，让 WindowManager 完全移除副屏路由任务。
- 经过设备实测的短延时后，用 Application Context + `FLAG_ACTIVITY_NEW_TASK` 在目标屏创建总控。
- 总控稳定后再创建另一屏的配对 Activity。

400ms 是当前 KEMI ROM 的实测值，不是 Android API 保证。移植项目必须通过 WindowManager/ActivityTaskManager
日志测量，必要时改为显式状态确认，而不是无条件复制这个数字。

### 4.2 Activity 类和 launchMode

不要指望同一个 `singleInstance` Activity 类同时占据两块屏。KEMI 拆分为 D0 总控类和 D2 顶部类：

- 总控使用 `singleTask`，保证 D0 会话根唯一。
- 顶部显示使用独立类和 `singleInstance`，避免副屏重复实例。
- 单屏使用第三个 Activity 类，留在发起显示，不创建配对 Activity。

不同 ROM 对 task affinity、多显示 task 复用和 multi-resume 的扩展不同。`ActivityOptions.launchDisplayId` 只表达
请求，不代表系统一定允许；必须在 `dumpsys activity activities` 中验证最终 display，而不是只看
`startActivity()` 没抛异常。

### 4.3 内部切屏不能当成用户离开

部分车机 ROM 在总控创建副屏 Activity 时会调用总控的 `onUserLeaveHint()`。如果应用把这个回调无条件解释为
HOME/退出，就会刚创建配对窗口又立即 `exitAll()`。

当前做法是在创建配对 Activity 的短保护窗口内忽略 leave hint，真实返回、工具栏退出和后续 HOME 仍执行
统一退出。更复杂项目可使用显式状态机和启动确认回调，避免长期依赖时间窗口。

### 4.4 单屏和双屏切换必须重建模式相关资源

单屏 compositor 高度为 1280，双屏为 2560；不能把旧 GeckoDisplay/SurfaceTexture 直接拿来换模式。
协调器检测 `singleScreenSession` 变化后应结束旧 Activity、GeckoDisplay、GeckoSession 和 compositor，再按
新尺寸建立会话，否则会出现拉伸、错误裁切、残留副屏或输入坐标错位。

## 5. 输入系统的坑

### 5.1 触摸映射使用逻辑画布，不使用 View 当前高度

D2 触摸坐标保持不变；D0 触摸 Y 固定增加 1280。偏移使用产品定义的逻辑 viewport 高度，而不是
`view.height`、可见窗口高度或系统栏变化后的 app bounds，否则沉浸栏/IME 出现时接缝和点击位置会漂移。

外屏已经由系统做 180° 显示和输入补偿时，应用不能再次旋转触摸坐标。是否需要旋转必须用四角点击测试决定，
不能只根据面板物理安装方向判断。

### 5.2 不要同步 scrollY

双 Session 原型中，两屏都监听滚动并设置对方 scrollY，会形成“用户滚动 → 对方程序滚动 → 回调 → 反向设置”
的反馈链，表现为两屏抖动、相互拉扯和惯性中断。节流、标志位或时间窗只能缓解，无法保证动态页面一致。

单 Session 方案只转发原始触摸/鼠标事件，绝不发送“让另一页面滚到某位置”的命令。

当前 KEMI 验收覆盖“一次只在一块屏完成一个手势”。`@Synchronized` 只能保证事件调用串行，不能保证两个
触摸屏同时按下时的 pointer stream 语义正确。如果产品允许两个人同时操作两块屏，应增加明确的 gesture
owner：第一个 ACTION_DOWN 锁定来源 Activity，直到该来源 ACTION_UP/ACTION_CANCEL 才释放；非 owner 的
事件丢弃或排队。不能把方法级同步误认为已经实现触摸源独占。

### 5.3 SurfaceView 有画面不代表能弹软键盘

普通 SurfaceView 只负责显示与触摸，没有 Android 文本编辑协议。网页输入框收到点击但软键盘不出现时，
根因通常不是网页，而是没有把 Gecko `SessionTextInput` 暴露为当前窗口的 `InputConnection`。

需要：

- 自定义 SurfaceView 返回 `onCheckIsTextEditor=true`。
- `onCreateInputConnection()` 转给共享 GeckoSession 的 `textInput`。
- 触摸 ACTION_DOWN 时把 `textInput.view` 切到实际触摸屏的 SurfaceView，并请求该 Activity 焦点。
- 转发 `onKeyPreIme`、down/up/long/multiple 等硬键事件。
- 用 `dumpsys input_method` 确认 IME client、focused window 和 input target 都属于目标显示 Activity。

跨屏代理输入框很容易导致 IME 挂在错误窗口；应以真正接收输入的 Activity 和该窗口 Insets 为状态真源。

### 5.4 鼠标右键可能被 ROM 改成 Android Back

桌面 Android 和车机输入栈不一定保留 `BUTTON_SECONDARY`。KEMI ROM 会在部分路径把右键转成 Back，因此：

- 标准路径继续把 Gecko context element 映射为链接/文字/媒体菜单。
- 兼容路径只在最近确实收到鼠标事件时，把 Back 解释为右键菜单。
- 普通键盘/系统返回仍必须退出双屏。

一个很隐蔽的实现坑：用 `Long.MIN_VALUE` 表示“从未收到鼠标事件”，直接计算
`uptimeMillis - Long.MIN_VALUE` 会发生 Long 溢出，结果可能被误判为“刚发生鼠标事件”。必须先判断 sentinel
是否已初始化，再计算时间差。

### 5.5 复制选区不能依赖输入框焦点

网页正文选择不等于文本输入连接中的 selection。Android PopupMenu 打开时还会抢焦点，车机右键转 Back
时 Gecko 可能先隐藏视觉选区。可靠做法是：

- 在 Gecko `SelectionActionDelegate` 中缓存最后一次非空正文选区。
- 弹 Android 菜单前，在 Gecko 仍持有焦点时尝试标准 Ctrl+C，并用剪贴板时间戳确认是否真正写入。
- 点击“复制所选内容”时明确调用 `ClipboardManager.setPrimaryClip()`。
- 页面开始跳转或复制完成后清理缓存，不能用旧选区串页。
- 系统剪贴板无非空文本时禁用“粘贴”，复制菜单本身不能因为当前没有输入框而禁用。

## 6. 网页与浏览器行为陷阱

- `target=_blank`/新窗口请求在定制单会话浏览器中若无人接管，会表现为链接点击无响应；当前实现改为在同一
  GeckoSession 导航并拒绝创建第二窗口。
- 地址栏显示为空时，内部值可能仍是 `about:blank` 或 `resource://` 主页；提交前要统一规范化，否则“空地址
  打开默认站点”会再次进入空白页。
- 两屏只能有一份导航历史和加载进度状态；不要让每个 Activity 各自维护 URL 真源。
- 严格跟踪保护能减少广告、跟踪脚本和布局跳动，但可能改变个别网站功能；网站回归需要区分浏览器拦截、网络
  不可达和站点自身未开放功能。

### 6.1 超高 viewport 对网页布局的影响

将 Gecko viewport 高度设为 2560 后，网站看到的是一个高页面视口，而不是两个独立 1280 高窗口。因此：

- `100vh` 弹窗、首屏大图和全屏菜单会按 2560 高度计算，视觉中心可能落在两屏接缝附近。
- `position: fixed` 和 sticky 元素只渲染一份，不会自动在两块物理屏各复制一份。
- D2 工具栏如果覆盖页面而不占用布局高度，会遮住顶部内容；如果让工具栏参与布局，又会改变固定 1280px 接缝。
  项目必须明确选择“覆盖”还是“缩小网页 viewport”，不能两种模型混用。
- Android 像素、density 和 CSS px 不一定 1:1；移植设备必须用网页 `innerWidth/innerHeight/devicePixelRatio`
  实测，不能只根据 Surface buffer 像素推断 CSS viewport。

对于固定导航栏很多的网站，可考虑提供站点级全屏策略或把浏览器 chrome 放到系统层独立 Surface，但不要
通过复制 DOM 来解决固定元素位置问题。

### 6.2 媒体、DRM、HDR 与颜色边界

当前 RGBA8 + External OES 的共享合成路径适合普通网页、Canvas、WebGL 和非保护视频，但其他项目需要单独验证：

- Widevine/受保护视频可能要求 protected Surface，普通 SurfaceTexture/EGL 复制路径可能得到黑帧或被拒绝。
- HDR、广色域、10bit 内容通过 RGBA8 EGLConfig 会降为普通色域/位深。
- 视频 overlay/HWC 直出可能因为离屏 SurfaceTexture 被迫转为 GPU 合成，增加功耗和带宽。
- `1920×2560×4` 单帧约 18.75MiB；考虑 BufferQueue、纹理、双输出和浏览器内部缓冲后，实际显存占用是其
  数倍。更高分辨率或 120Hz 设备必须重新评估 GPU fill-rate、内存带宽和温升。

## 7. 生命周期状态机建议

至少应显式覆盖以下事件：

| 事件 | 必须保证 |
| --- | --- |
| D0/D2 冷启动 | 最终 Activity 角色与 displayId 正确，只创建一个网页会话 |
| 第二块 Surface 晚到 | 先清白屏，首帧到达后两块输出使用同一缓存帧 |
| SurfaceView 重建 | 旧 EGLSurface 释放，新 Surface 重新绑定，不关闭共享会话 |
| HOME 后恢复 | retained Activity 主动重新注册有效 Surface |
| 任一屏返回/退出 | 原子结束共享会话和两 Activity，不留黑屏/孤儿任务 |
| 内部创建配对屏 | 不触发用户离开逻辑 |
| 单屏↔双屏 | 关闭旧尺寸 Gecko/EGL 资源，再创建新模式会话 |
| 页面新窗口 | 收敛到同一会话或显式实现统一标签模型 |
| 显示断开 | 降级单屏或整体退出，策略必须明确 |

KEMI 当前验收范围是固定连接的 D0/D2 车机。运行中热插拔 Display、不同分辨率组合、折叠屏动态尺寸和多于
两块输出尚未作为正式承诺。复用项目若需要这些场景，应增加 `DisplayManager.DisplayListener`、动态角色重算和
compositor 尺寸重建，不应直接沿用固定常量。

同样尚未作为正式承诺的边界包括：两块屏同时多点触摸、受保护 DRM 视频、HDR/广色域、无障碍跨屏焦点、
多标签同时可见、页面缩放后接缝精度以及面板级 VSync/扫描线锁相。它们需要独立设计和验收，不能由当前
“同一 Gecko 源帧”结论自动推出。

## 8. 测试中最容易出现的假通过

### 8.1 没有 FATAL 不代表没有失败

跨屏启动旧故障没有 `FATAL EXCEPTION`，真正证据在 ActivityTaskManager/WindowManager 的 task、window、
display 归属日志。验收至少同时检查：

- `dumpsys activity activities` 的 D0/D2 resumed Activity。
- `KBrowserLaunch` 路由日志。
- `KBrowserCompositor` TOP/BOTTOM 绑定和首帧尺寸。
- `FATAL EXCEPTION`、native/EGL 错误以及 WindowManager display mismatch。

### 8.2 两屏都有画面不代表连续拼接

可能是系统镜像、两个独立页面、同一页面重复顶部或裁切上下颠倒。需要一张带固定坐标/段落标记的长页面，确认：

- D2 是 `0…1279`，D0 是紧接的 `1280…2559`。
- 接缝处不存在重复或缺段。
- 两屏 Activity 不同，但 compositor 首帧只有一张 `1920×2560`。

截图哈希变化只能证明画面变了，不能单独证明接缝连续；应结合可识别内容、像素接缝或页面坐标标记。

### 8.3 只用组件名启动不能替代桌面入口

必须测试真实 LAUNCHER alias，因为副屏闪退正是 launcher task affinity 才触发的问题。建议矩阵：

1. D0 普通图标启动双屏。
2. D2 普通图标启动双屏。
3. D0 长按快捷入口启动单屏。
4. D2 长按快捷入口启动单屏。

ADB `am start --display` 适合精确复现，但最终仍要用真实启动器点击确认 OEM 行为一致。

### 8.4 测试输入会互相干扰

远程控制侧栏、系统手势监控、用户触摸和其他测试 App 都可能抢占输入。日志出现
`Monitor swipe-up ... stealing touch` 时，该轮 Activity 退出不能直接归咎于浏览器；必须清理干扰后重测。
被其他 App 覆盖的截图也必须作废。

### 8.5 逻辑显示 ID、物理输出 ID、LayerStack 不能混用

Activity 启动和 `dumpsys activity` 使用 Android 逻辑 Display ID；SurfaceFlinger、录屏工具或厂商接口可能使用
物理显示 ID/LayerStack。KEMI 设备的逻辑 D0/D2 与物理 0/1 不同。任何自动化脚本都要先打印映射并注明参数
属于哪套命名空间，不能因为某条命令接受数字 2 就推断它一定代表物理输出 2。

## 9. 推荐的最小闭环矩阵

每次涉及 Activity、Surface、输入或生命周期的改动，至少运行：

| 类别 | 最小场景 | 通过证据 |
| --- | --- | --- |
| 构建 | 本地正式/候选构建 | Gradle、R8、资源、v2/v3 签名通过 |
| 冷启动 | D0、D2 各启动双屏 | D0 总控、D2 顶部、单张 2560 首帧 |
| 单屏 | D0、D2 各启动 | 只占当前屏、单张 1280 首帧 |
| 恢复 | 至少两轮 HOME→重启 | 无黑屏，Surface 重绑定或缓存帧日志正确 |
| 页面 | 坐标长页/W3C | 初始接缝不重复、不缺段 |
| 滚动 | D2、D0 各 swipe | 两屏都更新、无反馈抖动、Activity 不分叉 |
| 输入 | 两屏网页输入框 | 软键盘属于目标窗口并实际输入 |
| 鼠标 | 左键选择→右键复制 | 正文进入系统剪贴板，普通返回不被劫持 |
| 导航 | `target=_blank` 站内链接 | URL 和内容变化但仍是同一共享会话 |
| 退出 | D0/D2 返回、退出、HOME | 两屏 Activity 同时消失，无残留 Surface |

性能测试不必一开始做重型 WPT。先记录滚动期间 SurfaceFlinger missed frame 增量、两屏视频、Activity 状态和
崩溃/EGL 日志；核心稳定后再扩展复杂网站和长时间压力测试。

## 10. 代码与补丁定位

| 关注点 | 当前代码/补丁 |
| --- | --- |
| Activity、输入、会话、统一退出 | `DualScreenBrowserActivity.kt` |
| EGL 单帧双输出 | `DualScreenSharedCompositor.kt` |
| 从任意显示安全启动 | `DualScreenLaunchActivity.kt`、补丁 0030 |
| Surface 恢复黑屏 | 补丁 0010 |
| 单屏快捷模式 | 补丁 0012、0025 |
| 新窗口链接 | 补丁 0013 |
| 双屏退出 | 补丁 0014、0030 |
| Gecko 输入法桥接 | 补丁 0016 |
| 鼠标与复制粘贴 | 补丁 0017–0020、0025 |
| 固定方向与选区 | 补丁 0019 |

## 11. 给其他项目的最终决策建议

1. 如果两屏只是展示不同内容，用两个普通 Activity 即可，不要引入共享 compositor。
2. 如果要求同一动态网页连续跨屏，优先一个网页实例 + 一个离屏生产 Surface + 多输出裁切。
3. 如果要求交互和软键盘，两块屏都使用真实 Activity，不要把 Presentation 当完整浏览窗口。
4. 把显示角色、任务路由、页面会话和 EGL 输出拆成四层，避免一个 Activity 同时承担所有职责。
5. OEM 多显示行为必须以真机 WindowManager/ActivityTaskManager 证据为准；AOSP 文档和模拟器成功不等于车机成功。
6. 明确产品边界：应用能保证同源内容帧和交互一致，但不能自动承诺两块独立面板的硬件扫描严格同步。
7. 把失败方案、设备特定参数和验收证据一起版本化；只保存最终代码，会让后续项目重复踩同样的坑。

## 12. Review 后的复用优先级

### P0：已验证，可作为当前项目基线

- 单 GeckoSession + 单 `1920×2560` 内容源 + 单 EGL 线程双裁切输出。
- D2/D0 的固定逻辑坐标映射、单屏/双屏资源隔离、任意屏统一退出。
- Surface 重绑定与缓存帧恢复，以及从 D0/D2 真实桌面入口路由到正确任务。
- 输入法绑定到实际触摸窗口，右键/Back 区分和系统剪贴板写入。

### P1：其他项目若放大使用范围，应先补齐

- 增加跨 Activity gesture-owner 状态机，再宣称支持两人同时操作两块触摸屏。
- 用显式路由状态/窗口移除确认取代设备特定的 400ms 经验延时。
- 监听 `DisplayManager.DisplayListener`，对热插拔、分辨率变更和显示角色重算制定明确降级策略。
- 增加可识别坐标的本地接缝测试页和像素级自动检查，减少截图肉眼误判。

### P2：需要独立架构和验收，不应从当前方案外推

- DRM/受保护视频、HDR/广色域/10-bit、无障碍跨屏焦点和多标签同时可见。
- 页面缩放后的像素级接缝、不同刷新率面板和面板级 VSync/扫描线锁相。
- GPU 带宽、BufferQueue 实际缓冲数和 HWC overlay 丢失所带来的长时性能与功耗问题。
