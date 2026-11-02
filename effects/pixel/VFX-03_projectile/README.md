# VFX-03 · Compact energy bolt / 短尾能量弹

**当前交付：Godot 视觉原型 + 中立参数/算法规格。没有 Unity 实现，也没有 Unity 编译或运行验收。**

首发只做远程弹道家族中的「小型能量弹」，不把飞刀、箭矢、法球各分支混为已完成。圆润前导头连接一条短而收束的真实轨迹尾；有限三色，硬像素轮廓，不使用外圈、放射线、噪声浪花、Bloom、预制图集或外部美术资源。

## 运行

Godot **4.6.3 标准版 / Compatibility**，从仓库根目录：

```sh
python3 effects/pixel/VFX-03_projectile/sync_config.py --check
godot --path preview/godot res://effects/VFX-03_projectile/projectile.tscn
```

不需要修改项目默认场景。窗口逻辑画布 640×360，沿用工程整数倍 / Nearest 显示。上方是 **1×实际游戏像素尺寸**；下方是同一实时状态的 **4×Nearest 跟随诊断**，不是另一张动画。

- `Pause` 冻结模拟位置、寿命、历史和内流；`+ Frame` 单步 1/60 秒。
- `Replay` 重新触发当前参数；`Reset` 恢复默认参数与预览运动。
- `Track` 让上方镜头跟随弹头；跟随镜头下内流仍在移动，不是平移静态图。
- `Turn` 仅切换预览轨迹，最大转速 **1.6 rad/s**；不是游戏索敌/追踪技能。
- `Stop` 在 90 ms 内收束并清理；`Teleport` 跳变 130 px，立即丢弃旧尾。
- `BG` 在深灰、近黑、浅色背景间切换；`Loop` 切换重播。
- Jade / Ember 只改变调色板，Small dart / Heavy pearl 还改变主体/尾部比例。

自动演示参数：`-- --projectile-auto --projectile-quit`。依次展示 180 px/s 自由飞行、180 px/s 跟随、60 px/s 短尾、320 px/s 长尾、受限转向、停止收束；总长约 10.6 秒，原速。

## 文件职责

- `config/presets.json`：唯一权威预设，包含单位、默认值与命名覆盖。
- `sync_config.py`：显式同步/检查 JSON；不是代码生成器或跨引擎转译器。
- `ALGORITHM.md`：可供未来其他引擎重实现的数学与状态契约。
- `preview/godot/effects/VFX-03_projectile/projectile_state.gd`：纯视觉状态、输入姿态、历史、寿命。
- `projectile.gdshader`：实际历史路径上的圆头＋变宽尾、离散三色色块和连续内流。
- `projectile_view.gd`：最后显示阶段才取整，保持模拟位置/速度连续。
- `projectile_demo.gd` / `.tscn`：独立原型 UI 和演示运动。
- `test_projectile.gd`：直接运行以上实际状态代码，不做假的目标引擎测试。

## 有效参数

| 参数 | 默认 | 有效范围 / 语义 |
|---|---:|---|
| `head_radius` | 4.5 px | 2–8；圆润前导头半径 |
| `tail_min` | 9 px | 0–30；低非零速度目标尾长 |
| `tail_max` | 27 px | tail_min–42；最高目标尾长 |
| `speed_reference` | 240 px/s | 30–600；达到最大尾长的速度 |
| `speed_response` | 0.055 s | 0.01–0.3；尾长指数响应时间常数 |
| `flow_strength` | 0.8 | 0–1；内部亮片宽度及头部微脉动，0 关闭内部运动 |
| `lifetime` | 1.6 s | 0.1–10；随后 0.09 s 干净收束 |
| `core/body/edge_color` | 玉色三色 | 直接有限色阶，正常 alpha 混合，不依赖大范围发光 |

GUI 有意只开放常用旋钮；速度参考与颜色直接在预设中调整。越界数字会夹到范围；NaN/Infinity 保留原值。尾宽由 `head_radius` 与尾长共同推导，避免独立旋钮产生断开的头尾。确定性效果无无效 seed。演示 `speed` 是预览输入，不是伤害/命中/索敌设置。

## 检查

```sh
python3 effects/pixel/VFX-03_projectile/tests/run_checks.py
```

该命令核对预设副本，并在 Godot headless 中检查实际状态代码：寿命边界和大 delta、暂停/恢复/重置、正常停止/立即清除、瞬移断尾、速度响应、历史上限、静止收尾、参数越界、30/60/144 FPS 一致性、非法输入及不量化模拟位置。导入/状态测试不能证明视觉完成；原生 UI、渲染和视频的实际结果见 `QA.md`。

## 边界

游戏传入世界位置、真实速度与停止/命中事件；特效代码不决定伤害、碰撞、索敌或服务器轨迹。入场 25 ms；停发/命中后在当前位置收束，不继续替游戏移动。历史按实际输入位置记录，不能从速度方向凭空造一条过去的尾。超过 96 px 的单次位置跳变视为瞬移；异常大帧移也安全断尾而不画跨屏长线。

全部特效算法和美术形状为本次新写；无复制第三方代码、付费内容或外部素材。实现参考 Godot 官方 [CanvasItem shader 文档](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html) 的 uniform 与混合方式，以及 [shader 语言文档](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shading_language.html) 的 uniform 数组规范；没有引入第三方代码许可依赖。
