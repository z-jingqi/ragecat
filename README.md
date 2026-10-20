# Rage Cat

Godot 4.6.3 Standard 桌面 2D 生存游戏原型。控制自动射箭的猫，在 Endless 模式击败敌人、拾取经验并组合升级；Practice Lab 可配置构筑与敌人。使用 Compatibility 渲染器，无需 .NET、第三方素材或网络服务。

## 运行与操作

用 Godot 导入 `project.godot` 后按 F5，或在工程目录运行：

```sh
godot --path .
```

- WASD：移动；Space：冲刺；Esc：暂停。
- 瞄准与射击自动完成。F12 截图保存到 Godot 用户数据目录。
- 20 项被动升级均最高 Lv3；弓专属为连珠、扇射、长弓。升级卡显示当前与下级数值。
- 远程敌人会保持距离、近身后退，并在预警后发射锁定方向的弹体。Practice Lab 的 Ranged 按钮可生成它们。
- 当前只有一个角色与一把弓，无音效、存档、局外成长、联网或手柄支持。UI 为英文，数值仍可调整。

## 配置指南

Open `scenes/main.tscn` and inspect its Character Definition, Arena Definition and Ranged Definition resources. The defaults are:

- `resources/cat.tres`: base character, movement, dash, collision, feedback, combat and bow references.
- `resources/bow.tres`: base arrow damage/rate/speed/range/width, spawn offset and separate primary/fragment budgets.
- `resources/upgrades/*.tres`: all 20 upgrade definitions, each capped at level 3. Primary and secondary level arrays configure durations, pierce retention, target counts, burst spacing, fragment angles and shield crit. Descriptions and numeric previews resolve these same values.
- `resources/settings/arena.tres`: bounds, spawn and boss cadence, health scaling, difficulty cap, XP curve/rewards, contact damage, object budgets, ranged population, healing choices, and practice arrangements/builds.
- `resources/settings/ranged.tres`: every ranged movement/health/shot knob and its distinguishing colors.
- `scenes/enemies/chaser.tscn`: inherited exported enemy movement/radius/appearance/feedback. Spawn HP is intentionally owned by Arena Definition.
- `scenes/bosses/arena_boss.tscn`: boss timing, charge, rock placement/damage/aftermath and pattern parameters. Arena Definition owns the three default lab/arena overrides (warning duration, charge width, rock radius), so practice sliders and newly spawned bosses agree.

Definitions are inputs, while HP, shields, timers, ranks and projectile travel belong to each run/actor. Runs snapshot validated settings rather than mutating loaded resource assets. Numeric array access is rank-clamped, and invalid timing/distance inputs are sanitized. Three upgrade cards remain the supported layout maximum. Safety bounds and mathematical tolerances remain named code constants; decorative drawing coordinates and UI layout values are not balance parameters.

## 工程结构

- `scenes/`：主场景、角色、武器、敌人、Boss 与箭。
- `resources/`：角色、弓、升级及世界/远程敌人配置。
- `scripts/`：战斗模型、角色/敌人行为、场景编排与 UI。
- `tests/`：可复用的回归、组合、配置与长局测试脚本。

## 测试

在工程目录执行整套回归（Godot 不在 PATH 时设置 `GODOT=/path/to/godot`）：

```sh
bash tests/run_all.sh
```

单独运行配置测试或正常策略长局：

```sh
godot --headless --editor --import --quit
godot --headless --script tests/ranged_config_tests.gd
godot --headless --fixed-fps 60 --script tests/ranged_normal_runs.gd
```

长局输出默认保存在 Godot 用户数据目录。需指定输出位置时使用 `-- --output=/absolute/path/results.json`，不要提交生成结果。受限环境可将 `XDG_DATA_HOME`、`XDG_CACHE_HOME`、`XDG_CONFIG_HOME` 设为可写目录。

固定游戏随机种子：

```sh
godot --path . -- --endless --seed=7319
```

## 导出

安装匹配的 Godot 4.6.3 官方 export templates，在 Project → Export 中选择 Linux、Windows 或 macOS。预设位于 `export_presets.cfg`，输出放在 `build/`。macOS 发行需要按平台要求处理签名与公证，不要绕过系统安全提示。

仓库保留项目源码、配置、可复用测试代码与使用说明；生成的报告、运行结果、日志、截图、校验清单、编辑器缓存和导出文件不纳入版本控制。
