# VFX-04 攻击命中：定向接触火花

**当前交付：Godot 4.6.3 可调视觉原型 + 独立数学/参数规格。不是 Unity 已验收组件。** 本阶段先确认设计与实际预览；Unity 接入另行安排。

## 视觉范围

从独立接触点爆发，不依赖怪物贴图、不做伤害或贴体闪白。入射方向是“攻击进入接触点”的方向，**不是表面法线**。默认象牙白/浅金/赭金三档色块，偏心短楔形亮芯、5 条不同角度的短碎片，约 **0.20 秒**结束。没有全圆太阳芒、连续波纹、烟雾、漂浮碎点或 Bloom。可选冲击肩部仅是短暂的两小段破弧，默认关闭。

- 0～20 ms：立即可读，达到亮芯主峰。
- 20～104 ms：亮芯迅速收缩；短碎片沿入射扇区离开。
- 104～200 ms：少量碎片缩短并降至边缘色，寿命结束立即清空。
- 全程由秒计时；固定种子只决定每条碎片的角度/长度/速度差异，不逐帧重抽。

## 运行

在仓库根目录：

```bash
python effects/pixel/VFX-04_hit_impact/build_adapters.py --check
godot4 --path preview/godot res://effects/VFX-04_hit_impact/lab.tscn
```

预览左侧是 **1×逻辑像素**接触点与占位靶，右侧是同一时刻、同一种子的 **4× Nearest**。全窗口的整数缩放由现有项目设置控制；不是将放大图冒充实际游戏尺寸。默认原速循环，两次命中间留空；可暂停、重播、清除、每次前进 1/60 秒、切 0.25×诊断速度、切深灰/黑/白/棋盘背景。

右侧面板可调方向、尺寸、亮芯、碎片数、长度、扇角、速度和时长；调参立即重播。`Seed +1` 稳定换一组碎片，`Shock` 开关短冲击肩部。选择预设即可切颜色与组合参数。配置文件可直接改三档颜色。

```gdscript
const Impact = preload("res://effects/VFX-04_hit_impact/impact.gd")
var fx = Impact.new()
add_child(fx)
# contact 是 Godot 画布坐标；incoming 使用数学坐标（+X 右、+Y 上）。
fx.play(Vector2(160, 90), Vector2(1, 0), preset_dictionary)
fx.paused = true
fx.paused = false
fx.clear()   # 立即清空；不保留碎片
fx.replay()  # 用上次位置、方向与触发时快照重播
```

## 有效参数

所有数值在 `play()` 时取快照并校验；外部字典之后改动不会污染当前播放。越界数值钳制，非有限数值回落默认值，非法颜色回落默认色，零/非法方向回落 +X。

| 参数 | 默认值 | 范围与意义 |
|---|---:|---|
| `size` | 1 | 0.35～2；整体逻辑尺寸倍率 |
| `coreSize` | 6 px | 2～12；主亮芯基准尺寸 |
| `shardCount` | 5 | 0～8；0 仍保留主亮芯 |
| `shardLength` | 8 px | 2～20；碎片初始长度 |
| `spreadDegrees` | 125° | 15～170°；入射方向周围的扇区 |
| `speed` | 78 px/s | 15～180；尺寸倍率之前的扩散速度 |
| `duration` | 0.20 s | 0.08～0.50；完整单次寿命 |
| `seed` | 23 | 0～4095；整数按低 12 位归一 |
| `shockAccent` | false | 是否加克制的破弧肩部 |
| `directionDegrees` | 25° | 预设演示方向；实际 `play()` 的入射向量优先 |
| `coreHex/bodyHex/edgeHex` | 象牙白/浅金/赭金 | 三档不透明颜色；透明区由遮罩决定 |
| `playback_rate` | 1 | 0～4；0 保持；不改变参数中寿命 |

命名预设：`ivory_gold`（默认）、`small_cut`（3 碎片/0.16s）、`heavy_contact`（6 碎片/0.24s/短破弧）、`jade_test`（用于验证调色与斜向）。不是新的特效家族。

## 文件与边界

- `config/presets.json`：参数事实源。
- `src/shared/ImpactKernel.hlsl`：**无引擎 API 的纯数学遮罩函数**，输入逻辑像素坐标/秒/参数，输出 0～3 色阶编号。扩展名只说明语法；这里不含 Unity 组件或正式 URP 材质。
- `build_adapters.py`：将数学函数的 `float2` 适配为 Godot `vec2`，生成 `preview/godot/effects/VFX-04_hit_impact/impact.gdshader` 与预览配置副本；不生成动画帧或图集。
- `impact.gd`：Godot 专用生命周期/参数/显示节点适配。`.gd` 和 `.gdshader` **不能直接导入 Unity**。
- 不依赖外部精灵图、贴图、Blender、Pixelorama 或第三方运行库。
- 逻辑连续计时；仅接触点显示位置取整，遮罩先采样统一像素格再旋转。当前预览验证静态接触点，不宣称已验证正式游戏的镜头/像素相机。
- 每个实例固定 1 个矩形、1 个材质，最多 8 条解析碎片；重复播放复用节点。世界特效并发管理由接入方负责。
- 无宿主跟随与销毁依赖；立即清除和离树清除不会遗留旧粒子。不是持续发射器，没有“停止发射后继续生成”的状态。

详见 [验证记录](VALIDATION.md) 与 [来源说明](THIRD_PARTY_NOTICES.md)。
