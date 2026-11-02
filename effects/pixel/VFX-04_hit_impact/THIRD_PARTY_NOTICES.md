# 来源与许可

## Sprite Fusion impact：设计参考，不打包外部源码

- 作者：Hugo Duprez / Sprite Fusion。
- 官方效果页：https://www.spritefusion.com/pixel-art-vfx/impact
- 核查下载：https://www.spritefusion.com/downloads/pixel-art-vfx/impact.zip
- 核查日期：2026-11-02；压缩包内 `impact.ts` 时间戳为 2026-10-27。
- 核查 ZIP SHA-256：`575761c59ee9a75012247eedfcda2544f6a711864647c1ba4439cc74a8f01336`。
- 官方页面标明 MIT / 可商用；源码头标明 `MIT License` 与 `Copyright (c) 2026 Hugo Duprez`。
- 阅读了方向拉伸的瞬时亮芯、固定种子碎片、前峰后收尾和输入位置/角度接口。
- 本实现重新编写解析遮罩、时间函数、有限三档配色与 Godot 适配；**未复制或随包分发 TypeScript 源码/素材**。主动去除了参考中的全圆环、烟尘、长寿命碎屑和大范围发光，以符合干净利落要求。
- 未使用 Sprite Fusion 付费生成服务。

## 引擎参考

- Godot CanvasItem shader：https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html
- Godot 自绘：https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html
- Godot Movie Maker：https://docs.godotengine.org/en/4.6/tutorials/animation/creating_movies.html

本项的实际引擎实现为 Godot；纯数学内核不是第三方引擎代码。无外部美术素材，也不包含预制帧动画。
