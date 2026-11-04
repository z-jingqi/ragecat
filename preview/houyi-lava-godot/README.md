# 后羿「射日」· 熔岩独立视觉预览

Godot 4.6.3 标准版 / Compatibility，纯程序化像素效果。只做视觉组件与独立预览，不含攻击动作、弹道、伤害、碰撞、技能冷却或游戏接入，也不修改山海工程、既有 SpriteFusion 25 项及其核心代码。

这是新的原创组合效果，不是 SpriteFusion 的第 26 项原版复刻。实际检查过其 fire / embers 原始算法与原生预览，借鉴颗粒尺度、分层色彩和清晰轮廓；不声称逐像素相同，也尚未替代用户视觉验收。

## 运行

导入本目录 `project.godot`，F5。无需插件、图集、素材下载、网络或绝对路径。

```sh
godot --path preview/houyi-lava-godot
godot --headless --path preview/houyi-lava-godot --script tests/test_lava.gd
```

预览上方是 3× Nearest 组合，下面是 2× 独立组件，固定小面积便于察看。两个人形与虚线环仅为静态程序化可读性参照，不是角色美术或战斗逻辑。

- 五个勾选框独立开关熔岩、气泡、短焰、火星、上升烟雾。
- 滑块调视觉半径、流速、气泡/短焰密度、持续时长。Small/Grown 切换 36/84 的视觉半径。
- Pause/Resume 暂停/继续，Replay 重播，Clear 清除所有层，清除后用 Replay 重新开始。
- 拖动时间轴可暂停并逐帧定位，包括冷却与完全消失。BG 切换深浅底色。
- 主节点 `configuration` 资源可在 Inspector 选择 `presets/default.tres` 或 `presets/grown.tres`。选中资源可展开完整参数，包括配色、气泡尺寸/周期、烟雾透明度/上升高度等。

## 组件与调用

五个组件都能独立创建：

- `components/lava_surface.gd`：裂纹打开 → 暗红熔岩缓慢流动 / 深色浮壳 → 冷却成灰黑地表 → 淡出。单个材质，无预制纹理。
- `components/lava_bubbles.gd`：低矮鼓泡、破裂小溅点与扁平涟漪。
- `components/short_flames.gd`：间歇性低火舌，面积成长不提高火焰高度。
- `components/impact_sparks.gd`：仅落地的短促火星，没有射箭或攻击动画。
- `components/rising_smoke.gd`：最后叠加的稀疏暖灰烟团，缓慢上升、低透明度，可完全关闭。
- `components/solar_lava.gd`：轻量组合，不实现游戏行为。

```gdscript
const SolarLava = preload("res://components/solar_lava.gd")
var effect = SolarLava.new()
add_child(effect)
var settings = load("res://presets/default.tres").duplicate()
settings.radius = 54.0
settings.smoke_opacity = 0.12
effect.set_layer_enabled("smoke", true) # 首次 play 前也可配置
effect.play(Vector2(160, 120), settings)
effect.advance(delta) # 由宿主提供时钟
# effect.seek(2.0) / effect.stop() / effect.clear()
```

独立组件同样支持 `play(origin, configuration)`、`seek(seconds)`、`advance(delta)`、`set_enabled(bool)`、`stop()` 和 `clear()`。组合用 `set_layer_enabled("lava"|"bubbles"|"flames"|"sparks"|"smoke", bool)`。停用层仍接收组合时钟，再启用会显示当前时刻；clear/stop 后 seek 不会复活，必须 play。自然结束后允许 seek 倒回检查。全部由宿主时钟驱动，没有 Timer、自动释放、物理查询或全局随机数。

`play()` 复制并清洗资源，不修改调用方配置。错误 Resource 类型回退默认。NaN/Infinity 参数回退安全值，负时间不向前推进，无效 origin 停止该实例。每个实例持有独立材质和时钟。

## 参数

参数定义及导出分组在 `components/lava_profile.gd`，颜色均可配置并限制为非 HDR。

| 分组 | 参数 / 默认 | 范围与含义 |
|---|---|---|
| 外形 | radius 54 / perspective 0.62 / pixel_size 1 / shape_seed 37 | 半径16–128，扁平度0.35–1，像素1–4取整；固定seed重复播放可重现 |
| 时序 | opening_time 0.65 / hold_time 3.6 / cooling_time 1.1 / fade_time 0.8 | 秒，仅视觉时间；总长6.15秒 |
| 熔岩 | flow_speed 0.22 / channel_width 0.31 / crust_scale 15 / lava_opacity 0.94 | 流速0–1，通道宽0.06–0.4，岩壳尺度8–24，透明度0–1 |
| 配色 | lava_dark / lava_red / lava_orange / crust_color | 深红、红褐、稀疏橙热斑、暗岩层级 |
| 气泡 | bubble_count 7 / bubble_period 2.4 / bubble_radius 3.5 / bubble_color | 密度0–24，周期0.7–5秒，半径1–8；0确实不绘制 |
| 短焰 | flame_count 5 / flame_height 8 / flame_period 1.8 / flame_color | 密度0–16，高度2–20，周期0.5–4秒 |
| 火星 | spark_count 14 / spark_duration 0.48 / spark_speed 34 / spark_color | 数量0–32，时长0.1–1秒，速度8–80；所有延迟和寿命位于总时长内 |
| 烟雾 | smoke_count 3 / smoke_period 3.2 / smoke_height 22 / smoke_opacity 0.16 / smoke_color | 密度0–12，周期1–6秒，高度4–40，透明度0–0.35 |

视觉范围放大时，岩壳仍保持固定像素/世界尺寸，粒子数量随面积增加并设上限（泡48、短焰24、烟18）；不提高颜色亮度、火焰/烟雾高度或单团透明度。这里的 radius 是视觉外形参数，绝不能当作游戏碰撞范围或平衡数据。

## 图层与已知边界

地面先画，再画小气泡、短焰、火星与低透明烟。游戏以后若接入，宿主负责把角色、敌人、伤害提示和危险预警放到更高层；本次仅用静态参照演示可读性。烟雾不带全屏遮罩、光照叠加或 HDR bloom。

参数采用限界固定循环；本轮未做性能优化或游戏内性能验证。MovieWriter 固定60fps只用于展示时间线，不是实时帧率成绩。不同 GPU 的 Shader 噪声浮点结果可能有细微差别，不承诺跨 GPU 逐像素确定性。

## 检查与录制

`tests/test_lava.gd` 覆盖五组件独立API、NaN/Infinity/越界、配置不变、无效Resource、play前禁用、结束/倒放、stop/clear不复活、组合重复play、独立实例时钟、成长保持亮度与高度、零密度、UI重播和时间轴。正常预览中的勾选层、暂停、清除、重播仍需实际窗口检查。

可在本机有图形显示时录制（生成文件留在仓库外）：

```sh
SOLAR_CAPTURE_DIR=/absolute/output godot --path preview/houyi-lava-godot \
  --audio-driver Dummy --write-movie /absolute/output/houyi-lava.avi --fixed-fps 60 -- --capture
```

`--capture` 演示两个完整时序：默认范围，然后扩大范围。源码中的截图帧直接读取实际 Godot viewport，包含开裂、流动、冷却和扩大范围。录制与日志不进入源码提交。
