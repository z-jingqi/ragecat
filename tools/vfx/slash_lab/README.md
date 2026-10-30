# 02 / 像素挥砍轨迹

独立小样，保留已认可的 01 护甲命中，不更改游戏主场景或战斗逻辑。当前实现像素风格，默认刀光无黑色描边。

## 运行

```sh
godot --path . res://scenes/vfx_lab/slash/slash_lab.tscn
```

编辑器打开该场景按 F6；F5 仍是原游戏。Godot 4.6.3 Standard / Compatibility；无需新插件或素材。

- R / Replay：从头播放；Space：暂停 / 继续。
- L：循环开关；S：1× / ¼×；B：明暗背景。
- →：暂停并推进 1/60 秒，末尾钳制。

384 × 160 低分辨率 viewport，3× 最近邻放大，无抗锯齿、发光或模糊。有限色板与阶梯状边缘，青色弧形刀光、象牙白锐边、3 道短剑影；像素练习人偶只负责提供动作参照。

## 时序与结构

- 0.16–0.36 s 蓄势，0.36–0.53 s 快速弧形挥砍。
- 刀影滞后 35 / 70 / 105 ms；0.53–0.79 s 刀光收缩消失。
- 1.05–1.48 s 回到准备姿态；一轮 1.65 s。
- `slash_behavior.gd`：独立时间、角度、阶段、拖尾包络；未来风格复用这一行为。
- `pixel_slash.gd`：像素色板、形状和绘制命令；没有伤害、碰撞或游戏依赖。
- `slash_lab.gd` / `slash_lab.tscn`：独立预览控件和真实 viewport 捕获。

这是固定构图小样，不是已整合进战斗的生产级武器系统。行为支持角度偏移，完整人偶构图不声明任意方向适配。为保持已认可第一项不变，没有重构它的演示代码。

## 检查与真实捕获

```sh
godot --headless --script tests/vfx/slash/pixel_slash_lab_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/slash/slash_lab.tscn -- --capture-dir=/absolute/path/outside/repo/frames
ffmpeg -framerate 60 -i /absolute/path/outside/repo/frames/frame_%04d.png -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart preview.mp4
```

聚焦检查覆盖时间边界、确定性、全部 240 个采样帧的多边形可三角化、背景、暂停 / 单步、速度、循环、100 次回放不增节点；已纳入全量入口。无头测试不能替代画面检查。

捕获需要真实图形显示（headless dummy 会明确拒绝）。240 帧：前 120 帧暗背景 1×，后 120 帧亮背景 ½×，60 fps 视频共 4 秒。半速捕获聚焦动作和消散，不包括完整回收阶段；交互慢放仍为 ¼×。截图、视频、日志保留仓库外。

## 参数控制

Inspector：选中 SlashLab 根节点，展开 `Settings` 资源。运行时按 **P** 或点击 Parameters 打开可折叠面板；Tab 切换数值输入，Enter 确认，Esc 关闭。每次修改自动重播；Reset defaults 恢复已认可的无黑色描边版本。顶部含默认、倾斜窄弧、扁宽弧、圆弧反向四个预设，Custom 表示手动调整。预设只用于演示，不覆盖资源文件；运行时编辑是临时状态。

| 参数 | 范围 | 含义 |
|---|---|---|
| Direction | −180…180° | 绕握剑点旋转整个椭圆与剑影；0° 为已认可方向 |
| Arc span | 30…290° | 实际扫过角度，默认约 212° |
| Radius | 24…75 px | 低分辨率空间中的刀光半径 |
| Ellipse height / width | 0.3…1 | 曲率/压扁程度，1 为圆弧，默认 0.67 |
| Band width | 0.25…2× | 刀光带宽倍率，不改变刀刃/人偶 |
| Sweep duration | 0.08…0.5 s | 越小越快；后续消散与收势顺延，前摇不变 |
| Afterimages | 0…6 | 残影数量上限 |
| Ghost spacing | 15…80 ms | 相邻残影对应的历史姿态时间差 |
| Ghost max age | 20…300 ms | 历史姿态最老年龄；超过上限的残影不绘制 |

残影数量与最大年龄共同限制可见条数：例如 6 条 × 35 ms 需至少 210 ms 年龄上限。淡出仍由整体轨迹包络控制；这里的年龄不是每条残影独立 alpha 寿命。最大/最小值同时由 UI、Inspector 提示与运行时 sanitize 保护，NaN/Infinity 回到安全默认；最多 6 条残影，不随重复调整增加节点。

方向会旋转刀光/武器/残影，不是人偶骨骼动画；手臂固定作参照。极端旋转下少量碎光可能到达画面边缘。参数只作用于独立实验，没有接入游戏武器。

真实参数演示捕获（4 个预设各 2 秒，60 fps）：

```sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/slash/slash_lab.tscn -- --parameter-demo --capture-dir=/absolute/path/outside/repo/parameter-frames
```
