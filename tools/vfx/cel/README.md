# 赛璐璐特效 / 01 盾牌命中

全新独立目录，从用户确认的蓝灰盾牌、象牙白核心与金色尖锐火花概念开始。**像素实验全部保留、不修改；本目录不依赖像素行为或渲染代码。** 本页记录首项命中；第二项独立刀光见 [02 金色弧形刀光](slash.md)。

## 运行

Godot 4.6.3 Standard / Compatibility，无需外部素材、插件或生成服务。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/shield_hit_lab.tscn
```

也可打开实验场景按 F6；F5 仍运行原游戏。原生 1280×800 画布，不经过低分辨率 viewport、像素取整或最近邻放大。纯色硬边分层，同色抗锯齿覆盖边缘，无黑色外描边、模糊发光或噪声轮廓。

**R** 重播；**Space** 暂停；**→** 前进 1/60 秒；**S** 1× / ¼×；**L** 循环；**B** 明暗背景；**E** 纯效果；**P** 参数；**Esc** 关闭参数并释放输入焦点。更改参数自动重播，Reset defaults 恢复默认。颜色可直接用拾色器编辑；修改仅影响运行时深拷贝，不回写 Inspector 资源。

## 参数

| 参数 | 默认 / 范围 | 用途 |
|---|---|---|
| `size` | 1 / 0.25–3 | 整体尺寸 |
| `direction_degrees` | 0° / −180°–180° | 入射方向，0° 向右，旋转完整效果和示范箭矢 |
| `duration_scale` | 1 / 0.4–2 | 整体时长倍率，不改变轨迹形状 |
| `flash_seconds` | 0.055 / 0.025–0.12 s | 核心峰值保持，随后短促收缩 |
| `spark_seconds` | 0.38 / 0.18–0.8 s | 最长火花寿命，Inspector / API 可调 |
| `spark_count` | 7 / 0–12 | 火花数量，0 关闭火花 |
| `spark_length` | 1 / 0.25–2 | 尖锥火花长度倍率 |
| `scatter` | 1 / 0.25–1.5 | 不规则角度图案的张开倍率 |
| `travel` | 1 / 0.4–2 | 火花飞行距离倍率 |
| `seed_value` | 27 | 可复现的随机种子；面板 0–9999，API 接受整数 |
| `show_arc` | true | 微弱压力弯月；可关闭 |
| 四种颜色 | 象牙白、金黄、橙金、灰白 | 核心 / 火花 / 硬边阴影 / 弯月；保持不透明 |

默认接触瞬间出现，16 ms 达到轮廓峰值，55 ms 后快速收缩；核心 132 ms 结束，弯月 220 ms 结束，末尾火花收缩清空，完整节点视觉寿命 420 ms。没有均匀放射烟花、连续漂浮尘埃或自动攻击。演示的箭矢在 0.48 s 接触，盾牌轻微回弹；演示回弹不是游戏击退。极端尺寸/飞行距离组合可能超出实验面板，这是可复用节点的允许范围。

## 结构与复用

- `scripts/vfx/cel/shield_hit_config.gd`：独立 Resource；范围、非有限值和颜色校验。
- `scripts/vfx/cel/shield_hit.gd`：纯效果 Node2D，原点就是接触点，没有箭矢、盾牌、背景、伤害、碰撞或屏幕震动。
- `scenes/vfx/cel/shield_hit.tscn`：可复用场景；初始休眠，宿主显式调用 `play()`。
- `scripts/vfx_lab/cel/shield_hit_demo.gd`：可选示范道具、飞行与回弹。
- `scripts/vfx_lab/cel/shield_hit_lab.gd` / `scenes/vfx_lab/cel/shield_hit_lab.tscn`：独立时间轴、实时面板、录制。

```gdscript
const HitScene = preload("res://scenes/vfx/cel/shield_hit.tscn")
const HitConfig = preload("res://scripts/vfx/cel/shield_hit_config.gd")
var config = HitConfig.new()
config.size = 0.75
config.direction_degrees = -30
var hit = HitScene.instantiate()
hit.configure(config) # 深拷贝并校验；添加节点之前也有效
hit.position = Vector2(320, 200)
add_child(hit)
hit.finished.connect(hit.queue_free) # 也可保留节点重播，由宿主决定
hit.play() # 接触即 age 0，无内置前摇
```

`seek(seconds)` 手动定格并停止自动播放；不触发 `finished`。`build_commands(age)` 返回确定性的多边形纯色命令；不需要场景或显示设备，便于测试。自动播放到 `config.duration()` 发出一次 `finished`，不自动删除节点。

## 验证与真实录制

```sh
godot --headless --script tests/vfx/cel/shield_hit_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/shield_hit_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-shield-hit.mp4
```

10 秒 / 600 帧 / 60 fps：暗底正常速度两遍、亮底半速一遍、纯效果半速一遍。来自实际 Godot viewport，不是生成概念图或重建视频。headless dummy 会拒绝截图；截图、视频、日志留仓库外。

聚焦检查覆盖确定性、生命周期、可配置项、资源隔离、几何可三角化、参数信号及播放控件；无头测试不代替实际视觉验收。该小样未接入生产战斗，也不是素材导出器或 Unity 实现。

## 设计参考

只参考形状和时序原则，不复制第三方运行时代码或素材：
- [ParticleFX / Timing](https://www.particlefx.studio/guides/2d-vfx-timing)：极短峰值，随后消散。
- [ParticleFX / Cartoon FX](https://www.particlefx.studio/cartoon-fx)：少量纯色层、弹出与收缩，而非透明模糊。
- [Riot / Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)：重要度层级、方向可读性和控制视觉噪声。
