# 火 / 雷 / 冰元素挥砍

入口：`godot --path preview/xingtian-slash-godot res://elemental_preview.tscn`。
Godot 4.6.3 Standard / Compatibility，无额外插件。这里是用户已认可设计图的
代码优先游戏尺度适配，不是 Sprite Fusion 原版复刻，不是完整游戏接入。

## 外观与范围

- 火：暖白切边、金黄到深红硬色带，边缘弯曲短焰，消散时少量热火星。
- 雷：蓝白刀光，边缘多段短电弧与分叉，30Hz重新折动，细白核外包青蓝边。
- 冰：青白刀光，外缘不对称三角冰晶、白色棱线和深浅切面，收尾散出旋转碎晶。

复用认可的 `components/copper_arc.gd` 接口，新元素Shader从认可版本派生，
只加宽靠前的亮刃区域。本轮不修改
原始脚本、默认预设、旧命中或重击。新增 Resource 继承原挥砍参数；新元素默认厚度24px、压扁0.45、弧段220°、
中心−60°、倾斜−18°，用于还原设计图横向长尖与右侧厚亮头。保留
0.06秒挥出 / 0.06秒保持 / 0.24秒尾端追赶；新附着跟随同一椭圆局部坐标与时间。
新七阶元素配色只应用于新的实例。原始半径52px不变。没有地面冲击波、命中闪光、喷血、碰撞、
伤害、减速、感电传播、燃烧状态或攻击频率变更。元素名称是视觉选择，不执行状态逻辑。

## 组件 API

```gdscript
const ElementProfile = preload("res://elements/element_profile.gd")
const ElementSlash = preload("res://elements/elemental_slash.gd")
var settings = ElementProfile.new()
settings.element = 1 # 0 fire, 1 lightning, 2 ice
settings.apply_palette() # 显式载入元素色带；之后可自行改颜色
var visual = ElementSlash.new()
add_child(visual)
visual.play(Vector2(120, 120), settings)
visual.advance(delta) # 宿主控制时钟
visual.set_layer_enabled("attachment", false) # arc / attachment / debris
visual.seek(0.08) # 正常结束后可倒回查看；clear 后不能复活
visual.clear() # 之后必须 play
```

`play`复制并清洗Resource。位置非法会清除，负delta/非有限时间不推进。
同一配置可用于多实例，时钟互不影响。不创建Timer、全局随机状态、物理查询或自动销毁。
局部正向对应现有刀弧；`facing_left`完整镜像，`reverse`与原弧一致。
宿主可移动整个Node2D；已脱离碎片仍是本次挥砍的局部视觉，不承诺世界空间历史轨迹。

### 新增参数

| 参数 | 默认 | 范围 / 含义 |
| --- | --- | --- |
| element | 0 | 0火 / 1雷 / 2冰；配色由显式apply_palette载入 |
| attachment_enabled / debris_enabled | true | 两层分别开启 |
| attachment_strength | 1 | 0–1.8，边缘伸出长度倍率；0同时关闭附着与碎屑 |
| attachment_count | 6 | 0–12，固定种子的不规则边缘节点 |
| debris_count | 8 | 0–16，独立碎屑数 |
| edge_reach | 15px | 3–25px，边缘短焰、电弧、冰晶的基准伸出长度 |
| debris_lifetime | 0.18s | 0.06–0.3s，每个碎屑实际寿命为65%–100% |

尺寸、厚度、种子、强度、七色、像素网格、镜像和时序仍用继承的原挥砍参数，
有效范围见原README。所有数值是美术参数，不是技能平衡数据。层开关在重播后保留。

## 预览与复核

三列同步显示火雷冰。上方最近邻3×细节，下方真实1×尺寸，与仓库原有76px高的
静止刑天原图对照。不会冒充角色攻击动画。范围增大时细节自动改为2×或1×，
保持整数像素且不裁边。面板可调半径、厚度、边缘伸出、节点数和碎屑数，
可独立关闭弧面/附着/碎屑、镜像、暂停、重播、清除、时间定位和0.25×慢放。
Clear后修改参数、镜像或Resume都保持清空，必须显式Replay。

```sh
godot --headless --path preview/xingtian-slash-godot --script tests/test_elements.gd
ELEMENT_SLASH_CAPTURE_DIR=/absolute/existing/output godot --path preview/xingtian-slash-godot \
  --audio-driver Dummy --script tests/render_elements.gd
godot --path preview/xingtian-slash-godot --audio-driver Dummy --fixed-fps 60 \
  --write-movie /absolute/existing/output/elemental-slashes.avi \
  res://elemental_preview.tscn -- --element-capture
```

12秒真实Godot录制：前4秒原速、中4秒0.25×、后4秒镜像原速。
录制和瞬时图片不是运行时素材，不提交入库。MovieWriter不是实时性能成绩。
自动测试覆盖三元素的起手、收尾、完全清空、倒放一致、附着开关、独立附着、
零强度、最大范围、Clear和预览控件。旧挥砍、命中、重击与多人测试需继续通过。
独立原生预览验证和实际游戏内验收不同，用户视觉确认仍单独进行。

## 来源与许可

本轮基线 `bef504345fdf5b7a381370ebff57a9fa9db18bfa`。认可的弧面以及派生宽亮刃来源、原始
许可证和现有角色图片来源分别保留在 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)、
[LICENSE](LICENSE) 和 [assets/README.md](assets/README.md)。

2026-11-05再次实际调用 SpriteFusion MCP `get_vfx(slash)`、`get_vfx(ice)`，
读取仓库中已验收的 `spritefusion_exact/source/slash.ts`、`fire.ts`、
`lightning.ts` 和 Slash 原生关键帧。学习指数挥出/追赶尾迹、短焰分层、
电弧折点与亮核优先、冰晶明暗切面。新附着是解析GDScript原创实现，不声明逐像素移植。
`elements/elemental_arc.gdshader`保留原算法和参数结构，仅将前缘白亮面由固定22%
改为随弧段位置渐宽的18%–46%；原Shader及旧预设保持不变。

同时通过GitHub读取固定版本 Patch-gg PixelFX
[`a84159688af3ca37a4be05a0d422b94451b2e24e`](https://github.com/patch-gg/pixelfx/tree/a84159688af3ca37a4be05a0d422b94451b2e24e)
的 `docs/AUTHORING.md`、`melee/heavy-cleave.js`、`lightning/electrified.js`、
`ice/ice-lance.js`。采用局部坐标、确定性种子、快入慢收、1px白色亮边、
深浅分层以及先渲染、观察最差问题、再修改的流程。本轮直接在Godot中渲染和检查，
没有声称重新运行PixelFX的JS工具。没有复制完整攻击、演员、地面裂纹、烟尘、
地波或参考素材，也没有使用Patch Pixel字体、图集、逐帧PNG或生成图片作运行时纹理。

Sprite Fusion代码MIT版权2026 Hugo Duprez；PixelFX代码MIT版权2026 Patch与
2026 Hugo Duprez，完整许可已保留。设计参考图用于视觉方向，不打包进运行时。

### 本轮验收状态

2026-11-05：最终状态测试28项、原生Compatibility渲染测试121项通过；
旧挥砍57、命中38、重击70、多人29项回归通过。原始弧面、命中、地波、
旧预设及 `spritefusion_exact/` 没有修改。新增渲染测试涵盖默认三元素在
7个时刻的双向画布边缘和6组大小混合参数，防止放大视图裁掉火舌、电弧或冰晶。

经过原生渲染对照后，修正了初版偏竖偏细的弧形、过均匀的节点、偏细的冰晶、
过亮的白色块面、参数滑块与实际清洗值不一致以及默认细节视图右缘裁切。
高分辨率设计图在52px半径上做了细节取舍，不声称逐像素一致；视觉相似度
以形状、七阶色带、宽亮头和各元素独有边缘为准。仍未接入真实游戏，
也没有跨GPU、移动端、Unity或量化性能验收。用户视觉确认不由测试替代。
