# 项目内 pstack 工作流

## 引入范围

本项目引入的是 **ScriptedAlchemy/pstack-codex 的文本工作流适配子集**，不是完整运行时插件，也不是 Godot `addons/` 插件。没有执行上游安装器，没有注册全局 marketplace，没有添加 hooks、MCP、模型供应商、后台服务或自动更新。此集成不改变游戏运行时。

项目入口：

- [pstack-plan](../.agents/skills/pstack-plan/SKILL.md)：实现规划，先区分已实现行为与玩法提案。
- [pstack-tdd](../.agents/skills/pstack-tdd/SKILL.md)：可复现问题的红灯/绿灯回归验证。
- [pstack-review](../.agents/skills/pstack-review/SKILL.md)：基于证据的只读审查。
- [pstack-acceptance](../.agents/skills/pstack-acceptance/SKILL.md)：本项目新增的七个验收岗位和逐效果证据门槛，详见 [25 类 / 41 场景验收流程](vfx-acceptance.md)。

可以直接要求“用 pstack-plan 讨论下一阶段实现”“用 pstack-tdd 修复这个问题”或“用 pstack-review 审查这些改动”。根目录 [AGENTS.md](../AGENTS.md) 提供本项目路由。新会话是否自动列出技能取决于宿主的项目技能发现能力；若未列出，可以按链接直接读取。不要声称完整插件已经激活。

## 固定来源与许可证

- 社区仓库：https://github.com/ScriptedAlchemy/pstack-codex
- 固定提交：`db9f38e9c75aaa19dd6be960134a7844b2c4d5c2`。
- 原始 pstack 作者：Lauren Tan。Codex 移植由 ScriptedAlchemy/pstack-codex 社区维护，非 Cursor/OpenAI 官方插件。
- [保留的 MIT 许可证](../.agents/skills/pstack-plan/LICENSE) 适用于这些派生工作流；不据此替整个游戏项目选择许可证。

2026-11-03 通过 GitHub 文件接口只读重新核对了以下固定版本源文件及许可证，blob SHA 与 Mountains & Seas 项目内适配的来源记录一致。表中的 SHA 是 Git blob SHA，不是本地派生文件的散列。

| 源文件 | Git blob SHA |
| --- | --- |
| [`plugins/pstack/skills/tdd/SKILL.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/tdd/SKILL.md) | `26f09b1f00d18dfea509fd85b5ea3dc2d7c14678` |
| [`plugins/pstack/skills/interrogate/SKILL.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/interrogate/SKILL.md) | `1a80061a045a0271826c7dce6e450f6ed2b56820` |
| [`plugins/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md) | `1347c23dd246b9ec04d15e9ac39c6ed0a5cd9310` |
| [`plugins/pstack/skills/interrogate/references/reviewer-prompt.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/interrogate/references/reviewer-prompt.md) | `ef7bff3d77c35a0af2a9947187ccee15465657f4` |
| [`plugins/pstack/skills/interrogate/references/rubric.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/interrogate/references/rubric.md) | `8dab195ab840554bfe5e74e9b5ca0d9edbe9b496` |
| [`plugins/pstack/skills/interrogate/references/code-quality-review.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/interrogate/references/code-quality-review.md) | `16581250d81044c7e80fe234c4970a3f7b7fc98a` |
| [`plugins/pstack/skills/interrogate/references/lead-judgment.md`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/plugins/pstack/skills/interrogate/references/lead-judgment.md) | `3b41346c9c3f5c35453d34f1c77374b7e9346aa9` |
| [`LICENSE`](https://github.com/ScriptedAlchemy/pstack-codex/blob/db9f38e9c75aaa19dd6be960134a7844b2c4d5c2/LICENSE) | `6b5400237fdf6545be0b8fae370d6f2fcff8fb25` |

## 本地修改与限制

前三个技能复用 Mountains & Seas 已有的项目内适配，并针对 Ragecat 路径和特效职责改写；它们是自包含的精简改写，不是原文件逐字复制。规划保留分阶段、可验证结果和依赖记录；TDD 保留先失败再修复的证据链；审查吸收 Interrogate 及四份参考文档的评判框架。所有需要的执行指导都已放入本项目技能及其链接的岗位文件，没有依赖未打包的上游文件。`pstack-acceptance` 和岗位说明为本项目新增流程，不冒充上游已有技能或多模型评审配置。

删除上游运行时契约中的全局模型配置依赖、固定模型/推理强度、自动编排和发布流程。没有打包任何可执行脚本、agent TOML、上游 manifest、Benny、bot UI、日志扫描器或安装/更新工具。没有导入完整 poteto-mode 的自主外部操作规则。仅在本项目范围应用技能，现有宿主权限和用户要求始终优先。

技能不授权发消息、推送/合并、发布、安装新工具或读取私有会话历史。委派默认继承模型，不冒充多模型评审。规划讨论不会自动开始实现。

## Godot 验证

按 [README.md](../README.md) 与受影响效果说明使用 Godot 4.6.3 Standard / Compatibility 及已有测试入口。旧预览工程在 `preview/godot/`；本轮精确移植工程单独放在 `spritefusion_exact/godot/`，以其实际 README 和文件为准，尚未存在的入口必须报告为未实现。Headless 导入和状态测试不能代替原生画面、参数交互、实际游戏接入、真机或导出验收。报告明确区分实际执行与未运行的检查。

## 更新与移除

不自动追踪上游。更新需重新选择固定提交、审查差异和权限影响，再显式修改这些文本并记录来源。不要运行上游 installer 来“补全”本子集。

移除时删除四个 `pstack-*` 技能目录（含验收岗位）、本说明、`docs/vfx-acceptance.md`，并清理根 AGENTS.md、README 和文档索引中的对应链接；保留其他项目约束及特效实现。没有全局插件、服务或依赖需要卸载。
