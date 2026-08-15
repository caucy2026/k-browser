# KBrowser 网页语音播报设计与闭环

## 1. 用户体验

- 双屏模式只在 Display 2 顶部工具栏显示朗读入口；Display 0 不增加重复工具栏。
- 单屏模式复用同一入口、主页和朗读状态机。
- 点击“朗读”后从 D2 工具栏下方实际显示的第一行、第一字开始；即使该行属于一个上半部已滚出屏幕的长段落，也不会回读隐藏内容或从页面顶部重读。
- 工具栏依次显示“朗读 / 准备 / 暂停 / 继续”，右上浮层显示当前段进度和独立“停止”。
- 当前语义块使用浅蓝背景和蓝色左边线标记；离开可视区时平滑滚到屏幕中部。
- 页面跳转、主页、返回、退出、配对 Activity 关闭或 GeckoSession 销毁都会立即停止语音并清除高亮。

## 2. 组件关系

| 组件 | 职责 |
| --- | --- |
| `BrowserTtsBridge` | 安装内置 GeckoView WebExtension，并验证消息来自当前共享 GeckoSession |
| `content.js` | 收集可见的标题、段落、列表、表格等语义块，返回正文并定位当前段 |
| `BrowserReadAloudController` | 维护提取、播放、暂停、续播、停止、预取和 UI 状态 |
| `SpeechTextSegmenter` | 首段短切、自然标点切分和超长硬切保护 |
| `IflytekTtsEngine` | 系统参数读取、设备鉴权、AIUI WebSocket、PCM 播放和下一段合成 |
| Android `TextToSpeech` | 讯飞参数缺失或云端错误时的本地系统降级 |

控制器属于 `DualScreenCoordinator`，与唯一共享 GeckoSession 同生命周期。D0 与 D2 两个 Activity 不分别
创建播放器，因此不会重复发声、双向反馈或在一屏退出后留下后台音频。

## 3. 正文提取与跟随

内置扩展位于 `app/src/main/assets/kbrowser_tts/`。它仅收集可见且有尺寸的语义元素：
`h1–h6`、`p`、`li`、`blockquote`、`pre`、`td/th`、`figcaption`、`article/main`。
脚本过滤隐藏元素、脚本、样式和模板，合并空白并去重。起读时先找到 D2 工具栏下方第一个相交语义块，
再通过 DOM `Range.getClientRects()` 逐字符确定第一条真正可见的文本行，从该行首字建立提取锚点，最多返回
500,000 字符。这样不会把“段落可见”等同于“段首可见”。

朗读跟随同样使用字符到 DOM Range 的映射，而不是只把整段元素滚到屏幕中间。控制器每开始一段语音，
内容脚本会定位该段首字符的实际行框；行框接近屏幕底部时平滑滚动到 D2 可读区域。脚本保存首行锚点、
当前块和字符游标，重复短语不会使页面回跳，暂停后重读当前段也保持原位置。

GeckoView 内容脚本向原生应用通信必须同时声明：

- `nativeMessaging`
- `nativeMessagingFromContent`
- `geckoViewAddons`

只声明 `nativeMessaging` 时，扩展会显示安装成功，但 `runtime.connectNative()` 不会建立内容连接；这是首轮
真机发现的关键问题。内部 `resource://android/assets/dual_screen_home.html` 不属于普通网页匹配范围，且 Gecko
页面提取器对该内部资源返回 `UNKNOWN_ERROR`，因此主页由原生代码读取同一 HTML、移除脚本/样式并转为纯文本。

## 4. 分段、预取和播放

- 第一请求优先在自然分句处控制在约 64 字以内，降低首次出声等待。
- 后续按中文/英文句号、问号、感叹号、分号、换行等自然边界切分。
- 极端长段使用 800 字硬保护，防止单次网络请求和内存不可控。
- 播放当前段时用第二个引擎只预取下一段；当前段完成后直接播放缓存，再预取后续一段。
- AIUI 返回 16kHz、单声道、16-bit raw PCM，通过 `AudioTrack.MODE_STREAM` 播放。
- 目标固件在短流欠载后可能冻结或复位 `playbackHeadPosition`，所以完成判定使用已提交 PCM 的固定时长，
  不等待播放头达到样本总数。

## 5. 状态机与并发保护

状态只有 `IDLE / LOADING / SPEAKING / PAUSED`：

- `IDLE -> LOADING`：请求当前页面正文，8 秒超时。
- `LOADING -> SPEAKING`：清洗正文、分段并播放首段。
- `SPEAKING -> PAUSED`：停止当前 AudioTrack、WebSocket 和预取，保留当前段索引。
- `PAUSED -> SPEAKING`：重新合成并从当前段开头继续。目标固件的 `pause()/play()` 可能返回成功却静音，
  因此不使用原流假恢复。
- 任意状态 `-> IDLE`：用户停止、换页、退出或错误。

每次开始、暂停、继续和停止都会推进 generation。网络回调、预取结果、本地 TTS 回调和定时任务都必须匹配
当前 generation；旧代回调直接丢弃，保证停止后不会因迟到 PCM 再次发声。

## 6. 凭据和数据边界

- 只读取系统预置 `Settings.Global["iflytek_params"]`，代码、APK、日志和 Git 都不保存 token、app id、
  api key、MAC 或完整鉴权 URL。
- 日志只记录字符数、段号、耗时、PCM 字节/样本数和匿名错误，不记录正文或凭据。
- 网页正文只有用户主动点击“朗读”才会送往讯飞服务；本次自动测试只使用公开 W3C 页面。
- 系统参数缺失或云端失败时切换 Android `TextToSpeech`；若系统也没有可用引擎，则在界面明确提示。

实现参考 KEMI RD 的
[`android-document-tts-closed-loop-guide.md`](https://github.com/caucy2026/kemi-rd/blob/main/md/android-document-tts-closed-loop-guide.md)，
并复用其中已在同类硬件验证的讯飞鉴权、PCM 时长完成判定和暂停重建策略。

## 7. 日志协议

关键日志标签是 `KBrowserTts` 和 `KBrowserIflytekTts`：

- `TTS_CONTENT_EXTENSION_READY / TTS_CONTENT_BRIDGE_CONNECTED`
- `TTS_EXTRACT_REQUEST / TTS_PAGE_TEXT / TTS_SEGMENTS`
- `TTS_CHUNK_START / TTS_CHUNK_DONE`
- `TTS_PREFETCH_SUBMITTED / READY / PLAY`
- `First PCM queued in ... ms / PCM playback complete`
- `TTS_PAUSE / TTS_RESUME_RESTART_CHUNK / TTS_STOP / TTS_ERROR`

日志闭环必须同时看到正文、分段、首 PCM 和完成/停止，不能只凭界面按钮变化判定成功。

## 8. 2026-08-15 真机结果

设备：`192.168.3.62:5555`，Android 12，Display 0/2 均为 `1920×1280@60Hz`。

| 检查项 | 结果 |
| --- | --- |
| 桌面冷启动 | D0=`DualScreenBrowserActivity`，D2=`DualScreenTopActivity` |
| W3C 正文 | 4022 字，50 段；首段 26 字，最长段 351 字 |
| 首 PCM | 361ms；后续一次暂停续播重建为 249ms |
| 下一段预取 | 当前段播放时 READY，段完成后直接 PREFETCH_PLAY |
| 高亮跟随 | 当前段浅蓝高亮、蓝色左边线，页面自动跟随 |
| 暂停/继续 | 暂停在第 7 段；继续从第 7 段重建，无静音假恢复 |
| 手动停止 | generation 失效，停止后没有迟到段落继续播放 |
| 换页停止 | 主页导航触发 `TTS_STOP reason=page-start` |
| 内部主页 | 原生兜底提取 189 字、6 段，首 PCM 355ms |
| 稳定性 | 构建/Lint 通过，APK v2/v3 验签通过，无浏览器 `FATAL EXCEPTION` |

### 8.1 D2 首行起读回归

`1.2.2-rc2` 增加精确行框锚点后，本地完整发布构建通过。使用与 Gecko 内容脚本一致的 DOM Range
回归页，将段落第一行放在 D2 工具栏遮挡区、第二行放在首个可见位置、第三行放在屏幕底部：源码脚本与
APK 内实际打包脚本均只返回“D2第一行 D2第二行”，并在第三行开始朗读时产生平滑向下滚动请求。

正式 APK 已覆盖安装到 `192.168.3.63:5555` 并确认 `versionName=1.2.2-rc2`。安装时设备两屏均有
其他测试应用，未抢占前台；因此该轮只记录安装和可重复行框测试，不把未执行的真机声音对照写成通过。

## 9. 后续复测清单

1. 从桌面图标启动，确认双屏拼接仍是一个 `1920×2560` 页面。
2. 在公开长页面滚到一个长段落中部，让段首滚出 D2，再点“朗读”；对照 D2 第一条可见文字，确认首段从该行首字开始。
3. 保持朗读直到当前屏末尾，确认内容按朗读行平滑上移，下一行自动进入可读区域且不回跳。
4. 连续执行朗读、暂停、继续、停止，检查状态和日志一致。
5. 朗读中点击链接、主页、返回和退出，确认立即停声且双屏生命周期仍联动。
6. 断网或清除测试机系统语音参数时，只验证明确降级/报错；禁止在代码中补写任何凭据。
