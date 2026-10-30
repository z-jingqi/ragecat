# 赛璐璐特效 / 07 持续火焰

从本项生成概念出发：宽而明亮的火根、橙红外焰、橙色火身、向上流动的金黄内层与少量象牙白热核；三条不等高火舌弯卷、变窄、断开，脱离的小火舌和火屑继续上升、变形并收缩。保留清楚的纯色分层，不采用黑色描边、像素网格、模糊辉光或整张图左右摆动。

火焰边界、内部通道和断裂位置有沿火舌传播的局部运动，**不是缩放/倾斜/平移一个静态火焰标志**。默认是点燃—持续—熄灭的一次性效果，也可由宿主持有持续状态，再显式 `release()`。组件没有角色、灼伤状态、伤害、碰撞或地面危险逻辑；原有像素及赛璐璐工作保留，不接回生产战斗。

## 运行与控制

Godot 4.6.3 Standard / Compatibility，1280×800。独立场景按 F6；F5 仍运行原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/fire_lab.tscn
```

**H** 切换持续保持，**F** 开始熄灭；**R** 重播，**Space** 暂停，**→** 单步 1/60 秒，**S** 正常 / ¼ 速度，**B** 明暗背景，**E** 隐藏通用源位置示意线，**P** 参数，**Esc** 关闭参数/拾色器并释放输入焦点。修改配置即时重播，不回写 Inspector Resource。

持续保持未释放时不自动重播；释放后完整尾段和空白间隔结束，**实验场**会按当前模式重播，便于观察。组件自身不自动重播。重播保留 H 模式但清除上次释放时间；Reset defaults 退出保持并恢复默认。暂停时按 F 仍保持暂停，只记录熄灭时刻；重复 F 不刷新尾段。有限模式已自动熄灭后按 F 不会重新点燃。

状态栏 **VIEW** 是自动取景倍率，不是效果 `size`。取景固定采样完整有限周期，不会因上一次提前熄灭只剩小火苗而把下一次点燃错误放大。极端尺寸可缩小取景，但组件配置不变。

## 生命周期 API

```gdscript
configure(settings)                         # 深拷贝并校验
play(hold_sustain: bool = false)            # age=0，清除旧释放状态
release()                                  # 从当前真实时间开始熄灭，幂等
stop()                                     # 立即清空，不发 finished
seek(seconds, released_at = -1.0,
     hold_sustain = false)                  # 重建并暂停
get_end_time() -> float                     # 绝对终止 age；未释放保持时为 INF
build_commands(at_age = -INF,
               released_at = -INF) -> Array
```

`age`、`release_at`、`seek()` 与 `build_commands()` 的释放时间均为**实际秒数**，已包含 `duration_scale`，不是内部归一化时间。

- 普通 `play()` 在点燃与持续阶段结束后自动熄灭，完整结束时发一次 `finished`；不自动删除节点。
- `play(true)` 保持火焰，直至 `release()`；内部仅枚举当前仍存活的断焰/火屑，即使保持数小时也不积累历史粒子节点。
- `release()` 记录第一次有效释放时间，不把暂停状态改成播放；休眠、完成、重复调用和有限模式已经自动熄灭后的调用均被忽略。
- 点燃未完成时释放，先锁定当前生长程度，再逐渐缩散，不会继续长成完整火焰。附着火身结束后，已出生的小火舌和火屑走完各自尾段。
- `seek(t, release, false)` 中晚于自动熄灭的显式释放时间会按自动时间钳制，不能延长普通有限模式。`seek(t, release, true)` 才允许任意较晚的保持释放；公开 `release_at` 保留输入秒数，`get_end_time()` 使用有效时刻。
- `build_commands(t)` 使用节点当前释放状态；第二参数 **−1** 强制有限自动周期，**+INF** 强制未释放保持，非负有限值显式指定释放时刻（仍遵守节点的 `holding` 模式）。默认 **−INF** 是使用节点状态的哨兵。NaN 或其他负释放值返回空命令。
- `seek()` 停止自动推进，不发完成信号；无效 age 安全休眠。`stop()` 清除 age、保持与释放状态。宿主自行决定节点回收。

默认有限周期 **2.24 s**：150 ms 点燃、1.10 s 持续、400 ms 主体熄灭、最多 550 ms 火屑余量与 40 ms 清空余量。保持释放后的结束时刻为：

`release_at + (release_seconds + ember_seconds + 0.04) × duration_scale`

## 参数

| 参数 | 默认 / 范围 | 含义 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 绕宽火根原点旋转所有层；0° 默认向上 |
| `intensity` | 1 / 0.25–2 | 火身与上升运动强度 |
| `seed_value` | 59 | 可复现的流动相位与火屑布局 |
| `base_width` | 180 / 80–320 | 火根与各火舌横向尺度 |
| `height` | 220 / 80–360 | 主火舌高度 |
| `curl` | 1 / 0–2 | 火舌弯卷与脱离片横向偏移 |
| `flow_speed` | 1 / 0–3 | 内部与边界传播速度；0 冻结附着火焰流动和断焰生成，仍保留独立火屑发射设置 |
| `ember_rate` | 8 / 0–24 每基准秒 | 独立细火屑生成频率；0 关闭火屑 |
| `duration_scale` | 1 / 0.4–2 | 全阶段时长倍率 |
| `ignition_seconds` | 0.15 / 0.06–0.5 s | 点燃与生长时间 |
| `sustain_seconds` | 1.10 / 0.2–4 s | 普通模式完整燃烧时间；保持模式不自动到期 |
| `release_seconds` | 0.40 / 0.15–1 s | 主体熄灭时间 |
| `ember_seconds` | 0.55 / 0.2–0.9 s | 火屑最长寿命与断焰尾段基准 |
| `show_body` | true | 附着的红橙外沿与主体 |
| `show_channels` | true | 向上流动的金黄内部通道，包括脱离火舌中的对应内层 |
| `show_core` | true | 火根局部象牙白热核，不铺满整根火柱 |
| `show_detached` | true | 从上端断开的较大火舌 |
| `show_embers` | true | 细火屑 |
| 五种颜色 | 橙红、橙、金黄、象牙白、浅金 | 外沿 / 主体 / 内层 / 热核 / 火屑，保持纯色不透明 |

时间倍率改变实际点燃、传播、释放与寿命速度，不改变同一归一化相位的轮廓。`flow_speed` 只控制持续运动，不改变有限周期的总时长；火根固定于节点原点，不依赖移动宿主。

## 复用示例

```gdscript
const Fire = preload("res://scenes/vfx/cel/fire.tscn")
const FireConfig = preload("res://scripts/vfx/cel/fire_config.gd")
var settings = FireConfig.new()
settings.size = 0.7
settings.height = 260
var flame = Fire.instantiate()
flame.configure(settings)
flame.position = Vector2(400,420)
add_child(flame)
flame.finished.connect(flame.queue_free) # 或保留重播
flame.play(true) # 宿主持有，独立于任何攻击/灼伤系统
# 在宿主自己的停止事件中：flame.release()
```

普通短火焰用 `play()`；需要立即取消时用 `stop()`。配置与绘制命令可以离线求值，但录像始终使用实际渲染 viewport。

- `scripts/vfx/cel/fire_config.gd`：独立资源、范围和非有限值校验。
- `scripts/vfx/cel/fire.gd` / `scenes/vfx/cel/fire.tscn`：纯火焰组件，点燃/保持/释放、局部流动与有界发射。
- `scripts/vfx_lab/cel/fire_lab.gd` / `scenes/vfx_lab/cel/fire_lab.tscn`：实验源位置线、控制、完整 18 秒录制；继承通用 study UI，不把演示依赖带进组件。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/fire_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/fire_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-fire.mp4
```

**18 秒 / 1080 帧 / 60 fps**：前 6 秒暗底正常循环；接着 6 秒亮底半速完整有限周期；最后 6 秒暗底半速保持，在效果 age **1.50 s** 释放，包含到 **2.49 s** 完全结束后的空白。默认共用 13 秒模板不足以覆盖本项尾段，因此火焰使用独立录制时序。

逐帧等待 `RenderingServer.frame_post_draw` 并读取真实 Godot viewport，headless dummy 拒绝录制。概念、视频、帧与日志留在仓库外。聚焦契约检查完整仿射变换消除后的真实形变、内层相对流动、零流速、长时间保持的有界几何、释放时刻/幂等/暂停/重播、极端配置和相位边界三角化、精确录制时序，以及实际控制的重复与中断路径。视觉 review 与测试通过分开报告；渲染和编码结束后，对冻结最终树运行标准完整测试。

## 方法参考

生成概念是造型依据。以下只参考火焰层次、持续发射和时序原则，不复制第三方运行时代码或素材：

- [ParticleFX / Fire Pillar](https://particlefx.studio/effects/fire-pillar)
- [ParticleFX / Ground Fire Hazard](https://particlefx.studio/effects/ground-fire-hazard)
- SpriteFusion 免费 `fire` 配方：上升、分层、寿命和独立发射的原则；本实现不采用其像素绘制、模糊光或源代码。
