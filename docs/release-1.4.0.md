# 双屏浏览器 1.4.0 正式发布

## 发布内容

- 文档阅读格式由 49 种扩展到 133 种；
- Jupyter Notebook 按 Markdown、代码和文本输出分节显示；
- 新增 JSONL/NDJSON、GeoJSON、HAR、FB2、Office/ODF 模板及大量程序语言/DevOps 配置；
- FB2 改为语义段落提取，解决单行 XML 导致 D0 空白；
- ADB 大 APK 真机安装固定使用非流式无损覆盖，规避车机 TCP ADB 掉线。

## 正式产物

- APK：`bin/DualScreenBrowser-v1.4.0-arm64-release.apk`；
- SHA-256：`47beca7bcb1f5868489c0602943e72d76ff192c9d1cb999976291843b8be1b04`；
- sourceCommit：`2993a4471f80d4675428dc83fa60fe3d825e6084`；
- 证书：`CN=KEMI Unified Android Release`；
- 证书 SHA-256：`C3:09:13:B0:C3:5B:84:50:F6:49:61:F5:B3:C7:6C:E8:30:4A:F0:76:0C:59:1E:40:BC:45:82:59:8C:38:8D:04`；
- APK Signature Scheme v2/v3：通过。

## 验收

- 新增格式：84/84，每种连续十页，共 840 个位置、1680 张分析帧；
- 旧格式代表回归：DOCX、EPUB、JSON、MD、MOBI、PDF、TXT、XLSX，8/8 十页通过；
- 正式 APK 抽检：FB2、IPYNB、XLSX，3/3 十页通过；
- 正式抽检性能：FB2 19ms/210350KiB/19 missed，IPYNB 20ms/198961KiB/15 missed，
  XLSX 274ms/198406KiB/11 missed；
- 崩溃/ANR：0；空白、镜像、重复页：0。

完整格式边界见 `docs/document-reader-supported-formats.md`，详细真机证据见
`docs/document-reader-expanded-device-report.md`。

