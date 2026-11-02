# VFX-08 单次雷击

当前是 Godot 像素视觉原型。只覆盖**起点到目标点的一次雷击**，不含闪电链、附身电流、持续光束、伤害或目标选择逻辑。与能量弹、实体投射物拖尾完全独立；没有 Unity 实现。

## 设计

默认 550 ms：25 ms 击穿到目标、65 ms 局部亮峰、140 ms 电弧衰退，之后最多 320 ms 余波。主干逐段粗细不均，长细支流从属主干；落点扁亮爆接破弧、短火花、余烬及离散上升烟块。无 Bloom 或全屏闪白；烟块使用三档透明度但保持硬像素轮廓。默认两次演示之间隔 1200 ms；演示间隔不是组件强制冷却。

种子在触发时生成折线，整个单次过程中不重新随机，不用每帧抖动伪造电感。默认 88 px 示例长度、1.5 px 外轮廓基准宽度。端点由调用者提供，组件不会猜测目标或发射方向。

```bash
python effects/pixel/VFX-08_lightning/tests/run_checks.py
godot4 --path preview/godot res://effects/VFX-08_lightning/lightning.tscn
```

左侧是 1× 逻辑像素，中央是**同一 SubViewport 纹理**的 2× Nearest 副本。可调方向、长度、宽度、偏折幅度和分叉，切预设、种子、背景，暂停/逐帧/重播/清空/重置；Slow 为 0.25× 诊断，默认正常速度。颜色和各阶段时长配置在 JSON 中。

## 接入契约

```gdscript
var bolt = preload("res://effects/VFX-08_lightning/lightning.gd").new()
add_child(bolt)
bolt.play(source_local_position, target_local_position, {"width": 3, "seed": 27})
# 或按方向和长度触发：
bolt.play_direction(origin, Vector2.DOWN, 88, {"branches": 2})
bolt.paused = true
bolt.paused = false
bolt.clear()
bolt.replay()
```

坐标均为组件局部坐标，Godot +Y 向下，逻辑单位视为像素。起终点在触发时冻结，不会追踪后来移动的目标。显示时取整，逻辑点保留浮点；宿主相机的非整数缩放需要接入方管理。长度低于 1 px 不播放；超过 2048 px 时将目标沿原方向钳制到 2048 px。非有限起点回落零，非有限终点回落起点。方向接口的零/非法方向回落向下。

调用 `play` 或 `replay` 会替换当前单次，保持调用者的暂停状态；不会堆积节点。`clear` 清除当前绘制，但保留上次参数供重播。生命周期由秒计时，不依赖帧率。`automatic=false` 时由宿主手动 `tick(delta)`，不可同时自动和手动更新。停止的单次在寿命结束后释放几何数组；不自毁节点，便于复用。

## 参数

`config/presets.json` 是默认值和预设事实源，`sync_config.py` 生成预览副本及 defaults.gd。参数触发时深拷贝并校验，之后外部字典的改动不污染当前单次。

| 参数 | 默认 | 范围 / 单位 |
|---|---:|---|
| width | 1.5 | 1–6 px；真实外轮廓基准宽度，逐段变化与收窄；默认最终主干 1–2 px，无额外增粗外沿 |
| segment_length | 7 | 5–24 px；名义分段长度，实际最多 64 段 |
| jitter | 10 | 0–20 px；横向偏折上限，短雷击还限制到长度的 18% |
| branches | 3 | 0–4；稀疏独立小分叉，0 关闭 |
| branch_length | 36 | 4–64 px；分叉方向长度基准 |
| attack | 0.025 | 0.008–0.08 s；击穿时间 |
| hold | 0.065 | 0.008–0.12 s；完整亮峰时间 |
| decay | 0.14 | 0.03–0.25 s；收束时间 |
| afterglow | 0.32 | 0–0.6 s；主雷柱结束后的寿命余量，0 会提前截断余波 |
| impact_size | 18 | 0–28 px；落点半径，0 关闭落点及所有地面余波 |
| spark_count | 7 | 0–12；抛射短火花数量 |
| smoke | true | 上升烟块开关；最多四团 |
| ember / smoke_color | eea656 / 6d5b78 | 余烬和烟块颜色；烟块透明度由阶段控制 |
| seed | 27 | 0–65535 整数；同配置同端点可复现 |
| core / body / edge | f4f0e5 / c1b8ef / 6a6098 | 三档颜色；接受颜色字符串或 Color，强制不透明 |

非法类型/非有限数值回落默认，越界钳制；默认不随机换种子。演示的角度、长度、播放倍率不属于组件内部目标选择。参数极限可能超出预览窗口，组件本身不按窗口大小裁剪。

## 文件

- lightning.gd：独立生命周期、确定性几何、自绘适配。
- ALGORITHM.md：引擎无关的实现描述，未来移植参考，不宣称代码可直接导入 Unity。
- tests 与 test_lightning.gd / test_demo.gd：参数、几何、生命周期和控件回归。
- 新预览视频由实时 Godot 渲染帧记录，仅供评审，不是生产动画素材。

## 参考图改进

参考 ParticleFX Studio 的单点雷击主图及八时刻条带，提取主从粗细、落点爆发与余波的结构关系，全部以代码重新构建。没有复制参考图作为运行时素材。保留 Air arc / no impact 预设，用于不需要地面余波的空中连接；地面方向默认垂直于雷击轴，真实地面法线由后续接入决定。更多参考说明见 SOURCES.md。

## 精细线宽

默认主干1–2逻辑像素、支流固定1像素。外沿不再额外扩张2px，避免将细宽度参数绘制成粗光柱。亮芯仍保留于同一宽度包络内；宽度可调大，但默认保持纤细。Air arc 预设为1px。550ms组合时长、主干形状和落点余波不变。细亮色电弧以暗背景为主要呈现环境，浅背景可通过配色参数提高对比。
