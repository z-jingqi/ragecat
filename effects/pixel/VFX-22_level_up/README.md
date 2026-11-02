# VFX-22 · 升级觉醒

子类型：地面锚点的单次升级/觉醒。地面短闪/双环、中央细亮柱、上升短火花/三角与星点收束；效果本体不绘制任何文字。不是爆炸换色，也不包含神兽图腾、UI文字或玩法升级逻辑。

## 运行

在 `preview/godot` 中打开 `effects/VFX-22_level_up/level_up.tscn`。1×真实逻辑尺寸与2×Nearest并排；Pause、+Frame、Replay、Stop、Reset、Seed、BG、Move 和四种预设。

组件 `level_up.gd`：`play(anchor, overrides, host=null, foot_offset=Vector2.ZERO)`；`tick(dt)`（`automatic=false` 时由调用方驱动）；`clear()`/`stop()`立即取消且不触发完成；`peak`仅在进入释放阶段一次；`finished`自然结束一次。事件回调允许重新播放或清空。只画视觉，不修改等级、奖励、宿主材质、位置或透明度。

host 是可选 Node2D，offset 使用宿主局部坐标并转换到效果本地坐标。绑定宿主销毁即取消；独立位置也可使用。跟随整个效果锚点，适用于跟随式升级；想锁定位置则不传host。

## 参数（全部重播生效）

|参数|默认|有效范围 / 单位|含义|
|---|---:|---|---|
|radius|25|10–40逻辑像素|地面/上升环半径|
|height|88|30–88逻辑像素|柱体与粒子上升高度|
|column_width|6|3–20逻辑像素|断续外围光丝宽度|
|core_width|2|1–4逻辑像素|细亮柱芯宽度|
|glints|5|0–12整数|短星点数量|
|pulse_amount|0.06|0–0.15|整体轻微起伏，0关闭|
|flicker_frequency|8|0–18 Hz|局部错相闪动频率|
|flicker_amount|0.45|0–0.65|局部明暗差，0关闭局部变化|
|flow_speed|90|0–180逻辑像素/秒|亮段向上流动速度|
|rings|2|0–4整数|错峰地面环层数；0关闭|
|ring_interval|0.08|0.02–0.18秒|地面环启动间距|
|particles|18|0–32整数|固定身份的上升粒子；0关闭|
|charge|0.1|0.08–0.8秒|内收准备|
|burst|0.65|0.1–1.2秒|中央柱保持与粒子释放|
|settle|0.85|0.25–1.5秒|收束|
|intensity|0.62|0–0.85|颜色亮度上限，0隐藏；不使用加法叠亮|
|seed|22|整数|固定粒子分布和环缺口|
|core/body/edge|fff2b5/e3af4b/887054|HTML颜色|三层色阶|

数值超出范围钳制，非有限浮点回默认；无效颜色回默认。粒子位置由时间解析计算，数量始终有界，没有每帧分配粒子。总时长为三个阶段之和；强度低不改变事件时间。

## 机制

地面短闪先出现，两个地面环错峰扩大；中央细柱快速升起，以细柱芯、断续中层和外围短光丝呈现；各高度独立明暗起伏，亮段向上流动，不再绘制整根静态矩形。柱体先收束，短火花、三角碎片和少量星点继续上升/减速后消失。地面环不再向上漂浮。角色独立置于效果前方保持可读性。像素取整发生在逻辑画布，放大用Nearest；局部闪烁只压低亮度而不超出总强度上限，不使用整屏闪光或加法叠亮。

## 参考与授权

按用户指定的 [Level Up](https://particlefx.studio/effects/level-up) 下载查看公开海报和8时刻图，参考中央金色细柱、地面双环、短火花、上升碎片和星点层次。效果不包含参考中的 LEVEL UP 文字，也不绘制字母或数字。此次参考不同于早先的 Character Level Up，已改为地面环与中央柱构图。

没有复制参考图片、动画图集、角色或网站源码；全部效果是独立程序几何。稀疏图条不是完整动画逐帧复刻。

## 检查

`godot --headless --path preview/godot --script res://effects/VFX-22_level_up/test_level_up.gd`

`godot --headless --path preview/godot --script res://effects/VFX-22_level_up/test_demo.gd`

覆盖30/60/144Hz阶段、事件一次性、重入、宿主移动/销毁、偏移、非法参数、种子、1000次复用和控制器。实际画面与录像检查见 QA.md。
