# Ragecat · 代码优先特效工作区

为 2D 俯视角《山海经》Roguelike 制作精致 16-bit 像素特效。**实时代码、几何、粒子、轨迹与 Shader 为主，不用预制精灵图集或逐帧 PNG 制作特效动画。所有效果都要干净利落。** **当前只做特效设计、可调参数、独立算法说明和 Godot 实际原型；Unity 2D URP 留待效果确认、用户明确要求接入后再移植，当前不写 Unity 代码。**

这里是特效制作与预览工作区，不是完整游戏项目，不恢复旧特效。当前按授权并行推进挥砍、拖尾、弹道、命中；每项的实现和验证状态以其 README、实际文件与提交记录为准，不把任务书当作效果已完成的证明。

## 项目内工作流与验收

已引入 [pstack 文本工作流](docs/pstack.md)，包括规划、回归与审查，以及 [25 类 / 41 场景精确移植的七个验收岗位](docs/vfx-acceptance.md)。这些是项目内流程，不是游戏角色或运行时插件，不启用全局 hooks 或自动更新。流程的存在不代表效果已通过验收。

## 制作依据

- [代码优先 VFX 任务书 V2.0](docs/pixel/shanhaijing-pixel-roguelike-vfx-brief-v2.0.md)：当前规范，含 22 类实现选择、素材依赖、第一阶段顺序、代码/素材参考、交付与验收要求。
- [文档索引](docs/README.md)：保留 V1.0 原文；旧版 PNG/图集优先要求已被 V2.0 取代，不与新版并行执行。

多数视觉可独立程序生成；指定造型可选单张静态纹理/网格。贴体闪色、残影、溶解需要游戏提供宿主外观，不需要另做特效动画帧。需要外部资源时先查许可明确的开放项目，区分代码和美术授权。

## 目录与交付方向

```text
docs/pixel/                 # 当前任务书与不改写的历史原文
effects/pixel/              # 后续按 VFX-XX_name 组织代码、参数、可选素材与说明
  source/                   # 旧管线空占位，暂留；不再是强制结构
  export/                   # 旧管线空占位，暂留；不要求输出 PNG 动画
preview/godot/              # 独立、可替换的预览工程
  assets/pixel/             # 本地预览素材副本（不提交）
  project.godot
  preview.tscn
```

新增单项结构以 V2.0 为准，当前不迁移目录、不提前搭建框架。其他风格需要时放在 `effects/<style>/`，与 `pixel` 平级。

当前交付是 Godot 原型源码、参数预设、独立算法/配置说明、使用方法和真实运行录制；静态素材及源文件仅在实际使用时交付。不要求 Unity C#/Shader、Prefab 或 Unity 测试，也不默认建立 `src/unity/`。Godot 的 `.gd`、`.gdshader` 和场景不能直接导入 Unity；未来明确获准接入后仍需独立适配和验证，不能承诺自动移植。

## 打开 Godot 预览工程

使用 **Godot 4.6.3 标准版**，不需要 .NET、插件或导出模板。导入 `preview/godot/project.godot`，按 **F6** 运行当前场景，或 **F5** 运行项目。也可从仓库根目录执行：

```sh
godot --editor --path preview/godot
godot --path preview/godot
```

预览基线使用 Compatibility 渲染器、中性深灰背景、640×360 逻辑画布、默认 1280×720 窗口、Nearest 采样和整数倍缩放。具体已接入效果与参数入口以当前场景和各项说明为准；不依赖图集动画。

获准制作后，可增加各项必要的程序化预览与参数控制，不建设完整双引擎特效平台。多个已批准效果可以并行、独立配置；单项完成自检后及时提交推送，再展示供用户验证，有问题继续修正。Godot 自检与用户视觉确认分别记录，提交保存不能代替验收；未来 Unity 接入不作为当前交付门槛。

`res://` 对应 `preview/godot/`。后续需要素材时，从该项交付源复制必要文件进预览工程并说明同步方式；不要编辑副本或当作正式交付源。无需绝对路径、软链接或专用图集导出器。

### 无窗口基础检查

```sh
godot --headless --editor --path preview/godot --import
godot --headless --path preview/godot --quit-after 10
```

这些命令仅检查导入/启动，不能替代实际视觉和参数行为验证；也不能证明未来 Unity 兼容性。运行产生的 `.godot/` 缓存和本地素材副本已加入忽略规则。

## 角色素材

角色图片与设计资料独立放在 [characters/](characters/README.md)，主角、普通敌人、Boss 分目录保留。角色制作当前暂停，本轮运动试验代码已清理；现有特效及其预览不受影响。

## Sprite Fusion 原版完整复刻

独立目录 [spritefusion_exact](spritefusion_exact/README.md) 保存全部25项、41种情况的官方原始代码与许可，并逐项实现可运行的Godot版本。这里的原版保真工作与既有22类效果、游戏适配预设分开，不用近似效果替代；每项以实际运行、逐帧/参数对照与新预览验收。

## 后羿「射日」独立视觉预览

[打开熔岩组件与参数说明](preview/houyi-lava-godot/README.md)。导入 `preview/houyi-lava-godot/project.godot`，或运行 `godot --path preview/houyi-lava-godot`。熔岩、气泡、短焰、落地火星与低透明上升烟雾可独立启停、配置和组合；这是新的原创视觉试验，不属于上述25项原版复刻，也不接入山海玩法或更改平衡数值。

## 元素双尖矛独立预览

[组件、阶段与参数说明](preview/elemental-spear-godot/README.md)。导入
`preview/elemental-spear-godot/project.godot`。高处中点展开的双尖矛按凝聚、展开、
悬停、下落、撞击、持续区、消散七阶段独立配置，元素模块可替换组合。
仅为原创视觉，不定义伤害或其他玩法。
