# VFX-07 验证

## 已检查

- Godot 状态、参数、面板：1069 项断言，包括四预设×30/60/144 Hz、暂停/恢复、0/0.25倍速、负值/NaN/Inf、字典快照、非法位置清空、重播、单帧、清除/恢复默认，以及1000次节点复用。
- 实际 GPU 遮罩：4组×21时刻，默认重复两次、最大组合、最小且无余烬组合。193项断言覆盖同 seed 逐像素一致、alpha仅0/255、无边界截断、结束为空；另29个默认帧验证1×和3×逐像素Nearest一致，共222项。
- 原生窗口实际操作：清除、单帧、暂停、恢复默认、尺寸、种子、背景切换。原速默认与预设主体可读。
- 最终预览由实际 Godot viewport 录出720帧，编码为640×360/60fps/12秒视频。不是预制图集驱动的播放，不将放大画面冒充实际尺寸。
- 默认遮罩面积依次膨胀到844像素，收束到0；极大组合峰值3814像素并干净清空。随机值不按帧重抽。
- 配置事实源与预览副本字节一致，git diff --check 通过。

## 可重复检查

```bash
godot --headless --path preview/godot --script res://effects/VFX-07_fire_explosion/test_fire.gd
# 需要图形渲染器；输出路径可省略，默认用户数据目录/fire_probe
FIRE_PROBE_DIR=/tmp/fire_probe godot --path preview/godot --script res://effects/VFX-07_fire_explosion/render_probe.gd
```

GPU 探针只输出诊断图片，不生成运行用纹理或生产动画帧。实际游戏并发数量、宿主相机与未来Unity接入不是本原型的已测范围。未设置自动CI流程时不把手工检查称为CI通过。
