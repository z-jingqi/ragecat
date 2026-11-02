# VFX-21 · 经验掉落、吸附与抵达

**本项：** 程序化小型切面经验晶体，短抛物线掉落、低幅停留、实时追踪移动目标、短尾迹和 0.14 秒四向抵达闪点。视觉清晰、无图集、无全屏闪光或浓烟。Godot 4.6.3 Compatibility 原型，当前没有 Unity 实现。

## 运行

```sh
godot --path preview/godot res://effects/VFX-21_xp_pickup/xp_pickup.tscn
```

左上实际 1×，左下同一逻辑像素的 2×近邻细节。Drop 重播掉落，Attract 是预览模拟的游戏吸附指令；Move target 切换移动目标，Lose target 模拟目标失效。Pause、Frame、Reset、Palette、BG 分别控制暂停、逐帧、默认重置、双色预设和深浅底色。播放演示加 `-- --xp-auto --xp-quit`。

## 接口与权威边界

正式核心是 `preview/godot/effects/VFX-21_xp_pickup/xp_state.gd`，绘制是 `xp_view.gd`。不依赖其他特效。

- `configure(Dictionary)`：设置经过钳制的可视参数；非法数字/颜色忽略。
- `spawn(origin)`：新建最多容量内的掉落，不隐式吸附。
- `attract(target_position)`：游戏层明确允许拾取后调用，对掉落/停留的物体启动吸附；对已吸附/抵达物体不重启。
- `tick(delta, current_target, valid)`：每次读当前目标；目标无效立即返回停留并清尾迹。恢复有效不自动吸附，游戏层需重新发指令。
- `arrived(id)`：仅一次的视觉抵达通知，**本组件不计算/发放经验、不决定拾取半径或规则**。宿主按自身权威状态判断奖励。
- `reset()`：清除所有对象/轨迹/计时和本轮抵达计数。id 单调递增避免回收后的重复身份。

没有正式游戏人物/关卡资产依赖；菱形收集标记仅是预览辅助，经验晶体/光点全部实时画出。

## 参数

配置 `config/default.json` 与运行目录 `default.json` 必须一致。调整代码中的 config 或预设后提交两份；执行 tests/run_checks.py 会检查同步。

| 参数 | 默认 | 有效范围/单位 | 生效 |
|---|---:|---|---|
| count | 9 | 整数1–32 | 下一次spawn |
| seed | 21 | 整数0–2147483647 | 下一次spawn |
| radius | 4 | 整数像素2–8 | 即时，绘制取整 |
| scatter | 48 | 0–90像素 | 下一次spawn |
| drop_seconds | 0.38 | 0.08–1秒 | 即时；中途改会重算掉落进度 |
| bounce_height | 23 | 0–42像素 | 即时 |
| idle_seconds | 8 | 0.2–30秒 | 即时，超时回收不发奖励 |
| attract_speed | 260 | 30–600像素/秒 | 即时 |
| acceleration | 780 | 60–2000像素/秒² | 即时 |
| trail_length | 17 | 0–40像素 | 即时，0无尾迹 |
| arrival_seconds | 0.14 | 0.05–0.35秒 | 即时 |
| color_dark/body/light | 绿系三阶 | 有效HTML颜色 | 即时 |

参数只影响视觉原型的运动表现。真实游戏中的物品生命周期、磁吸触发和奖励由游戏决定；预览的闲置超时是容量保护，不是正式物品销毁规则。

## 结构、预算

单组件最多32个拾取物；每条尾迹最多48个历史点。固定240Hz状态步进，单次传入delta最多接纳0.25秒，避免卡顿后的无界追赶；正常30/60/120Hz一致。目标位置由外部每tick更新，固定步内复用该值，不预烘焙终点。所有绘制最终对齐整数像素，画面有限三阶晶体色，不用模糊/抗锯齿。

## 参考与授权

制作前参考 [Sprite Fusion Pickup](https://www.spritefusion.com/pixel-art-vfx/pickup) 的掉落/悬停/吸附/抵达分阶段设计，以及 [Godot Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html) 的向量运算文档。本项是独立实现，未复制其代码或图片，没有外部美术素材。没有导入任何付费资产。

测试与视觉结果见 QA.md；提交不代表用户视觉验收。
