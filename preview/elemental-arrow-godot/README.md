# 弓箭箭矢 · 独立 Godot 工作台

Godot 4.6.3 Standard / Compatibility，原创实时像素几何，不使用逐帧图集。
默认箭矢34px，30px静态人形仅为游戏尺寸参照。左侧1×、右侧2× Nearest显示同一画面。
不添加伤害、碰撞、燃烧、麻痹、减速、攻击动作、命中或玩法规则。

通用箭矢、火附着、雷附着和冰附着已全部实现。四份预设可直接运行，三个元素可同时组合。

冰附着由箭杆霜边、三枚不对称冰晶、短冷雾尾迹和零散碎晶组成；箭尖与箭杆仍清楚可辨。
冰晶随箭身方向，脱落碎晶沿历史轨迹运动，没有减速、冻结或命中机制。

雷附着当前试验版为多条从箭头到箭尾、螺旋包绕箭身的独立电弧。默认两条，
每条端点距箭头/箭尾各1px；不把多段短弧拼成“看起来覆盖全长”的一条线。
前半圈在箭身前、后半圈在箭身后，30Hz随机折线扰动和独立相位持续变化；亮芯固定1px。
Arc amplitude控制半径，Arc density控制条数（默认2，最高4，非整数部分平滑调整透明度）；
Intensity和颜色分别可调。所有电弧跟随当前箭身方向，无历史尾迹、离体电粒或战斗机制。
右上LIGHTNING选择SPIRAL（当前试验）或CRACKLE（保留的短分叉版本）；切换不重置时间或其他元素。
旧版本模块完整保留为lightning_crackle.gd，也可回看提交f1c7393。
雷的trail_length参数仍不产生尾迹；同一面板位置显示Arc density，火/冰仍显示Wake length。

火附着按反馈改为箭头聚集的一团分层火焰，只有三条短小火舌和少量短命火星。
箭杆后段与羽毛不附火，无长火尾；火星保留离开时的位置，转弯后不随整支箭旋转。
尺寸、强度、颜色和短火星余量仍可调，没有落地爆炸或燃烧机制。

## 打开

从仓库根目录：

```sh
godot --headless --editor --path preview/elemental-arrow-godot --import --quit
godot --path preview/elemental-arrow-godot
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

`arrow_profile.gd`配置箭身、羽色和三份`attachment_profile.gd`资源。
每个附着资源有enabled、size、intensity、tint、trail_length、glow、seed_value。
arc_density只供雷使用（0–2，默认1）；lightning_mode为0=SPIRAL、1=CRACKLE。
火/冰渲染不读取这两个字段。雷的size只改变幅度，不把亮芯变粗。
颜色在Inspector或颜色按钮修改（对EDIT选中的元素/箭身生效）；强度0完全不绘制该元素。仅几何尺寸变化，不替宿主决定弹道。

## 验证

```sh
godot --headless --path preview/elemental-arrow-godot --script tests/test_arrow.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_workshop.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_crackle.gd
godot --headless --path preview/elemental-arrow-godot --script tests/test_helix.gd
# 以下渲染项需要真实图形显示：
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_validation.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_combinations.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_crackle.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_helix.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot --script tests/render_refinements.gd -- --lightning
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/plain.avi \
  -- --capture --element=0
```

输出目录须预先创建。element参数0/1/2/3分别为通用/火/雷/冰。
录像由Godot真实窗口渲染，包含五种方向/运动场景。测试命令及结果见[QA.md](QA.md)。
受限环境如无可写用户目录，运行前将XDG_DATA_HOME、XDG_CONFIG_HOME和XDG_CACHE_HOME设置为可写目录。
固定MovieWriter60fps不代表目标设备实时性能。无完整游戏或Unity接入验证。
研究与许可证见[REFERENCES.md](REFERENCES.md)。缓存、录制、对照图和日志只保留本地。
