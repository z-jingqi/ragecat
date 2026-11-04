# 刑天 · 不屈

Godot 4.6.3 Standard / Compatibility 独立视觉组件。濒死入场时暗红地环快速收紧，抛出短促碎光与可关闭的少量血滴；随后保持克制的贴体战意。**只有宿主明确调用 revive() 才向上汇聚赤铜光；exhaust() 只会熄灭。** 不读取生命、不决定死亡或复活、不实现伤害、技能或攻击动画。

## 运行与预览

```sh
godot --path preview/xingtian-unyielding-godot
godot --headless --path preview/xingtian-unyielding-godot --script tests/test_unyielding.gd
```

导入本目录 project.godot，F5。左右两个完整序列分别演示复活成功、战意耗尽，下面是四个固定阶段样本。静态人形只是比例参照。默认演示在 2.8 秒由预览脚本明确发出结果，不是组件内置的自动复活时限。

- Hold 重新进入并无限等待；Resolve 给左侧发出成功、右侧发出耗尽。
- 半径、贴体战意透明度、入场碎光数、复活光数可调。
- Blood / Aura / Ring 可独立关闭。更多图层与配色参数在 Resource 中。
- Pause / Replay / Clear、拖动时间轴、深浅背景。Clear 后拖动不复活，Replay 恢复。

## 复用接口

```gdscript
const Unyielding = preload("res://components/unyielding.gd")
var fx = Unyielding.new()
add_child(fx) # 把它排在角色后方
fx.enter(Vector2.ZERO, load("res://presets/default.tres"))
# 可选：宿主当前 alpha 轮廓，art pixel 坐标，相对脚底定位
fx.set_body_mask(actor_alpha_image, Vector2(-16, -44))
fx.advance(delta)
# 游戏确认结果时二选一；重复或冲突结果返回 false：
fx.revive()
# fx.exhaust()
```

`seek(seconds)` 用本次 enter 的绝对时间，保留已确认结果的时间点，可倒回检查。`get_phase()` 返回 idle / entry / holding / revival / exhaustion / finished。`get_frame()` 返回实际运行纹理 Image 的副本。`clear()`、`stop()` 后 seek 或 resolve 均不重启；必须再次 enter。完成自然淡出后可以倒放检查。

`set_layer_enabled("ring"|"shards"|"aura"|"blood"|"revival", bool)` 保留到下一次 enter。关闭血滴不影响碎光。血滴只在入场出现，短程落地、变暗消散，无大面积血雾、伤口或持续血池。

配色与视觉参数存放于 `components/unyielding_profile.gd` 和 `presets/default.tres`。半径18–44（32），扁平度0.25–0.65（0.42），收紧0.15–0.6秒（0.28），复活尾迹0.5–1.6秒（1.05），耗尽0.3–1.5秒（0.8），战意透明度0–0.65（0.36），碎光0–24（14），复活光0–18（12），血滴0–14（7）。全部为视觉量，不是玩法平衡值。

配置复制、数值清洗、局部 seed、独立时钟与纹理，不修改调用者 Resource 或角色图片。无指定轮廓时使用静态人形轮廓；自定义轮廓只读取局部64×72范围，限制到脚底周围 x±32、y -72..3；更大角色需要另行扩充画布。标准画布176×168，覆盖当前允许的效果参数。调用方需提供按本效果像素尺度匹配的轮廓并管理角色排序；这不是游戏自动绑定。

## 参考与验证

实际使用两项目：Sprite Fusion MCP Power Up / Blood 的前后分层、贴体轮廓、短促血滴与干燥色阶；Patch-gg/pixelfx Rage 源码、AUTHORING/SKILL 以及真实 render.mjs 联系图，借鉴地面/身体分离、seed、分阶段渲染与检视方法。没有引入两项目的角色动作、现成图片、图集、gallery 或运行时包。具体来源与保守保留的 MIT 许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。不是原版精确复刻。

测试涵盖无限保持不自动复活、明确结果与冲突拒绝、两种结尾均为空、倒放确定性、非法输入、配置/轮廓不变、独立实例、血滴/图层开关、Clear不复活、UI Hold/Resolve，以及最大范围入场环边界。独立审查发现的首帧下沿裁切已扩大画布并添加回归。

```sh
XINGTIAN_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-unyielding-godot \
  --audio-driver Dummy --write-movie /absolute/output/unyielding.avi --fixed-fps 60 -- --capture
```

原生录制演示两条完整分支，记录留在仓库外。录制固定60fps不代表实时性能；尚未做游戏集成、多实例压力测试或用户视觉验收。
