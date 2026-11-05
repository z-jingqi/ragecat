# 弓箭箭矢 · 独立 Godot 工作台

Godot 4.6.3 Standard / Compatibility，原创实时像素几何，不使用逐帧图集。
通用/火/冰预设为34px；设计图雷箭预设为96px，尺寸可调。30px静态人形仅为游戏尺寸参照。左侧1×、右侧2× Nearest显示同一画面。
不添加伤害、碰撞、燃烧、麻痹、减速、攻击动作、命中或玩法规则。

通用箭矢、火附着、雷附着和冰附着已全部实现。四份预设可直接运行，三个元素可同时组合。

冰附着由箭杆霜边、三枚不对称冰晶、短冷雾尾迹和零散碎晶组成；箭尖与箭杆仍清楚可辨。
冰晶随箭身方向，脱落碎晶沿历史轨迹运动，没有减速、冻结或命中机制。

雷附着REFERENCE版按认可设计图重构：修长褐金箭身，三段不等长开口，
偏离箭轴的交点；蓝色细边和柔和蓝光衬托集中白热亮段，伴随断口、锯齿与少量细分叉。
不是规则正弦绳索或镜像双线。主轮廓依据设计图约束，每秒12次真正重新生成主折点、交点与峰谷，局部细噪声30Hz击发；蓝光平滑，硬边保持像素网格。
这次重新制作了独立REFERENCE箭形，CLASSIC原箭形完整保留。火和冰仍使用原34px CLASSIC预设。
游戏工作台雷箭默认为96px；可用Length调18–128px、BODY切回CLASSIC，也可在资源/API中设置18–256px。
Arc amplitude调幅度，Arc visibility调两股可见度；Intensity、颜色、Glow及分叉/闪动参数独立可配。
LIGHTNING提供REFERENCE、DOUBLE（严格对称双螺旋）、SPIRAL（独立螺旋）、CRACKLE（短分叉弧）。
旧0/1/2索引和模块保留，切换不重置时间或其他元素。SPIRAL/CRACKLE仍使用Arc density调数量。
雷无历史尾迹或离体粒子，trail_length不产生尾迹；火/冰Wake length不变。

另提供`reference_preview.tscn`设计预览：256px母版3倍展示，下面同时显示64/96/128px的真实1×飞行。
不能把大图细节完整塞入34px；缩尺会合并细分叉与光晕像素。当前是可运行的程序化还原，
箭羽纹理和细分叉仍与设计图不同，不宣称像素级一致。母版不是默认游戏投射物尺寸。

火附着按反馈改为箭头聚集的一团分层火焰，只有三条短小火舌和少量短命火星。
箭杆后段与羽毛不附火，无长火尾；火星保留离开时的位置，转弯后不随整支箭旋转。
尺寸、强度、颜色和短火星余量仍可调，没有落地爆炸或燃烧机制。

## 打开

从仓库根目录：

```sh
godot --headless --editor --path preview/elemental-arrow-godot --import --quit
godot --path preview/elemental-arrow-godot
# 单独查看设计母版与游戏缩尺
godot --path preview/elemental-arrow-godot res://reference_preview.tscn
```

选择向右、向左、斜向、弯曲转向、静止五种宿主轨迹。可暂停、清空、重播、拖动时间轴，
切换深浅背景。长度、粗细、行程速率、元素尺寸、强度、尾迹长度可实时调整。EDIT选择要编辑的独立元素，不重置组合。
行程速率控制示例轨迹推进；曲线速度向量由位置的真实导数计算，并非恒速曲线的玩法实现。
Body、Air、Fire等复选框直接启停各自当前配置，可组合已安装的元素；不改变时钟。
宿主API的set_layer_enabled只控制显示，不修改配置，关后再开会显示当前时间。
Clear后调参数、拖时间轴、切换预设或Pause不会复活，须Replay或选新轨迹。
UI改动只影响当前运行，不写回预设。

## 宿主接口

```gdscript
const Arrow = preload("res://components/elemental_arrow.gd")
var effect = Arrow.new()
add_child(effect)
var config = preload("res://presets/plain.tres").duplicate(true)
config.length = 34
# 以下坐标和速度使用 effect 父节点的局部坐标系；组件本身保持原点和无旋转。
effect.play(tip_position, flight_velocity, config)
effect.advance(delta, next_tip_position, next_flight_velocity)
effect.set_layer_enabled("body", false)
effect.clear()
```

箭尖位于tip，速度决定箭身方向。速度为零保持上次朝向；首次静止默认朝右。
过去0.9秒轨迹用于历史尾迹，最多160条，过高调用频率会合并采样，仍保留完整尾迹时间窗，不用Timer、物理查询、全局随机或宿主自动释放。
大于180px的单次跳位清除旧尾迹；高速或传送宿主可主动clear/play。
提供`seek(seconds, trajectory_callable)`用于编辑器时间定位；轨迹返回tip和velocity；如果某段速度为0，另返回axis指定静止朝向。seek从固定朝向重建，不依赖上次调用；缺省axis时静止窗口默认朝右，实时advance仍保持上次朝向。
配置深复制，实例互不影响；无穷/NaN和超范围值安全处理。宿主负责释放节点。

`arrow_profile.gd`的body_style为0=CLASSIC、1=REFERENCE，length为18–256px。
REFERENCE采用固定褐金局部调色板，可用body_tint整体调色；feather_color供CLASSIC使用。
它配置箭身、羽色和三份`attachment_profile.gd`资源。
每个附着资源有enabled、size、intensity、tint、trail_length、glow、seed_value。
arc_density只供雷使用（0–2，默认1）；DOUBLE/REFERENCE把它用作可见度并在1处饱和。
lightning_mode为0=SPIRAL、1=CRACKLE、2=DOUBLE、3=REFERENCE（默认），旧索引保持不变。
REFERENCE另有Inspector/API参数arc_forks（0–2，资源默认1，雷箭预设1.4）、arc_jitter（0–2，默认1）、
arc_rate（5–60Hz，默认30）；控制细分叉密度、锯齿扰动及细节击发速度。
arc_variation（0–2，默认1）控制主路径变化幅度，0固定主轮廓；
arc_path_rate（3–20Hz，默认12）控制整条主弧重新生成的频率。二者与细噪声独立，
即使arc_jitter=0，主要转折和交点仍会变化。每次击发共用两处移动交点，保留三组开口，
前后层随交点切换，分叉在当前路径上重新选根；不使用沿固定曲线流动的亮点替代主弧变化。
arc_forks=0严格关闭分叉，每股最多三根；少量支路再分出一条短叉，根部只连到当前可见的主干段。
火/冰渲染不读取雷专用字段。雷的size只改变幅度，不把亮芯变粗。
颜色在Inspector或颜色按钮修改（对EDIT选中的元素/箭身生效）；强度0完全不绘制该元素。仅几何尺寸变化，不替宿主决定弹道。

## 验证

```sh
godot --headless --path preview/elemental-arrow-godot --script tests/test_arrow.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_workshop.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_crackle.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_helix.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_double_helix.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_reference_lightning.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_dynamic_reference.gd
# 以下渲染项需要真实图形显示：
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_validation.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_combinations.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_crackle.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_helix.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_reference_lightning.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_reference_preview.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_dynamic_reference.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_helix.gd -- --original-spiral
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_refinements.gd -- --lightning
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/plain.avi \
  -- --capture --element=0
```

设计预览录像使用`godot --path preview/elemental-arrow-godot res://reference_preview.tscn --fixed-fps 60 --write-movie /absolute/output/design.avi -- --capture`，共12秒。
静态参考比较板使用`tests/render_reference_board.gd`，须显式设置ARROW_REFERENCE_IMAGE本地图片路径与ARROW_CAPTURE_DIR；不打包参考图片。

输出目录须预先创建。element参数0/1/2/3分别为通用/火/雷/冰。
录像由Godot真实窗口渲染，包含五种方向/运动场景。测试命令及结果见[QA.md](QA.md)。
受限环境如无可写用户目录，运行前将XDG_DATA_HOME、XDG_CONFIG_HOME和XDG_CACHE_HOME设置为可写目录。
固定MovieWriter60fps不代表目标设备实时性能。无完整游戏或Unity接入验证。
研究与许可证见[REFERENCES.md](REFERENCES.md)。缓存、录制、对照图和日志只保留本地。
