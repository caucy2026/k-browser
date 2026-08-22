# KEMI 文档阅读连续十页真机闭环规范

## 1. 验收目标

原有“成功解析并显示首屏”只能证明格式入口可用，不能证明长文档适合车机阅读。本规范要求列表内每个
扩展名都在真实双屏设备完成十个连续视口，任何格式未完成前不得发布“全部通过”结论。

测试设备优先使用 `192.168.3.62:5555` 或 `192.168.3.63:5555`。脚本同时检查两块屏幕的前台应用；
发现 KOffice、NativeGPU、游戏或其他测试程序时立即退出，不抢占、不 `force-stop` 其他项目。

若只有 D0 被其他项目占用而 D2 明确停在 Secondary Launcher，可先以 `single` 模式在 D2 完成 49 格式
十页筛查，禁止发送全局 HOME 或停止 D0 应用。单屏每格式结束只停止浏览器自身以隔离样例，不用受
Display 2 旋转/全局鼠标影响的 ADB 坐标冒充人工退出；最终“完整通过”仍必须补做 D0/D2 同时空闲的
`dual` 矩阵及真实 D2 系统返回。

## 2. 测试规模

- 49 个独立扩展名样例；
- 每个格式 10 个连续页面位置；
- 每页同时抓取 D2 与 D0，因此完整矩阵分析 980 张真机帧；
- 保存每个格式第 1、5、10 页两屏截图，其余帧分析后只保留量化指纹，控制证据体积；
- 第 1、3、5、7、9 页后的手势来自 D2，第 2、4、6、8 页后的手势来自 D0，覆盖两屏输入源。

样例统一保留至少 12 页余量：文本类为 420 行；PPTX 为 24 张、每张 12 段；PDF 为 12 个真实 PDF
Page 对象；EPUB 两章合计 420 行。不能用滚到底后重复截图冒充十页。

## 3. 每格式通过条件

1. `ACTION_VIEW` 识别正确，D2 为 `DualScreenTopActivity`，D0 为
   `DualScreenBrowserActivity`；
2. 非 PDF 格式必须出现对应 `DOCUMENT_READY` 和私有回环页 `DOCUMENT_LOADED`；PDF 必须走 Gecko
   原生查看器；
3. 解析耗时 `< 1500ms`；
4. 十组 D2/D0 内容区域感知指纹全部不同，证明每次滚动确实进入新内容；
5. 同一页 D2 与 D0 指纹不同，禁止镜像；
6. 两屏正文区域亮度标准差均 `>= 5`，拒绝黑屏、纯白屏和仅有工具栏的空页面；
7. 十页后总 PSS `< 300000KiB`，并记录 SurfaceFlinger Total/HWC/GPU missed-frame 增量；
8. 无浏览器 `FATAL EXCEPTION`、ANR、解析失败和读取失败；
9. 从 D2 返回后，D2/D0 两个浏览器 Activity 必须同时消失。

性能评价在完整矩阵后按格式比较：超过同组解析耗时 P90 两倍、PSS 明显高于中位数、连续滚动
GPU missed-frame 增量异常的格式列为优化对象。优化后必须用相同样例和脚本从该格式重新执行十页，
不能用桌面或模拟器结果代替。

SurfaceFlinger 计数是整机全局计数。每一页截图前都重新检查两块屏幕的前台包；其他项目进入任意
显示时立即以退出码 3 中断，并删除该格式尚未闭环的指纹，不能把抢占期间的漏帧归因给浏览器。
该系统还会在另一显示焦点变化时撤销普通 shell 的跨应用输入权限，因此脚本只在前台检查通过后，
通过设备已有的 root input 服务向指定显示发送手势，并留出最终运动帧提交时间。

## 4. 自动化命令

```sh
# 完整 49 格式双屏十页矩阵
./scripts/test-documents-ten-page-device.sh \
  192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.1-arm64-release.apk

# D0 被其他测试占用、D2 空闲时的非抢占单屏筛查
./scripts/test-documents-ten-page-device.sh \
  192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.1-arm64-release.apk single

# 单格式诊断
KBROWSER_ONLY_EXT=pdf ./scripts/test-documents-ten-page-device.sh \
  192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.1-arm64-release.apk

# 修复后从指定格式继续
KBROWSER_FROM_EXT=pptx ./scripts/test-documents-ten-page-device.sh \
  192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.1-arm64-release.apk

# 单格式优化复测，使用独立结果目录，不覆盖完整矩阵
KBROWSER_ONLY_EXT=xlsx KBROWSER_RESULTS_TAG=optimized-xlsx \
  ./scripts/test-documents-ten-page-device.sh 192.168.3.62:5555 \
  bin/DualScreenBrowser-v1.3.1-arm64-release.apk single
```

逐格式结论写入 `ten-page-results.csv`，逐页内容证据写入 `page-fingerprints.csv`；最终人工复核第 1、5、
10 页截图，并在 `docs/document-reader-ten-page-device-report.md` 汇总支持等级、性能异常、修复和复测结果。

## 5. 能力边界

- DOC/XLS/PPT 仍是正文兼容提取，十页通过不等于复杂版式完整还原；
- Mermaid/PlantUML 测试的是源码长文档阅读，不代表在线图形渲染；
- PDF 测试文本型多页 PDF；扫描 PDF 不包含 OCR 承诺；
- MOBI 只测试未加密 PalmDOC/MOBI；不绕过 DRM；
- 不执行 Office 宏、ActiveX 或本地文档中的不可信脚本。
