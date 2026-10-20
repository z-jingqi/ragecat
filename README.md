# Rage Cat

独立的 Godot 4.6.3 桌面 2D 生存原型。扮演自动射箭的猫，在无限竞技场中组合升级；Practice 实验室用于直接验证战斗规则。工程不依赖其他游戏、第三方素材、服务器或网络服务。

## 开始运行

1. 安装 **Godot 4.6.3 Standard**，无需 .NET。
2. 导入本目录的 `project.godot`，按 F6/F5 运行主场景。
3. 主菜单选择 **ENDLESS** 或 **PRACTICE**。

命令行也可运行：

```sh
godot --path .
```

使用 Compatibility 渲染器，设计分辨率 1280×800，物理更新 60 Hz。

## 操作

| 操作 | 按键 |
| --- | --- |
| 移动 | W / A / S / D |
| 冲刺 | Space；持续 0.2 秒，冷却 2 秒，冲刺期间免伤 |
| 暂停 / 继续 | Esc |
| 截图 | F12；保存到 Godot 用户数据目录的 `screenshots/` |
| 瞄准 / 攻击 | 自动选择目标并射击，无需鼠标瞄准 |

菜单、升级卡和 Practice 控件通过界面操作。战斗移动目前为键盘操作，未实现手柄或触屏控制。

## 游戏循环

- 击败敌人，拾取经验，升级时暂停并从最多 3 个不同选项中选择。
- 除 Toxic Precision 仅 1 级外，永久升级最高 3 级；有前置要求的组合在前置升级取得后进入候选池，满级项不再出现。
- 当候选不足 3 项时只展示剩余选项；全部耗尽时允许继续。
- 生命不足时可出现恢复最大生命 35% 的一次性选项；护盾不足时可出现全部补满护盾的选项。提高护盾容量也会补满护盾。
- 首只 Boss 于 120 秒出现，击败后再等待 120 秒出现下一只。Boss 存活时普通敌人的刷新变慢。
- 普通运行最多 69 个普通敌人，并为 1 个 Boss 预留位置和 250 个经验拾取物，避免无限积累。
- 死亡后可以重新开始；当前没有存档、局外成长或跨局解锁。

## 升级与数值

以下列出 **第 1 / 2 / 3 级的累计效果**，不是逐级增量。0 级表示未取得。数值属于原型平衡参数，可从 `resources/upgrades/*.tres` 调整。

| ID / 名称 | 1 / 2 / 3 级 | 前置 |
| --- | --- | --- |
| `vitality` / Nine Lives | 最大生命 +20 / +40 / +60 | 无 |
| `damage` / Sharp Claws | 箭伤害 +20% / +40% / +60% | 无 |
| `attack_speed` / Quick Paws | 攻速 +15% / +30% / +45% | 无 |
| `crit_chance` / Killer Instinct | 暴击率 +8 / +16 / +24 个百分点 | 无 |
| `crit_damage` / Deadly Precision | 暴击倍率 +0.4 / +0.8 / +1.2 | 无 |
| `move_speed` / Zoomies | 移速 +12% / +24% / +36% | 无 |
| `pickup_radius` / Magnetic Whiskers | 拾取半径 +45 / +90 / +135 | 无 |
| `regen` / Purring Recovery | 每秒恢复 0.5 / 1 / 1.5 HP | 无 |
| `shield` / Bubble Guard | 护盾容量 1 / 2 / 3；每层当前护盾额外提供 10 个百分点暴击率 | 无 |
| `poison` / Venom Fangs | 毒伤每秒 3 / 6 / 9，持续 4 秒 | 无 |
| `bleed` / Rending Arrows | 流血每秒 4 / 8 / 12，持续 4 秒 | 无 |
| `poison_crit` / Toxic Precision | 仅 1 级：攻击前已中毒的目标必定暴击 | Poison ≥ 1 |
| `spread` / Contagion | 扩散半径 55 / 80 / 110，最多影响 3 个其他目标 | Poison ≥ 1 |
| `pierce` / Needle Shot | 单箭最多命中 2 / 3 / 4 个目标；首次穿透后，所有后续目标固定保留 75% / 85% / 95% 伤害（不连乘） | 无 |
| `burst` / Feline Frenzy | 每次攻击共发射 2 / 3 / 4 轮，额外轮间隔 0.12 秒 | 无 |
| `spread_arrow` / Fan of Fangs | 每轮总共 3 / 5 / 7 箭，含中央箭 | 无 |
| `bleed_regen` / Blood Purr | 命中攻击前已流血目标后，获得每秒 0.5 / 1 / 1.5 HP 的 3 秒恢复增益 | Bleed ≥ 1 |

基础角色：100 HP、移速 230、拾取半径 75；基础弓：15 伤害、每秒 1.8 次攻击、弹速 650、射程 520、宽度 7、击退 45。基础暴击率 5%，倍率 2 倍。

## 战斗结算约定

- 先读取目标**命中前**的毒 / 流血状态，结算直接伤害与组合，再施加本箭的状态。因此首次造成中毒的箭不能享受该次中毒带来的必暴。
- Toxic Precision 仅有 1 级，保证对已中毒目标暴击；取得后不再进入候选池。
- 护盾每次消耗一层，完全挡住整个伤害包，不向生命溢出。有效受击立即开启 0.5 秒无敌，同一帧后续伤害不能再消耗护盾。
- 暴击率最终限制为 0–100%；护盾暴击加成使用**当前**层数，不是容量。
- 毒与流血独立，每 0.5 秒结算一次；命中刷新持续时间，不重置下一次跳伤时钟，不叠加同类独立层数。
- 持续伤害不暴击，也不触发扩散或恢复组合。扩散不递归传播，每支箭最多触发一次。
- 散射相邻箭间隔 0.2 弧度，中央箭直接伤害 100%，侧箭 55%。各箭仍施加完整毒 / 流血。不同箭允许命中同一个目标，近距离“霰弹”效果是有意保留的。
- 单支箭不会重复命中同一目标，穿透只对后续目标衰减直接伤害。
- 普通回血由 HealthState 统一处理，流血组合的短时增益由玩家处理；刷新增益时长，不叠加多份恢复率。
- 重算升级派生数值不会自动治疗或复活，也不会隐式补满护盾；升级选择流程显式处理护盾补充。

## Practice 实验室

实验室与正式模式共享同一套战斗模型。可直接配置升级等级、使用组合预设、生成木桩 / 普通敌人 / Boss、调整模拟速度以及恢复生命和护盾。适合验证毒必暴、流血恢复、护盾暴击、穿透、连射和散射；界面显示运行指标。

## 工程结构

```text
project.godot                  独立工程配置
scenes/main.tscn               主场景
resources/cat.tres             角色基础数据
resources/bow.tres             武器基础数据
scripts/main.gd                菜单、HUD、暂停、升级和实验室接线
resources/upgrades/            17 份独立升级 Resource
scenes/characters/cat.tscn      可实例化角色场景
scenes/weapons/bow.tscn         玩家装备的独立武器节点
scenes/projectiles/arrow.tscn   独立箭场景
scenes/enemies/chaser.tscn      普通敌人场景
scenes/bosses/arena_boss.tscn    Boss 场景
scripts/combat/                属性、伤害、状态与生命模型
scripts/characters/            角色行为与角色定义
scripts/weapons/               武器行为节点与基础数据定义
scripts/projectiles/           弹体行为
scripts/enemies/                普通敌人行为
scripts/bosses/                 Boss 与落石预警
scripts/upgrades/               升级 Resource 类型与目录索引
scripts/systems/arena.gd       场景编排、生成与命中流程
scripts/systems/run_director.gd 无尽模式时序与 Boss 节奏
scripts/ui/                    Practice 面板与浮动文字
tests/model_tests.gd           无界面的确定性模型测试
```

`CharacterDefinition` 与 `BowDefinition` 为 Resource；新增角色可建立独立 `.tres`，无需在战斗规则中按角色名分支。`CombatStats` 重算派生属性；`UpgradeCatalog` 从 17 份独立升级 `.tres` 读取定义并生成数值预览；`CombatRules.resolve_direct()` 是不修改输入的纯函数；`StatusEffects` 管理持续伤害；`HealthState` 管理生命、护盾与受击无敌。`BowController` 是玩家装备的独立 Node / PackedScene，自己管理自动瞄准、攻击冷却、连射与箭场景实例化；通过信号把命中交给战斗结算，不把武器行为堆进玩家或竞技场。毒、流血等被动状态保留为轻量模型，而非每个目标都挂重复行为节点；本设计不引入基础闪避之外的主动技能。画面使用 Godot 原生绘制与 UI，不依赖下载美术资产。

## 自动化检查

从本工程目录执行：

```sh
godot --headless --editor --import --quit
godot --headless --script tests/model_tests.gd
godot --headless --script tests/bow_tests.gd
godot --headless --script tests/integration_tests.gd
godot --headless --script tests/boss_tests.gd
godot --headless --script tests/combo_tests.gd
godot --headless --script tests/stress_tests.gd
```

模型测试通过时输出 `MODEL TESTS: ... checks, 0 failures` 并以状态码 0 退出；失败以状态码 1 退出。覆盖前置过滤、满级过滤、资源加载、预命中判定、毒必暴、护盾暴击、散射数量、伤害倍率、DOT 刷新与到期、整次挡伤、同帧免伤、回血和禁止复活。

受限 Linux 环境需将 Godot 用户目录设置为可写路径，避免用户日志目录无法创建：

```sh
mkdir -p /tmp/rage-cat-{home,cache,data,config}
export HOME=/tmp/rage-cat-home
export XDG_CACHE_HOME=/tmp/rage-cat-cache
export XDG_DATA_HOME=/tmp/rage-cat-data
export XDG_CONFIG_HOME=/tmp/rage-cat-config
godot --headless --editor --import --quit
godot --headless --script tests/model_tests.gd
```

## 桌面导出

使用与引擎匹配的 **Godot 4.6.3 export templates**，在 Project → Export 中选择 Windows Desktop 或 Linux，导出独立可执行程序。可将 PCK 嵌入可执行文件；若选择分离 PCK，应将其与可执行文件放在同一目录分发。Linux 可执行文件需保留执行权限。

Windows / Linux 独立可执行文件已成功导出；源码也可直接通过 Godot 启动。不要将“能够导出”视为所有系统都已实机验证。macOS Universal ZIP 亦已成功导出，但未经签名、公证或 macOS 实机验证。系统可能阻止启动；这不是经签名发行版本，不应绕过安全提示。Linux 版已经实际启动测试，Windows / macOS 仅完成导出验证。

## 当前限制

- 尚未加入音效或音乐。
- 仅一个角色与一把基础弓，没有局外系统、存档或联网功能。
- 当前文本 UI 为英文，本文档为中文。
- 数值、难度曲线和组合强度为原型版本，未经过长期平衡测试。
- F12 截图写入 `user://screenshots`（Godot 应用用户数据目录），需要该目录可写；无界面测试不会验证图形截图。

### 可复现随机种子

正式游玩每次使用新的随机种子；测试可通过 `godot --path . -- --endless --seed=7319` 固定刷怪、暴击和 Boss 落石布局随机序列。

### 2026-10-20 差异化验收

修复UI/Reset崩溃风险、DOT/治疗统计、盾/HP反馈、死亡状态、练习选择控件、穿透一次减伤与射程边界、XP上限和回血末帧。冲刺维持0.2秒/从开始计2秒冷却，新增READY/剩余时间HUD；受击保护0.5游戏秒、基础箭击退45px均已专项验证。

按不同风险分组测试，而不是把断言数当作试玩轮数：三种不同升级倾向的正常自动局各240游戏秒，无无敌/赠级/改HP，全部自然经历首Boss并继续成长；另有桌面实际操作、穿透几何/步长、真实键盘连按、状态组合、晚落石清理、返菜单节点和奖励/回血边界。详情、证据与限制见 `QA_REPORT.md`。

运行定向回归：`bash tests/run_all.sh`。正常策略局：`godot --headless --fixed-fps 60 --script tests/normal_seeded_runs.gd`。这是自动策略，不是人类试玩或平衡保证。

最新修复只更新Linux导出；现存Windows/macOS导出是旧版本，不能用于本次验收。请用Godot4.6.3及对应官方模板从源码重新导出。源码包含测试脚本，不含缓存/二进制/原始日志。
