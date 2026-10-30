# 赛璐璐特效 / 08 雷电

根据本项生成概念实现：蓝紫硬色外层、象牙白亮芯、较粗主干、细分叉、接触点的不对称电花。细先导从上往下延伸；随后三次短回击分别重排折点与分叉根部；间隙与最后阶段只留下断开的短电弧，局部退缩、形变并消失。没有黑色描边、像素格、模糊辉光、整图闪烁或静态贴图平移。

组件独立于角色、连锁选敌、伤害、碰撞和任何元素状态，不接回生产战斗，也不替换既有像素或赛璐璐组件。坐标原点是接触点，默认从本地 −Y 向原点落下。

## 运行与实验场

Godot 4.6.3 Standard / Compatibility，1280×800。独立场景 F6；F5 仍为原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/lightning_lab.tscn
```

**R** 重播；**Space** 暂停；**→** 单步 1/60 秒；**S** 正常 / ¼ 速度；**B** 明暗背景；**E** 隐藏接触点示意线；**P** 参数；**Esc** 关闭参数与拾色器、释放输入焦点。配置修改立即重播，不回写输入 Resource。`VIEW` 是实验场自动取景倍率，不改变组件 `size`。

## 生命周期与复用

```gdscript
const Lightning = preload("res://scenes/vfx/cel/lightning.tscn")
const LightningConfig = preload("res://scripts/vfx/cel/lightning_config.gd")
var settings = LightningConfig.new()
settings.size = 0.75
settings.stroke_count = 2
var bolt = Lightning.instantiate()
bolt.configure(settings) # 深拷贝、校验，不改调用者资源
bolt.position = Vector2(400,420)
add_child(bolt)
bolt.finished.connect(bolt.queue_free) # 或宿主保留后重播
bolt.play()
```

- `play()` 从 0 秒开始；`seek(seconds)` 重建指定真实秒数并暂停，不发送完成信号。
- `stop()` 立即清空并休眠，不发送完成信号。
- `finished` 每次完整播放只发一次；组件不自行删除或自动循环。
- `build_commands(at_age = -INF)` 纯求值；默认取当前 age。无效、负数和到期时间返回空命令，不修改节点状态。
- `config.strike_end()` 是未乘倍率的回击结束时刻；`config.duration()` 是包含全部尾段的真实秒数。所有 API 输入秒数都已包含 `duration_scale`。
- 没有生成历史粒子节点或全局随机数；同一配置和时间返回同样命令。

默认周期 **0.805 s**：130 ms 先导，3 × 75 ms 回击，中间 2 × 45 ms 间隙，320 ms 断弧尾段，再留 40 ms 空白。时长公式：

`(leader_seconds + stroke_count × stroke_seconds + (stroke_count − 1) × stroke_gap_seconds + residual_seconds + 0.04) × duration_scale`

## 参数

| 参数 | 默认 / 范围 | 作用 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 所有几何绕接触点旋转 |
| `intensity` | 1 / 0.25–2 | 主干厚度、接触电花和碎屑运动强度 |
| `seed_value` | 83 | 可复现折点、分叉与电屑布局 |
| `length` | 340 / 160–520 | 主干高度 |
| `bolt_width` | 22 / 6–42 | 主干外层宽度基准 |
| `zigzag` | 36 / 0–72 | 主干折点横向范围；0 为直线放电 |
| `branch_count` | 4 / 0–7 | 主分叉数；每两条附一条细次级分叉 |
| `branch_reach` | 110 / 30–190 | 分叉横向长度 |
| `contact_size` | 1 / 0.25–2 | 接触冠与地面电弧尺寸 |
| `duration_scale` | 1 / 0.4–2 | 全阶段时长倍率 |
| `stroke_count` | 3 / 1–5 | 回击次数，每次改变路径 |
| `leader_seconds` | 0.13 / 0.06–0.35 s | 先导下降时间 |
| `stroke_seconds` | 0.075 / 0.04–0.18 s | 每次明亮回击时长 |
| `stroke_gap_seconds` | 0.045 / 0.02–0.14 s | 两回击间的细碎余弧间隔 |
| `residual_seconds` | 0.32 / 0.15–0.65 s | 最后一击后断弧消散时间 |
| `show_leader` | true | 先导及先导阶段分叉 |
| `show_main` | true | 回击主干 |
| `show_branches` | true | 附着主干的主、次分叉 |
| `show_contact` | true | 接触冠与近地电弧 |
| `show_residual` | true | 间隙和尾段的断开余弧 |
| `show_sparks` | true | 游离菱形电屑 |
| `rim_color` / `core_color` / `residual_color` | 蓝紫 / 象牙白 / 淡蓝 | 纯色不透明调色板 |

主干、分叉、接触、余弧、电屑分别开关；关闭一种层不改变其余层时序。回击不是整根光柱的淡入淡出：每次用不同的确定性折点和分叉连接，宽度沿主干不均匀；最后将路径切为六段，段间负空间扩大，局部折点分别回缩。主干与分叉纵向单调，横向截面构成简单多边形；地面折线按独立凸四边形绘制，避免交叉轮廓。

## 真实录制与测试

```sh
godot --headless --script tests/vfx/cel/lightning_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/lightning_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-lightning.mp4
```

使用通用 study 实验场的 **13 秒 / 780 帧 / 60 fps** 录制：暗底正常速度循环，亮底半速完整周期，暗底隐藏示意线的半速完整周期。每帧等待 `RenderingServer.frame_post_draw` 并读取真实 viewport；headless dummy 拒绝录制。概念、帧、视频和日志不放进仓库。视频与自动测试结果分别核验。

## 方法参考

生成概念是造型依据。只参考通用方法，不复制第三方运行时代码或素材：

- [Godot 官方：Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)：自定义多边形、按需 `queue_redraw`、平滑边缘。
- [Godot 官方：2D antialiasing](https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html)：纯色几何边缘的抗锯齿方式。

- [SpriteFusion 免费 lightning 配方](https://www.spritefusion.com/pixel-art-vfx/lightning)：只参考下行先导、多次改道回击、渐细分叉和断弧的时序原则；不采用像素绘制、辉光、震屏或源代码。
