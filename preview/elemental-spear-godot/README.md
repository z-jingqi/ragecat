# 元素双尖矛 · 独立 Godot 特效

Godot 4.6.3 Standard / Compatibility。原创程序化像素效果，不用预制动画图集。
只做视觉组件，不包含伤害、碰撞、麻痹、减速、技能冷却或完整游戏接入。

火、雷已独立实现并逐项保存，冰正在接入。预设资源是实际运行配置。
七阶段均可独立更换已安装元素或自定义渲染脚本；未安装元素在工作台禁用。

## 运行与观看

导入本目录 `project.godot`，F5，或从仓库根目录运行：

```sh
godot --path preview/elemental-spear-godot
```

左侧原生 1× 游戏像素，右侧同一时刻 2× Nearest。两个28px静态人形只用于尺寸参照。
每阶段都有独立显示开关；主元素和地面元素分开选择，可把不同元素的矛与持续区组合。
长度、粗细、落下速度、范围半径、持续时间可实时调整。Replay 重播，Pause 暂停，
Clear 清空，Light/Dark 检查深浅底，时间轴可定位各阶段。
Clear 后调整参数、时间轴或 Resume 不会复活，必须 Replay。

主场景 `configuration` 真正读取 `presets/fire.tres`。Inspector 展开其中七个阶段资源，
分别编辑 enabled、duration、size、tint、intensity、element、renderer_override。
Reset 或切换主元素会重新加载对应预设；运行时编辑不会自动写回资源文件。

## 七个阶段

1. `gather`：高处中心凝聚，粒子向同一中点收束。
2. `form`：保持中心不移动，双尖沿同一轴线对称伸长。
3. `hover`：完整双尖矛短暂停留，只有轻微呼吸运动。
4. `descent`：矛尖向宿主给定落点加速落下，带元素尾迹。
5. `impact`：仅落地时的短促放射爆发。
6. `field`：与 impact 同时开始的持续地面表现。
7. `dissolve`：持续区收尾；动画时钟连续，不重新开始气泡或闪烁。

雷元素使用细长青白双尖与紫蓝边，矛身间歇跳弧，下落时拖出锐利电尾。撞地时分叉电纹
放射展开，持续区是固定节点之间间歇换线的电网，随后电弧减少、余光褪去。

火元素使用红橙熔芯、短焰尾迹、低矮喷溅；落地后采用后羿已认可熔岩的扭曲 Voronoi 岩壳、噪声不规则边缘与流动热通道方法，
没有规则圆环或重复正弦网格。气泡鼓起、
破裂并留下扁平涟漪，稀疏短焰与余烬。消散时先冷却，再褪去。

组件可见开关不改变时钟；关掉再打开显示当前时间。
资源中的 enabled=false 则跳过该阶段时长，后续阶段自动前移。
`impact` 与 `field` 共用落地时刻。总时长取 impact 和 field+dissolve 中较长者。
不启用 field 而启用 dissolve 时，允许单独展示收尾阶段，这属于可组合视觉而非玩法决定。

## 参数与接口

全局外形：spear_length 70px、spear_width 8px、fall_height 94px、fall_speed 540px/s、
angle_degrees -12°、field_radius 57px、ground_squash 0.48、固定 seed_value 41。
落下实际时间 = fall_height / fall_speed × descent.duration；descent.duration 默认1.0，
作为速度时长倍率。fall_height 表示沿运动轴的视觉行程。下落速度方向、矛轴和尾迹方向一致，
尾迹从后尖之外向反方向延伸；落点是下端尖，不是矛身中心。

默认阶段时间：凝聚0.12s、展开0.24s、悬停0.16s、下落约0.174s、撞击0.32s、
持续2.40s、消散0.50s；整套约3.594s，接触地面约0.694s。都是可调视觉参数，不作为玩法数值。
阶段 size 默认1、tint 默认白、intensity 默认1；强度0完全不绘制该阶段。
几何与计数限界，NaN/Infinity回退安全值，配置深复制，不修改调用方或其他实例。

```gdscript
const Spear = preload("res://components/elemental_spear.gd")
var effect = Spear.new()
add_child(effect)
var settings = preload("res://presets/fire.tres").duplicate(true)
settings.spear_length = 78
settings.field_radius = 62
settings.field.duration = 4.0
settings.hover.intensity = 0.8
settings.impact.tint = Color("ffd1a0")
effect.set_stage_enabled("gather", false) # 首次 play 前也有效
effect.play(actual_ground_contact, settings)
effect.advance(delta) # 宿主时钟；也可 seek(seconds)
effect.clear() # clear/stop 后 seek 不会复活，须 play
```

任意阶段可独立调用：

```gdscript
const Layer = preload("res://components/stage_layer.gd")
var field = Layer.new()
add_child(field)
field.play(actual_ground_contact, settings, "field")
field.advance(delta)
field.set_enabled(false)
```

`renderer_override` 可替换一个阶段的渲染脚本。脚本继承 RefCounted，提供
`render(canvas, phase, state, config, stage)`；state 含解析时间、进度、矛轴、中心、
长度、粗细、半径、消散系数与种子。渲染模块不得隐式驱动计时或更改游戏对象。
无 Timer、全局 RNG、物理查询、宿主角色依赖或自动释放；宿主决定节点生命周期。

## 参考、原创与验证边界

借鉴仓库中已复刻 Sprite Fusion fire、embers、bubbles、lightning、ice、impact、
explosion 的分层色阶、低分辨率粒子、折线电弧、晶体切面与时间组织。
新矛形、阶段组合、熔岩区域及本工作台均为原创实现，不冒充第26项原版复刻，
不改变原25项、41场景的源码或验收。没有上传参考视频、截图、原版对照素材。

检查命令：

```sh
godot --headless --editor --path preview/elemental-spear-godot --import --quit
godot --headless --path preview/elemental-spear-godot --script tests/test_spear.gd
godot --headless --path preview/elemental-spear-godot --script tests/test_elements.gd
SPEAR_CAPTURE_DIR=/absolute/output godot --path preview/elemental-spear-godot \
  --audio-driver Dummy --script tests/render_spear.gd -- --element=0
SPEAR_CAPTURE_DIR=/absolute/frames godot --path preview/elemental-spear-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/fire.avi \
  -- --capture --element=0
```

先创建输出目录。element 0/1/2 对应火/雷/冰，只测试已存在模块。
录像含两个完整本元素周期；可额外传 `--mix` 在第二周期展示不同地面模块。
缓存、日志、测试截图和录像留在仓库外，不提交对照素材。
Headless 只证明状态与启动，不证明画面质量。MovieWriter 固定60fps也不是实时性能成绩。
当前没有完整游戏、目标设备或 Unity 集成验收。最大参数组合需由宿主保证画面空间。
