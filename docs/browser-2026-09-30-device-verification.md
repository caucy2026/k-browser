# KBrowser 1.0.3 文档打开实机验证

测试日期：2026-09-30。功能源码提交：`5451bfcbdc03e74fa17c6873e353bf69dee184d2`。

## 构建与安装

- Windows 本地 `app:assembleForkRelease` 编译通过；[GitHub Actions 构建](https://github.com/caucy2026/k-browser/actions/runs/36578868136)也通过。
- 测试 APK 的 16 KiB zipalign 与 v2/v3 验签通过。APK SHA-256：`dbdbf043b04949de21c1fe3427bd207ff0ef8483b70192b82c28c8f2032ded1b`；测试证书 SHA-256：`c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8`。
- Android 12 的 KEMI Vibe Pads S1 从 1.0.2（102）覆盖安装到 1.0.3（103），`pm install -r` 返回 `Success`。设备安装后的 `base.apk` SHA-256 与本机测试 APK 一致。

## 下载列表实测

| 从下载列表点击 | 实机结果 |
| --- | --- |
| DOC、DOCX、TXT | 直接进入 KEMI Office，内容显示正常；没有系统选择窗 |
| PPT、PPTX | 直接进入 KEMI Office，幻灯片内容显示正常；没有系统选择窗 |
| PDF | 直接进入 KEMI Office，页面内容显示正常；没有系统选择窗 |
| 停用 KEMI Office 后点击 TXT | 系统打开方式选择窗出现；测试后已恢复 KEMI Office |

DOC 和 PPT 使用 [Apache POI 官方测试样本](https://github.com/apache/poi/tree/trunk/test-data)，其他格式使用本机生成的有效样本。每个文件均通过浏览器下载，随后点击下载列表项完成验证。从 Office 返回浏览器正常。

## 验证边界

其他列出的扩展名共用此分发逻辑，但未逐个实机打开。本次使用仓库外的用户指定测试证书，尚未制作商城正式签名包或执行商城发布。
