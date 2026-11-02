# VFX-02 · 武器拖尾（Godot 参数原型）

真实武器 **base / tip 世界坐标历史** 的程序化像素带。它不是挥砍模板曲线随武器移动，也不读取精灵图集。当前阶段仅交特效设计、独立数学、参数与 Godot 实际预览；**没有 Unity 运行代码或 Unity 兼容性验收**。

## 直接运行

仓库根目录，Godot 4.6.3 标准版：

```sh
godot --path preview/godot res://effects/VFX-02_weapon_trail/weapon_trail.tscn
```

独立场景，不修改默认预览入口。左侧同时显示 1× 游戏尺寸和 2× 整数像素检查，右侧参数立即生效。Pause / + Frame / Reset 控制时间；Turn 反转实际武器运动，Stop 停住武器但让历史继续老化，Teleport 断开历史，Pan 验证世界像素栅格。左下 Motion 切换旋转、直线平移、斜向平移、曲线+旋转；平移模式固定刀刃方向，确实不是换了旋转轨迹。顶部 3 个命名预设来自 `config/presets.json`。Gold / Jade 只替换颜色，不冒充新特效。

灰色细线只是示例宿主武器；拖尾输入是独立的真实端点采样，不依赖该示例的旋转方程。游戏接入时，把实际世界坐标送给 `trail_history.gd` 的 `submit_pose(base, tip)`，每模拟步调用 `advance(delta_seconds)`，视图调用 `sync()`。先推进时间再提交本步姿态。

## 数学与采样契约

- +X 向右、+Y 向上；距离以世界单位、时间以秒。预览显式翻转 Godot 的画布 Y，不量化逻辑运动。
- `src/shared/TrailKernel.inc` 是不含引擎 API 的纯数学文本；`build_shaders.py` 只转换所需向量语法并生成 Godot Shader，**不是通用跨引擎转换器**。
- 环形数组固定 64 槽，按时间保存 base / tip / birth。两端最大位移达到 `min_sample_distance` 才追加，静止不追加、不刷新出生时间。历史到期独立于发射状态。
- 相邻两条实际刀刃截面形成两三角形；剩余寿命 `r = clamp(1 − age/lifetime, 0, 1)`，截面内端 `tip + (base − tip) × width_fraction × r^taper_power`。因此尾端细、近刀身宽，停止后缩窄并干净消失。
- 超过瞬移阈值，或单步刀刃方向跳变大于 120°，先清空再种下新点，不虚构中间轨迹、不跨屏拉长线。持续正反旋转均支持；采样太稀会有意显露折面，应降低间距或提高宿主更新率，而非编造轨迹。
- Shader 对**世界坐标**执行 `floor(world_pixels)+0.5` 后做三角形覆盖测试。三个不透明色阶，无 AA、Bloom、黑边、噪点或装饰残留。可选透明消退也只有四阶；默认完全依赖几何收束。
- 交叠处选剩余寿命较大的（较新）几何，防止反向转动叠成更亮色块。每视图只绘制实际历史边界外扩 2 像素的矩形。
- `stop_emission()` 停止收样并自然清尾；`clear()` 立刻清理；`begin_trail()` 清理后复用。没有逐点 Node、粒子对象或无界队列；历史和上传数组均复用固定容量。

### 不是只支持旋转；但也不是中心点线条拖尾

采样类不接收角度或轨迹模式，只接收两端世界坐标。因此真实平移、斜扫、曲线和转动都能留下历史扫掠面。示例 Motion 仅改变宿主如何运动，不改变拖尾算法。

**严格沿刀刃轴线前后直刺时，一条零厚度刀刃扫出的面积是零。** 本实现不会为它凭空加横向宽度，因而这种特例不产生可见带面；横向/斜向平移则有真实扫掠面积。需要“直刺也始终有固定宽度”的风格时，应另定义武器厚度或中心轨迹带的视觉规则，不应称当前扫掠面已支持那种表现。

## 真正有效的参数

| 参数 | clean_blade | 有效范围 / 行为 |
|---|---:|---|
| lifetime | 0.16 s | 0.02–0.60 s；到期删除 |
| min_sample_distance | 0.045 u | 0.005–0.50 u；两端最大位移 |
| max_samples | 32 | 2–64；调小立即裁旧记录 |
| width_fraction | 0.68 | 0.05–1；相对当时刀刃长度，不是世界固定线宽 |
| taper_power | 1.35 | 0.25–4；越大尾部越快变细 |
| teleport_distance | 3 u | 0.25–30 u；应大于正常单步端点位移 |
| pixels_per_unit | 16 | 1–128；正式视觉以游戏统一像素密度设置 |
| opacity | 1 | 0–1；全局不透明度 |
| fade_mode | hard | hard / stepped（四阶 alpha） |
| core / body / edge | 暖白 / 金 / 琥珀 | 三层有限色阶；无纹理依赖 |

预览 Speed 0.2–2.5× 只改变示例武器速度，**不改变秒制寿命**。没有无效 seed；此效果完全确定性。Reset 恢复运动、时间控制、预设、颜色、相机与采样状态。预设 JSON 是正式源；不要单独编辑预览目录的同步副本。

## 再生成与测试

```sh
python3 effects/pixel/VFX-02_weapon_trail/build_shaders.py
python3 effects/pixel/VFX-02_weapon_trail/build_shaders.py --check
python3 effects/pixel/VFX-02_weapon_trail/tests/test_contract.py
godot --headless --path preview/godot --script res://effects/VFX-02_weapon_trail/test_history.gd
godot --headless --path preview/godot --script res://effects/VFX-02_weapon_trail/test_demo.gd
```

这些自动测试覆盖独立于旋转的直线/斜向/轴向端点采样、混合变换、静止、到期、停止、瞬移、反向、世界变换、容量复用、非法输入、实时配置极值与预览状态机。无窗口通过不等于视觉验收；真实渲染与原速观看必须另行检查。未来若确认需要 Unity 接入，再移植并单独编译/运行验收。

### 实际引擎录制

```sh
godot --path preview/godot res://effects/VFX-02_weapon_trail/weapon_trail.tscn \
  --write-movie /absolute/path/outside-repo/trail.avi \
  --fixed-fps 60 --quit-after 960 -- --trail-auto
```

引擎实际渲染 16 秒：旋转 → 固定朝向直线平移 → 固定朝向斜扫 → 曲线+旋转 → 加速反向 → 停止清空 → 瞬移 → 基线。`--trail-auto` 仅操作同一组预览控件和宿主输入，不使用另一套渲染算法；MovieWriter 输出只是审阅证据，不是运行时素材。

## 来源与依赖

本项代码与视觉为新编写，无第三方图像/模型/纹理依赖，无额外插件。实现参考官方 [Godot CanvasItem Shader 文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) 与 [自定义 2D 绘制说明](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)。官方文档仅用于 API 语义，没有复制外部实现。
