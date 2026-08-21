# 双屏浏览器 1.3.0 文档阅读真机报告

测试日期：2026-08-22

设备：`192.168.3.63:5555`（单屏矩阵）与 `192.168.3.62:5555`（完整双屏），Android 12 / arm64 / Mali-G52

单屏：`1920×1280@60Hz`；双屏目标画布：`1920×2560@60Hz`

## 1. 当前结论

- 本地正式签名 APK 已构建成功，SHA-256 为
  `c77706a256deaf0bacee607b31f15d96c36652b9aef0569752b355e7fef4c7c3`，构建清单源码提交为
  `1339471a438ed28d75e71187c13a720fb0d19d0f`。
- 49 个格式样例在 Display 2 单屏诊断模式全部打开；48 个离线转换格式逐项产生独立
  `DOCUMENT_READY` 和 `DOCUMENT_LOADED loopback=true`，PDF 由 Gecko 原生查看器实际显示。
- 48 个转换样例解析耗时：最小 6ms、中位数 9ms、平均 15.3ms、最大 86ms（XLSX），均明显低于规范门槛。
- Markdown 实测可以滚动，滚动前后截图 SHA-256 不同；朗读从当前页面提取 6158 字，按标点切为
  302 段并启动第一段，下一段预取成功。
- 最终样例运行时总 PSS 为 196531KiB；Markdown + 朗读场景为 196831KiB。相对此前干净单屏主页
  177871KiB 的增量分别约 18.2MiB 和 18.5MiB，低于 120MiB 门槛。
- 49 项测试未发现浏览器 `FATAL EXCEPTION`、ANR、`parse failed` 或 `read failed`。
- 测试期间 Display 0 的 NativeGPU 始终保持前台，单屏诊断没有抢占或停止其他项目。
- 最终正式包在 62 完成 49 格式双屏矩阵：48 个转换格式全部加载，PDF 原生显示；解析最小 5ms、
  中位数 7ms、平均 13.9ms、最大 75ms，总 PSS 212090KiB。
- 双屏为同一 `1920×2560` Gecko 帧的连续裁切：D2 滚动后显示 YML 第 3–19 行，D0 紧接第 20–38 行；
  D0 再滚动后 D2 显示第 18–33 行，D0 紧接第 34–52 行，四张截图哈希均不同，没有镜像或双页面抖动。
- Markdown 冷启动日志同时出现 `Bound TOP output`、`Bound BOTTOM output` 和
  `Received first 1920x2560 Gecko frame`；朗读切分 308 段并连续播放/预取。从 D2 退出后 D0/D2
  两个浏览器 Activity 均消失。单双屏文档闭环验收通过。

## 2. 格式结果

| 分组 | 真机通过格式 | 结果与边界 |
| --- | --- | --- |
| 基础文本 | TXT、LOG、MD、Markdown | 结构化排版、滚动、复制基础与朗读链路可用 |
| 源码 | Java、Kotlin、Kotlin Script、C/H、C++/HPP、Go、Rust、Python、JS/JSX、TS/TSX、CSS/SCSS、Shell、SQL、GraphQL | 等宽显示并保留空白；每个扩展名独立启动验证 |
| 配置 | JSON、XML、YAML/YML、TOML、INI、properties | JSON 美化；其余安全文本/结构阅读 |
| 表格文本 | CSV、TSV | 表格生成成功；行列有安全上限 |
| 网页 | HTML、XHTML | 本地脚本被清理，不执行样例中的不可信脚本 |
| 现代 Office | DOCX、XLSX、PPTX | 正文、工作表与幻灯片文字提取成功；XLSX 最慢 86ms |
| ODF | ODT、ODS、ODP | `content.xml` 离线提取成功 |
| 电子书 | EPUB、RTF、MOBI | EPUB 按 spine，RTF Unicode，未加密 PalmDOC/MOBI 成功 |
| 图表源码 | Mermaid、PlantUML | 源码可读、可复制/朗读；不访问在线渲染服务 |
| 旧 Office | DOC、XLS、PPT | 可打印字符串兼容阅读通过；不承诺复杂二进制版式、宏和公式 |
| PDF | PDF | Gecko 原生查看器实际显示；扫描 PDF 不承诺 OCR |

逐项解析耗时（ms）：

```text
c 9, cpp 7, css 7, csv 19, doc 35, docx 20, epub 12, go 7,
graphql 8, h 10, hpp 16, html 7, ini 8, java 7, js 7, json 8,
jsx 7, kt 6, kts 8, log 10, markdown 48, md 60, mmd 15, mobi 10,
odp 12, ods 13, odt 11, ppt 47, pptx 15, properties 9, puml 8,
py 11, rs 10, rtf 20, scss 8, sh 7, sql 7, toml 10, ts 9,
tsv 8, tsx 7, txt 18, xhtml 8, xls 34, xlsx 86, xml 7,
yaml 11, yml 6; PDF 使用原生查看器，不经过转换计时。
```

## 3. 性能和硬件优化

1. Office/ODF/EPUB 解包与格式转换放在后台线程，不阻塞 Activity 主线程。
2. 输入限制为 32MiB，ZIP 限制 2048 个条目、单条目 16MiB、累计 64MiB，防止车机内存峰值和 ZIP bomb。
3. 输出最多 500000 可读字符/16MiB HTML；表格限制 5000 行、128 列。
4. PalmDOC/MOBI 使用固定 2MiB 增量输出缓冲处理重叠回溯，时间复杂度为 O(n)，不再为每个回溯重建
   已输出内容；既保留约 500000 字符阅读上限，也限制极端电子书的临时内存。
5. 解析结果只进入应用私有 cache，并由仅绑定 `127.0.0.1` 的只读服务供 Gecko 访问；不上传、不列目录、
   不接受写入。普通 HTTP origin 保留了现有朗读扩展的可见首行、逐段高亮和自动滚动能力。
6. 双屏仍复用一个 GeckoSession、一个 DOM 和一个 `1920×2560` 合成帧，不创建两个文档页面互相同步，
   避免反馈抖动和双倍页面脚本开销。
7. 正式构建启用 arm64 Release、R8 与资源优化，APK v2/v3 签名均通过。

## 4. 真机证据

证据保存在不提交 Git 的 `artifacts/document-reader-device63-single/`：

- `pdf-display2.png`：Gecko PDF 真机显示；
- `md-before-scroll.png` / `md-after-scroll.png`：实际滚动前后；
- `md-tts.log`：朗读扩展、正文提取、302 段切分和预取；
- `md-activities.txt`：D2 `SingleScreenBrowserActivity` 与 D0 原 NativeGPU 同时存在；
- `meminfo.txt` / `md-meminfo.txt`：PSS；
- 49 份 `*-document.log`：逐项隔离后的解析/加载结果；
- `logcat.txt`：崩溃与 ANR 检查。

62 完整双屏证据保存在 `artifacts/document-reader-device62-dual/`：

- 49 份 `*-document.log`：48 个转换格式 `DOCUMENT_READY`，PDF 走 Gecko 原生查看器；
- `display2-after-d2-scroll.png` / `display0-after-d2-scroll.png`：D2 操作后第 3–19 / 20–38 行连续；
- `display2-after-d0-scroll.png` / `display0-after-d0-scroll.png`：D0 操作后第 18–33 / 34–52 行连续；
- `md-initial-display2.png` / `md-initial-display0.png`：Markdown 顶部与其下一段相邻画面；
- `md-compositor-tts.log`：两块 Surface 绑定、`1920×2560` 首帧及 308 段朗读；
- `md-dual-activities.txt` / `md-after-exit-activities.txt`：D2/D0 配对运行及统一退出；
- `meminfo.txt`、`logcat.txt`：PSS、崩溃与 ANR 检查。

另做了两个预期失败边界样例：100 字节损坏 DOCX 返回错误页并记录 `EOFException`，33MiB TXT 返回
32MiB 上限错误页；两者均未崩溃、未 ANR。负向样例日志中的 `parse/read failed` 是设计内错误页证据，
不计入上述 49 个有效格式样例。最终正式包已忽略客户端提前关闭连接产生的预期 Socket 异常日志。

## 5. 自动复测

```sh
python3 scripts/generate-document-fixtures.py
bash scripts/test-documents-device.sh \
  192.168.3.63:5555 \
  bin/DualScreenBrowser-v1.3.0-arm64-release.apk single

# 只有 D0/D2 同时空闲时执行，脚本发现其他前台应用会立即拒绝抢占：
bash scripts/test-documents-device.sh \
  192.168.3.63:5555 \
  bin/DualScreenBrowser-v1.3.0-arm64-release.apk dual

# 中途因 ADB/logd 抖动需要续测时，从指定扩展名继续：
KBROWSER_FROM_EXT=tsv bash scripts/test-documents-device.sh \
  192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.0-arm64-release.apk dual
```

## 6. 准确的“不支持”范围

- 不绕过 DRM 或加密 Office；
- 扫描 PDF 不做 OCR；
- Mermaid/PlantUML 只安全阅读源码，不联网渲染；
- DOC/XLS/PPT 是兼容正文提取，不是完整旧 Office 排版引擎；
- 不执行 Office 宏、ActiveX、EPUB/本地 HTML 中的不可信脚本。
