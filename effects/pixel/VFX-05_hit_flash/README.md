# VFX-05 · 贴体受击闪色

短促、适度的全身闪色：瞬间进入峰值，短暂停留后快速回落。**不降低角色透明度、不改变轮廓、不增加外部光晕**。预览原创程序化小兵只是宿主测试样本，不是正式人物素材。当前只有 Godot 原型，不含 Unity 代码。

## 运行

```sh
godot --path preview/godot res://effects/VFX-05_hit_flash/flash.tscn
python3 effects/pixel/VFX-05_hit_flash/tests/run_checks.py
```

左侧 Original / Hit 对照，分别1×与3×Nearest，使用相同状态。Pause、单帧、Reset、Hit、Repeat hit、Loop、背景切换和宿主Alpha对照。四预设为柔和象牙白、暖色、冷色和重击。Alpha按钮用于验证已有透明角色的闪色不改变其透明度，不是受击闪烁的实现。

## 参数

| 参数 | 默认 | 范围 / 单位 |
|---|---:|---|
| peak | 0.46 | 0–0.8，颜色混合强度，非透明度 |
| duration | 0.11 | 0.02–0.5秒，总寿命 |
| hold | 0.018 | 0–0.08秒，且不超过总寿命一半 |
| color | #e1ebef | RGB闪色；忽略该颜色的Alpha |

配置权威源是 `config/presets.json`，预览目录保存相同字节副本；测试检查一致性。数字夹到范围，NaN/Inf忽略。无随机行为，不提供seed。高强度可用于重击，默认强度避免整身过曝。

## 算法与宿主边界

从伤害事件调用 `trigger()`，在独立状态中按dt推进；重复命中从峰值重新计时，不累加强度。`reset()` 清空状态并取消暂停。短暂hold之后强度为 `peak * (1-t)^2`，到时严格归零。暂停冻结（包括演示的第二次命中计时），单帧推进1/60秒。Reset取消尚未触发的第二次命中，避免重置后旧事件再次闪色。

每个独立角色使用独立 ShaderMaterial，避免一个角色被击中让其他角色一起变色。Shader对宿主当前RGBA处理：RGB向flash_color混合，输出Alpha仍等于原宿主Alpha。Godot 4 fragment中的COLOR已包含纹理与modulate，所以不要再乘一次纹理。材质不保存宿主帧或复制角色图片，宿主动画、换帧、位置及透明度由游戏继续管理。

宿主必须提供自身纹理/绘制几何。当前演示用透明ImageTexture，真实AnimatedSprite2D或Sprite2D可以绑定该材质；自定义着色器、骨骼多部件、灯光效果需要在宿主已有着色逻辑内合并，不能盲目覆盖材质。当前unshaded预览不验证未来Unity或游戏光照接入。

## 验证

- `test_flash.gd`：2025项状态/边界/1000次重用及场景控件断言，30/60/144Hz结束一致。
- `test_render.gd`：需正常渲染器运行；透明SubViewport内逐像素核对零强度等于原图、所有透明度保持、56个可见像素均闪色，2049项断言。包含0–1纹理Alpha和0.5宿主modulate。
- 原生预览检查Pause→Hit→单步→Alpha→Reset及正常速度；录像是真实Godot画面60Hz固定步长输出，未用预绘制特效帧驱动效果。

录制：`-- --flash-auto --flash-capture=/absolute/output/frames`，10秒四预设和半透明宿主，导出帧仅为录屏/QA产物，不是生产特效图集。

## 参考与许可

依据 [Godot CanvasItem Shader 文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) 的COLOR/Alpha语义。实现和程序化测试角色为本项目原创；未复制第三方美术、声音或动画，没有外部素材依赖。
