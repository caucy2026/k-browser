# KEMI 双屏浏览器文档格式清单（1.4.0）

## 结论

当前明确支持并有连续十页真机证据的扩展名共 **133 种**。这里的“支持”不是仅注册扩展名：文件必须
能离线打开，D2/D0 必须显示同一 `1920×2560` 文档的相邻区域，两屏都能发起滚动，并在十个滚动
位置保持非空白、非镜像、画面唯一且无崩溃。

## 已支持格式

### 文本、标记和技术写作

`txt`, `log`, `md`, `markdown`, `rst`, `adoc`, `asciidoc`, `org`, `tex`, `bib`, `html`, `htm`,
`xhtml`, `rtf`, `mmd`, `mermaid`, `puml`, `plantuml`。

Markdown 会保留标题、列表、代码块和常用行内强调；Jupyter Notebook 会按 Markdown、代码、文本输出
分节显示；RST、AsciiDoc、Org、LaTeX、BibTeX 与图表语言采用安全源码阅读，不调用在线渲染服务。

### 程序语言和前端源码

`c`, `h`, `cc`, `cpp`, `hpp`, `java`, `kt`, `kts`, `cs`, `go`, `rs`, `py`, `js`, `jsx`, `ts`,
`tsx`, `swift`, `dart`, `rb`, `php`, `scala`, `groovy`, `lua`, `r`, `clj`, `cljs`, `ex`, `exs`,
`erl`, `hrl`, `fs`, `fsx`, `vb`, `asm`, `s`, `vue`, `svelte`, `css`, `scss`, `less`, `sh`,
`bash`, `zsh`, `bat`, `cmd`, `ps1`, `sql`, `graphql`, `gql`, `proto`。

源码使用等宽字体、保留空格和换行，支持选择、复制及从 D2 当前首行开始朗读；浏览器不会编译或执行
源码。

### 配置、构建、接口和数据交换

`json`, `jsonl`, `ndjson`, `geojson`, `har`, `ipynb`, `xml`, `svg`, `plist`, `yaml`, `yml`,
`toml`, `ini`, `conf`, `cfg`, `properties`, `gradle`, `dockerfile`, `makefile`, `cmake`, `mk`,
`tf`, `tfvars`, `hcl`, `env`, `editorconfig`, `gitignore`, `npmrc`, `lock`, `diff`, `patch`, `http`,
`pem`, `crt`, `ics`, `vcf`, `csv`, `tsv`。

JSON/GeoJSON/HAR 会格式化；JSONL/NDJSON 保持逐行结构；CSV/TSV 生成带粘性表头的表格；PEM/CRT
指文本编码内容，二进制 DER 证书不在此承诺内。无扩展名的 `Dockerfile`、`Makefile`、`GNUmakefile`、
`CMakeLists.txt`、`Gemfile`、`Rakefile`、`Podfile` 也会按文件名识别。

### Office、开放文档和模板

`doc`, `docx`, `docm`, `dotx`, `dotm`, `xls`, `xlsx`, `xlsm`, `xltx`, `xltm`, `ppt`, `pptx`,
`pptm`, `potx`, `potm`, `odt`, `ods`, `odp`, `ott`, `ots`, `otp`。

OOXML/ODF 在本机离线提取正文、单元格和幻灯片文字。宏启用格式只读正文，VBA、ActiveX 和嵌入式
可执行对象永远不执行。`doc/xls/ppt` 是旧 OLE 文档的可打印正文兼容视图，不承诺复杂版式还原。

### 电子书和固定版面

`pdf`, `epub`, `mobi`, `azw`, `azw3`, `fb2`。

EPUB 按 spine 顺序合并章节；FB2 按标题和正文段落提取；MOBI/AZW/AZW3 支持未加密 PalmDOC/MOBI
正文；PDF 使用 Gecko PDF 查看能力。扫描 PDF 不提供 OCR，加密或 DRM 内容不会绕过保护。

## 明确未支持

以下格式仍不标记为支持：

- 专有 Office/工程容器：OneNote `one`、Visio `vsd/vsdx`、Publisher `pub`、Project `mpp`、
  WPS `wps/et/dps`、HWP `hwp/hwpx`、Apple iWork `pages/numbers/key`；
- 固定版面和帮助系统：`chm`, `djvu/djv`, `xps/oxps`；
- 图像漫画和压缩容器：`cbz`, `cbr`，以及把 `zip/rar/7z` 当文档直接阅读；
- CAD/设计文件：`dwg`, `dxf`, `psd`, `ai`, `sketch`, `fig`；
- 二进制构建产物：`class`, `dex`, `wasm`, `so`, `dll`, `exe`, `core`, `apk`, `ipa`；
- 任何带密码的 Office/PDF、DRM 电子书、扫描件 OCR、Office 宏和 ActiveX。

原因是这些格式需要专用排版/图形内核、授权解码器、可靠离线 OCR 或存在执行风险。当前版本会给出
可理解的“不支持/无法读取”提示，不以乱码、空白页或调用第三方上传服务伪装兼容。

## 证据入口

- 原 49 种报告：`docs/document-reader-ten-page-device-report.md`；
- 新增 84 种报告：`docs/document-reader-expanded-device-report.md`；
- 测试规范：`docs/document-reader-ten-page-test-plan.md`；
- 原始新增矩阵：`artifacts/document-reader-ten-page-device62-dual-expanded-133/ten-page-results.csv`。

