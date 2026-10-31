# 赛璐璐特效 / 11 能量护盾：生成、受击与破碎

本项生成概念：`libfile_f5337663b14c8191a54d6876126d5fbe`（v0）。一个中间留空的立式椭圆能量屏障，宽窄不一的青蓝外壳、浅青色面与象牙白弧形高光；两侧弧段从下向上闭合，受击位置出现局部凹陷、短促金白接触尖冠和沿球面传播的曲线波纹，最后裂成保留原色带的弯曲壳片。

这是新的独立能量屏障，不是替换原来的 `shield_hit` 实体盾牌命中实验。全部像素与赛璐璐效果保留；组件没有角色、血量、护盾值、伤害、碰撞、敌人、投射物或镜头震动。局部原点在屏障中心。平滑轮廓、不透明硬色块，无黑色描边、像素格、透明玻璃填充或模糊辉光。

## 实验场与控制

Godot 4.6.3 Standard / Compatibility，1280×800；独立场景 F6，F5 仍运行原游戏。

```sh
godot --path . res://scenes/vfx_lab/cel/shield_lab.tscn
```

**H** 保持护盾，**F** 破碎；**J / 1** 在右上方受击，**2** 在左下方受击。**R** 重播，**Space** 暂停，**→** 单步 1/60 秒，**S** 正常 / ¼ 速度，**B** 明暗背景，**E** 隐藏实验场中心十字，**P** 实时参数，**Esc** 关闭参数与拾色器、释放焦点。暂停时受击或破碎只记录事件，不恢复播放。

实验宿主默认在生成完成后的保持阶段 25% 与 57% 处演示两次命中；这些时间线只在实验场里，不在可复用组件里。额外手动命中会保留当前时间线并添加事件，重播清除手动事件。保持模式不自动破碎或循环；F 后尾段结束才由实验场重播。`VIEW` 是按完整有限周期取样的取景倍率，不改变配置的 `size`。

## 生命周期和事件协议

```gdscript
configure(settings) # 深拷贝、校验；保留已有命中事件快照
play(hold_shield: bool = false) # age=0；清除命中和破碎记录
hit(angle_degrees = -35.0, strength = 1.0) -> bool
break_shield() # 当前真实 age 开始破碎；幂等
stop() # 清空、休眠、清除命中事件；不发 finished
seek(seconds, broken_at = -1.0, hold_shield = false)
get_end_time() -> float
build_commands(at_age = -INF, broken_at = -INF) -> Array
set_hit_events(events: Array) -> bool
get_hit_events() -> Array
clear_hits() -> void
```

所有公开时间均为乘过 `duration_scale` 的真实秒数。角度是组件本地角度：0° 向右，−90° 向上；整体 `direction_degrees` 在此后统一旋转。

- 普通播放在 `spawn_seconds + hold_seconds` 后自动破碎；保持模式结束时刻为 `INF`，直到宿主调用 `break_shield()`。完成只发一次 `finished`，不会自行删除节点。
- 普通模式已自动破碎之后的请求不延长寿命；重复破碎、休眠或已完成后的请求忽略。暂停时破碎仍暂停。提前破碎冻结当时真正建成的弧段及局部受击凹陷，不补成完整圆环。
- `seek()` 重建并暂停，不发完成信号；它保留已有命中快照。负值/非有限 age 休眠。`play()` 和 `stop()` 明确清除命中事件，宿主如需预设时间线，应在 `play()` 后调用 `set_hit_events()`。
- `build_commands()` 第二参数默认 **−INF** 使用节点状态；**−1** 强制有限自动周期；**+INF** 强制未破碎保持；非负有限值显式指定破碎时刻。有限模式仍将过晚显式时刻钳到自动时刻；NaN 或其他负值返回空。绘制是纯求值，不修改事件或节点状态。
- 命中事件是 `{ "time": 0.75, "angle": -35.0, "strength": 1.0 }` 的数组，最多 **16** 项。必须是字典，三个值均为有限整数或浮点数，time ≥ 0、strength > 0；角度归一到 −180…180°，strength 钳到 0.1…2。校验全部通过后才提交深拷贝，按时间排序；无效或超容量请求返回 false，旧快照不变。额外字段不保存。读取快照也是深拷贝。
- 事件可预先包含未来命中；求值到其时间才产生效果。对尚未建成的角度、生成前或破碎后的时间线命中不画效果。实时 `hit()` 在这些状态直接返回 false；有效命中保留暂停状态，先移除已过寿命事件，满 16 项时移除最早记录，再加入新命中。命中不会改变护盾寿命。
- 破碎源包含当时的局部凹陷。开始破碎后取消接触尖冠及传播波纹，避免在已经解体的虚拟球面上继续出现环；壳片保留色带并各自张开、轻弯、旋转与收缩。

默认有限周期 **2.49 s**：400 ms 弧段生成、1.40 s 保持、650 ms 破碎，以及 40 ms 清空余量。保持破碎的结束时刻是：`break_at + (break_seconds + 0.04) × duration_scale`。

## 参数

| 参数 | 默认 / 范围 | 作用 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体缩放 |
| `direction_degrees` | 0° / −180°–180° | 绕中心旋转所有层及本地命中方向 |
| `intensity` | 1 / 0.25–2 | 壳厚、凹陷和碎片运动强度 |
| `seed_value` | 211 | 可复现不等宽壳片分割和运动 |
| `radius` | 145 / 70–230 | 水平半径 |
| `aspect` | 1.08 / 0.7–1.4 | 垂直 / 水平半径比 |
| `rim_width` | 37 / 8–54 | 两侧宽弧色带厚度，极端组合有内侧上限 |
| `flow_speed` | 1 / 0–3 | 壳内色带与高光传播速度；0 冻结持续内流 |
| `dent_depth` | 12 / 0–22 | 局部受击凹陷深度 |
| `ripple_speed` | 1 / 0.5–2 | 球面波纹传播速度 |
| `hit_size` | 1 / 0.25–2 | 接触尖冠和金色短屑尺寸 |
| `break_force` | 1 / 0.25–2 | 壳片与小片向外分离距离 |
| `spin` | 1 / 0–2 | 破碎壳片和小片旋转速度 |
| `piece_count` | 8 / 6–12 | 不均等角宽的来源壳片数 |
| `duration_scale` | 1 / 0.4–2 | 全阶段真实时长倍率 |
| `spawn_seconds` | 0.40 / 0.16–0.8 s | 成对弧段闭合时间 |
| `hold_seconds` | 1.40 / 0.3–4 s | 有限模式保持时间 |
| `hit_seconds` | 0.45 / 0.2–0.8 s | 一次接触 / 波纹总寿命 |
| `break_seconds` | 0.65 / 0.3–1.2 s | 壳片完整尾段 |
| 七个开关 | true | `show_shell`、`show_highlights`、`show_streaks`、`show_hits`、`show_ripples`、`show_fragments`、`show_chips` |
| 五种颜色 | 青蓝 / 浅青 / 象牙 / 暖白 / 淡金 | `rim_color`、`body_color`、`highlight_color`、`hit_color`、`spark_color`，均不透明 |

层开关不改变其余几何和事件时序。`show_shell` 控制外壳底色及主体色，亮边和内部弧纹独立；`show_fragments` 控制破碎后的全部来源壳层，小片仍由 `show_chips` 独立控制。隐藏命中尖冠不取消凹陷；这是视觉层开关，不是事件开关。

## 复用

```gdscript
const Barrier = preload("res://scenes/vfx/cel/shield.tscn")
const BarrierConfig = preload("res://scripts/vfx/cel/shield_config.gd")
var settings = BarrierConfig.new()
settings.radius = 120
var shield = Barrier.instantiate()
shield.configure(settings)
shield.position = Vector2(400,300)
add_child(shield)
shield.finished.connect(shield.queue_free)
shield.play(true)
# 生成完成后，宿主自己的视觉事件可调用：
# shield.hit(-35.0,1.0)
# shield.break_shield()
```

生成使用固定半径上的角度前缘，不缩放整张盾牌图；保持时内层边界和亮面独立传播。受击凹陷仅作用在邻近角度，波纹以球面小圆的投影形成前半球弧。壳片由破碎当时同一来源角区构成，底色、高光、内部弧纹共享支点和变形场；几何细分不会变成独立碎屑。只枚举固定数量色面和最多 16 条事件，保持很久也不会累积历史节点。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/shield_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/shield_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-shield.mp4
```

18 秒 / 1080 帧 / 60 fps：暗底正常速度、亮底半速、纯效果半速保持后手动破碎；最后有完全清空尾段。每帧在 `frame_post_draw` 后读取真实 Godot viewport，headless dummy 拒绝录制。概念、视频、帧与日志留在仓库外；原生视觉验收和自动测试分别执行。

## 方法参考

生成概念是造型依据；以下只参考原则，不复制运行时代码或素材：

- [Godot 官方 Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html)：几何构造与三角化验证。
- [Riot 官方 Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)：局部主次、明确接触位置与减少噪声。
- [SpriteFusion Shield 免费配方](https://www.spritefusion.com/pixel-art-vfx/shield)：生成、保持扫光、局部传播波纹与破碎的阶段关系。本实现不用其像素、抖色、透明辉光、网格、角色耦合或 TypeScript 源码。
