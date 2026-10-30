# 赛璐璐特效 / 09 结冰与碎冰

从本项生成概念开始：一个高的中央冰棱、左右不等高的倾斜晶体、两侧短晶体与低矮霜片。使用天蓝阴面、青色亮面、淡蓝顶面与近白棱面；形状是平滑硬边的纯色多边形，不是像素、黑描边或模糊辉光。

各晶体错时生长，宽高比例随结晶改变；窄高光带在面内移动。裂纹沿真实分块边界前进，随后每根冰棱分成上端与下部两块，保留原来的切面和颜色，以各自的中心飞散、旋转、收缩。不是整簇图片缩放，也不是五根完整冰棱原封不动飞走。早期碎冰只分割当时已长出的形状，不补出尚未存在的上半部。

组件完全独立于角色、冰冻状态、减速、碰撞和伤害；不接回生产战斗，不替换已有像素或赛璐璐组件。

## 运行与控制

Godot 4.6.3 Standard / Compatibility，1280×800。独立实验场 F6，F5 仍为原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/ice_lab.tscn
```

**H** 保持晶体；**F** 请求开裂与碎冰；**R** 重播；**Space** 暂停；**→** 前进 1/60 秒；**S** 正常 / ¼ 速度；**B** 明暗背景；**E** 隐藏源位置线；**P** 参数；**Esc** 关闭参数与拾色器并释放焦点。修改参数会深拷贝、校验并重播，不回写 Inspector Resource。

保持模式不会自动碎冰或循环；F 后完整尾段与空白间隔结束，实验场才按当前模式重播。组件本身不循环。暂停时 F 只记录请求，不擅自恢复播放；重复 F 不推迟结束。普通模式已经自动开裂后再按 F 不会延长寿命。

`VIEW` 是自动取景比例，不是组件尺寸。取景固定采样完整默认有限周期，不受上一次早期碎冰或保持状态污染。

## API 与时间约定

```gdscript
configure(settings) # 深拷贝并校验；添加节点前可调用
play(hold_crystals: bool = false)
shatter() # 从当前 age 开始裂纹阶段，随后真正分离；幂等
stop() # 立即清空，不发 finished
seek(seconds, shattered_at = -1.0, hold_crystals = false)
get_end_time() -> float
build_commands(at_age = -INF, shattered_at = -INF) -> Array
```

- `play()` 默认有限生长—保持—开裂—碎片周期。`play(true)` 持续保持，直至 `shatter()`。未释放的保持模式 `get_end_time()` 为 `INF`。
- `age`、`shatter_at` 和公开 API 的时间都是真实秒数，已经包含 `duration_scale`。`shatter_at` 指**开裂开始**，不是碎片飞离时刻；真正分离在其后 `crack_seconds × duration_scale`。
- 请求开裂时冻结当时的生长程度。裂纹阶段不继续长大；每个已存在的切面按同一折线分割，上下块的切面一起旋转，不互相散开成纸片。
- `seek()` 纯重建并暂停，不发完成信号。无效 age 安全休眠。`stop()` 清除 age、保持与开裂时间。完成只发一次 `finished`，宿主决定回收或重播。
- `build_commands()` 默认 `−INF` 使用节点状态；第二参数 **−1** 强制有限自动周期，**+INF** 强制未碎保持，非负有限值显式指定开裂时间。有限模式会把过晚的显式时间钳到自动时刻，不能延寿；保持模式允许任意较晚时刻。NaN 或其他负值返回空。
- 绘制命令含 `points`、`color`、`layer`，另有 `crystal` 与 `piece` 标识，方便检查来源连续性。它们不是物理刚体，不产生节点历史或全局随机状态。

默认 **1.82 s**：380 ms 生长、550 ms 保持、130 ms 裂纹、720 ms 碎片，再留 40 ms 空白。有限时长：

`(growth_seconds + hold_seconds + crack_seconds + shatter_seconds + 0.04) × duration_scale`

保持模式开裂后的结束时间：

`shatter_at + (crack_seconds + shatter_seconds + 0.04) × duration_scale`

## 参数

| 参数 | 默认 / 范围 | 作用 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 所有层绕晶体根部旋转 |
| `intensity` | 1 / 0.25–2 | 飞散运动强度 |
| `seed_value` | 107 | 可复现高度细差、倾斜、碎片运动和霜片 |
| `height` | 240 / 100–360 | 中央晶体高度基准 |
| `width` | 54 / 24–100 | 晶体宽度基准 |
| `spread` | 1 / 0.3–1.6 | 侧晶体张角、根部散布与霜片范围 |
| `crystal_count` | 5 / 1–7 | 由中央向侧面增加的晶体数 |
| `shatter_force` | 1 / 0.25–2 | 分块与细碎片的飞散距离 |
| `spin` | 1 / 0–2 | 分块和细碎片旋转速度，0 关闭旋转 |
| `glint_speed` | 1 / 0–3 | 面内光带与稀疏菱形闪光速度，0 冻结相位 |
| `duration_scale` | 1 / 0.4–2 | 全阶段时长倍率 |
| `growth_seconds` | 0.38 / 0.16–0.8 s | 所有错时晶体完成生长的时间 |
| `hold_seconds` | 0.55 / 0.2–2 s | 有限模式的完整晶体保持时间 |
| `crack_seconds` | 0.13 / 0.06–0.35 s | 裂纹沿分块接缝传播时间 |
| `shatter_seconds` | 0.72 / 0.35–1.2 s | 源分块与细碎片的完整寿命 |
| 六个独立开关 | true | `show_crystals`、`show_frost`、`show_glints`、`show_cracks`、`show_chunks`、`show_shards` |
| 五种颜色 | 天蓝 / 淡蓝 / 青色 / 近白 / 白 | `shadow_color`、`body_color`、`light_color`、`ridge_color`、`crack_color`，保持纯色不透明 |

时间倍率改变播放速度，不改变同一归一化相位的几何。颜色、层开关、形状与运动参数互相独立；隐藏完整晶体并不自动隐藏高光或后续碎片，可逐层研究。

## 复用

```gdscript
const Ice = preload("res://scenes/vfx/cel/ice.tscn")
const IceConfig = preload("res://scripts/vfx/cel/ice_config.gd")
var settings = IceConfig.new()
settings.size = 0.7
settings.crystal_count = 3
var crystal = Ice.instantiate()
crystal.configure(settings)
crystal.position = Vector2(400,420)
add_child(crystal)
crystal.finished.connect(crystal.queue_free)
crystal.play(true)
# 宿主自己的事件：crystal.shatter()
```

短暂冰簇直接 `play()`；需要取消则 `stop()`。组件不保存角色、不修改状态、不与生产元素系统互相依赖。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/ice_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/ice_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-ice.mp4
```

**18 秒 / 1080 帧 / 60 fps**：前 6 秒暗底正常循环；接着 6 秒亮底半速完整有限周期；最后 6 秒暗底纯效果半速保持，在 age **1.15 s** 请求碎冰，完整结束于 **2.04 s**，之后有空白确认清空。每帧等待真实 `RenderingServer.frame_post_draw` 并读取 viewport；headless dummy 拒绝录制。

聚焦契约和实际视觉 review 分别核验。概念、视频、帧和日志放在仓库外。渲染/编码/播放器退出后，冻结最终代码并运行标准完整测试，不用截图取代自动测试，也不用无头测试替代运动 review。

## 方法参考

生成概念决定造型。以下只参考通用方法与时序原则，不复制第三方运行时代码、素材或像素描边：

- [Godot 官方 / Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html)：面与分区相交、几何处理和三角化。
- [Godot 官方 / 2D particle systems](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html)：有界寿命、一次发射和独立粒子运动原则。
- [SpriteFusion 免费 Ice 配方](https://www.spritefusion.com/pixel-art-vfx/ice)：根部生长、明暗切面、传播裂纹与源色碎片；本项不采用其像素、黑描边、模糊光或运行时代码。
