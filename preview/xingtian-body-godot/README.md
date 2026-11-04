# 刑天 · 贴体状态预览

独立 Godot 4.6.3 Compatibility 工程。本阶段只表现 **普通 → 攻速/气势积累 → 衰减**：暗红光从胸甲接缝逐渐延伸到肩部、前臂与既有披布纹样，高状态出现克制的流动高光，衰减时逐步收暗并完整恢复原图。

没有脚下圈、地面光、自由飞散粒子、攻击动作或人物位移。不增加护甲、战意、濒死、复活、血量、攻速数值、被动、碰撞或任何游戏逻辑。12 秒时间轴只用于展示视觉，百分比不是实际叠层或平衡参数。现有挥砍和 SpriteFusion 原版目录保持独立。

## 运行与操作

```sh
godot --path preview/xingtian-body-godot
godot --headless --path preview/xingtian-body-godot --script tests/test_body_state.gd
```

导入本目录 `project.godot`，F5 也可。无插件、网络、外部图集或绝对路径依赖。

- 主视图保留原始静态人物，右侧是同一贴体效果的上半身放大视图。
- Normal 保持原图，Build 开始积累，Full 保持满状态，Decay 展示衰减。Replay 重播完整流程。
- Pause 暂停全部显示时钟，底部时间轴可暂停定位；手动强度模式显示独立的 Flow clock。
- Display amount 是视觉输入；Intensity、Local glow、Flow speed 可调，Shoulder flow 可关闭。
- Clear 清除特效而保留原图，后续滑块或时间轴操作不能自动恢复，必须 Normal / Build / Full / Decay / Replay 显式启动。
- BG 切换深浅背景；Reset 恢复默认参数。主视口和录像固定 1280×800，小窗口仅缩放显示。

## 复用组件

`components/body_state.gd` 是角色专用 Sprite2D：它绑定此刑天立绘的原始透明 PNG 与对应接缝几何，不是自动识别任意角色的通用裂纹生成器。可直接作为宿主角色的显示子节点；位置、缩放由宿主设置。原图纹理和一次生成的静态接缝数据共享，ShaderMaterial 与配置快照逐实例独立。不做逐帧图像读回、纹理上传或像素图集动画。

```gdscript
const BodyState = preload("res://components/body_state.gd")
var body = BodyState.new()
add_child(body)
body.position = Vector2(320,400)
body.scale = Vector2.ONE * 0.21875
body.configure(load("res://presets/default.tres"))
body.start(0.0)
body.set_amount(0.65) # 外部状态归一化后的视觉输入
body.advance(delta)   # 外部可暂停时钟；也可 seek(seconds)
body.clear()          # 保留人物原图，所有光归零
```

组件不自行积累、衰减或循环，宿主拥有 `amount` 与时钟。`start` 显式重启，非法数值以零开始；`set_amount` 清洗到 0–1，非有限输入被忽略。`advance` 拒绝负值/非有限值/溢出；`seek` 支持向前或向后定位。清除后 `set_amount/advance/seek/configure` 均不复活。

`body_profile.gd` 提供 intensity 0–1.5、local_glow 0–0.6、flow_strength 0–1、flow_speed 0–3、breathing 0–0.2、三色调色板和纹样/流光开关。`configure` 复制并清洗参数，不改调用方。零 amount 或零 intensity 完全显示原图。Shader 不修改 alpha，不向轮廓外加光；源图已有的头火和护臂火焰是静态素材的一部分，并非本效果生成。

接缝在 `body_paths.gd` 的 238×318 坐标中可编辑，对应原图每 8×8 像素。RGBA 数据保存距离、显现次序、路径位置与流光权重，运行时 shader 依据输入状态揭示路径。局部辉光只作用于原图内部。更换人物/姿势需要另行校准路径，不应复用当前路径假装自动贴合。

## 素材与方法

直接复用用户已批准的 1904×2544 RGBA 刑天透明图，文件 SHA-256：
`092ce44128c7d60c0fc34d9bc7648ae132fcb049e019b06b297928b32571257e`。

未重新绘画、去背景、缩图或改变源文件。纹理导入为 lossless、无 mipmaps、Nearest；原图顶部火焰/烟的既有裁切仍保留，不擅自补画。路径/纹理基于实际像素检查而非文字猜测。素材来源记录见 [assets/README.md](assets/README.md)。

实际读取 SpriteFusion MCP 的 Power Up 配方/源码和 Patch PixelFX 的 status/rage、haste、body-mask helper，借鉴贴体采样、分层调色、外部时钟和渲染迭代方法。没有直接搬用地面冲击、外轮廓光环、抖动人物、奔跑姿势、残影或库存美术。`tools/pixelfx-body-draft.js` 是另写的接缝时序草稿，可在固定版本 PixelFX 工具中检查；最终原生工程不依赖 PixelFX 运行时。此项是刑天定制设计，**不是 SpriteFusion 精确复刻**。来源和许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 原生渲染检查与录像

需要有图形显示环境，先创建仓库外输出目录：

```sh
XINGTIAN_BODY_CAPTURE_DIR=/absolute/output godot --path preview/xingtian-body-godot \
  --audio-driver Dummy --script tests/render_probe.gd
godot --path preview/xingtian-body-godot --audio-driver Dummy --fixed-fps 60 \
  --write-movie /absolute/output/body-state.avi -- --capture
```

像素探针比较零状态与未加 shader 的人物，检验积累覆盖增长、alpha/轮廓不变、流动/关闭、重复定位、零强度、清除/重播和衰减还原。MovieWriter 固定 60fps 只用于可重复展示，不是实时帧率成绩。源图包含二值透明度，本素材不能独立证明任意半透明输入表现。实际游戏接入、其他姿势、移动端和硬件 GPU 尚未验证。
