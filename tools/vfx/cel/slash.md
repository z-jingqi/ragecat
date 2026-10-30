# 赛璐璐特效 / 02 金色弧形刀光

从用户确认的概念图出发：**一整道连续弯月、宽厚前端与收尖尾部、象牙白亮刃、金色主体和一块暖色内阴影**。不添加黑色外描边、像素网格、波浪、碎片或发光模糊。概念中的细碎毛边被收敛为清楚的连续轮廓，便于快速挥动时阅读。原有像素特效和盾牌命中完全不变。

## 运行与控制

Godot 4.6.3 Standard / Compatibility，1280×800，独立 F6 小样；F5 仍运行原游戏。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/slash_lab.tscn
```

**R** 重播，**Space** 暂停，**→** 前进 1/60 秒，**S** 正常 / ¼ 速度，**L** 循环，**B** 明暗底色，**X** 反向挥动，**A** 同一组件四角度对照，**P** 实时参数，**Esc** 关闭参数并释放输入焦点。更改参数或颜色自动重播，不回写 Inspector Resource。主视图最大 92% 尺寸、参数面板打开时最大 82%，按朝向自动取景，避免竖直刀光遮挡 UI；不改组件配置，尺寸/长度变化仍有可见差别。四角度模式固定为 0°、90°、180°、270°（等同 −90°），以 30% 尺寸并列展示；不是四种不同效果。

## 参数

| 参数 | 默认 / 范围 | 含义 |
|---|---|---|
| `size` | 1 / 0.25–2.5 | 整体尺寸倍率 |
| `length` | 760 / 160–1100 | 外弧横向直径，局部画布单位；实际端点宽度随弧度变化 |
| `thickness` | 128 / 6–220 | 最大径向厚度；最多为 length 的 35%，防止内弧翻转 |
| `curvature` | 0.56 / 0.3–1 | 纵向/横向半径比，控制弧线扁平程度 |
| `arc_degrees` | 210° / 60°–250° | 弧线的张开角，不是画面朝向 |
| `direction_degrees` | 0° / −180°–180° | 完整 360° 朝向；Godot 屏幕坐标正角顺时针 |
| `reverse` | false | 镜像整个挥动；先镜像，再按朝向旋转 |
| `sweep_seconds` | 0.08 / 0.025–0.25 s | 从尾部迅速扫出宽厚前端 |
| `peak_seconds` | 0.045 / 0–0.15 s | 完整弧形短暂停留并继续伸展 |
| `disappear_seconds` | 0.17 / 0.05–0.4 s | 尾部收回、厚度变窄直至消失，不透明渐隐 |
| `duration_scale` | 1 / 0.4–2 | 整体时长倍率，不改变同一相位的轮廓 |
| `extension` | 0.055 / 0–0.2 | 峰值的额外径向伸展，不生成第二道弧线 |
| 三种颜色 | 象牙白、金黄、暖棕金 | 亮刃 / 主体 / 内阴影，保持纯色不透明 |

默认完整视觉寿命 **295 ms**：80 ms 扫出、45 ms 伸展、170 ms 收缩。实验时间轴在 0.32 s 启动效果并间隔重播；可复用组件本身没有前摇。没有随机细节，故不暴露无意义的 seed；任意 age 与配置均完全确定。极端尺寸/旋转组合可能超出演示卡片，允许范围不是自动取景限制。

## 结构与复用

- `scripts/vfx/cel/slash_config.gd`：独立配置与有限值/安全范围校验。
- `scripts/vfx/cel/slash.gd`：纯效果 Node2D；最多三个连续纯色带，无演员、武器、背景、碰撞、伤害、粒子或像素依赖。原点是挥动弧的中心。
- `scenes/vfx/cel/slash.tscn`：休眠的一次性效果，由宿主显式播放。
- `scripts/vfx_lab/cel/slash_lab.gd` / `scenes/vfx_lab/cel/slash_lab.tscn`：可选独立实验场，拥有全部背景、UI、时间轴与录像逻辑。

```gdscript
const Slash = preload("res://scenes/vfx/cel/slash.tscn")
const SlashConfig = preload("res://scripts/vfx/cel/slash_config.gd")
var config = SlashConfig.new()
config.size = 0.5
config.direction_degrees = 90 # 任意方向可调，不固定偏左下
config.reverse = true
var slash = Slash.instantiate()
slash.configure(config) # 深拷贝再校验，不修改调用者资源
slash.position = Vector2(320,240)
add_child(slash)
slash.finished.connect(slash.queue_free) # 也可保留节点反复重播
slash.play()
```

`seek(seconds)` 停止自动播放并定格，不发出 finished；负值或非有限值清空。`play()` 从 age 0 重播；到达 `config.duration()` 仅发出一次 finished，不自动删除。`build_commands(age)` 可脱离场景求得确定性几何，便于测试。没有接入生产战斗，不改变任何现有攻击。

## 验证与真实 viewport 录像

```sh
godot --headless --script tests/vfx/cel/slash_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/slash_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-slash.mp4
```

12 秒 / 720 帧 / 60 fps：暗底正常两遍、暗底四分之一速度、亮底半速、四个方向并列半速。截图直接来自 Godot 实际渲染 viewport；headless dummy 拒绝录制。视频、帧、日志均放仓库外。无头检查覆盖生命周期、资源隔离、全部配置、密集相位边界、随机合法组合的三角化及完整录制时间轴，不代替视觉验收。

## 制作参考

用户已确认概念图为主要视觉依据。以下只用于方法参考，未复制第三方素材或运行时代码：

- [CGHOW / Project L Slash FX](https://cghow.com/project-l-slash-fx-in-unreal-engine-5-2-niagara-tutorial/)：以弧形轮廓、方向、尺寸和动态参数分离组织刀光。这里不采用其噪声/渐变，保留本次要求的干净纯色。
- [Godot / CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)：自定义多边形绘制和重绘生命周期。
- [Godot / 2D antialiasing](https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html)：细薄同色覆盖边的抗锯齿，不是黑色描边。
