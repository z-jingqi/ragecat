# Fixed-path Thunder · 纯视觉接入

`fixed_path.gd` 用于游戏已经完成目标选择与伤害判定的场景。它只读取调用者给出的局部坐标快照，按原顺序绘制；不接收敌人节点、不扫描场景、不跟随移动目标、不发命中信号。旧 `chain.gd` 的交互演示保留不动，**不要用旧控制器替代游戏已有连锁逻辑**。

## API

```gdscript
var visual = preload("res://effects/VFX-08_chain_lightning/fixed_path.gd").new()
add_child(visual)
# 第一点是起点，之后是游戏已经判定的命中位置；全部相对 visual。
visual.play_path(thunder_points, {"duration": 0.18})
# 只在游戏模拟实际推进时调用；不改变原伤害与冷却时刻。
visual.advance(delta)
visual.paused = true
visual.seek(0.06) # 调试专用：显式跳转仍可在暂停时使用。
visual.replay()  # 原快照和种子重播，解除暂停。
visual.stop()    # 立即隐藏，保留显式重播能力。
visual.reset()   # 清除快照和子节点；结束战斗/重开时使用。
```

- 没有 `_process` / `_physics_process` 时钟。共享电弧的自动更新也关闭；调用者拥有推进、暂停和清除。
- `age` / `duration` 为视觉时间；`done` 表示视觉结束。没有命中、伤害或其他游戏事件。
- `snapshot_points()` 返回独立副本。输入数组、返回数组与外部对象后续变化不修改本次路径。
- `play_path()` 替换旧视觉并清除暂停。`seek()` 可正向/反向定位，不影响游戏模拟；反向定位按原种子还原几何。
- 默认总时间为现有游戏反馈的 **0.18 秒**。默认原连锁65ms生长、25ms亮峰、180ms收束及90ms间隔按比例压入这段视觉时间，保留错峰生长、残迹重叠与分段消散。这里的生长/接点火花不代表任何伤害发生时刻。
- 长时间步会直接、精确到期；负数、NaN、Infinity 时间步忽略。到期无残留，`reset()` 释放子节点。
- 支持2–129个有限点，每段不超过2048局部单位；超出则整条拒绝，避免静默改路或缩短。小于1单位的段不绘制但保留其序号/视觉间隔，后续段正常处理；全部重合则不显示。

## 视觉与参数

直接复用 `VFX-08_lightning/lightning.gd` 的精修像素主电弧、从属分叉、生长和逐段收束；关闭其落地爆光、烟雾和余波。保留原连锁的细接点火花，只有视觉用途。不使用预制动画、PNG图集或模糊泛光。

默认配色与原连锁一致：米白芯、浅青主体、蓝色暗边，宽度1.25。`width`、`branches`、`jitter`、`seed`、`core/body/edge`、`attack/hold/decay`、`jump_interval` 继承原连锁视觉默认和范围。新增 `duration` 默认0.18，范围0.05–5秒；它只控制视觉总长。非法参数回落默认，越界参数钳制，颜色强制不透明。

## 运行与验证

```sh
godot4 --path preview/godot res://effects/VFX-08_chain_lightning/fixed_path_preview.tscn
python effects/pixel/VFX-08_chain_lightning/tests/run_checks.py
# 实际 Compatibility 渲染器，不是 headless 视觉替代：
godot4 --path preview/godot --rendering-method gl_compatibility --script res://effects/VFX-08_chain_lightning/test_fixed_path_render.gd
```

预览含1×和2×Nearest观察、重播、暂停、逐帧、清空、重置、种子和背景切换。`Slow x4` 只是本演示放慢，游戏默认仍是180ms。`-- --fixed-path-auto` 在4秒后切到慢速，方便录制。

测试覆盖路径顺序、输入隔离、局部坐标、无内部时钟/命中信号、30/60/144Hz、暂停、确定性反向定位/重播、巨型时间步、零长度段、参数/边界验证和重复复用清理；本地渲染测试检查实际像素可见、动态差异、暂停/重播一致及清空无残迹。自检不等同于用户视觉验收。

## 迁移依赖

只复制以下三个运行时文件，保留两个目录的相对关系：

```text
VFX-08_chain_lightning/fixed_path.gd
VFX-08_lightning/lightning.gd
VFX-08_lightning/defaults.gd
```

运行时依赖使用相对预加载，可放入其他 `res://` 子目录。无需旧选敌控制器、敌人演示节点、JSON预设、预览场景或测试文件。单点雷击的改动只有将 `defaults.gd` 预加载改为相对路径，绘制算法未变。来源及许可沿用 [SOURCES.md](SOURCES.md)。
