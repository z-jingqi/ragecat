# VFX-08 连锁闪电

Godot 实时像素原型，独立于单点雷击、持续电场和瞬间范围雷爆。由调用者传入候选敌人，不扫描场景，也不直接扣血。根据距离逐次选择最近的未命中目标，电弧有主从粗细和局部接触火花，接点随着敌人移动。

## 运行

```
godot4 --path preview/godot res://effects/VFX-08_chain_lightning/chain.tscn
python effects/pixel/VFX-08_chain_lightning/tests/run_checks.py
```

左侧1×实际尺寸，右侧同一低分辨率画布2×Nearest。可调目标数量、距离、跳跃间隔；支持移动敌人、移除候选、重播、暂停、逐帧、清空、重置、种子与背景切换。数字标示命中顺序。敌人和其闪色只是演示宿主，组件本身还自带短接触火花。

## 接入

```
var chain = preload("res://effects/VFX-08_chain_lightning/chain.gd").new()
add_child(chain)
chain.target_hit.connect(func(enemy, jump_index): pass) # 游戏端处理伤害
chain.play(Vector2(10, 65), enemy_nodes, {"max_targets": 5, "jump_range": 72})
```

- `origin` 为组件局部位置；目标为有效的 Node2D，使用其 global_position 转到组件局部坐标。
- 每次跳跃重新选最近的未访问目标；同距按输入顺序。最多读取128个不同候选，最多命中12个。没有回跳模式。
- 每个目标在本次施放中最多触发一次 `target_hit(target, jump_index)`，索引从0开始；电弧击穿阶段结束时通知。组件不执行血量、伤害类型、阵营或碰撞规则。
- 候选应是调用者已过滤的可攻击敌人。目标销毁或 queue_free 后不再发命中通知；已经发出的通知不撤回。上一跳源节点失效时使用该跳的初始锚点。
- 电弧的随机形状只在跳跃开始时生成，之后仅变换端点，不每帧重新随机。移动目标可能离开原选取范围；已发出的电弧仍跟随，下一跳重新按距离选择。
- `paused` 暂停内部时间；`clear()` 取消所有未触发命中和视觉，允许复用；`play()` 替换当前施放，保留暂停状态。
- 默认自动更新。`automatic=false` 后调用 `tick(delta)`；不要同时自动和手动更新。完成后发一次 `finished`，清空所有子电弧。

## 参数（触发时快照）

| 参数 | 默认 | 范围/单位 |
|---|---:|---|
| max_targets | 5 | 1–12个目标 |
| jump_range | 72 | 1–512逻辑像素 |
| jump_interval | 0.09 | 0.04–0.4秒，相邻跳跃起始间隔 |
| width | 1.25 | 1–3像素，电弧主体宽度 |
| branches | 1 | 0–3条从属分叉 |
| jitter | 7 | 0–20像素，横向偏折 |
| attack | 0.02 | 0.008–0.035秒，击穿及通知时刻 |
| hold | 0.045 | 0.008–0.12秒，亮峰 |
| decay | 0.15 | 0.03–0.3秒，电弧收束 |
| seed | 31 | 0–65535，同初始场景可复现 |
| core/body/edge | 米白/浅青/蓝 | 颜色字符串或Color，强制不透明 |

非法数值回落默认，越界钳制。颜色强度由配色控制，不使用屏幕泛光。参数与示例预设见 config/presets.json；预览内源码 DEFAULTS 与其在测试中一致校验。

## 依赖

复用 `VFX-08_lightning/lightning.gd` 的精修电弧绘制，关闭其地面爆光、烟雾和落点余波。连锁控制和演示在独立目录；迁移或复制时需同时带上单点雷击的 lightning.gd / defaults.gd。不是纯独立单文件，也不是现成 Unity 代码。未来引擎适配需重写绘制和节点接口，选择与时间算法可复用。

## 精细电弧

默认主体宽度由2.5降至1.25逻辑像素，采用共享绘制器的细线轮廓，不再叠加固定2像素外边。保留不规则走向、跳跃顺序和轻量接触火花；2×图只是观察像素结构，不代表实际游戏尺寸。
