# 03 / 像素蓄力与独立消散

**当前只做蓄力 → 持续 → 显式消散**。角色周围粒子向内收紧；脚下贴地旋转风带缓缓上升、随蓄力变快并收束。不是独立龙卷风，不自动变成冲击波、挥砍、命中或伤害。后续攻击特效由宿主独立组合。

```sh
godot --path . res://scenes/vfx_lab/charge/charge_lab.tscn
```

Godot 4.6.3 Standard / Compatibility；384×160 低分辨率、3× 最近邻、有限色板、无抗锯齿 / 发光 / 模糊。风带分角色前后两层，保留身体与手势可读性。演示角色和背景不属于可复用特效；游戏主场景和战斗系统不变。

## 控制

R 重播；Space 暂停；S 1× / ¼×；B 明暗背景；→ 暂停并单步；L 循环开关；**A 切换自动演示 / 手动持续**；**C / Dissipate 显式消散**。

默认自动演示是实验室调用方安排“蓄满后保持 0.6 秒，再调用消散”，不是行为自动释放。A 切到 MANUAL 后会无限持续，直到 C；再次 C 不延长消散；循环开着时消散完成后开启下一轮，L 可关闭循环。R 清除消散记录重新蓄力。暂停冻结全部动画；单步保持暂停。

P / Parameters 打开折叠面板；Esc 关闭并释放焦点。Tab / Enter 编辑；持续强度实时生效、不重启当前蓄力，其余参数修改自动重播。四预设 Default、Quick / compact、Heavy / wide、Quiet / sparse；Reset defaults 恢复默认。Inspector `Settings` 在运行时深拷贝，不回写源 Resource。

| 参数 | 默认 | 安全范围 |
|---|---:|---:|
| 蓄力时间 | 1.2 s | 0.4–2.5 s |
| 底部风场半径 | 48 px | 24–64 px |
| 风旋转速度 | 1× | 0.25–3× |
| 风上升高度 | 42 px | 16–60 px |
| 粒子内收速度 | 1× | 0.25–3× |
| 风带强度 | 1× | 0.5–2× |
| 持续强度 | 1× | 0.25–1× |
| 消散时间 | 0.45 s | 0.2–1 s |
| 粒子数量 | 24 | 0–40 |

半径同时决定粒子的聚集范围；强度控制风带厚度，不是伤害。风场在蓄力过程中自然加速并收束，速度参数整体缩放。所有字段有 Inspector/UI/运行时边界与非有限值保护。默认构图完整；最大风半径/高度/强度共同取极值时少量末端可接近画布边缘，复用宿主可提供更大画布。

## 独立 API / 结构

- `charge_config.gd`：Resource、参数安全范围。
- `charge_behavior.gd`：无场景依赖；`configure(settings)` 深拷贝；`sample(time, stop_at=-1)` 返回 READY / GATHER / INTENSIFY / SUSTAIN / DISSIPATE / FINISHED 与 charge/opacity/active。
- 没有 stop_at 时 `duration()` 为 INF，永不自动消散或攻击；调用方记录一次 stop_at 后传入，每次采样确定性消散。`duration(stop_at)` 包含 0.25 秒安静间隔。
- `pixel_charge.gd`：纯像素风带与粒子；默认无演示人物 / 背景。`effect_origin` 可在宿主画布定位，`behavior/time/stop_at` 由宿主驱动；节点生命周期由宿主管理。
- `pixel_charge_demo.gd`：可选实验室人物 / 背景，由实验室注入；纯效果不依赖实验室脚本。
- `charge_lab.gd` / `.tscn`：预设、控件、自动演示编排和真实 viewport 捕获。

`active` 仅表示视觉活跃，不是攻击许可。下一项投射物 / 龙珠式能量弹（圆头、锯齿波纹光冠、渐细尾部）独立实现，不属于本项，也未开始。

## 检查 / 捕获

```sh
godot --headless --script tests/vfx/charge/pixel_charge_lab_tests.gd
bash tests/run_all.sh
godot --audio-driver Dummy --path . res://scenes/vfx_lab/charge/charge_lab.tscn -- --capture-dir=/absolute/outside/repo/frames
godot --audio-driver Dummy --path . res://scenes/vfx_lab/charge/charge_lab.tscn -- --parameter-demo --capture-dir=/absolute/outside/repo/presets
```

主捕获 720 帧 / 12 s：暗背景正常 3 s、亮背景半速 6 s、暗背景提前消散 3 s。预设捕获 960 帧 / 16 s。是真实 Godot 渲染 viewport；headless dummy 拒绝捕获。截图、视频、日志留仓库外。检查覆盖持续不攻击、显式消散、长期保持、参数 / 非有限范围、确定性、前后层绘制、Resource 隔离、实际 SpinBox 信号、暂停 / 单步 / 重置 / 重复节点数量；无头测试不替代视觉验收。
