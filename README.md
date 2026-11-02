# Ragecat · 代码优先特效工作区

为 2D 俯视角《山海经》Roguelike 制作精致 16-bit 像素特效。**实时代码、几何、粒子、轨迹与 Shader 为主，不用预制精灵图集或逐帧 PNG 制作特效动画。所有效果都要干净利落。** Unity 2D URP 是正式目标，Godot 仅用于视觉与参数原型验证。

当前仍是空白工作区，没有已实现的特效或 Unity 运行时代码。本次更新只修订文档，不恢复旧特效、不修改预览工程。

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

正式交付是 Unity C#/Shader 与必要配置、参数预设、使用说明和真实运行录制；静态素材及源文件仅在实际使用时交付。Godot 的 `.gd`、`.gdshader` 和场景不能直接导入 Unity；可共享算法、参数与测试规格，运行代码分别适配、分别验证。

## 打开现有空白预览

使用 **Godot 4.6.3 标准版**，不需要 .NET、插件或导出模板。导入 `preview/godot/project.godot`，按 **F6** 运行当前场景，或 **F5** 运行项目。也可从仓库根目录执行：

```sh
godot --editor --path preview/godot
godot --path preview/godot
```

现有工程使用 Compatibility 渲染器、中性深灰背景、640×360 逻辑画布、默认 1280×720 窗口、Nearest 采样和整数倍缩放。当前只显示空状态，不会自动加载代码或素材；旧空状态里的“exported animation”文字尚未随文档修订，不代表继续采用图集管线。

获准制作后，可增加各项必要的程序化预览与参数控制，不建设完整双引擎特效平台。多个已批准效果可以并行、独立配置；单项完成自检后及时提交推送，再展示供用户验证，有问题继续修正。Godot 视觉通过与 Unity 编译/运行通过分别记录，提交保存不能代替验收。

`res://` 对应 `preview/godot/`。后续需要素材时，从该项交付源复制必要文件进预览工程并说明同步方式；不要编辑副本或当作正式交付源。无需绝对路径、软链接或专用图集导出器。

### 无窗口基础检查

```sh
godot --headless --editor --path preview/godot --import
godot --headless --path preview/godot --quit-after 10
```

这些命令仅检查导入/启动，不能证明视觉、参数行为或 Unity 兼容性合格。运行产生的 `.godot/` 缓存和本地素材副本已加入忽略规则。
