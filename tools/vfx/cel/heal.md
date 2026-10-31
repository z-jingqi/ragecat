# 赛璐璐特效 / 12 治疗与升级

生成概念：`libfile_62df9c098c848191913c58efe639044b`（v0）。治疗使用玉绿 / 薄荷色向上生长的宽叶带、象牙白展开十字、断开的足底弧；升级使用金色双重尖角、独立伸缩的四芒冠星、侧翼叶带与上升细线。两者是不同几何配方，不是同一效果换色。平滑、不透明硬色块，无黑色描边、像素格、模糊辉光或角色剪影。

这是独立视觉组件。没有治疗数值、血量、经验值、升级判断、角色、碰撞、伤害或镜头逻辑。局部原点在效果底部，默认向 −Y 上升。原有像素和赛璐璐效果与游戏均保留。

## 实验场

```sh
godot --path . res://scenes/vfx_lab/cel/heal_lab.tscn
```

Godot 4.6.3 Standard / Compatibility，1280×800；独立场景 F6，F5 仍运行原游戏。

- **1** 治疗，**2** 升级；切换模式重新播放，两套调色板分别保留。
- **R** 重播，**Space** 暂停，**→** 单步 1/60 秒，**S** 正常 / ¼ 速度。
- **B** 明暗背景，**E** 隐藏实验场来源短线，**P** 参数面板，**Esc** 关闭面板与拾色器、释放焦点。
- 参数 `Mode` 的 0 / 1 与顶部有名字的模式按钮一致。所有数值、开关和八个颜色可实时编辑；Reset 恢复治疗默认值。
- `VIEW` 只是按完整有限周期取样的实验场取景倍率，不改变组件的 `size`。

## API

```gdscript
configure(settings) # 深拷贝并校验，null 恢复默认
play()              # age=0，从头开始一次
stop()              # age=-1，立即清空；不发完成信号
seek(seconds)       # 重建并暂停，不发完成信号
build_commands(at_age = -INF) -> Array
# finished 信号：真正播放到结束只发一次；不会自行删除节点
```

配置脚本 `scripts/vfx/cel/heal_config.gd` 的 `Mode.HEAL = 0` 与 `Mode.LEVEL_UP = 1` 决定配方。`config.duration()` 是真实秒数；默认 **2.14 s**（250 ms 足底聚集 + 550 ms 展开 + 650 ms 持续 + 650 ms 收尾 + 40 ms 清空余量）。`duration_scale` 同时缩放全部时间。负数、NaN、±INF 的 seek 休眠；`build_commands()` 默认 −INF 取节点 age，其他无效或结束时间返回空。

`build_commands()` 纯求值、无随机流副作用、不修改播放状态。每条命令含 `points: PackedVector2Array`、`color: Color`、`layer: String`、`source_id: int`。同一来源叶带 / 箭翼的色面共享形变场，便于独立测试与组合；source_id 不代表额外节点。所有多边形最终统一应用 `size` 与 `direction_degrees`。

## 关键参数

| 参数 | 默认 / 范围 | 含义 |
|---|---|---|
| `mode` | 0 / 0–1 | 治疗 / 升级的不同配方 |
| `size` | 1 / 0.25–3 | 整体缩放 |
| `direction_degrees` | 0° / −180°–180° | 围绕底部统一旋转 |
| `intensity` | 1 / 0.25–2 | 叶带、符号和星芒宽度 |
| `seed_value` | 307 | 固定小叶 / 细线分布与符号微差 |
| `height` | 270 / 120–360 | 上升高度 |
| `spread` | 115 / 65–180 | 横向铺展与足底弧半径 |
| `ribbon_width` | 30 / 12–50 | 宽叶带截面 |
| `curl` | 1 / 0–2 | 叶带弯曲程度 |
| `glyph_count` | 5 / 0–7 | 仅治疗十字数量；升级始终双尖角和一颗冠星 |
| `glyph_size` | 18 / 9–30 | 十字、尖角厚度和冠星尺寸 |
| `rise_speed` | 1 / 0–2 | 符号及尾段上升偏移；0 不取消展开 / 收缩 |
| `flow_speed` | 1 / 0–3 | 叶带与色面内流；0 不取消出生 / 消散 |
| `duration_scale` | 1 / 0.4–2 | 整体时间倍率 |
| `gather_seconds` | 0.25 / 0.1–0.6 s | 足底弧聚集 |
| `bloom_seconds` | 0.55 / 0.2–0.9 s | 叶带生长、符号展开 |
| `sustain_seconds` | 0.65 / 0.15–1.5 s | 形态清晰保持与内部运动 |
| `release_seconds` | 0.65 / 0.3–1 s | 叶尾脱离、符号收回、向上消散 |

八个独立开关：`show_arcs`、`show_ribbons`、`show_highlights`、`show_glyphs`、`show_chevrons`、`show_star`、`show_streaks`、`show_motes`。`show_ribbons` 控制叶带底色与主体色；叶带高光由 `show_highlights` 独立控制。箭翼全部由 `show_chevrons` 控制，其中高光还受 `show_highlights` 控制。治疗不会出现尖角 / 星，升级不会出现十字；开关不重排随机序列，也不改变其他层的几何。

两套独立硬色：`heal_shadow_color`、`heal_body_color`、`heal_highlight_color`、`heal_glyph_color`；以及同后缀的 `level_*`。RGB 校验并钳到 0–1，alpha 固定为 1，避免透明辉光代替清晰轮廓。

## 运动不是移动整张图片

- 三条治疗叶带 / 两条升级侧带的头部先沿曲线生长，底部尾端随后追赶并脱离；中心线及内部色面持续变形。水平截面与严格单调的 Y 保证最大弯曲仍是简单多边形，高光使用同一截面而不是另一个移动贴图。
- 治疗十字先是窄竖线，左右臂与上下臂分时展开、分时缩回。五个符号有不同出生位置与节奏，并保持稀疏阅读，不用大批细碎十字淹没主体。
- 升级的两枚尖角分别展开两翼、上流、变薄；高光是同一来源三角面内的重心插值。冠星四个方向分时伸缩，侧带与纵线不依赖冠星开关。
- 足底弧是断开的弧段，沿底面旋转并逐步收窄；小叶片是少量二级节奏，不扩张为无限粒子池。

## 复用示例

```gdscript
const HealScene = preload("res://scenes/vfx/cel/heal.tscn")
const HealConfig = preload("res://scripts/vfx/cel/heal_config.gd")
var settings = HealConfig.new()
settings.mode = HealConfig.Mode.LEVEL_UP
settings.height = 240
var visual = HealScene.instantiate()
visual.configure(settings)
visual.position = Vector2(400,500)
add_child(visual)
visual.finished.connect(visual.queue_free)
visual.play()
```

## 测试与真实录像

```sh
godot --headless --script tests/vfx/cel/heal_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/heal_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-heal-levelup.mp4
```

**24 秒 / 1440 帧 / 60 fps**，四段各 6 秒：治疗暗底正常、治疗亮底半速、升级暗底正常、升级亮底半速纯效果。正常段有两次完整循环，半速段一次完整循环；每段结尾均完全清空。`capture_pose(frame)` 公开同一确定时间表用于测试。每帧在 `frame_post_draw` 后读取真实 Godot viewport；headless dummy 拒绝录制。概念、录像、帧与日志保存在仓库外。

## 方法参考

只参考原则，不复制运行时代码或素材：

- [Godot 4.4 官方 2D 自定义绘制](https://docs.godotengine.org/en/4.4/tutorials/2d/custom_drawing_in_2d.html)：Node2D 自定义绘制与重绘生命周期。
- [Godot 官方 ParticleProcessMaterial](https://docs.godotengine.org/en/stable/classes/class_particleprocessmaterial.html)：出生、寿命与速度应独立控制的参数原则；本组件不依赖粒子材质运行时。
- [SpriteFusion Heal 免费配方](https://www.spritefusion.com/pixel-art-vfx/heal) 与 [Power Up 免费配方](https://www.spritefusion.com/pixel-art-vfx/power-up)：分阶段上升符号、足底扫弧到上升光环再到尾段。未采用其 TypeScript、像素、抖色、模糊或角色图层。
