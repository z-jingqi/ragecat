# Ragecat · 特效素材工作区

先制作可移植的素材，Godot 仅负责预览，之后在 Unity 中组装使用。
这不是游戏项目；目前只有目录和空白预览，没有特效素材或旧工程代码。

## 目录

```text
effects/
  pixel/
    source/                 # 按特效名分目录，保存 Blender / Pixelorama 等源文件
    export/                 # 同名目录，保存可交付的 PNG 和 JSON 元数据
preview/
  godot/                    # 独立 Godot 工程，可替换，不是素材的源头
    assets/pixel/           # 导出素材的本地预览副本（不提交）
    project.godot
    preview.tscn
```

将来的其他风格放在 `effects/<style>/`，与 `pixel` 平级；需要时再创建。
每个特效使用简短的英文 `snake_case` 名称，源文件和导出目录保持同名。

## 像素素材约定

- 交付透明背景 RGBA PNG：连续帧 `frame_0000.png` 起编号，或规则网格精灵图集 `sheet.png`。
- 同一动画保持相同画布、对齐和锚点；默认不裁掉每帧的透明边缘。
- 同目录保存 `animation.json`，记录画布尺寸、帧顺序、每帧 `duration_ms`、`loop`、`pivot_px`、`blend`。
  `pivot_px` 以画布左上角为原点，x 向右、y 向下；`blend` 明确写 `alpha` 或 `additive`。
- 图集另外记录单帧尺寸、行列数、有效帧数、边距/间隔和扫描顺序；默认从左到右、从上到下。
- PNG 保持原始像素尺寸，不烘焙预览背景或放大倍数。源文件可用专用工具，交付文件不依赖 Godot。

这些是轻量约定；第一份素材确定后再给出具体 JSON 示例和回放配置，不预先搭建导入框架。
Unity 将使用 `effects/pixel/export/` 中的 PNG 与元数据，不使用 Godot 场景或缓存。

## 打开预览

使用 **Godot 4.6.3 标准版**，不需要 .NET、插件或导出模板。
在项目管理器中导入 `preview/godot/project.godot`，打开后按 **F6** 运行当前预览场景，或 **F5** 运行项目。
也可从仓库根目录执行：

```sh
godot --editor --path preview/godot
godot --path preview/godot
```

预览使用 Compatibility 渲染器、中性深灰背景、640×360 逻辑画布、默认 1280×720 窗口、Nearest 采样和整数倍缩放。
现在显示空状态；首个素材制作时才添加回放，不生成 Godot 程序化特效或游戏逻辑。

### 素材如何进入预览

`res://` 只对应 `preview/godot/`，不引用它之外的素材路径。
有素材后，把 `effects/pixel/export/<effect_name>/` **复制**为
`preview/godot/assets/pixel/<effect_name>/`，再在编辑器内配置该副本的动画回放。
也就是先复制，再让 Godot 导入；当前空白预览不会自动加载文件。
更新素材时重新复制对应目录，删除了源帧时也要移除副本中的旧帧；不要编辑副本或把它当交付源。
此流程不需要绝对路径、软链接或 Godot 专用素材导出器。

Godot 的 [资源路径说明](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html) 和
[项目设置](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html) 可作参考。

### 无窗口检查

```sh
godot --headless --editor --path preview/godot --import
godot --headless --path preview/godot --quit-after 10
```

运行产生的 `.godot/` 缓存和本地素材副本已加入忽略规则。
