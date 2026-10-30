# 赛璐璐特效 / 05 重击、冲击波与扬尘

从本项新生成的赛璐璐概念出发：**不对称的象牙白上冲尖冠、贴地扩散的断开金色压力弧、两侧滚动的暖灰褐扬尘和少量有重量的石片**。先强烈接触，后快速扩散，再让扬尘滞后舒展、缩散。不是移动整张概念图；闪光、波、云团边界和碎片有各自的时间函数。

保留原有像素与赛璐璐效果。仅新增独立 VFX 实验组件，不接回游戏战斗，不添加伤害、碰撞、震屏、敌人或投射物耦合。纯色硬边、平滑轮廓与同色抗锯齿边，没有黑色效果描边、像素取整、渐变辉光或均匀时钟状放射线。

## 运行与控制

Godot 4.6.3 Standard / Compatibility，1280×800。独立 F6 场景；F5 仍运行原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/heavy_impact_lab.tscn
```

**R** 重播，**Space** 暂停，**→** 前进 1/60 秒，**S** 正常 / ¼ 速度，**B** 明暗底色，**E** 纯效果 / 简单落锤示范，**P** 实时参数，**Esc** 关闭参数及拾色器并释放输入焦点。直接关闭参数面板也关闭其拾色器。参数面板显示各配置项；修改立即重播，不回写组件的 Inspector Resource。参数面板打开时取景缩至左侧，旋转或极端配置也按整段动画的包围盒取景，不改变组件本身的参数。

状态栏的 **VIEW** 是预览取景倍率，不是 `size`；尺寸超过视图时会自动缩小取景，因此大尺寸之间的屏幕占比可能相似，实际配置仍保持所设数值。示范落锤与水平地面仅在 `direction_degrees = 0` 且非纯效果模式时显示；其他方向自动隐藏宿主，避免用未旋转的落锤暗示错误的接触方向。

## 参数

| 参数 | 默认 / 范围 | 含义 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 绕接触原点旋转全部层；0° 时地面沿 X 轴，冲击冠向 −Y |
| `intensity` | 1 / 0.25–2 | 闪光伸展、波厚、扬尘上升及碎片初速的强度 |
| `seed_value` | 73 | 可复现的尘团、石片布局；UI 0–9999，API 接受整数 |
| `show_flash` / `show_shockwave` / `show_dust` / `show_chips` | true | 四层独立开关，可任意组合或全部关闭 |
| `duration_scale` | 1 / 0.4–2 | 所有相位统一时长倍率，不改变归一化形状 |
| `flash_seconds` | 0.055 / 0.035–0.12 s | 接触尖冠的峰值时刻，3.5 倍该值后结束 |
| `shockwave_seconds` | 0.4 / 0.2–0.75 s | 压力弧扩张与变薄时长；接触后 0.015 s 起动 |
| `shockwave_radius` | 300 / 100–480 | 压力弧最大半径，不改变扬尘距离 |
| `dust_seconds` | 1.25 / 0.6–2 s | 单尘团最长寿命；各团轻微错开起始与寿命 |
| `dust_count` | 12 / 0–16 | 两侧不规则尘团数；0 关闭尘团 |
| `dust_spread` | 1 / 0.4–1.8 | 扬尘水平分离距离 |
| `chip_count` | 11 / 0–20 | 弹道石片数；0 关闭石片 |
| `chip_gravity` | 520 / 120–1000 | 石片视觉重力；不进行物理碰撞查询 |
| 五种颜色 | 象牙白、淡金、暖灰褐明/暗面、石片棕 | 独立纯色、不透明的赛璐璐色块 |

默认视觉寿命 **1.42 s**，包括最后错时云团和收尾余量。闪光在约 25 ms 打开，随后快速压扁；压力弧减速向外推进、变薄；尘团边界滚动，明暗面相对滑动，晚期小团剥离并缩散；石片独立旋转、抛落。这里的消散是形状缩小、分离和结束，不是叠加半透明雾。`size`、角度和时间倍率作用于所有层，其余参数可单独调节。

## 结构与复用

- `scripts/vfx/cel/heavy_impact_config.gd`：配置、范围与非有限值校验；保留纯色 alpha。
- `scripts/vfx/cel/heavy_impact.gd`：接触原点锚定的纯效果 Node2D；闪光、压力波、尘团、石片分别求值，层间无游戏对象依赖。
- `scenes/vfx/cel/heavy_impact.tscn`：默认休眠，宿主显式启动。没有道具、背景或活动角色。
- `scripts/vfx_lab/cel/study_lab.gd`：可复用的独立实验宿主，拥有背景、抽象落锤、取景、时间轴、实时面板和 viewport 录制。组件不依赖它。
- `scenes/vfx_lab/cel/heavy_impact_lab.tscn`：本项实验入口。

```gdscript
const Impact = preload("res://scenes/vfx/cel/heavy_impact.tscn")
const ImpactConfig = preload("res://scripts/vfx/cel/heavy_impact_config.gd")
var config = ImpactConfig.new()
config.size = 0.65
config.show_chips = false
config.shockwave_radius = 260
var impact = Impact.instantiate()
impact.configure(config) # 深拷贝后校验，不修改调用者资源
impact.position = Vector2(320, 400)
add_child(impact)
impact.finished.connect(impact.queue_free) # 或由宿主保留用于重播
impact.play() # 立即从接触时刻开始，没有内置前摇
```

`play()` 从 age 0 重播；自动播放到 `config.duration()` 仅发出一次 `finished`，不自动删除。`seek(seconds)` 停止自动播放并定格，不发出完成信号；负值或非有限值清空。`stop()` 立即休眠，不发出完成信号。`build_commands(age)` 在无场景/显示环境下也能生成确定性多边形命令，便于契约验证；同一 seed 和 age 不抽取新的随机布局。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/heavy_impact_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/heavy_impact_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-heavy-impact.mp4
```

录制包含暗底正常速度重复、亮底慢速及纯效果慢速。每帧等待 `RenderingServer.frame_post_draw`，读取实际 Godot viewport；headless dummy 明确拒绝录制。概念、视频、帧、运行日志均在仓库外，不把概念图或 CPU 重建动画冒充游戏运行视频。

聚焦检查包含范围与非有限值、纯色、资源隔离、种子/朝向/尺寸/时长、单层开关、生命周期、密集相位边界、18 组合法配置的全程三角化，以及重播/暂停/单帧/参数修改/关闭输入焦点与拾色器等重复和中断路径；还检查旋转时隐藏宿主、状态栏公开取景倍率。测试通过与视觉接受分开报告；录像后关闭渲染器和编码器，再对冻结的最终树运行标准完整测试。

## 制作参考

本项生成概念为视觉依据，以下只参考时序和分层原则，未复制第三方素材或运行时代码：

- [ParticleFX / Ground Slam Impact](https://www.particlefx.studio/effects/ground-slam-impact)：接触闪光、贴地冲击波与较慢的尘层分工。
- SpriteFusion 开源 VFX 库的 `impact` 配方（免费查询）：火花/石片/尘雾按各自速度、重力和寿命处理。本实现不采用像素绘制、透明圆盘或其源代码。
