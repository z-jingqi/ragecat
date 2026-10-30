# 赛璐璐特效 / 06 轮廓消解

依据本项新生成的概念：蓝灰轮廓短促亮成象牙白，随后被连续、不规则的金白侵蚀前缘逐步剥离；大小不一的薄碎片从原形内部被前缘触及的位置出生，向右上方漂移、转动并收缩，最终完全清空。没有血腥、规则网格、整身三角爆炸、黑色 VFX 描边、像素化或发光模糊。

**这是由宿主提交多边形轮廓的独立效果，不是任意 Sprite/Texture 的截图或自动轮廓提取器。** 人形和另一个多面形 token 仅属于实验场示范；可复用组件没有硬编码角色、活动敌人、伤害、碰撞、死亡结算或游戏接入。原有像素与赛璐璐组件均保留。

## 运行与实验控制

Godot 4.6.3 Standard / Compatibility，1280×800。打开独立场景按 F6；F5 仍运行原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/death_lab.tscn
```

**1** 简单人形，**2** 多面形 token；**R** 重播，**Space** 暂停，**→** 单步 1/60 秒，**S** 正常 / ¼ 速度，**B** 明暗背景，**E** 隐藏接触前的完整示范轮廓，**P** 实时参数，**Esc** 关闭参数/拾色器并释放输入焦点。修改参数、颜色或源形状自动重播；Reset defaults 恢复默认配置及人形源。

宿主只在效果开始前绘制完整轮廓，age 0 后全部可见形状由组件产生，不重复叠加一个未消解角色。状态栏 **VIEW** 是自动取景倍率，和效果 `size` 分开；极端尺寸或角度会缩小取景，不改变所设配置。这里没有地面落锤或战斗角色。

## 源轮廓协议

```gdscript
set_source_polygons(polygons: Array, colors: Array = []) -> bool
clear_source() -> void
source_count() -> int
get_source_snapshot() -> Dictionary # {polygons: Array, colors: Array}
```

- `polygons` 必须含 **1–16 个 `PackedVector2Array`**。每轮廓 3–128 个顶点，总计最多 512。可选的末点等于首点会先去掉，再计入预算。
- 每个坐标分量必须有限且位于 **−4096…4096**。支持顺/逆绕向的简单凸形与凹形；拒绝连续共线顶点、零长度边、内部重复顶点、自交、自接触、重叠边及零面积。提交前应清理冗余共线点。
- 多轮廓表示多个**实心形状**，不是带洞路径。内层轮廓仍会填充，不会自动减去成洞。API 不提取纹理 alpha，也不追踪活动对象。
- `colors = []` 使用配置中的 `source_color`；否则数量必须和轮廓数一致，每项为有限的 RGB 0–1、alpha 恰好为 1 的 `Color`。显式源颜色不会被后来的 `source_color` 调色替换。
- 完整请求先验证、后提交。失败返回 `false`，`source_error` 给出理由，**此前的源轮廓、颜色和缓存不变**；空数组也被拒绝，需要清空时显式 `clear_source()`。成功清除错误文本。
- 顶点与颜色在提交时复制；`get_source_snapshot()` 也返回深拷贝，修改调用方数据或返回值不修改效果内部快照。
- 源形状只在提交时三角化，三角形仅用于按面积采样碎片出生点，不作为爆炸外观。`configure()` 保留源轮廓并重建与参数有关的运动缓存；`cache_generation` 用于观察缓存更新，逐帧采样不会重复建立源缓存。

碎片可从轮廓内部出生：它们在**移动侵蚀前缘抵达其采样位置**时释放，而不是要求每片都从原外边界发射。不同 seed 会改变前缘与薄片分布，但同一源、配置和时间完全确定。

## 参数

| 参数 | 默认 / 范围 | 含义 |
|---|---|---|
| `size` | 1 / 0.25–3 | 绕提交源的原点统一缩放 |
| `direction_degrees` | 0° / −180°–180° | 旋转完整轮廓和所有效果层 |
| `intensity` | 1 / 0.25–2 | 碎片运动强度 |
| `seed_value` | 41 | 可复现的前缘、出生点与薄片分布 |
| `erode_degrees` | −35° / −180°–180° | 侵蚀轴；从该轴远端向源的另一端退去 |
| `shard_direction_degrees` | −38° / −180°–180° | 碎片释放方向，与整体旋转和侵蚀方向独立 |
| `edge_width` | 8 / 2–24 | 金白侵蚀边缘宽度 |
| `edge_roughness` | 1 / 0–2 | 不规则前缘起伏；0 为平直推进 |
| `shard_count` | 31 / 0–56 | 有界薄片数量；0 关闭薄片 |
| `shard_spread` | 1 / 0.2–2 | 薄片方向离散与微小漂移 |
| `shard_size` | 1 / 0.3–2 | 碎片局部尺寸 |
| `shard_speed` | 235 / 80–520 | 释放后漂移速度 |
| `duration_scale` | 1 / 0.4–2 | 整体时长倍率，不改变归一化形状 |
| `flash_seconds` | 0.055 / 0.025–0.12 s | 源轮廓象牙白短闪 |
| `erosion_seconds` | 0.60 / 0.25–1.1 s | 前缘扫过源轮廓的时长 |
| `shard_seconds` | 0.64 / 0.2–1 s | 最长薄片尾段寿命 |
| `show_source` / `show_flash` / `show_edge` / `show_shards` / `show_wisps` | true | 源残留、短闪、侵蚀边、碎片与根部余灰分别开关 |
| 五种颜色 | 蓝灰、象牙白、暖金、淡金、灰白 | 源默认色 / 核心 / 前缘 / 碎片 / 余灰，均为不透明纯色 |

默认完整寿命 **1.345 s**：55 ms 短闪、600 ms 侵蚀、最多 640 ms 的错时碎片尾段，加 50 ms 清空余量。前缘和薄片内部轮廓随时间变化；不是把概念图或固定碎片贴图平移。边缘单独模式绘制实际细带，不借背景色遮盖整个人形。

## 复用示例

```gdscript
const Death = preload("res://scenes/vfx/cel/death.tscn")
const DeathConfig = preload("res://scripts/vfx/cel/death_config.gd")
var settings = DeathConfig.new()
settings.shard_direction_degrees = -50
var dissolve = Death.instantiate()
dissolve.configure(settings)
var contour = PackedVector2Array([
    Vector2(-35,-80), Vector2(30,-90), Vector2(45,-20),
    Vector2(5,0), Vector2(-40,-25)
])
if not dissolve.set_source_polygons([contour]):
    push_error(dissolve.source_error)
    dissolve.free()
    return
dissolve.position = Vector2(400,420)
add_child(dissolve)
dissolve.finished.connect(dissolve.queue_free) # 或保留后重新提交/重播
dissolve.play()
```

组件默认没有源且休眠。提交源不自动播放；`play()` 从 age 0 开始，`seek(seconds)` 停止自动播放并定格；负值/非有限时间为空。`stop()` 立即休眠，不发完成信号。自动到达 `config.duration()` 时发一次 `finished`，不自行删除。`clear_source()` 立即清除所有源衍生绘制和缓存；已有游戏对象何时隐藏或删除仍由宿主决定。

文件结构：

- `scripts/vfx/cel/death_config.gd`：纯表现配置与有限值校验。
- `scripts/vfx/cel/death.gd` / `scenes/vfx/cel/death.tscn`：通用多边形源组件。
- `scripts/vfx_lab/cel/death_lab.gd` / `scenes/vfx_lab/cel/death_lab.tscn`：仅此示范拥有简单人形/token 源；继承 `study_lab.gd` 的 UI、时间轴和录制。

## 测试与真实录像

```sh
godot --headless --script tests/vfx/cel/death_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/death_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-death.mp4
```

默认 **13 秒 / 780 帧 / 60 fps**：人形暗底正常重复、人形亮底半速，最后切换为 token 源并隐藏预备轮廓，展示半速纯效果。每帧等待真实 `frame_post_draw` 再保存 viewport，最终慢速段包含薄片完全消失。headless dummy 拒绝录像；概念、视频、帧及日志留在仓库外。

契约包括严格事务式源验证与预算边界、凹形/双绕向/多轮廓、深拷贝、源相关出生与方向、源形内侵蚀、独立层、生命周期、随机合法配置及密集相位/碎片出生消失边界三角化、完整录制时序，以及源切换、重播、暂停、编辑中断和拾色器关闭。测试状态与真实正常速度/逐帧视觉 review 分开报告；录像与编码结束后才对冻结最终树跑标准全套。

## 方法参考

生成概念为视觉依据。以下仅参考分层、时序和沿消解前缘释放粒子的原则，未复制第三方运行时代码、着色器或素材：

- [ParticleFX / Disintegrate Effect](https://www.particlefx.studio/effects/disintegrate-effect)
- [ParticleFX / Hit Flash and Dissolve](https://particlefx.studio/guides/hit-flash-and-dissolve)
- [ParticleFX / Character Disintegrate to Dust](https://www.particlefx.studio/effects/character-disintegrate-to-dust)
- SpriteFusion 免费 `energy` 配方：颗粒分层、移动和尾段缩散的原则，不采用其像素渲染器或源代码。
