# VFX-07 火焰爆炸

当前子类型是独立的一次性火焰爆炸。Godot 可调视觉原型，无外部贴图、精灵图集、烟雾贴图或宿主依赖；不包含火球弹道、持续燃烧、伤害与摄像机震动。

默认 0.60 秒：快速热芯 → 不规则火团膨胀、冷却 → 短褐灰烟团被不均匀侵蚀散去。周围细短火星有尖头、渐窄尾部与错开的起止时刻，不是等长的矩形点。火焰四档、烟灰三档不透明色块，不使用 Bloom、全屏闪白、多重扩散圆环或长时间烟尘。火团之间的位置、半径、空洞和余烬轨迹随时间独立变化，不是缩放一张静态图。

## 使用

```bash
godot --path preview/godot res://effects/VFX-07_fire_explosion/lab.tscn
godot --headless --path preview/godot --script res://effects/VFX-07_fire_explosion/test_fire.gd
```

```gdscript
const Fire = preload("res://effects/VFX-07_fire_explosion/fire.gd")
var fx = Fire.new()
add_child(fx)
fx.play(Vector2(200, 140), {"radius":18.0, "seed":37})
fx.paused = true
fx.paused = false
fx.clear()   # 立即清空；节点保留以便复用
fx.replay()  # 用上次触发参数与位置重播
```

`play(contact, config)` 的位置为画布坐标，+Y 向下。上升始终沿画布 -Y，不是任意朝向喷射。显示位置取整，调用者的逻辑位置不修改。每次触发复制参数快照，改变源字典不影响已播放效果。单次特效没有连续发射器；自然结束或 clear 均无残留。

## 参数

| 键 | 默认 | 范围 / 单位 | 作用 |
|---|---:|---|---|
| radius | 18 | 6～30 px | 主要火团尺度；不是伤害半径 |
| duration | 0.60 | 0.18～0.85 s | 全部阶段比例缩放，结束清空 |
| rise | 22 | 0～45 px | 火团后期向上位移 |
| lobes | 7 | 3～10 整数 | 不规则主体火瓣数量 |
| embers | 10 | 0～16 整数 | 细短火星数，0 可以关闭 |
| emberLength | 4.5 | 1～7 px | 火星最大尾长，具体长度错开并随寿命缩短 |
| smoke | 0.65 | 0～1 倍 | 冷却烟团尺度，0 可关闭 |
| spread | 1 | 0.5～1.5 倍 | 火瓣分离与余烬外扩，不改时间 |
| seed | 37 | 0～4095 整数 | 固定形状、分布、起止错峰 |
| coreHex | #fff2ac | 颜色 | 初期热芯 |
| bodyHex | #ffb33c | 颜色 | 主体亮黄 |
| flameHex | #f26329 | 颜色 | 橙红火焰 |
| edgeHex | #a72e25 | 颜色 | 深红边缘与末期余烬 |
| smokeHex / smokeLightHex / ashHex | #615862 / #8a7370 / #3c3440 | 颜色 | 烟团主体 / 前期亮部 / 边缘 |
| playback_rate | 1 | 0～4 倍 | 播放节点属性；0 暂停时钟 |

数值越界钳制；非数值与非有限值回落默认；颜色非法回落默认，颜色 alpha 强制为 1。透明区是硬遮罩。参数下次 play/replay 生效；实验面板调参立即重播。提供 clean_burst、small_pop、heavy_burst、blue_flame 四预设，最后一个验证配色能力而非新的元素家族。

面板支持暂停、单帧、清除、重播、恢复默认、种子、速度和背景切换。左侧 1× 逻辑尺寸、右侧 2× Nearest 同时同 seed；放大视图是诊断，不替代原速实际尺寸检查。

配置事实源为 `config/presets.json`，预览同名副本需保持字节一致。无跨引擎运行声明；算法见 ALGORITHM.md，Godot 文件未来需要按目标引擎重新适配。

本次周边火星与烟团收尾参考 [Midair Fireball Explosion](https://particlefx.studio/effects/midair-fireball-explosion) 的逐时刻图像；没有使用该站图集、贴图或运行代码，详见算法来源说明。
