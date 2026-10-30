# 可组合像素组件

不再将整套效果叫作“投射物蓄力”。可自由组合三个独立组件，无发射、命中、伤害或自动攻击：

| 组件 | 可复用目录 | 职责 |
|---|---|---|
| Gathering Lines / 聚拢光线 | `scripts/vfx/gathering_lines/` | **唯一一套**已认可人物v5的不规则尖针采样及像素绘制。错时出生、直线内收、渐细双端、明暗长短层次。 |
| Pulsing Orb / 呼吸光球 | `scripts/vfx/pulsing_orb/` | 已认可的四层像素光球与呼吸，完全不生成光线。 |
| Character Glow / 人物辉光 | `scripts/vfx/character_glow/` | 脚下透明渐变辉光＋宿主轮廓扩张，接收轮廓命令，不依赖角色脚本。 |

`shared/`只包含小型像素绘制工具和线性生命周期；不是全局效果管理器。`scripts/vfx_lab/components/`才拥有练习人物与组合控制器。正式游戏、命中与挥砍效果不变。

## 两个组合示例

```sh
godot --path . res://scenes/vfx_lab/components/orb_composition.tscn
godot --path . res://scenes/vfx_lab/components/character_composition.tscn
godot --headless --path . --script tests/vfx/components/effect_components_tests.gd
```

两例实例化**同一**Gathering Lines类。人物使用原v5中心偏移−38、上/下纵向比例.72/.42；光球例设置半径48（避免圆形画幅裁切）、中心偏移0、圆形比例1/1、内半径13，其余采样/针形算法相同。人物默认完整绘制命令、光球默认命令分别与抽取前8个时刻的基线逐项哈希比对一致。

## 独立参数与颜色

每组件独立Resource、behavior和pixel renderer。配置不会串到其它实例。

- 光线：蓄力/消散时间、半径、数量、强度、内收速度、中心偏移、上下径向比例、内半径、最短/最长针、寿命比例；主色、高亮色、综合色调（默认白色不改变原色）。
- 光球：半径、呼吸幅度/频率、强度、蓄力/消散；外缘/主体/内层/核心四个颜色。
- 人物辉光：蓄力/消散、强度、轮廓宽、脚下强度；脚下综合色调、轮廓/边缘/身体淡染颜色。

颜色保留Alpha并检查非有限值；数值有Inspector与运行时范围保护。P展开参数，三个分组可折叠，ColorPicker可单独调整颜色。底部组件复选框可单独关闭光线、光球或辉光；Palette给出暖色组合例，Reset恢复全部默认，不改变其它实例。

R重播、Space暂停、→单步、C显式消散、A自动演示/无限保持、L循环、B背景、T色板。演示定时停止只是宿主行为；组件不自动释放。长消散配置会等待所有启用组件清理完才重播。

## 集成方式

```gdscript
var fx = preload("res://scripts/vfx/gathering_lines/pixel_gathering_lines.gd").new()
fx.behavior.configure(my_resource) # 深复制，实例独立
add_child(fx)
fx.effect_origin = Vector2(100, 80)
fx.time = elapsed
fx.stop_at = -1.0 # 无限保持；停止时填入当前elapsed，且>=0.2
fx.queue_redraw()
```

所有组件一致使用`configure / sample(time, stop_at)`和renderer的`time / stop_at / effect_origin`接口。光球可从0.04s起效；光线/辉光从0.2s起效，组合宿主可用时间偏移同步。停止时光线冻结原有事件位置并淡出，这是已认可人物v5行为；不会产生新一轮事件。人物辉光的`silhouette`是宿主的像素矩形命令数组，`build_foot()`与`build_contour(actor_commands, skip_leading_rectangles=0)`允许宿主显式排除开头的阴影命令（默认不排除任何矩形），并安排脚光→光线→轮廓/人物的层次。

主预览均为实际Godot正常速度，含默认、替代颜色与关掉聚拢光线的组合对照。旧整体效果类别和重复光线实现已删除，无兼容别名。截图/视频与测试运行日志置于仓库外。
