# VFX-22 · 升级觉醒

子类型：地面锚点的单次升级/觉醒。蓄能内收、向上释放、分层升环及短亮点收束。不是爆炸换色，也不包含神兽图腾、UI文字或玩法升级逻辑。

## 运行

在 `preview/godot` 中打开 `effects/VFX-22_level_up/level_up.tscn`。1×真实逻辑尺寸与2×Nearest并排；Pause、+Frame、Replay、Stop、Reset、Seed、BG、Move 和四种预设。

组件 `level_up.gd`：`play(anchor, overrides, host=null, foot_offset=Vector2.ZERO)`；`tick(dt)`（`automatic=false` 时由调用方驱动）；`clear()`/`stop()`立即取消且不触发完成；`peak`仅在进入释放阶段一次；`finished`自然结束一次。事件回调允许重新播放或清空。只画视觉，不修改等级、奖励、宿主材质、位置或透明度。

host 是可选 Node2D，offset 使用宿主局部坐标并转换到效果本地坐标。绑定宿主销毁即取消；独立位置也可使用。跟随整个效果锚点，适用于跟随式升级；想锁定位置则不传host。

## 参数（全部重播生效）

|参数|默认|有效范围 / 单位|含义|
|---|---:|---|---|
|radius|25|10–40逻辑像素|地面/上升环半径|
|height|72|30–88逻辑像素|柱体与粒子上升高度|
|column_width|22|6–32逻辑像素|左右柱丝间距，不是实心遮盖|
|rings|3|0–4整数|错峰上升环层数；0关闭|
|ring_interval|0.08|0.02–0.18秒|升环启动间距|
|particles|18|0–32整数|固定身份的上升粒子；0关闭|
|charge|0.22|0.08–0.8秒|内收准备|
|burst|0.24|0.1–0.6秒|向上释放|
|settle|0.68|0.25–1.5秒|收束|
|intensity|0.62|0–0.85|颜色亮度上限，0隐藏；不使用加法叠亮|
|seed|22|整数|固定粒子分布和环缺口|
|core/body/edge|fff2b5/e3af4b/887054|HTML颜色|三层色阶|

数值超出范围钳制，非有限浮点回默认；无效颜色回默认。粒子位置由时间解析计算，数量始终有界，没有每帧分配粒子。总时长为三个阶段之和；强度低不改变事件时间。

## 机制

准备阶段的短地面线向内收拢。释放阶段左右分段光柱快速上行，中央保留宿主可读性；各环独立起始后上升、开裂并消失。固定种子的短亮点/向上箭形闪点错峰升起。收束采用位置推进和碎裂，不是整层瞬间隐藏。像素取整发生在逻辑画布，放大用Nearest。

## 参考与授权

已下载查看 [Character Level Up](https://particlefx.studio/effects/character-level-up) 的公开8时刻图，参考其地面聚能、上行柱、升环与光点层次。没有复制参考图片、动画图集、角色或网站源码；全部效果是独立程序几何。该稀疏图条不是完整动画逐帧复刻。

## 检查

`godot --headless --path preview/godot --script res://effects/VFX-22_level_up/test_level_up.gd`

`godot --headless --path preview/godot --script res://effects/VFX-22_level_up/test_demo.gd`

覆盖30/60/144Hz阶段、事件一次性、重入、宿主移动/销毁、偏移、非法参数、种子、1000次复用和控制器。实际画面与录像检查见 QA.md。
