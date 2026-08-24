# PDF 渲染复核与性能测试

## 结论

PDF 保留为双屏浏览器支持格式。它不走 DocumentReader 的文本转换，而是直接交给 Gecko 内置
PDF.js/PDF 渲染链路，保留 PDF 的页面画布、矢量、嵌入字体、图片、分页、选择、缩放和原生下载能力。
这与 Word、Excel、PowerPoint 的“仅抽取语义文本”路径不同。

## 已复核的实现

1. DualScreenLaunchActivity 识别 application/pdf 与 .pdf，跳过本地 HTML 转换和 ZIP 解包；
2. PDF 文件 URI 直接交给同一个 GeckoSession，避免复制整份文件、正文抽取和二次编码；
3. 双屏仍是一个 1920x2560 Gecko 合成帧，由 Display 2/Display 0 上下连续裁切，不会创建两份 PDF.js
   页面或进行两套滚动同步；
4. PDF.js 页面由 Gecko 原生渲染；浏览器没有替换解码器，也不注入脚本修改文档；
5. 加密、DRM、恶意 JavaScript、XFA 动态表单和扫描件 OCR 不承诺支持或绕过。

## 真实样例与旧证据

artifacts/document-fixtures/kemi-sample.pdf 是 12 页、未加密的 PDF 1.4 文本型样例。它已在
Display 2/Display 0 的连续十页矩阵中完成页面 1、5、10 截图、双屏交替滚动、成对退出、PSS 与
SurfaceFlinger 漏帧检查。旧日志中从双 Surface 绑定到首个 1920x2560 Gecko 帧为约 317ms；
该数字只是 PDF.js 外壳，不代表第一页已完成光栅化。

## 新的测速口径

旧测试对 PDF 固定等待 4 秒，不能回答“解码有多快”。测试脚本现改为：

1. 从发送 ACTION_VIEW 计时；
2. 等待双屏合成 Surface 首帧；
3. 每 250ms 抓取 Display 2 的正文区域，跳过工具栏；
4. 以正文区域亮度标准差 >= 5 判定首个真实 PDF 页面像素已经出现；
5. 保存 pdf-first-raster-d2.png、pdf-first-raster-ms.txt，10 秒超时即失败；
6. 随后继续既有的十个连续视口、D2/D0 交替滚动、内存、漏帧和同步退出检查。

执行方法：

\`\`\`sh
KBROWSER_ONLY_EXT=pdf KBROWSER_RESULTS_TAG=pdf-review \
  ./scripts/test-documents-ten-page-device.sh 192.168.3.62:5555 \
  bin/KBrowser-arm64.apk dual
\`\`\`

真机当前不在线时不得把旧固定等待时间当作“解码速度”；设备可用后以上结果文件才是正式性能结论。
