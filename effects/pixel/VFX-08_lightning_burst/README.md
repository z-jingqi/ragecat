# VFX-08 瞬间范围电球

独立 Godot 实时像素原型，和单次雷柱、连锁闪电、持续电场分开。中心一颗分层亮球轻微脉动，周边电弧错峰击穿、断裂收束。默认500ms；只包含光球与闪电，没有爆炸、膨胀冲击波、烟、余烬、碎片、屏幕闪白、Bloom或动画图集。

## 运行与验证

```sh
godot --path preview/godot res://effects/VFX-08_lightning_burst/burst.tscn
godot --headless --path preview/godot -s res://effects/VFX-08_lightning_burst/test_burst.gd
```

预览左侧实际1×、右侧同一176×128 SubViewport的2×Nearest纹理。灰色模拟敌人中，被本次范围选中的变金色，未被选中的仍为灰色。范围圆以中心点距离判定；绘制电弧不是每条独立伤害检测。可重播、暂停、单步、清空、重置和切换背景。自动录像展示默认、小范围、大范围、紫色、浅底。

## 接入

```gdscript
var burst = preload("res://effects/VFX-08_lightning_burst/burst.gd").new()
add_child(burst)
burst.target_hit.connect(func(target): your_damage_system.resolve_hit(target))
burst.play(impact_global_position, candidate_nodes, {"radius":42, "seed":21})
```

调用者提供候选 `Node2D`；本组件只发通知，**不直接修改生命值，也不搜索场景或决定阵营**。候选对象全局中心到爆点的距离小于或等于半径即选中；不包含碰撞体外沿计算。中心与半径使用世界逻辑像素；组件应放在无缩放的2D效果层，父级非等比缩放不支持伤害形状一致性。非有限中心回落零。

`play` 立即快照范围内的有效候选，去重后按候选顺序各发一次 `target_hit`。以后移动进范围不会补伤害。已销毁/待销毁目标忽略；回调中 `clear` 或 `play` 会取消旧调用尚未发出的事件。渲染的细枝可以略超出伤害圆，只是装饰。上一次效果被新 `play` 替换，不叠加节点。

`finished` 只在自然结束时一次；`clear` 是取消，不触发结束。`paused` 冻结视觉；`play` 的即时命中不会受视觉暂停延迟。若不希望暂停时伤害，由调用者暂停调用。`automatic=false` 时用 `tick(dt)`，不要双重更新。无效/负dt忽略，运行时长以秒计；参数在触发时校验并复制。

## 参数

| 参数 | 默认 | 范围 / 单位 |
|---|---|---|
| radius | 42 | 8–80 世界逻辑像素 |
| duration | 0.5 | 0.12–0.8 秒 |
| arcs | 6 | 3–16 主电弧 |
| width | 2 | 1–4 逻辑像素 |
| orb_radius | 8 | 3–16 逻辑像素 |
| pulse_hz | 7 | 0–16 Hz，0不脉动 |
| seed | 21 | 0–65535，固定种子固定几何 |
| core/body/edge | 冰白/亮蓝/靛蓝 | Color 或HTML颜色字符串；硬边不透明 |

几何容量上限为16条主弧、至多6条短支流及3层光球。种子几何在触发时冻结，电弧独立错峰消失，中心光球在最后22%时长内收束清空。光球半径和范围半径独立：小范围时光球可以占据大部分视觉空间，但不会改变命中范围。

## 参考与许可边界

最终造型依据 [ParticleFX EMP Blast](https://particlefx.studio/effects/emp-blast) 的海报与8帧条带。只借鉴中心亮球及周边闪电，按用户要求去除其爆炸、膨胀圆波、烟雾和余烬。下面其他参考仅为早期雷电造型研究。

- [ParticleFX Pixel Art Lightning Strike](https://particlefx.studio/effects/pixel-art-lightning-strike)：查看下载的海报及8时刻条带，研究局部落点亮爆、细电弧、火星分离的次序。
- [ParticleFX Thunderclap](https://particlefx.studio/effects/thunderclap)：查看海报及条带，研究扁平落点和短促残留；本项不添加重复落雷。
- [Mimic Mart Lightning Spell Effects](https://mimicmart.itch.io/pixel-art-lightning-spell-effects)：查看公开GIF，研究细连接线、局部端点爆光、径向电击和末段短碎片。
- [Crunchy VFX](https://crunchyvfx.com/)：已查看首页与公开预览图，研究亮芯/几何碎片分层；该预览图没有可辨雷电，因此不把它当作雷电形态依据。

本实现独立编写，没有复制第三方图像、动画图集、专有代码或商店素材。参考下载只用于研究，不作为生产资源纳入仓库；不能把网页可见视为素材再分发许可。
