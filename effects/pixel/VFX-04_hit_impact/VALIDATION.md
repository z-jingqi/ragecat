# VFX-04 验证记录

日期：2026-11-02。范围：独立定向接触命中，Godot 视觉原型；不是贴体受击、暴击或物理反弹。

| 项目 | 状态 | 证据 |
|---|---|---|
| Godot 4.6.3 脚本/遮罩加载 | 通过 | isolated `lab.tscn` headless 启动，无解析/Shader 编译错误 |
| 生命周期/参数 | 通过 | `test_impact.gd` 81 项；四预设×30/60/120 Hz；1000 次复用 |
| 共享数学遮罩 | 通过 | `tests/test_kernel.py` 104138 项；直接编译实际函数，不是重写的近似算法 |
| 生成适配同步 | 通过 | `build_adapters.py --check` |
| 原生 Godot 视觉/交互 | 通过 | 正常时间播放、重播、清空、暂停定步进、预设/方向切换；实际尺寸及 4× 像素轮廓可读 |
| 引擎渲染动态预览 | 通过 | 640×360，60 Hz 固定步进，720 张实际 viewport 输出编码为 12.000 秒 H.264；解码检查无错误 |
| Unity | 未验收/当前不制作 | 当前阶段先确认效果与 Godot 参数原型，之后按需要移植 |
| 正式设备性能/大量并发 | 未验证 | 仅有固定实例/碎片上限，不把代码生成等同于性能合格 |

## 已覆盖

- 单次起始/结束；结束时确切 age = duration，绘制隐藏，无末帧残留。
- 30/60/120 Hz 总寿命误差不超过一个该帧率渲染间隔，遮罩按绝对秒求值，不以帧数推进形状。
- 暂停/恢复、0×、0.25×、重播、clear 后重播、固定时间 seek。
- 方向 +X/+Y 与任意角度；零方向/非有限方向回落；非法接触点清除。
- 参数上限/下限、NaN/Infinity、非法颜色、外部配置快照、seed 归一。
- 1000 次重播清除仍保持一个显示矩形，不累积粒子节点。
- 共享函数检查：只有 0/1/2/3 色阶，瞬时起始、短尾、固定 seed 重现、不同 seed 有效、方向确实旋转。
- 极端尺寸/速度/寿命/碎片数下，保守边界外围没有遮罩像素。

## 复现命令

```bash
python effects/pixel/VFX-04_hit_impact/build_adapters.py --check
python effects/pixel/VFX-04_hit_impact/tests/test_kernel.py
godot4 --headless --path preview/godot --script res://effects/VFX-04_hit_impact/test_impact.gd
godot4 --path preview/godot res://effects/VFX-04_hit_impact/lab.tscn
```

## 实际预览

`vfx04-hit-impact-godot-preview.mp4`：四个命名预设，原速，依次深灰/黑/白/棋盘背景；左右同步 1×逻辑尺寸与 4×检查。已经交付独立视频文件，仓库只保存源码与复现入口。

原生正常播放与控件检查独立执行；视频采用 **Godot 实际 viewport 在 `frame_post_draw` 后输出**、固定 60 Hz 求值再编码。不是桌面实时屏幕录制，也不是 CPU 重画的假运行视频；不能由此推断真实设备性能或帧率。

```bash
godot4 --path preview/godot res://effects/VFX-04_hit_impact/lab.tscn --fixed-fps 60 -- \
  --impact-showcase --impact-capture-dir=/absolute/path/frames --impact-capture-frames=720
ffmpeg -framerate 60 -i /absolute/path/frames/frame_%05d.png -frames:v 720 \
  -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart vfx04-hit-impact-godot-preview.mp4
```

原始渲染帧抽查：默认主峰只有背景与三档色阶；20/60 秒样本已完全清空。白底重命中检查后，将可选肩部收紧为两处短标记，未保留大片环线。无 Shader/GDScript 运行错误。

极限组合的数学边界/生命周期已测；本次原生视觉逐一检查的是命名预设，不宣称每一种极限参数组合均已通过美术验收。
