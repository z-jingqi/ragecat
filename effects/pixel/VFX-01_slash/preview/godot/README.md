# Godot 薄预览适配

实际入口位于仓库根 `preview/godot/preview.tscn`，控制面板为同目录 `preview.gd`，
自动生成的 `slash.gdshader` 内嵌唯一数学源。此目录只记录边界，不复制第二套算法。

Godot 4.6.3 标准版，Compatibility renderer，无外部插件或纹理依赖。
640×360逻辑画布、整数缩放、Nearest；默认180ms正常速度播放。
本适配只验证像素形状、节奏、参数和交互，不证明任何其他引擎兼容性。
