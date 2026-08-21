# 文档阅读真机闭环测试计划

## 1. 测试对象

- 设备：`192.168.3.63:5555`（不抢占主屏的单屏矩阵）和
  `192.168.3.62:5555`（D0/D2 完整双屏矩阵）；
- 屏幕：Display 2 为上页，Display 0 为相邻下页；
- 版本：本次本地正式签名构建；
- 启动方式：文件管理器 `ACTION_VIEW` 与 ADB 等价 Intent；浏览器普通图标仍默认双屏；
- 测试数据：`scripts/generate-document-fixtures.py` 在被忽略的
  `artifacts/document-fixtures/` 中生成无隐私、可重复样例。

ADB 自动化不会伪造文件管理器权限。测试脚本先把样例推到公共 Download，再使用设备 root 只将这些
无隐私样例复制到浏览器私有 cache，并以只读 `file://` Intent 启动；正式用户入口仍是文件管理器授予的
`content://` URI。该做法既覆盖相同解析入口，也不会扩大正式 App 的存储权限。

## 2. 样例规则

每份样例包含：

- `KEMI-DOC-TOP-<FORMAT>` 顶部标记；
- 至少 80 行/足够跨越 1280 px 的正文；
- `KEMI-DOC-SEAM-<FORMAT>` 接缝附近标记；
- 中文、英文、数字、标点、URL 和可复制句子；
- 表格类包含引号、逗号、空单元格和中文；
- 压缩格式包含多个章节/工作表/幻灯片；
- 电子书按 spine 设置与文件名不同的阅读顺序，以验证不是简单文件排序。

## 3. 单格式闭环

1. 清空旧日志并记录基线 PSS；
2. 从 Display 2 发起打开文档，等待页面停止加载；
3. 检查 D2/D0 两个 Activity、分辨率、横屏锁定和非黑屏；
4. 截取两屏，确认顶部/接缝/后续内容属于同一文档且不重复；
5. 从 D2 滚动一次，再从 D0 滚动一次，确认同一页面平滑移动；
6. 选择唯一句子并复制，核对 Android 剪贴板；
7. 在已滚动位置启动朗读，核对起点来自 D2 当前第一条可见文本；
8. 从发起屏返回，确认 D2/D0 同时退出；
9. 记录解析耗时、PSS、`FATAL EXCEPTION`、ANR 和格式化告警。

## 4. 格式矩阵

| 组 | 格式 | 必测点 |
| --- | --- | --- |
| 基础 | TXT、LOG、MD、Markdown | 编码、长行、代码块、朗读 |
| 程序员 | Java、Kotlin、Python、JS/TS、C/C++、Go、Rust、Shell、SQL、GraphQL | 空白保留、复制、横向长行 |
| 配置 | JSON、XML、YAML、TOML、INI、properties、OpenAPI | 格式化、错误输入降级 |
| 表格 | CSV、TSV | 引号换行、粘性表头、行列上限 |
| 网页/PDF | HTML、XHTML、PDF | 离线加载、脚本隔离、PDF 文本选择 |
| Office | DOCX、XLSX、PPTX | 段落/表格、工作表顺序、幻灯片顺序 |
| ODF | ODT、ODS、ODP | `content.xml` 内容顺序 |
| 电子书 | EPUB、RTF、MOBI | spine、Unicode、未加密正文 |
| 图表源 | Mermaid、PlantUML | 源码可读、不访问外部渲染服务 |
| 兼容 | DOC、XLS、PPT | 显示边界提示，不崩溃、不假装完整还原 |

当前生成器共输出 49 个真机样例。程序员文本格式通过扩展名分别测试，不把一个 Kotlin 样例代表所有语言；
PDF 走 Gecko 原生查看器，其余 48 项要求每次清空日志后分别出现与扩展名一致的 `DOCUMENT_READY`。

## 5. 性能门槛

- 1 MiB 纯文本：解析目标 `< 800 ms`；
- 小型 OOXML/EPUB：解析目标 `< 1,500 ms`；
- 文档打开后应用 PSS 增量目标 `< 120 MiB`；
- 连续滚动 10 秒：无 Activity 抖动、无 ANR，SurfaceFlinger missed frame 增量纳入报告；
- 5 次冷启动与 2 次 HOME 后恢复：D2 黑屏次数必须为 0；
- 超限、损坏或加密文件：必须在 2 秒内给出错误页，不崩溃、不无限解压。

## 6. 报告模板

最终报告写入 `docs/document-reader-device63-report.md`（文件名保留首次验收设备编号，正文同时记录 62
完整双屏结果），包含：

- 版本、提交、APK/证书 SHA-256；
- 支持/部分支持/不支持矩阵与准确边界；
- 每项实测结果、耗时、PSS、截图路径和日志摘要；
- 双屏连续、滚动、朗读、复制、退出结论；
- 未通过项、根因、修复提交和复测结果；
- 后续风险，不用“支持全部”掩盖格式或 DRM/OCR 限制。
