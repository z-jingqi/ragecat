# VFX-08 持续范围电球

中心光球在配置时间内稳定存在，周边细电弧持续错峰刷新。**不是瞬间爆炸**，也不是只有开头闪一下的雷爆。只含光球和闪电，不含膨胀冲击波、爆炸、烟、碎片或余烬。目录与文件名保留 `lightning_burst/burst.gd`，避免已有预览路径失效；语义已改为持续电球。

默认持续3秒，半径4的中心亮点以局部像素轮廓、亮芯位置与面积变化闪烁，6个方向槽以180ms周期错峰产生新电弧。每条电弧包含12个主干点和两条短支流，70ms沿路径长出、40ms亮峰、190ms逐段退去并冷却。前后代同时存在，不能整条换形。默认主干1逻辑像素，没有宽外描边；支流以较暗的1像素线表达。可将主干调到2像素，分叉仍为1像素。硬边有限色阶，无Bloom、动画图集或逐帧贴图。

## 运行

```sh
python effects/pixel/VFX-08_lightning_burst/tests/run_checks.py
godot --path preview/godot res://effects/VFX-08_lightning_burst/burst.tscn
```

左侧实际1×，右侧同一SubViewport的2×Nearest纹理。模拟敌人被周期事件选中后变金色，其他保持灰色。演示默认启用0.5秒事件间隔，以状态栏事件累计数说明范围命中；组件本身默认关闭事件。持续时间、范围、数量、光球半径、刷新周期可以现场调整；有暂停、单步、重播、清空、重置、背景切换。20秒录像依次演示默认、小范围、大范围、紫色和浅背景，每段完整展示3秒存在和结束。演示段落间的空白是重播间隔，不在有效持续时间内。

## 接入契约

```gdscript
var orb = preload("res://effects/VFX-08_lightning_burst/burst.gd").new()
add_child(orb)
# 纯视觉默认不发伤害事件。
orb.play(center_global_position, [], {"duration":5.0, "arc_interval":0.18})
# 可选：交给游戏自己的伤害系统解析事件。
orb.target_hit.connect(func(target): your_damage_system.resolve_tick(target))
orb.play(center_global_position, candidate_nodes, {"duration":5.0, "hit_interval":0.5})
```

中心、范围半径按世界逻辑像素，组件应置于无缩放效果层；非均匀父缩放不支持视觉与范围一致。候选是调用者提供的Node2D，组件不搜索场景、不选择阵营、不修改生命值。范围采用目标全局中心距，不包含碰撞形状半径。

`hit_interval=0` 完全关闭事件。大于零时在触发时及每个间隔发一次范围通知，精确到结束时刻不再补一次。每个tick按目标当时位置重新选中且去重；移动入范围的目标从下一个tick开始收到通知。一个长dt跨越多个tick时会补齐事件数量，但使用本次更新能看到的位置，不伪造历史轨迹。失效、待删除目标忽略。回调中的clear/play立即取消旧流程尚未发出的通知。

候选数组在play时浅拷贝以保留真实节点身份；后续增减候选需要重播或由接入方维护自己的调用契约。`play` 替换旧实例，参数校验后保存；`clear`取消并清空几何和候选，不发finished。自然结束只发一次finished。暂停冻结视觉更新和后续tick；显式调用play仍立即建立光球及可选首个tick，因此游戏暂停时应同时暂停调用。`automatic=false`时只用tick(delta)，不要双重推进。

## 参数

| 参数 | 默认 | 范围 / 单位 |
|---|---|---|
| duration | 3 | 0.25–30 秒，光球全程存在 |
| radius | 42 | 8–80 世界逻辑像素，视觉电弧范围与事件半径 |
| arcs | 6 | 3–16 并存电弧组 |
| width | 1 | 1–2 逻辑像素主干；支流固定1像素 |
| orb_radius | 4 | 3–16 逻辑像素 |
| flicker_hz | 12 | 0–24 Hz，不规则像素形态更新频率；0冻结形态 |
| flicker_strength | 0.7 | 0–1，轮廓和亮芯变动幅度；0关闭闪烁 |
| pulse_hz | 3 | 0–16 Hz，0关闭光球脉动 |
| arc_interval | 0.18 | 请求0.04–0.4秒；按电弧寿命进一步限制，保证重叠与容量 |
| formation | 0.07 | 0.03–0.16秒，沿路径生长 |
| decay | 0.19 | 0.08–0.3秒，逐段回收/颜色冷却 |
| hit_interval | 0 | 0关闭；启用时0.1–5秒，与视觉刷新独立 |
| seed | 21 | 0–65535，固定种子和时刻生成相同几何 |
| core/body/edge | 冰白/亮蓝/靛蓝 | Color或HTML字符串，硬边不透明 |

电弧寿命=formation+40ms亮峰+decay。实际产生间隔限制为max(40ms,寿命/6)到寿命×0.7之间，因此始终有代际重叠；最多每槽7代、16槽共112条，每条12主干点＋2×5支流点。无无限历史、粒子或子节点。只在新一代生成时使用固定种子，几何保留到生长/冷却结束；对应时间的形状不随帧率改变。

主干沿路径逐渐出现；支流等待主干抵达其根部后长出。衰退时可见区间从根部向末端回收，颜色由冰白→浅蓝→暗蓝，不用整条透明度闪灭。光球60ms几何进入、最后140ms收束；关停阶段所有剩余电弧也沿路径退去，持续时间内仍有可见球/弧，最终清空。显式clear作为取消仍立即清理。

光球默认半径由8缩为4逻辑像素；所有演示预设使用这个默认值。电弧起点基准保持原来的8像素，不随光球半径变化，因此电弧路径、范围、密度、宽度及时序完全不变。光球大小独立可配，小范围下可能比某些电弧更宽；伤害半径不会跟随球脉动。

中心使用独立种子的逐像素亮点，不是静态三层圆形。12个局部方向的边界不同，亮芯轻微错位、面积变动，中心像素始终明亮；不做整球闪黑。默认仍是4像素基准半径，扰动不到1像素；外围闪电随机序列、路径和时序不受影响。

## 参考

亮芯修订查看 [ParticleFX Pixel Art Plasma Orb](https://particlefx.studio/effects/pixel-art-plasma-orb) 的实际8时刻条带：借鉴局部明暗和不规则亮芯变化，不添加其外围环线、轨道或大范围辉光。

时序修订重新下载查看 [ParticleFX Pixel Art Lightning Strike](https://particlefx.studio/effects/pixel-art-lightning-strike) 的8时刻条带，重点是亮峰后的逐步降亮与残留，不将8帧条带当作完整逐帧动画。配合持续电球需求，采用每条独立生长/退去、代际交叠的实现。

最终依据 [ParticleFX EMP Blast](https://particlefx.studio/effects/emp-blast) 的重新下载海报及8帧条带，查看中央亮芯和不规则细电流。参考自身是一次EMP爆炸；按用户定向要求**只保留中心光球＋周边电流，并延长为可配置持续存在**，不复制其圆形冲击波、烟、余烬。

其他早期研究：[ParticleFX Lightning Strike](https://particlefx.studio/effects/pixel-art-lightning-strike)、[Mimic Mart Lightning Spell Effects](https://mimicmart.itch.io/pixel-art-lightning-spell-effects) 的实际公开GIF。另查看 [Crunchy VFX](https://crunchyvfx.com/) 首页公开预览，其图没有可辨闪电，未将它作为雷电形态依据。

所有几何独立编写；没有复制第三方资产或专有代码，研究图片不放进生产资源。可见网页不自动授予素材再分发权。
