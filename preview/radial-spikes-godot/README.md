# 角色中心 · 土锥、冰锥、雷电逐层扩散

原创 Godot 4.6.3 像素特效独立原型。土锥与冰锥从角色脚下周围的内层起，向外逐层破土；
每一层独立生长、短暂停留、消退；前一层正在消退时，下一层开始长出，形成连续外传波，
不再先铺满三层。默认仅相邻两层短时间共存。同层存在小幅半径、角度、尺寸和时间差。厚实的碎岩、阶梯断层、落土碎屑与地裂
全部由实时代码绘制，无 PNG 帧动画、预制素材或外部依赖。

这是没有新设计图时的原创提案，不宣称已获得用户视觉批准，不是 Sprite Fusion 的精确移植。
只做视觉，不定义伤害、击退、碰撞、状态、地形阻挡或战斗规则。

## 运行

导入 `preview/radial-spikes-godot/project.godot`，或：

```sh
godot --path preview/radial-spikes-godot
```

左侧 360×240 原生 1×，右侧相同帧 Nearest 2×。30px 中性角色仅用于尺度和前后遮挡。
预览有 Replay、New seed、Pause/Resume、Clear、背景切换、Reset、时间轴、10 项滑块、三色调色和 1× / 0.35× 播放速度。
空格暂停，R 重播，Esc 退出。颜色及滑块直接修改当前实例副本，不覆盖预设文件。

## 组件接口

复制 `components/`、`modules/`、`presets/` 与 `licenses/` 到新 Godot 工程，保持相对结构。
渲染模块使用组件相对路径，迁移到其他 Godot 子目录后仍可加载；场景的 `res://` 预设路径需按宿主调整。

```gdscript
var effect = preload("res://components/radial_spikes.gd").new()
world.add_child(effect)
effect.configure(load("res://presets/earth.tres"))
effect.play(character_feet, 17)
# Host drives time. The component itself has no _process or Timer.
effect.advance(delta)
# seek(seconds) reconstructs the same deterministic frame, even after completion.
# clear() removes all runtime geometry; seek() cannot resurrect a cleared cast.
```

宿主需要 `y_sort_enabled=true`，角色与 `effect` 作为同级节点，角色原点设在脚下。
组件嵌套 y-sort 把各锥的地面锚点与角色一起排序。`play` 固定本次施法中心，
不会在角色随后移动时拖走地面特效。`finished` 每次到达终点发出一次，宿主决定释放节点。
修改运行中参数会按同一种子重建一次布局；任意时间的绘制都只依赖时间、种子和参数。

## 参数

`components/spike_profile.gd` 可在 Inspector 或 API 调整：

- layers：1–6，默认 3。单层位于 inner_radius。
- inner_radius / radius：内外层半径，默认 36 / 103 逻辑像素。
- layer_overlap：前后层衔接的交叠时长，土 / 冰 / 雷默认 0.24 / 0.25 / 0.21 秒。
- layer_delay：交叠计算后的额外层间延迟，默认 0 秒；首次出现仍为 0.10 秒。
  设大于 0 可推迟下一层，设 overlap=0 可查看完全分开的对照。
- density：默认 1。每层数量 round(周长 / 32 × density)，至少 4、最多 82。
- spike_size：默认 1，同时缩放高度和宽度。
- rise_time / hold_time / fade_time：每个锥生长 / 持续 / 消退，土锥默认 0.14 / 0.08 / 0.28 秒。
- irregularity：默认 0.7，控制环内角度、半径和短延时扰动，0 关闭这些扰动。
- ground_squash：默认 0.53，只压缩地面深度，不压扁锥体。
- debris_density / ground_opacity：碎屑数量和地面裂纹透明度，均可设为 0。
- primary / highlight / shadow：主体、亮面、暗面，独立三色及 Alpha。

时序公式为“层跨度 = 生长 + 停留 + 消退 + 同层抖动窗口”，“层步长 = 层跨度 − overlap + delay”。
overlap 限制在消退时长以内，且不超过层跨度的 49%，避免三层同时共存。
UI 的 overlap 上限随时长改变；完整参数仍可通过 Inspector / API 设置。
旧 layer_interval（固定起始间隔）已由 layer_delay / layer_overlap 取代；更新旧调用时请改用这两个字段。

输入会深复制并限制范围，NaN/Infinity 用安全默认值替换。最多 492 个锚点，
这是边界限制，不代表最大负载已通过目标游戏性能验收。极端参数可能超出预览画布；
实际宿主应为完整范围留足相机空间。

## 验证与录制

```sh
godot --headless --editor --path preview/radial-spikes-godot --import --quit
godot --headless --path preview/radial-spikes-godot --script tests/test_radial.gd
godot --headless --path preview/radial-spikes-godot --script tests/test_workshop.gd
godot --headless --path preview/radial-spikes-godot --script tests/test_overlap.gd
RADIAL_CAPTURE_DIR=/absolute/output godot --path preview/radial-spikes-godot --script tests/render_wave.gd
RADIAL_CAPTURE_DIR=/absolute/output godot --path preview/radial-spikes-godot --script tests/render_radial.gd -- --element=earth
godot --path preview/radial-spikes-godot --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/earth.avi -- --capture --element=0
```

原生图形检查拒绝 headless。视频为真实 Godot 16 秒 60fps MovieWriter：前 6 秒正常速度，后 10 秒 0.35× 慢放，
最后 4 秒切换亮底。下方逐层标注 waiting/growing/holding/fading/gone，便于核对交接。
MovieWriter 的固定帧率不是设备实时性能承诺。无完整游戏 / Unity 接入测试。
日志、截图、视频保存在仓库外。受限环境可将 HOME 和 XDG_* 指向可写目录。
验证状态见 [QA.md](QA.md)，算法与参考见 [ALGORITHM.md](ALGORITHM.md) 和 [REFERENCES.md](REFERENCES.md)。

## 冰锥预设

选择 ICE 或加载 `presets/ice.tres`。独立的三叉晶体采用窄长非对称冰棱、青蓝半透明切面、
亮色断续棱线、地面碎霜与少量脱落冰屑，与宽厚不透明岩锥明显区别。
冰锥生长 / 持续 / 消退为 0.16 / 0.07 / 0.30 秒，其余扩散参数共用接口但各预设独立。
原生检查把 `--element=earth` 换为 `--element=ice`；视频参数为 `--element=1`。

## 雷电预设

选择 LIGHTNING 或加载 `presets/lightning.tres`。雷电沿相同向外层序出现在各地面锚点，
表现为短促上窜锯齿弧、非对称分叉和局部贴地爬电，不是固体锥，也不是常亮圆环。
每处放电都有种子决定的脉冲与熄灭间隙，路径每 0.042 秒重新折转。
紫蓝外层、淡白亮芯和少量短电火花分开绘制，无全屏闪光或相机震动。
其生长 / 持续 / 消退为 0.12 / 0.08 / 0.25 秒，主参数仍可独立调节。
原生检查参数为 `--element=lightning`，视频为 `--element=2`。另可运行：

```sh
godot --path preview/radial-spikes-godot --script tests/render_lightning.gd
```

此测试测量单处放电的明暗间隙、动态换形、逆向时间重现、碎屑/地面关闭与 Alpha。
