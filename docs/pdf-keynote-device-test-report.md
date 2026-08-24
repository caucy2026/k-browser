# KEMI S1 Keynote PDF 真机体验报告

日期：2026-08-23

## 测试对象

- 输入：用户提供的 KEMI-S1-KEYNOTE.pptx；
- 视觉 PDF：KEMI-S1-KEYNOTE-visual.pdf；
- PDF：18 页，1600 x 900 pt，7,600,398 bytes，SHA-256
  29d651e614e27741c77103d42af2f41cae2b6468c62cc37022b97cf13ee46b24；
- 生成方式：逐页验证正确的 1600 x 900 PNG 写入 PDF。该文件用于视觉/性能验证，页面版式完整，
  但文本不提供选择；
- 浏览器测试口径：从 ACTION_VIEW 发出到 Display 2 正文出现真实页面像素的时间，不把 PDF.js
  工具栏外壳当作“解码完成”。

## 转换质量

LibreOffice 的直接 PPTX -> PDF 导出在本机丢失大量中文文字，已拒绝作为测试输入。视觉 PDF 逐页
回渲后与原 PPTX 的 18 页渲染图一致；抽检第 2 页保留标题、正文、灰色副标题、橙色强调文字及页码。

## 本机基线（非真机结果）

使用 Poppler 以 144 dpi 渲染图像型 PDF：

| 项目 | 结果 |
| --- | ---: |
| 第 1 页完成 | 2.04 s |
| 18 页全部完成 | 15.40 s |
| 渲染页数 | 18/18 |

这只用于确认 PDF 本身可被正常解码，不能代表 Android 车机或浏览器的首屏体验。

## 已有 PDF 真机链路证据

此前的 12 页文本型 PDF 在 192.168.3.62 完成双屏十页验收：D2/D0 显示同一 PDF 页的相邻内容，
双屏 Surface 从绑定到首个 1920x2560 Gecko 帧约 317 ms。该指标仅代表 PDF.js 外壳和合成帧建立，
不是当前 18 页视觉 PDF 的真实首屏时间。

## 本次真机结论：未执行

2026-08-23 检查 192.168.3.62:5555 与 192.168.3.63:5555：两者均不在 ADB 列表中；显式连接均返回
No route to host。因此本次不能安装浏览器、不能打开该 PDF，也不能给出真机速度或体验通过结论。

设备恢复在线后，执行：

\`\`\`sh
KBROWSER_ONLY_EXT=pdf KBROWSER_RESULTS_TAG=kemi-s1-keynote \
  ./scripts/test-documents-ten-page-device.sh 192.168.3.62:5555 \
  bin/KBrowser-arm64.apk dual
\`\`\`

验收必须包含 pdf-first-raster-ms.txt、D2/D0 首屏截图、页面 1/5/10 截图、九次交替滚动、PSS、
SurfaceFlinger missed-frame 增量、崩溃/ANR 日志和成对退出状态。未生成这些证据前，本报告不得改为
“真机通过”。
