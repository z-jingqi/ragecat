# VFX-03B · 实体飞行道具的独立路径拖尾

**这是新建的独立效果，不是能量弹换皮，也不是武器扫掠面的拖尾。** 当前交付 Godot 4.6.3 原型、独立参数、算法和真实运行视频；没有 Unity 代码。

- **箭矢**：清楚的箭头、细杆、尾羽，沿自身长轴直飞。
- **飞刀**：金属刀刃、护手和短握柄，沿刃尖方向飞行。
- 两者尾部接一条细、短、逐渐收束的真实历史路径线；转向时旧路径留在原处，不把整条线当静态三角形一起旋转。
- 没有能量亮芯、内流、光晕、放射装饰、图集或外部素材。实体明暗是金属/木质色块，不是能量动画。

## 独立运行

```sh
python3 effects/pixel/VFX-03_physical_projectile/sync_config.py --check
godot --path preview/godot res://effects/VFX-03_physical_projectile/physical_projectile.tscn
```

不改变项目默认场景。上方 **1×实际游戏尺寸、正常速度**；下方是同一状态的 **3×Nearest跟随诊断**。面板裁剪仅防止极端值覆盖控件，不裁剪真实历史缓存。

控件：Pause / 单步 / Reset / Replay，独立拖尾宽度、长度上限、保留时间、收尖程度、速度响应，以及实体比例。Track 切换跟随镜头；Turn 切换有转速上限的演示轨迹；Stop 停止发射并留下短暂历史消退；Teleport 清空跨越旧位置的线。Trail on/off 可直接比较裸实体。BG 检查深灰、黑、浅色背景。预设提供 Arrow、Throwing knife、Long arrow trail、Warm knife trail。

自动演示：追加 `-- --physical-auto --physical-quit`，依次为箭矢轴向直飞、飞刀轴向直飞、箭矢转向、飞刀转向、60 px/s、320 px/s、停后清空，约12.7秒。

## 参数

唯一权威配置为 `config/presets.json`；`sync_config.py` 显式复制到独立预览目录，`--check` 验证字节一致。

| 参数 | 默认 | 范围 / 作用 |
|---|---:|---|
| body_kind | 0 | 0箭矢 / 1飞刀；更换时断开旧锚点历史 |
| body_scale | 1 | 0.5–2，实体比例；独立于拖尾宽度 |
| trail_width | 2.4 px | 0.5–6，拖尾根部总宽度 |
| length_min / length_max | 8 / 34 px | 0–40 / min–64，按实际速度插值的路径弧长上限 |
| speed_reference | 260 px/s | 30–600，达到最大尾长的速度 |
| speed_response | 0.05 s | 0.01–0.3，尾长指数响应时间常数 |
| history_seconds | 0.20 s | 0.02–0.6，真实历史点的最长保留时间和停后消退时间 |
| taper | 0.75 | 0.25–3，沿弧长的收尖幂次 |
| lifetime | 1.6 s | 0.1–10，实体活动时间，结束后历史继续短暂消退 |
| trail_color / trail_edge | 蓝灰两级 | 独立拖尾调色板，普通透明混合，不发光 |
| metal_light / metal_dark / wood_color | 金属/木色 | 独立实体调色板 |

越界数字夹到范围；非有限值保留原值。真实可见长度还受实际走过的路程和 `history_seconds` 限制，**不会为填满参数长度凭空造历史**。低于1像素的宽度差异可能量化为相同覆盖。无随机行为，因此不提供无效 seed。

## 接入边界

`path_history.gd` 接收 `tick(dt, world_tip_position, actual_velocity)`。当前两种实体的尾端偏移分别为20 / 18逻辑像素乘实体比例；正式宿主可在适配边界替换这个尾端锚点。预览中的直线/转向控制器不是玩法移动、自动索敌或碰撞实现；命中时由游戏调用 `stop()`，特效不判伤害。

- `reset(position, velocity)` 清除旧轨迹、年龄、暂停状态并重新开始。
- `stop()` 隐藏演示实体、停止采样；原世界历史在保留时间内收细淡出。
- `stop(true)` 立即清除。
- 位置跳变超过96 px时断尾；生命周期最后一帧内发生的跳变也不能连接旧位置。
- 暂停冻结位置、速度、计时、历史与绘制状态；单步推进1/60秒。

## 测试与隔离

```sh
python3 effects/pixel/VFX-03_physical_projectile/tests/run_checks.py
```

运行真实Godot状态和场景回调测试，覆盖生命周期、停后消退、暂停/重置、瞬移和寿命边界交叉、参数极值、容量、独立宽度、预设和30/60/144 FPS一致性。另有原始录制帧检查器和不可变源快照工具，详见 `QA.md`。

当前目录不导入 `VFX-03_projectile`（能量弹）或 `VFX-02_weapon_trail`（武器扫掠拖尾）的运行文件；那两项原有文件和行为保持不变。通用的指数响应、历史裁剪和显示量化思路得到复用，但没有能量核心依赖。
