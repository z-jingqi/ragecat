# 刑天重击挥砍与独立砸地冲击波

独立视觉研究，基底 `93b7929d9fc8446d5c406e5fb799984bd9564dc3`。
保留认可的普通挥砍、命中组件和所有原预设；重击挥砍与砸地冲击波分开展示。
按用户澄清，冲击波只供重锤等砸地攻击的视觉落点使用，不加入普通或重击挥砍组合。
不是新技能实现，不定义伤害、攻击距离、碰撞、击退、频率或相机震动。

## 看预览

默认工作台右上角 **Heavy cleave preview**，或运行：

```sh
godot --path preview/xingtian-slash-godot res://heavy_preview.tscn
```

- Normal：原普通攻击配置，作为锁定参照。
- Heavy：更厚的70px赤铜挥砍与短促命中，不生成地面冲击波。
- 6 targets：六个独立接触实例，不生成地面冲击波。
- Ground wave：独立贴地冲击波，不生成挥砍、命中火星或血液。十字标记是预览攻击落点，
  波纹向其周围扩张。没有重锤素材或砸地角色动作，也不代表已经接入某个技能。
- 挥砍模式禁用波参数控件；Ground wave禁用挥砍厚度和血量控件，避免把独立效果混为组合。
- 左1×使用76px已认可刑天静止原图和32px几何测试敌人，右2×看同一帧细节。
- 地波远半部在角色后、近半部在前。默认没有完整光盘、烟团、地裂、血池或残留贴花。
- Pause、Replay、Clear、Mirror、0.25×、Blood、Wave和时间轴可用。
  Clear后改参数、改色、拖时间轴、切朝向或Resume不会复活，须Replay。
- Reset还原已加载的默认资源；切换四个展示模式或重播保留当前血液/地波开关。
  返回Hit preview再进入本页会新建场景，恢复初始开关。

所有敌人接触都是预览脚本安排，刑天没有挥斧、受击或移动动画。已有原图上的火焰
也仍是静态图片。固定两次展示的间隔不代表实际角色攻击速度。

## 冲击波参数

`presets/heavy_pressure.tres` 是预览真正读取的资源，可在Godot Inspector编辑并保存。
工作台滑块和颜色选择器实时更新两视图，但不会把临时调整自动写回磁盘。
`components/heavy_profile.gd`继承原SlashProfile，所以同一资源也能交给原挥砍组件。

| 参数 | 默认值 | 有效范围 / 意义 |
|---|---:|---|
| pressure_radius | 72px | 32–112，椭圆横向半径，仅视觉范围 |
| pressure_duration | 0.32s | 0.12–0.60，独立于挥砍和血液寿命 |
| pressure_strength | 0.85 | 0–1.5，调亮度；0不画任何波纹或碎屑 |
| pressure_color | #e9a463 | 任意RGB颜色，调色板会按时序变暗，不改变挥砍色 |
| pressure_thickness | 3px | 1–6，波纹径向半宽；初始完整波带约为该值的两倍 |
| pressure_squash | 0.34 | 0.20–0.70，椭圆高宽比 |
| debris_count | 8 | 0–16，独立碎屑数量，不随半径或强度增长 |
| pressure_enabled | true | 关闭全部地波和碎屑 |
| pressure_echo | true | 较短、较暗的内侧回声，Inspector可关闭 |
| blood_count | 9 | 0–20，接触血滴数量，半径改变不增加血量 |
| blood_enabled | true | 全部血液可关闭，工作台Blood独立控制 |

重击默认挥砍：半径70、厚度20、总长0.44s、扫出0.075s、保持0.07s、残线0.08s；
命中半径16、亮核0.045s、总长0.18s。都是美术配置，不作为玩法数值。
原 `presets/heavy.tres` 不受影响。

范围、时长、强度、颜色、厚度、压扁比与碎屑均有实际采样/渲染测试，不是空的Inspector字段。
配置会复制并清洗，NaN/Infinity回退，非法位置清空，不修改调用方资源。

## 宿主调用

```gdscript
const Pressure = preload("res://components/heavy_pressure.gd")
var wave = Pressure.new()
add_child(wave)
var settings = preload("res://presets/heavy_pressure.tres").duplicate()
settings.pressure_radius = 80.0
settings.pressure_duration = 0.36
settings.pressure_strength = 0.9
settings.pressure_color = Color("e9a463")
wave.play(actual_ground_contact, settings) # 宿主提供攻击落点，坐标在wave父节点空间内
wave.advance(delta) # 或由宿主统一 seek(seconds)
wave.set_enabled(false)
wave.clear() # seek不会复活；须再次play
```

地波只有显式`play`才发生；它不会找敌人、检测碰撞、生成血液或造成伤害。
挥砍命中仍单独使用原组件的`play_hit(contact, settings)`，每目标独立实例；
它与地波互不触发。地波不依赖角色、敌人、刀光或命中组件即可调用。
预览`heavy_stage.gd`仅在Ground wave模式创建地波，时序独立于挥砍的`onset`。
当前示例落点为画像定位锚点前方18px、下方7px，朝左时镜像X，不改为人物中心。
`ground_contact_offset`可由预览宿主修改，前后半波与十字标记始终使用同一落点。
需要遮挡分层时，可用相同配置和时钟创建两半：`draw_half=-1`画远半部，`draw_half=1`
画近半部，把角色节点放在两者之间。`draw_half=0`（默认）一次绘制完整效果。

实现按秒解析采样、局部固定种子，不采用全局随机、逐更新概率生成或固定帧编号。
波纹立方缓出扩张，逐步变薄、变暗、断裂并完全清空；无自动销毁或宿主状态变更。

## 参考与原创取舍

参考已复刻 [Explosion](../../spritefusion_exact/recipes/explosion.md) 的贴地椭圆、
前后遮挡、缓出扩张与短色阶；参考 [Impact](../../spritefusion_exact/recipes/impact.md)
的破环和有序消散。实际查看对应原生关键帧与代码。
也阅读固定版本PixelFX的`melee/heavy-cleave.js`，借鉴斩击到压力波的时序分离和前后层。

新增三段不规则铜色断环、短内回声、八颗有限碎屑均为独立程序化实现。
未复制原爆炸、完整重击、26火星、44泥沙、地裂、长烟尘、角色动作、hit-stop或镜头效果。
原已认可挥砍shader只接收独立的重击参数，没有源码修改。
许可与来源详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 验证与录像

```sh
godot --headless --path preview/xingtian-slash-godot --script tests/test_heavy.gd
XINGTIAN_HEAVY_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --script tests/render_heavy.gd
XINGTIAN_HEAVY_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/heavy.avi \
  res://heavy_preview.tscn -- --heavy-capture
```

先创建输出目录。20秒录像为Heavy、六目标挥砍、独立Ground wave、地波0.25×慢放、地波参数示例各4秒。
参数示例使用104px / 0.48s / 1.1 / 青色，仅为展示可配置，不替换默认赤铜方案。
MovieWriter固定60fps不代表实时性能，尤其极值与多实例应在真实宿主及目标设备单独测量。
