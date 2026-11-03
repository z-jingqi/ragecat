# VFX-01 · 挥砍 / Clean cut

**当前交付：代码生成的像素挥砍原型 + Godot 实际预览。** 不含序列帧，
不需要 Pixelorama 或 Blender；正式游戏引擎适配等视觉确认后再做。

一笔弧形刀光：细线起势 → 快速展开为两端近似同样尖、中段饱满的弧面 → 尾部追上刀尖收净。
只有象牙白刃、金色主体、琥珀色内侧三层硬色阶；没有黑边、泛光、随机碎点或拖泥带水的残留。

## 文件与运行

- `src/shared/SlashKernel.inc`：唯一形状/时间公式，输入像素坐标、秒、弧度，输出色阶编号 0–3。
- `config/presets.json`：默认值与四个示例预设，作为参数契约与可读交换格式。
- `build_shaders.py`：将纯数学代码转换为 Godot 语法；生成仓库根 `preview/godot/slash.gdshader`。
- `preview/godot/README.md`：预览适配边界。
- `tests/`：数学、参数、生成一致性和预览生命周期检查。
- `THIRD_PARTY_NOTICES.md`：Sprite Fusion 参考来源与保留的 MIT 声明。

从仓库根目录运行：

```sh
python3 effects/pixel/VFX-01_slash/build_shaders.py
godot --path preview/godot
```

左侧同时看 **1×实际像素尺寸** 与 **2×Nearest细看**。小方块只标识挥砍中心，不是角色素材。
右侧可以实时调整，支持四个预设、暂停、单步 1/60 秒、0.25×慢放、循环、重播和默认值重置。
默认正常速度，慢放只用于检查，不降低实际运动的时间采样。

## 有意义的参数

| 参数 | 默认 | 有效范围 / 单位 | 判断与生效方式 |
|---|---:|---|---|
| `direction_degrees` | 0 | 0–360°，+X向右，正方向逆时针 | 任意朝向；即时 |
| `reach_px` | 46 | 16–80 美术像素 | 弧外沿半径，决定攻击视觉长度；即时 |
| `thickness_px` | 13 | 2–28 px，且不超过 reach×0.65 | 弧面最宽处，保留中空；即时 |
| `sweep_degrees` | 112 | 30–220° | 扫过的总角度，改变弧长而非旋转；即时 |
| `curvature` | 0.82 | 0.35–1 | 局部椭圆短轴/长轴比，1为圆弧，低值更扁；即时 |
| `reverse` | false | 布尔 | 反转挥动方向及粗细朝向；即时 |
| `start_seconds` | 0.025 | 0.005–0.080 s | 薄线起势，不能抢走主爆发；修改后重播 |
| `burst_seconds` | 0.065 | 0.015–0.160 s | 快速展开，刀尖三次 ease-out；修改后重播 |
| `decay_seconds` | 0.090 | 0.025–0.250 s | 尾部追赶并变薄，到期完全清空；修改后重播 |
| `edge_color` | `#fff4ce` | RGB，alpha固定1 | 亮刃；即时 |
| `body_color` | `#f5c56b` | RGB，alpha固定1 | 主体；即时 |
| `tail_color` | `#ba7637` | RGB，alpha固定1 | 内沿与最后收势；即时 |

默认合计 **180 ms**；这是普通挥砍的起点，不是全库统一时长。
弧面确定性生成，没有随机行为，因此不提供无效的 seed 旋钮。
`pixels_per_unit:32` 仅记录未来宿主坐标换算参考，本预览直接使用美术像素，不把它伪装成视觉旋钮。
参数文件不是运行时配置加载器；预览中的默认值保持一致，并有测试保护。

### 四个预设

`clean_cut` 普通挥砍；`diagonal_return` 45°反向；`flat_blade` 低弯曲窄刃；
`heavy_arc` 160°、18px、235ms。预设均保留相同硬边与像素密度，不靠粒子数量伪装变化。

## 可移植的数学契约

1. 在统一的**世界/画布像素网格**采样 `floor(world_px)+0.5`，然后减去中心。
   **先量化，再逆向旋转形状**，避免旋转后像素变成菱形或大小不一。
2. 逆转 `direction`，按 `reverse` 翻转局部Y，再用 `curvature` 恢复椭圆坐标。
3. 起势阶段刀尖进至总扫角10%、宽度至22%；爆发阶段展开至完整扫角与宽度。
4. 收势时尾部按 `u²(3−2u)` 追赶刀尖，宽度收至12%，弧段长度归零。
5. 弧长比例 `v` 的宽度为 `thickness × widthEnvelope × sin(πv)^1.2`。
   两端使用同一收尖曲线，最大中段厚度不变；挥动方向由头部推进与尾部追赶保留。
   方形像素网格在任意角度下不保证端点逐像素完全相同。沿宽度切三层纯色，不做 alpha渐隐。
6. `t<=0` 或 `t>=start+burst+decay` 输出0，其他有效输出仅1/2/3。

预览翻转屏幕向下的Y为数学向上的Y；放大视图重复同一像素采样，不重绘更高分辨率轮廓。
这份 `.inc` 是数学源，不是某引擎的可直接导入效果包；`.gd`/`.gdshader` 仅是预览适配。
参数、时间、形状可以移植；本项不宣称已经在其他引擎编译或渲染。

## 自检

```sh
python3 effects/pixel/VFX-01_slash/tests/run_checks.py
godot --headless --editor --path preview/godot --import
godot --headless --path preview/godot --script "$PWD/effects/pixel/VFX-01_slash/tests/check_preview.gd"
```

覆盖：起止清空、薄→宽→收、双端收尖对称性、不同角度/正反向/宽度的尖端内外边界、
360°像素覆盖稳定性、正反镜像、参数边界、四预设、
暂停/单步/重播/循环、时间修改重播、生成代码同步。C++包装只执行同一数学内核，
不是GPU或正式游戏引擎测试；Godot原生运行和实际画面需另行检查。

### 可复现的原生预览录制

```sh
godot --path preview/godot --fixed-fps 60 -- --demo --capture-dir /absolute/path/outside-repo
ffmpeg -framerate 60 -i /absolute/path/outside-repo/frame_%05d.png \
  -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart preview.mp4
```

`--demo` 正常速度依次演示四预设，每个3秒后自动退出。
PNG来自实际 viewport 的 `frame_post_draw`，只是审阅证据，不是运行时素材。

参考：[Sprite Fusion Slash](https://www.spritefusion.com/pixel-art-vfx/slash)、
[Godot CanvasItem Shader](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html)。

## 可复用 Godot 接入（2026-11-03）

`src/godot/slash_effect.gd` 是正式组件来源；`build_shaders.py` 将它与同一份
`SlashKernel.inc` 同步生成到 `preview/godot/effects/VFX-01_slash/`。
原预览的屏幕空间 Shader、默认外观和 180ms 时间不变。新运行时 Shader 用局部 UV，
随 Node2D/相机/视口变换，不依赖屏幕坐标或实验室 UI，也没有角色或武器绘制。

接入时复制生成的 `slash_effect.gd` 和 `slash_runtime.gdshader`（放同目录），保留
本项 `THIRD_PARTY_NOTICES.md`。调用：

```gdscript
var fx = preload("slash_effect.gd").new()
add_child(fx)
fx.play(origin, direction, 115.0, 0.85, {"pixel_size": 2.0, "curvature": 1.0})
# 由游戏的模拟时钟调用；暂停时不调用。
fx.advance(delta)
if fx.done: fx.queue_free()
```

- `origin`、半径：父节点坐标与世界单位，不再受实验室 80 美术像素滑块上限限制。
- `direction`：Godot +Y 向下。组件转换到原内核 +Y 向上；零向量安全地向右。
- `half_angle`：弧度半角；两倍为扫角。圆锥游戏设 `curvature=1` 保留圆形距离边界。
- `pixel_size`：一个美术像素的世界单位，默认 1；山海接入为 2。
- 可覆写 `reverse`、三段时间、`thickness_ratio`、三层颜色；默认仍是获准的干净三色刀光。
- 每个实例独立材质；重播复用、重叠刀光、`stop()` 清理均支持。游戏负责数量上限和销毁。
- 组件不发攻击、碰撞、伤害或奖励事件；可见起势不改变已结算的游戏命中时间。

验证：`python3 effects/pixel/VFX-01_slash/tests/run_checks.py`；
`godot --headless --path preview/godot --script res://effects/VFX-01_slash/test_runtime.gd`。
实战尺寸预览：`godot --path preview/godot res://effects/VFX-01_slash/runtime_preview.tscn`。
本轮对照了 SpriteFusion `slash` 结构和 ParticleFX Sword Slash Combo 的八帧图，
保留既有原始刀光，不新增参考里的泛光、碎点或角色动画。
