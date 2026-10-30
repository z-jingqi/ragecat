# 赛璐璐特效 / 03 聚拢光线 + 脉动光球

依据已确认的象牙白 / 金色概念图：短而有尖端的光线沿直线吸向中心；中心光球用清楚的纯色色块和少量锐利表面形状呈现。**Gathering Lines** 与 **Pulsing Orb** 是两种独立组件，可各自调色、调尺寸、播放和停止，没有投射物或自动发射依赖。原有像素组件、赛璐璐盾击与刀光不变。

## 运行和预览

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/cel/charge_lab.tscn
```

Godot 4.6.3 / Compatibility，独立 F6 场景；F5 仍运行原游戏。

- **1 / 2**：分别显示 / 隐藏聚拢光线和光球；可自由组合或都关闭。
- **R** 重播，**Space** 暂停 / 继续，**→** 前进一帧，**S** 正常 / ¼ 速度。
- **D** 消散后停止；不会发射，也不会自行重播。再按 R 或在停止后按 Space 可重新播放。
- **C** 金色 / 青绿色，**P** 实时参数面板，**Esc** 关闭面板并释放输入焦点。
- 参数面板分为两个标签页，所有参数和三种颜色分别独立；更改立即重播，不回写调用者或 Inspector Resource。Reset defaults 恢复两组件、金色和正常速度。

蓝灰底色、UI、显示缩放和组合关系全部由实验场拥有。组件没有背景。预览使用固定显示缩放，故尺寸修改保持可见；非常大的参数组合可超出演示卡片，应在实际宿主中按用途取景。

## 独立配置

| 组件 | 参数 | 默认 |
|---|---|---|
| 两者 | `size`、`core_color`、`body_color`、`shade_color` | 1；象牙白 / 金色 / 金色阴影 |
| 聚拢光线 | `line_count`、`density`、`seed` | 36、1、23 |
| 聚拢光线 | `length_min/max`、`width_min/max` | 22–65、2–5 |
| 聚拢光线 | `spawn_radius_min/max`、`end_radius` | 170–300、14 |
| 聚拢光线 | `lifetime_min/max`、`speed` | 0.24–0.46 秒、1 |
| 聚拢光线 | `dissipate_seconds` | 0.20 秒 |
| 脉动光球 | `radius`、`pulse_amplitude`、`pulse_rate` | 104、0.045、3.8 次 / 秒 |
| 脉动光球 | `accent_strength`、`dissipate_seconds` | 1、0.22 秒 |

参数范围与有限值检查在各自的 `*_config.gd` 中。`density` 改变聚拢光线的时间密度，`line_count` 控制线流数量；光线半径、长度、宽度、寿命和相位各有变化。固定 seed 保证相同配置和时间可复现，不改变游戏随机数。光球小幅快速脉动，不旋转同心圆，也不叠加模糊光晕。

## 复用

- `scripts/vfx/cel/gathering_lines_config.gd` + `gathering_lines.gd`
- `scripts/vfx/cel/pulsing_orb_config.gd` + `pulsing_orb.gd`
- `scenes/vfx/cel/gathering_lines.tscn` 和 `scenes/vfx/cel/pulsing_orb.tscn`
- 可选实验场：`scripts/vfx_lab/cel/charge_lab.gd` 与 `scenes/vfx_lab/cel/charge_lab.tscn`

```gdscript
const GatheringLines = preload("res://scenes/vfx/cel/gathering_lines.tscn")
const PulsingOrb = preload("res://scenes/vfx/cel/pulsing_orb.tscn")
var lines = GatheringLines.instantiate()
var orb = PulsingOrb.instantiate()
add_child(lines)
add_child(orb)
lines.position = Vector2(320,240)
orb.position = lines.position
lines.play()
orb.play()
# 宿主按需停止；没有自动发射或战斗行为。
lines.stop()
orb.stop()
```

`configure(config)` 深拷贝并校验配置。`play()` 从头播放并持续保持；`stop()` 消散，`stop(true)` 立即清空；`seek(seconds, stop_at=-1)` 用调用者时间定格，适合独立时间轴。两个组件都只负责表现，不拥有伤害、碰撞、角色或技能状态。

## 验证与真实录像

```sh
godot --headless --script tests/vfx/cel/charge_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/cel/charge_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart /absolute/outside/repo/cel-charge.mp4
```

12 秒 / 720 帧 / 60 fps：3 秒金色组合、2 秒仅光线、2 秒仅光球、3 秒青绿色组合、2 秒金色实时面板和消散。全部为正常速度，从真实 Godot viewport 截取；headless dummy 拒绝录像。视频、帧与运行日志应保留在仓库外。完整测试不要与渲染 / 编码并行，避免干扰原生时间测试。

## 制作参考

已确认概念图是主要依据。只参考以下成熟效果的层次拆分与错峰节奏，未复制第三方素材或运行时代码，也不使用付费生成：

- [ParticleFX / Charge Up](https://particlefx.studio/effects/charge-up)：吸入光线与主体分层、错开时间；本实现不包含角色、释放爆发或光晕。
- [ParticleFX / Anime Charge Up](https://www.particlefx.studio/effects/anime-charge-up)：硬色块核心与速度线分层；本实现不采用其中的旋涡、闪电、尖刺冠或爆炸。
