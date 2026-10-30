# 赛璐璐特效 / 04 飞行能量弹

独立飞行表现，不依赖蓄力光球、聚拢光线、角色、碰撞或伤害系统。现有像素与赛璐璐组件全部保留。**圆头、长尾和象牙白内芯是同一个连续轮廓的分层，不是光球加 Line2D。**

## 运行

Godot 4.6.3 / Compatibility，无插件、外部下载或生成服务。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/energy_bolt_lab.tscn
```

独立 F6 场景；F5 仍运行原游戏。默认展示金色参考速度的能量流动；前 5 秒没有背景标记，相机稳定跟随，以便直接检验内部与周边动画，而非用位移制造活力。其余运动模式的世界标记帮助辨认实际速度。正常速度、加速、减速与连续转弯分别演示；低速缩短尾巴，高速拉长，头部的前缘和尖角造型不换成另一张图。

- **1–4**：参考匀速 / 加速 / 减速 / 转弯。
- **R** 重播，**Space** 暂停 / 继续，**→** 前进 1/60 秒。
- **S** 正常 / ¼ 播放速度；慢放改变实验时间推进，不伪造世界速度。
- **C** 金色 / 青绿色；**P** 实时参数面板；**Esc** 关闭面板、拾色器并释放输入焦点。
- 尺寸、头部高度、起始方向、参考速度、尾长上下限、响应时间，以及内部流动、脉动、周边光片和五种颜色均可调整。Reset defaults 恢复金色参考模式和全部默认参数。

## 造型与运动

`energy_bolt_shape.gd` 保存从已确认概念图测量的轮廓、浅金层与连续象牙白层：右侧圆头、左侧单一长尖尾、上下非对称缺口、向后的内切面、两条细小游离速度线。参考坐标为 1774×887，主轮廓高度 342；边界去除一像素采样噪声后保留尖端。运行时只提交抗锯齿硬边纯色几何，没有黑描边、噪声波浪、模糊光晕或放射尖刺。概念图的细微渐变/颗粒归并为三种可调纯色；并非逐像素复制图片纹理。

宿主每次传入**移动后的实际世界位置**与真实模拟时间差。组件以位移 / 时间测量速度，不接受目标速度来伪装尾长；尾长按实际速度 / 参考速度映射并限幅，指数响应不依赖帧率。默认参考速度下尾长恰为 1×。整套轮廓沿有界的世界空间路径历史变形，包括内芯和细小速度线；正面仍保持连贯圆头。历史采样间距与数量上限限制开销。

瞬移或单步突然反向会重新建立路径，不画贯穿地图的连线。非常厚的主体在很紧的转弯上统一压缩横向宽度，避免内侧折叠；过久绕行的旧轨迹被截断并以最后切线延展，不把自身绕回头部。正常参考轮廓不受这些保护影响。

| 参数 | 默认 | 作用 |
|---|---:|---|
| `size` | 1 | 整体尺寸倍率 |
| `head_height` | 96 px | 参考轮廓高度 |
| `direction_degrees` | 0° | 没有实际运动时的初始方向 |
| `reference_speed` | 640 px/s | 1× 原轮廓所对应的速度 |
| `tail_min` / `tail_max` | 0.38 / 1.65 | 尾段长度上下限，前部不随尾长拉伸 |
| `response_seconds` | 0.12 s | 尾长指数响应时间常数 |
| `sample_distance` | 3 px | 路径历史采样间距 |
| `history_limit` | 256 | 历史点上限 |
| `teleport_distance` | 1200 px | 单步异常位移保护 |
| `detached_streaks` | true | 游离尾线 / 动态周边光片开关 |
| 三种颜色 | 象牙白 / 浅金 / 金色 | 内芯、主体与下侧阴影 |

`configure()` 深拷贝并校验 Resource，不回写调用者设置。位置、时间、颜色及数值都有有限值保护。

## 内部与周边动画

在实际匀速且跟拍位置固定时，内部能量仍持续向尾端流动：独立批次的细长尖舌具有不同出生偏移、长度与寿命；金色/象牙白的真正分界也有独立向后的压力切口，而不只是覆盖几条移动贴片。连续内芯只做小幅异步形变与亮度变化，所有绘制保持不透明；没有周期波浪、透明闪烁或同时明灭。

周边光片从上下边缘以独立世界位置出生，沿后方与略向外的速度移动，短寿命结束时收束消失。它们不附着在头部，也不是旧的两条静态尾线。活跃光片限制为 24，单步出生限制为 12。将 `flow_strength`（或 `flow_speed`）、`core_pulse_amplitude`、`edge_shed_rate` 都设为 0，可恢复原有静态参考分层及两条尾线；不影响实际速度驱动的尾长与转弯。

| 动画参数 | 默认 | 作用 |
|---|---:|---|
| `flow_speed` / `flow_strength` | 1.4 / 1.0 | 内部后流速度与幅度（0 关闭） |
| `core_pulse_amplitude` / `core_pulse_rate` | 0.045 / 4.6 Hz | 克制的内芯压力与亮度脉动 |
| `edge_shed_rate` | 11 / s | 不规则光片发射频率（0 恢复静态尾线） |
| `edge_lifetime` | 0.24 s | 周边光片基准寿命 |
| `edge_length` / `edge_speed` | 26 px / 220 px/s | 光片长度与独立后掠速度 |
| `flow_color` / `spark_color` | 浅金 / 亮象牙 | 内部纹路与周边光片颜色 |

## 复用

```gdscript
const BoltScene = preload("res://scenes/vfx/cel/energy_bolt.tscn")
var bolt = BoltScene.instantiate()
add_child(bolt)
bolt.reset_motion(projectile.global_position,Vector2.RIGHT)

# 在宿主移动投射物之后调用；不要给一个虚构的动画速度。
func _physics_process(delta: float) -> void:
    projectile.global_position += velocity*delta
    bolt.advance(projectile.global_position,delta)

# 宿主决定何时销毁，组件不自动命中、发射或排队删除。
bolt.stop() # 立即清空表现和历史；reset_motion() 可复用。
```

新节点初始休眠。`reset_motion(position, direction=Vector2.ZERO)` 开始新的路径；零方向使用配置角度。`advance(position, delta)` 测量速度、更新历史与轮廓。暂停时不调用 advance；停止移动但仍希望尾巴收短且内部流动继续时，持续以相同位置调用。`motion_snapshot()` 提供实际速度、尾长倍率、有界历史、能量时间及光片计数；`build_commands()` 提供当前动态纯色多边形，`build_commands(false)` 单独提供无内部动画的运动变形基线，`build_reference_commands()` 提供未经运动变形的基准几何，便于测试。

## 验证与实际录像

```sh
godot --headless --script tests/vfx/cel/energy_bolt_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/energy_bolt_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-energy-bolt.mp4
```

20 秒 / 1200 帧 / 60 fps：5 秒金色参考匀速跟拍、4 秒加速、4 秒减速、4 秒转弯、3 秒青绿色转弯与参数。来自真实 Godot viewport；headless dummy 拒绝录像。原始帧、视频、比较图与日志留仓库外。完整回归和最终聚焦测试不与渲染/编码并行。

## 设计参考

批准的概念图是造型依据。研究成熟引擎的空间采样原则以及动画能量弹的分层运动，未复制第三方素材或运行时代码：

- [Unity TrailRenderer / minVertexDistance](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/trailrenderer/minvertexdistance)：按实际移动距离采样；点间距在平滑与成本间取舍。
- [Godot Curve2D](https://docs.godotengine.org/en/stable/classes/class_curve2d.html)：按距离采样路径及切线。此组件使用自身有界历史，避免普通等宽 Trail 取代已确认轮廓。

- [ParticleFX Studio / Anime Fireball](https://www.particlefx.studio/effects/anime-fireball)：实际查看 24 帧循环与逐帧图，借鉴独立内部流动、边缘剥离与短寿命余片；不采用其墨线、圆瓣团块或烟雾，仍以已批准的圆头长尾造型为准。
