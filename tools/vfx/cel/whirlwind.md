# 赛璐璐特效 / 10 旋风

依据本项新生成的概念：狭窄风脚、逐渐张开的上口、带倾斜透视的薄荷白螺旋风带、青绿背面、少量上行弯月气流与断开的贴地风环。概念 Library：`libfile_714f99c9274c81918e418cc096883004`，v0。形状为平滑、纯色、不透明的赛璐璐层，没有黑色外描边、像素格、模糊或辉光。

风带沿轴向上行，前后可见段轮换，宽度与尖端局部改变；不是旋转或平移一张固定旋风图。释放时从当时实际存在的每个色面出发，分段卷离、剪切、张开并缩散；早期释放不会补出完整旋风。每段主体和亮边共用来源、支点与变形，因此不会把颜色拆成互不相干的纸片。

组件独立于角色、吸引力、击退、碰撞和伤害，不接入生产战斗，不替换已有像素或赛璐璐效果。

## 运行与控制

Godot 4.6.3 Standard / Compatibility，1280×800。独立实验场 F6；F5 仍运行原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/whirlwind_lab.tscn
```

**H** 保持旋风，**F** 释放；**R** 重播，**Space** 暂停，**→** 单步 1/60 秒，**S** 正常 / ¼ 速，**B** 明暗背景，**E** 隐藏源位置示意线，**P** 参数，**Esc** 关闭参数与拾色器并释放焦点。参数和颜色变化即时重播，不回写 Inspector Resource。

保持模式不自动释放或循环。F 后完整尾段与空白间隔结束，实验场才按当前模式重播；组件自身不循环。暂停时 F 只记录释放时刻，不恢复播放；重复 F 不延长尾段。普通模式已经自动释放后按 F 不会重启。`VIEW` 是实验场取景倍率，不改变组件 `size`。

## 生命周期 API

```gdscript
configure(settings) # 深拷贝并校验，可在 add_child 前调用
play(hold_sustain: bool = false)
release() # 当前真实时间开始释放，幂等
stop() # 清空并休眠，不发 finished
seek(seconds, released_at = -1.0, hold_sustain = false)
get_end_time() -> float
build_commands(at_age = -INF, released_at = -INF) -> Array
```

- 普通 `play()` 是聚风—持续—释放的有限周期；`play(true)` 持续保持至 `release()`。保持未释放时终止时间为 `INF`。
- `age`、`release_at`、`seek()` 和绘制求值都使用实际秒数，已经包含 `duration_scale`。
- `release()` 冻结当时可见的来源曲线和生长程度，再运行每个来源段的尾动画。休眠、完成、重复释放和已自动释放时忽略调用。
- `seek()` 重建并暂停，不发完成信号；无效 age 安全休眠。`stop()` 清除时间和保持状态。自动完成时只发一次 `finished`，宿主决定是否删除节点。
- `build_commands()` 默认 `−INF` 取当前状态。第二参数 **−1** 强制有限自动周期，**+INF** 强制未释放保持，非负有限值指定释放时刻。普通模式的过晚显式释放被钳到自动时刻；保持模式允许较晚释放。NaN 和其他负值返回空。
- 生成命令包含 `points`、`color`、`layer`、`ribbon_id`、`piece`。来源支点及外边界辅助数据用于保持同段颜色同步；不是物理刚体或历史粒子节点。

默认周期 **2.16 s**：320 ms 聚风、1.15 s 持续、650 ms 释放，再留 40 ms 清空余量。

`(spinup_seconds + sustain_seconds + release_seconds + 0.04) × duration_scale`

保持释放的结束时刻为 `release_at + (release_seconds + 0.04) × duration_scale`。

## 参数

| 参数 | 默认 / 范围 | 作用 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 绕风脚旋转全部层；0° 向上 |
| `intensity` | 1 / 0.25–2 | 半径和风带厚度强度 |
| `seed_value` | 173 | 可复现的风带相位细差 |
| `height` | 280 / 120–380 | 漩涡主体高度 |
| `top_radius` | 108 / 50–170 | 上口半径 |
| `ribbon_count` | 4 / 2–7 | 主体沿高度的螺旋圈数 |
| `ribbon_width` | 19 / 4–28 | 色带半宽基准，极密圈数时受螺距限制 |
| `spin_speed` | 0.72 / 0–2 | 每基准秒绕轴转数 |
| `rise_speed` | 1.25 / 0–3 | 每基准秒上行圈数 |
| `release_spread` | 1 / 0.25–2 | 释放分段横向张开与上漂距离 |
| `duration_scale` | 1 / 0.4–2 | 全阶段时长倍率 |
| `spinup_seconds` | 0.32 / 0.12–0.8 s | 从低处建立旋风的时长 |
| `sustain_seconds` | 1.15 / 0.2–4 s | 普通模式的完整流动时长 |
| `release_seconds` | 0.65 / 0.25–1.2 s | 释放风带的完整尾段 |
| 四个独立开关 | true | `show_ribbons`、`show_highlights`、`show_slivers`、`show_ground` |
| 四种颜色 | 薄荷 / 青绿 / 近白 / 淡青 | `front_color`、`back_color`、`highlight_color`、`sliver_color`，均不透明 |

关闭层不改变其他层的运动与释放支点。两个流速都为 0 时持续形状冻结；生命周期仍推进。保持模式只计算当前可见风带，使用有界周期相位，不累积运行历史。

## 几何与复用

投影曲线在实际横向极值处分段，色面由连续的凸梯形单元构成，避免宽法线带在急弯处自交。相邻单元只绘制外轮廓抗锯齿，不画内部格线。主体和高光使用相同横截面、来源段支点与剪切场；额外的横向极值分割仅用于几何构造，同一前/后半圈的所有单元仍共享释放支点，不拆成微小飞片。几何缩小到无法由 Float32 画布可靠表达的亚像素面积时结束，不通过检测三角化失败来隐藏非法形状。

```gdscript
const Wind = preload("res://scenes/vfx/cel/whirlwind.tscn")
const WindConfig = preload("res://scripts/vfx/cel/whirlwind_config.gd")
var settings = WindConfig.new()
settings.size = 0.8
settings.top_radius = 120
var wind = Wind.instantiate()
wind.configure(settings)
wind.position = Vector2(400,450)
add_child(wind)
wind.finished.connect(wind.queue_free)
wind.play(true)
# 宿主自己的事件：wind.release()
```

运行时、配置、可复用场景和实验场分别为 `scripts/vfx/cel/whirlwind.gd`、`whirlwind_config.gd`、`scenes/vfx/cel/whirlwind.tscn` 与 `scenes/vfx_lab/cel/whirlwind_lab.tscn`。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/whirlwind_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/whirlwind_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-whirlwind.mp4
```

**18 秒 / 1080 帧 / 60 fps**：暗底正常速度有限周期、亮底半速完整周期、纯效果半速保持后释放，并保留清空尾段。每帧等待 `RenderingServer.frame_post_draw` 后读取实际 Godot viewport；headless dummy 拒绝录制。概念、帧、视频和日志均留在仓库外。

聚焦验证涵盖参数范围和非有限值、层与颜色独立性、内在流动、早期/重复/暂停释放、保持时间有界、来源连续性与亮边附着、极端配置全相位三角化、实际控件和完整录制时间轴。自动测试与原生视觉验收分别执行；录制完成并停止渲染/编码后，再冻结源文件运行完整标准测试。

## 方法参考

仅参考通用方法，不复制第三方素材或运行时代码：

- [Godot 官方 Custom drawing in 2D](https://docs.godotengine.org/en/4.4/tutorials/2d/custom_drawing_in_2d.html)：自定义多边形、局部坐标与逐帧重绘。
- [Godot 官方 State of particles and future updates](https://godotengine.org/article/progress-report-state-of-particles/)：把轨道、径向和方向运动独立控制的思路。本项使用自己的确定性曲线与多边形实现，不依赖粒子插件。
