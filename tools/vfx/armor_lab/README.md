# Armor impact lab / 护甲命中特效实验

独立演示，不接入或修改现有战斗。**像素版箭矢命中护甲**默认效果已获认可；本版补充参数面板，默认外观保持不变。非像素风格当前暂缓。

## 运行

Godot 4.6.3 Standard / Compatibility，无需 Blender 或新增素材。

```sh
godot --headless --editor --import --quit
godot --path . res://scenes/vfx_lab/impact/armor_impact_lab.tscn
```

也可在编辑器打开该场景按 F6；F5 仍运行原游戏。画面以 384 × 160 像素渲染、最近邻放大 3 倍。

- **R / Replay**：重新播放；**Space**：暂停 / 继续。
- **L**：连续循环开关；关闭后停在本轮末尾。
- **S**：1× / ¼× 慢放；**B**：亮 / 暗背景。
- **→**：暂停并前进 1/60 秒，末尾不越界。
- **P / Parameters**：展开 / 隐藏实时参数；改值自动重新播放。**Esc** 关闭面板并释放输入框焦点，恢复快捷键。
- **Reset defaults**：恢复已认可的默认参数及箭矢 / 护甲演示；**Example: heavy angled hit**：试用较强斜向命中。
- **Show arrow + target demo**：关闭时只显示命中特效，不画示范箭矢、护甲、地面或背景。

默认时序：0.16 秒开始飞行，0.48 秒接触，75 ms 闪光；火花、回弹和烟尘依次衰减；1.65 秒一轮；调长烟尘时自动延长循环至所有粒子衰减完毕。固定种子式序列确保回放一致。

## 结构与复用边界

- `scripts/vfx/impact/impact_config.gd`：可在 Inspector 编辑的参数 Resource；校验范围与非有限值。
- `scripts/vfx_lab/impact/pixel_impact_demo.gd`：实验室专用箭矢、护甲与背景，与纯命中特效独立。
- `scripts/vfx/impact/impact_behavior.gd`：无场景依赖的时序与轨迹采样，包含方向、力度、回弹、闪光和烟尘包络。
- `scripts/vfx/impact/pixel_impact.gd`：原创程序化像素形状与有限色板；采样同一行为，生成绘制命令，不负责伤害或碰撞。
- `scripts/vfx_lab/impact/armor_impact_lab.gd`：演示时间轴、控件、背景及捕获。
- `scenes/vfx_lab/impact/armor_impact_lab.tscn`：独立入口。

后续平滑材质 / 赛璐璐版本应读取同一时序和轨迹，只替换形状、材质与渲染参数。方向参数同时旋转箭矢全部几何、烟尘偏移、火花轨迹与护甲回弹；重力也随命中局部坐标轴旋转，这是当前表现约定。护甲姿态本身不随方向旋转。没有复制《流放之路 2》素材，也不以此原型声称同等品质。Unity 适配仍未实现。

## 参数与调用

Inspector：选中实验室根节点，展开 `impact_settings`。运行时编辑的是其深拷贝，不回写原 Resource。

| 参数 | 范围 / 默认 |
|---|---|
| `strength` / `effect_scale` | 0.25–2 / 1；0.5–1.5 / 1 |
| `direction_degrees` / `hit_position` | −180°–180° / 0°；默认 (215,79) |
| `spark_count` / `spark_spread_degrees` | 0–40 / 19；10°–160° / 约 131.78° |
| `spark_speed` / `spark_lifetime` | 0.25–1.5 / 1；0.5–1.5 / 1 |
| `flash_seconds` | 0.025–0.2 / 0.075 秒 |
| `smoke_amount` / `smoke_seconds` | 0–1.5 / 1；0.3–1.2 / 0.95 秒 |
| `recoil_pixels` / `recoil_seconds` | 0–8 / 4 像素；0.1–0.5 / 0.24 秒 |

面板限制命中位置 X=100–270、Y=45–100；Resource 接受任意有限坐标，以便放进其他画布。火花数量或烟尘数量为 0 可独立关闭对应层。极端组合可能离开预览区域，不会强行裁成相同尺寸。

```gdscript
const ImpactConfig = preload("res://scripts/vfx/impact/impact_config.gd")
const ImpactBehavior = preload("res://scripts/vfx/impact/impact_behavior.gd")
const PixelImpact = preload("res://scripts/vfx/impact/pixel_impact.gd")

var settings = ImpactConfig.new()
settings.hit_position = Vector2(80, 60)
settings.direction_degrees = -30
settings.spark_count = 24
var behavior = ImpactBehavior.new()
behavior.configure(settings) # 深拷贝并校验；不修改 settings
var effect = PixelImpact.new()
effect.behavior = behavior
add_child(effect) # show_demo 默认 false：不带护甲/箭矢/背景
# 在所属场景自己的时间轴中更新：
effect.time = ImpactBehavior.CONTACT + 0.08
effect.queue_redraw()
# 用 behavior.duration() 判断全部衰减结束；节点生命周期由调用者管理。
```

`sample(time)` 和 `spark(index, age)` 是无场景依赖的行为采样；`configure(settings)` 是参数入口。实验室另提供 `set_parameter(name,value)`、`apply_preset()`、`reset_defaults()`。这些都是展示参数，不决定命中检测、伤害或游戏击退。未接入生产战斗，也未实现 Unity 转换。

## 检查与捕获

```sh
godot --headless --script tests/vfx/impact/armor_impact_lab_tests.gd
bash tests/run_all.sh
```

聚焦测试覆盖时序边界、回放确定性、完整箭矢方向 / 力度、衰减、暂停 / 单步、循环、背景、重复回放节点数量、参数范围 / NAN / INF、Resource 拷贝隔离、纯效果模式、实际 SpinBox 信号、预设和重置绘制命令一致性；已纳入全量测试入口。无头测试不等于 GPU 画面或交互视觉验收。

有可用图形显示时，可输出实际 viewport PNG 序列到仓库外目录：

```sh
godot --path . res://scenes/vfx_lab/impact/armor_impact_lab.tscn -- --capture-dir=/absolute/path/outside/repo/frames
```

截图、视频、测试日志不提交仓库。捕获脚本输出暗背景正常速度与亮背景慢速两段；图形环境不可用时不要把 headless dummy 输出当作真实截图。

## 实施顺序 / 设计清单

每项先审阅当前像素效果；非像素版本待恢复范围后复用同一行为。清单只标记本实验的新工作，不代表游戏已有系统状态。

| 顺序 | 效果 | 当前状态 |
|---|---|---|
| 1 | 箭矢命中护甲：闪光、火花、烟尘、回弹 | 像素版已获认可并保留；非像素暂缓 |
| 2 | 挥砍拖尾 | [像素小样](../slash_lab/README.md)已实现，默认无黑色描边，支持实时参数 |
| 3 | 聚拢光线 / 呼吸光球 / 人物辉光 | [可组合像素组件](../components_lab/README.md)，独立参数/颜色、保持与显式消散；共享唯一聚拢光线实现，不自动攻击 |
| 4 | 投射物飞行 / 独立能量弹（龙珠式方向） | 待实现，与蓄力分开组合 |
| 5 | 重击 / 冲击波 / 扬尘 | 待实现 |
| 6 | 死亡消散 / 碎裂 | 待实现 |
| 7–12 | 火焰、闪电、冰霜、旋风、护盾生成 / 受击 / 破碎、治疗 / 升级 | 第二阶段，待实现 |
