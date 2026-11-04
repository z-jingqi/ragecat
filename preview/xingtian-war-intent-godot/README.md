# 刑天 · 战意积累

Godot 4.6.3 Standard / Compatibility 的独立视觉组件与预览。脚下低亮度暗红裂纹与断续纹环随外部 `momentum` 输入逐渐完整，输入下降时缩短、变暗，归零时完全消失。始终贴地，不遮角色，不修改游戏、不实现攻击动作或玩法。

## 运行

导入本目录 `project.godot`，F5。无需插件、图片、图集或网络。

```sh
godot --path preview/xingtian-war-intent-godot
godot --headless --path preview/xingtian-war-intent-godot --script tests/test_intent.gd
```

大窗演示完整 8 秒视觉输入：空 → 逐渐积累 → 保持 → 衰减 → 空。下方固定显示 25%、60%、100% 三个独立实例。人形是程序绘制的静态比例参照，不是刑天角色美术。

- Momentum 滑块可手动输入；这会退出预览自动积累。
- Radius、Perspective、Brightness 调视觉外形；Ring / Cracks 分层开关。
- Pause、Replay、Clear、时间轴、深浅背景。Clear 后只有 Replay 或重新开始才显示，时间轴不会把已清除实例复活。
- `presets/default.tres` 是可替换的 Inspector 配置。

## 复用

```gdscript
const BattleIntent = preload("res://components/battle_intent.gd")
var fx = BattleIntent.new()
add_child(fx)
fx.play(Vector2.ZERO, load("res://presets/default.tres"))
fx.set_momentum(0.6) # 0..1，由游戏决定积累与衰减
fx.advance(delta)    # 只驱动非常轻的呼吸变化
# fx.seek(seconds), fx.set_layer_enabled("ring"|"cracks", bool)
# fx.clear(), fx.stop()
```

把 `components/` 复制到宿主项目后按相对路径使用即可，不依赖另一个刑天效果。宿主负责节点位置、角色与地面排序；组件画在角色下面。没有 Timer、物理查询、伤害、攻速、资源消耗、自动释放或全局随机数。

参数：半径 18–50 像素（默认34），地面扁平度 0.25–0.65（0.42），裂纹 6–16（10），纹环段 8–24（18），seed 0–65535（37），透明度 0.1–1（0.88），呼吸强度 0–0.15（0.045），三阶可调非 HDR 红色。配置在 play 时复制、清洗，不修改调用者 Resource；NaN/Infinity 会回退安全值。

组件使用确定性的 CPU 像素几何，上传为每实例纹理，不保存帧动画。`get_frame()` 返回与运行纹理相同的 Image 的副本，供测试/工具读取。固定 160×144 画布覆盖所有允许参数；每实例自持时钟、输入和开关。自然状态没有结束时刻，输入归零就是空画面；stop / clear 后 seek 不会重启，必须 play。

## 参考、验证与边界

实际调用 Sprite Fusion MCP、读取 Power Up / Blood / Energy 配方，检查原生参考画面；实际读取 Patch-gg/pixelfx Rage 与 AUTHORING/SKILL，并运行其 `render.mjs status/rage` 检查联系图。借用其分层、带 seed 的裂纹与反复渲染检视方法，未使用现成素材或复制整项效果。来源与保留的 MIT 许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。这是原创适配，不是第 26 项 Sprite Fusion 原版复刻。

测试涵盖覆盖率递增、归零、时钟确定性、非法输入、配置不变、层开关、实例隔离、clear 不复活、UI 时间轴/重播，以及最大参数纹理边界。独立审查发现的最大范围下沿裁切已扩大画布并添加回归。原生全流程录制与截图保存在仓库外，不把 headless 通过当作用户视觉确认或游戏接入证明。

```sh
XINGTIAN_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-war-intent-godot \
  --audio-driver Dummy --write-movie /absolute/output/intent.avi --fixed-fps 60 -- --capture
```

固定60fps MovieWriter 是展示时钟，不是实时性能成绩；本项未做游戏内性能评估或多实例压力测试。血液不挂在持续积累状态上，避免无受伤事件也持续出血；可选血滴保留在单独的不屈濒死入场与挥砍命中效果。
