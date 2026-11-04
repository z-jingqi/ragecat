# 刑天 · 赤铜挥砍与短促命中

Godot 4.6.3 Standard / Compatibility。借鉴已验收的 SpriteFusion Slash 复刻：倾斜椭圆上的亮刃快速扫出，内侧细回声晚一帧出现，七阶暖铜色逐步冷却，尾端追赶并留下短暂细线。保留轻微破口；新增独立的两拍命中亮核、脱离碎片和断续压力弧，火星热头逐步冷却，三束以内的短血丝衔接可关闭血滴。角色没有攻击动画。

仅独立视觉组件与预览，不改玩法、血量、伤害、攻击频率、碰撞或技能规则。这里不是 SpriteFusion 原版复刻目录。本轮明确以仓库中已复刻 Slash 的原生关键帧、配方和代码作为设计起点；借鉴轮廓、层次、时序，独立实现 shader，不依赖原版运行时，也不改原版。原始来源仍是实际调用过的 SpriteFusion MCP Slash / Blood 和 PixelFX 工具。来源、取舍与 MIT 许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 本轮参考与取舍

- 参考：[已复刻 Slash](../../spritefusion_exact/reports/slash.md)、[配方](../../spritefusion_exact/recipes/slash.md)、[原生关键帧](../../spritefusion_exact/previews/slash/native-keyframes.png)。
- 保留的视觉规律：指数起手、倾斜椭圆、前重后细的刀刃、内层回声、七阶明暗、Bayer 尾部消散与收尾细线。
- 默认节奏对齐参考的 0.06s 扫出 / 0.06s 保持 / 0.24s 收尾，自己的残线最多再留 0.12s。
- 刑天的二次设计：暖白切边到赤铜暗红，更厚的单次劈砍，轻微缺口、小而克制的刀尖亮点和暖光。没有原版大光晕、16枚飞屑、连击调度或相机震动。
- 火星和血液仍由显式 `play_hit` 驱动。刀尖亮点属于挥砍本身，不代表碰撞发生。

## 运行

```sh
godot --path preview/xingtian-slash-godot
godot --headless --path preview/xingtian-slash-godot --script tests/test_slash.gd
godot --headless --path preview/xingtian-slash-godot --script tests/test_hit.gd
```

也可在 Godot 导入本目录 `project.godot`，F5。默认入口为 `hit_preview.tscn`；认可的旧挥砍工作台保留为 `preview.tscn`，可单独 F6。没有外部插件、网络、预制图集或绝对路径依赖。

主视图显示组合及两个静止的原创几何人形，仅说明尺寸与命中位置；不是刑天角色素材，也没有挥动、受击或行走动画。下方分别显示独立命中、火星、血滴与带静止尺寸参照的 1× 原始像素组合。

- 弧面、命中、火星、血滴四层可单独开关，重播保留开关。Hit / Miss 显式切换展示命中与挥空；挥空没有任何命中层。
- 默认命中工作台的滑块控制命中半径、亮核时长、命中总时长、强度和血滴数量。旧挥砍工作台仍控制弧面范围、厚度和时长。
- Pause 暂停，Replay 重新播放，Clear 完全清除；Clear 后时间轴和参数编辑不会复活效果，必须 Replay。
- 时间轴可暂停定位。0.25× 仅供慢放观察，默认 1×。当前录像分为正常、0.25× 慢放、关闭血液、挥空四段，各3秒。
- Mirror 水平镜像（不把弧面旋到角色下方），BG 切换背景，Default / Heavy 切换两个预设。
- 主图使用整数 3× 或 2× 缩放；下方命中小图默认为 2×，大范围自动改为 1×，实际游戏尺寸组合为 1×，双向与最大范围都不跨出面板。
- 预览为固定逻辑 1280×800 的 viewport。小窗口可能缩放显示，但录制与渲染探针保留原始像素。

预览每次在 `onset` 后模拟一次命中，只是展示脚本。**组件不会因为挥砍播到某一时刻就自动喷血**，真正宿主需要显式调用 `play_hit`。

## 组件与调用

全部组件由宿主时钟驱动，无 Timer、随机全局状态、物理查询、自动释放或角色变换。

- `components/copper_arc.gd`：单独赤铜弧面，独立 ShaderMaterial。
- `components/hit_impact.gd`：40ms 两拍亮核，随后四块铜色碎片与两段压力弧，总计160ms；所有时序按秒，不按调用次数。
- `components/hit_particles.gd`：单独命中粒子；`blood=false` 火星，`blood=true` 血滴。
- `components/xingtian_slash.gd`：可选的四层组合，不做命中检测。
- `components/slash_profile.gd`：Inspector 可编辑配置，两个 `.tres` 预设。

```gdscript
const Slash = preload("res://components/xingtian_slash.gd")
var effect = Slash.new()
add_child(effect)
var settings = load("res://presets/default.tres").duplicate()
settings.radius = 52.0
settings.impact_radius = 12.0
settings.impact_duration = 0.16
settings.blood_count = 9
settings.blood_enabled = true
effect.play(Vector2(120, 120), settings) # 仅挥砍
# 实际命中事件到来时，由宿主提供接触点：
effect.play_hit(Vector2(164, 110), settings)
effect.advance(delta)
effect.set_layer_enabled("blood", false)
effect.stop() # 清除所有层，之后必须 play / play_hit
```

弧面组件的生命周期为 `duration + thread_duration`，到时完全清空；残线关闭时最后一段可能为空。所有光与回声配置都存储在同一个可复制的 Profile 中。

独立组件均支持 `play(origin, configuration)`、`advance(delta)`、`seek(seconds)`、`set_enabled(bool)`、`stop()`、`clear()`。`play` 复制并清洗配置，不会修改调用方；错误 Resource 类型回退默认，NaN/Infinity 参数清洗，非法位置停止该实例，负 delta 或非有限时间不推进。

自然播放结束后可倒回查看。stop/clear 后 seek 不会复活。组合再次 play 会清掉旧命中；再次 play_hit 替换前一组命中、火星和血滴。需要同帧多个敌人命中时，由宿主创建多个独立命中实例。

## 参数与视觉边界

| 参数 | 默认 | 有效范围 / 含义 |
|---|---:|---|
| radius / thickness | 52 / 12 | 20–88 / 4–28 像素；厚度最多半径一半，滑块同步显示实际清洗值 |
| sweep_degrees | 200 | 50–220°，弧面总角度 |
| direction_degrees / reverse | −22 / false | −180–180°；reverse 反向扫动，不移动角色 |
| squash / roughness | 0.6 / 0.45 | 0.45–1 / 0–3 像素，椭圆和固定缺口 |
| pixel_size / shape_seed | 1 / 19 | 1–3 整数像素 / 0–65535，同种子可重播 |
| duration / onset / hold | 0.36 / 0.06 / 0.06 s | 0.12–0.6 / 0.025–0.09 / 0–0.08；onset 最多总时长40%，hold 最多20% |
| intensity | 1 | 0–1.5；0完全不画，非HDR颜色限于0–1 |
| edge / highlight / body / inner / shade / tail / dark | 暖白 / 金铜 / 亮铜 / 赤铜 / 暗红 / 暗紫 / 深暗 | 七个可改颜色，硬像素色带 |
| facing_left | false | 水平镜像刀刃、预览接触点与粒子速度，重力方向不变 |
| sweep_center_degrees | −46° | 椭圆上的弧段中心，−180–180°，独立于整体 tilt(direction) |
| echo_enabled / thread_enabled / glint_enabled | true | 内侧回声、收尾细线、刀尖小亮点可分别关闭 |
| glow_strength / thread_duration | 0.16 / 0.12s | 0–0.4 的局部暖光 / 0–0.2s 最大残线延长 |
| impact_radius / duration / core_duration | 12px / 0.16s / 0.04s | 6–24px / 0.09–0.24s / 0.02–0.06s；独立于挥砍时长与伤害 |
| impact_enabled / impact_fragments_enabled / impact_ring_enabled | true | 总命中、脱离碎片、两段断续压力弧可分别关闭；沿用赤铜五阶色 |
| blood_filaments_enabled | true | 最多三束1像素短血丝，75ms内脱离；血液开关或数量0同时关闭 |
| spark_count / duration / speed | 6 / 0.24 s / 76 | 0–16 / 0.08–0.5 s / 10–120 像素每秒 |
| blood_count / duration / speed | 9 / 0.42 s / 92 | 0–20 / 0.15–0.8 s / 10–160 像素每秒 |
| sparks_enabled / blood_enabled | true / true | 可分别关闭；数量0同样完全不画 |
| spark_color / blood_color / blood_shade | 暗铜红 / 血红 / 暗血红 | 独立可调，不复用角色纹理 |

所有 radius 都是美术范围，不能当作碰撞半径或平衡数据。血液以至多三束短血丝、1–2像素点与短尾表现，逐个落下并收净，不包含血雾、大血池或伤口。强度不会增加数量；放大范围不会擅自增加血量。

## 检查和录制

`tests/test_hit.gd` 增加独立命中、30/60fps首拍、清空/重播、参数、血丝与挥空交互检查。`tests/test_slash.gd` 检查配置隔离、边界、时间、重复播放、独立实例、显式命中、关闭血滴、清除后不复活和预览控件。

有图形显示时执行真正的渲染检查：

```sh
XINGTIAN_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --script tests/render_probe.gd
XINGTIAN_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/slash.avi -- --capture
```

先创建输出目录。探针检查实际 viewport 像素的起止清空、收尾、重复帧、朝向、最大旋转范围、零强度、改色和血滴密度。12秒新录制包含正常速度、0.25×慢放、关闭全部血液，以及挥空。Heavy配置仍可通过工作台按钮手动查看。

这些检查不是游戏内验收，也不承诺跨GPU浮点逐像素相同。MovieWriter固定60fps只是展示时间轴，不是实时性能成绩。最终审查记录见 [QA.md](QA.md)，用户视觉确认仍单独进行。

## 命中参考与独立实现

本轮从远端 `043c68f03d2075e0a1bf57359c831551b2315d39` 开始。认可的
`copper_arc.gd` 和 `copper_arc.gdshader` 不变。新增命中从仓库已复刻的
[Impact 配方](../../spritefusion_exact/recipes/impact.md)、[原生关键帧](../../spritefusion_exact/previews/impact/native-keyframes.png)
学习两拍亮核、脱离碎片与断环的层次；从 [Blood 配方](../../spritefusion_exact/recipes/blood.md)
学习短扇形出射和根部脱离。与 PixelFX `impacts/hit-spark.js` 的一瞬白核、非对称轮廓和快入慢收方法结合。

原创取舍为六向短赤铜核、四枚碎片、两段压力弧、六颗火星和默认九滴血。
没有复制原版的完整弹着、反弹、长血雾、血池、角色闪白或击退。
`tools/pixelfx-hit-draft.js` 可放入固定版本 PixelFX 的 `src/fx/impacts/xingtian-copper.js`
后运行 `node tools/render.mjs impacts/xingtian-copper --all` 和 `node tools/check.mjs impacts/xingtian-copper`。
它是原始视觉草稿和方法复核；Godot 组件是正式交付，不声明 JS / Godot 逐像素等价。

## 多敌人命中预览

从默认工作台右上角 **Multi-target preview** 进入，或单独运行
`godot --path preview/xingtian-slash-godot res://crowd_preview.tscn`。

- **3 simultaneous**：同一帧3处命中，两轮展示。
- **6 staggered**：6个接触点间隔35ms，展示连续出现与余迹共存。
- **6 dense**：6处同时命中，每280ms重复一轮；旧血滴尾迹与新命中独立叠加。
- 左侧1×：沿用现有游戏展示的76px刑天原图高度，几何测试敌人直径32px。
  右侧2×：同一时间、同一配置与种子的最近邻细节视图，不增加特效密度。
- 原 `components/`、预设和挥砍参数保持 `6103cf0` 完全不变。只为各目标和各波
  创建独立命中实例，不把单实例 `play_hit()` 替换旧效果的问题隐藏掉。
- Pause、Replay、Clear、时间轴、镜像、0.25×和关闭血液均可用。
  Clear 后 Resume、时间轴或镜像都不会自动恢复，须显式 Replay。

这里是**脚本调度的独立视觉测试场景**，不是实际游戏接入。刑天是已认可的静止原图，
没有攻击或受击动画；敌人是现有项目风格的几何测试占位，不冒充完成的敌人美术。
不包含寻敌、移动、碰撞、伤害、击退、相机抖动或连击规则。280ms只是叠加测试间隔，
不表示实际角色攻击频率。外围8个测试敌人不会触发命中。

六目标挤在同一短弧附近时，血滴和铜片会局部相叠，这是本场景要观察的情况；没有
为使录像好看而偷偷压低特效数量、改变默认时长或改动战斗设计。游戏接入后的遮挡、
目标分布与性能仍须在真实宿主里另行验证。

```sh
godot --headless --path preview/xingtian-slash-godot --script tests/test_crowd.gd
XINGTIAN_CROWD_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --script tests/render_crowd.gd
XINGTIAN_CROWD_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/crowd.avi \
  res://crowd_preview.tscn -- --crowd-capture
```

先创建输出目录。16秒录像按同帧、错峰、密集、密集0.25×慢放各4秒排列。
原生像素探针覆盖三个场景的实际1×像素、2×对应、精确倒放、Clear/Resume、
血液关闭、镜像和收尾清空。MovieWriter不是实时性能测试，录制文件与探针数据不入库。

## 重击与可配置冲击波

新入口 **Heavy cleave preview** / `heavy_preview.tscn`：保留普通攻击参照，展示
原创重击地波、六目标和1×/2×尺度。冲击波半径、时长、强度、RGB颜色等都可实时调整，
默认72px / 0.32s / 0.85 / 赤铜色；资源、完整默认值和宿主API见 [HEAVY.md](HEAVY.md)。
仅独立视觉预览，不添加战斗机制或改变已认可的普通挥砍。
