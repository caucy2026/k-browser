# KEMI 双屏硬件优化基线

目标设备：`huanglong / hi3781v730`，Android 12（API 31），arm64。

## 固定硬件参数

- Display 2：外接触摸屏，`1920×1280 @ 60Hz`，连续页面顶部。
- Display 0：内置触摸屏，`1920×1280 @ 60Hz`，承接 Display 2 下方 1280px。
- GPU：ARM Mali-G52，OpenGL ES 3.2；双屏当前均由 SurfaceFlinger Client/GPU 合成。
- 内存：约 5.5GB。
- 外屏物理输出由系统执行 `ROT_180`，输入系统已将触摸映射为 orientation 2；应用禁止再次旋转坐标。
- VSync 周期：16.67ms，目标同步频率固定为每帧最多一次。
- 物理显示 ID 为 0/1，Android 逻辑显示与 LayerStack 为 D0/0、D2/2；录屏与 SurfaceControl 取证不能混用两套 ID。

## `kemi-rd` 系统文档结论

依据：[项目总览](https://github.com/caucy2026/kemi-rd)、[芯片与双屏开发](https://github.com/caucy2026/kemi-rd/blob/main/md/chip.md)、[本地/CI 构建](https://github.com/caucy2026/kemi-rd/blob/main/md/ci-build.md)、[跨屏键盘](https://github.com/caucy2026/kemi-rd/blob/main/md/cross-display-keyboard.md)、[双屏录制](https://github.com/caucy2026/kemi-rd/blob/main/md/dscr.md)。

1. Display ID 不保证连续，启动副屏必须枚举 `DisplayManager.displays`，不能把数组下标当成 Display ID。
2. 交互型双屏应使用两个独立 Activity；`Presentation` 只适合辅助展示，焦点与生命周期不适合浏览器输入。
3. 双 Activity 独立渲染会使 GPU 负载接近翻倍，因此两个 GeckoSession 只作为当前原型；正式目标仍是单页面、单合成源裁切到两个 Surface。
4. 平台签名场景可通过隐藏 `SurfaceControl.Transaction` 访问物理 LayerStack。该能力当前先用于 D0/D2 无弹窗录屏取证，后续评估是否能承载单合成源双屏投影。
5. 跨屏软键盘必须由目标屏真实 Activity 承载，并以目标窗口 IME Insets 为状态真源。浏览器地址栏首版保留本屏输入，后续单独验证代理输入 Activity，避免键盘导致网页布局或系统栏跳动。
6. 同一 Activity 类需要在 D0/D2 同时存在，不能直接照搬副屏 `singleInstance`；若要采用该防多实例策略，必须拆成主/副屏两个 Activity 类后再验证。

## 浏览器连续画布定义

- 两块屏幕是同一 Android 设备上的两个独立 Display，不是物理叠屏，也不是系统镜像/复制模式。
- 逻辑网页画布按 `1920×2560` 建模：Display 2 固定显示 `logicalTop + 0…1279`，Display 0 固定显示 `logicalTop + 1280…2559`。
- 屏幕角色只允许根据 Activity 实际 `displayId` 判断，禁止使用启动器来源、Intent 布尔值或 Display 数组下标猜测。
- Display 0 是会话总控 Activity，Display 2 是顶部显示 Activity。两者分别使用 `singleTask` 与 `singleInstance`，避免同一 Activity 类在两个任务栈中产生复制实例。
- 任一时刻只允许触摸中的一块屏作为滚动源；另一块屏只接收同一帧的逻辑位置，禁止把程序性滚动再反馈给源屏。
- Display 0 返回、HOME 或销毁时必须原子关闭 Display 2，不能残留副屏页面或独立任务。

## 应用优化约束

1. 接缝偏移固定为 1280px，不使用可能受系统栏瞬态变化影响的 View 高度。
2. 滚动回调先按帧合并，再向另一显示提交；程序化滚动不得回传，避免反馈环和抖动。
3. 用户在任一屏按下时，立即取消旧的程序化同步目标，保证触摸接管无延迟。
4. 两屏显式选择 `1920×1280 @ 60Hz` 显示模式并固定横屏。
5. 浏览器栏使用不透明背景并取消阴影，减少 Mali-G52 的透明混合与离屏合成。
6. 使用严格跟踪保护和 Cookie 横幅拒绝策略，减少广告/跟踪脚本带来的布局跳动与 GPU/CPU 开销。
7. Display 2 的 180 度补偿交给系统显示与输入栈，应用层不得增加旋转矩阵。

## 性能闭环

真机验证至少记录：SurfaceFlinger missed frames 前后增量、两屏滚动视频、Display 0/2 Activity 状态、崩溃日志。测试页面优先使用长文档和知识站点，购物/信息流网站不作为默认入口。
