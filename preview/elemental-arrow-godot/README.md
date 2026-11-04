# 弓箭箭矢 · 独立 Godot 工作台

Godot 4.6.3 Standard / Compatibility，原创实时像素几何，不使用逐帧图集。
默认箭矢34px，30px静态人形仅为游戏尺寸参照。左侧1×、右侧2× Nearest显示同一画面。
不添加伤害、碰撞、燃烧、麻痹、减速、攻击动作、命中或玩法规则。

当前阶段：通用箭矢已实现。火、雷、冰为后续独立可组合的附着模块；未实现的选项禁用。

## 打开

从仓库根目录：

```sh
godot --headless --editor --path preview/elemental-arrow-godot --import --quit
godot --path preview/elemental-arrow-godot
```

选择向右、向左、斜向、弯曲转向、静止五种宿主轨迹。可暂停、清空、重播、拖动时间轴，
切换深浅背景。长度、粗细、速度、元素尺寸、强度、尾迹长度可实时调整。
Body和Air独立显示开关；元素模块按各自资源enabled启用，显示开关不改资源或时钟。
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
过去0.7秒轨迹用于历史尾迹，最多160条，不用Timer、物理查询、全局随机或宿主自动释放。
大于180px的单次跳位清除旧尾迹；高速或传送宿主可主动clear/play。
提供`seek(seconds, trajectory_callable)`用于编辑器时间定位；轨迹返回tip和velocity。
配置深复制，实例互不影响；无穷/NaN和超范围值安全处理。宿主负责释放节点。

`arrow_profile.gd`配置箭身、羽色和三份`attachment_profile.gd`资源。
每个附着资源有enabled、size、intensity、tint、trail_length、glow、seed_value。
颜色在Inspector修改；强度0完全不绘制该元素。仅几何尺寸变化，不替宿主决定弹道。

## 验证

```sh
godot --headless --path preview/elemental-arrow-godot --script tests/test_arrow.gd
ARROW_CAPTURE_DIR=/absolute/output godot --path preview/elemental-arrow-godot \
  --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/plain.avi \
  -- --capture --element=0
```

输出目录须预先创建。录像由Godot真实窗口渲染，包含五种方向/运动场景。
固定MovieWriter60fps不代表目标设备实时性能。无完整游戏或Unity接入验证。
研究与许可证见[REFERENCES.md](REFERENCES.md)。缓存、录制、对照图和日志只保留本地。
