# 单根土锥：连续岩面与轻晃碎裂

本次只做一根土锥，不扩成整圈，不修改四元素或多层切换。
独立 Godot 4.6.3 Compatibility 工程，原创实时几何，不依赖动画贴图。

```sh
godot --path preview/single-earth-spike-godot
```

## 观看重点

- 完整不对称岩刺在55毫秒内从地下平移顶出，保持尺寸，不拉长。
- 连续左亮面、主面和右暗面不依赖碎块边界；轮廓只有少量不等距缺口。
- 完整保持460毫秒，最后130毫秒才让不规则裂纹从内部向边缘延展。
- 断裂前后有短促主体轻晃，默认幅度1.05逻辑像素，断裂前90毫秒加初段约32毫秒，不震屏。
- 七块大小不同的硬石沿原裂缝分离，最多约55毫秒错时，550毫秒内旋转坠落，首次接地分散在约248毫秒窗口内。
- 每块沿用原岩面的明暗，带固定2.5像素厚度断面，厚度一起旋转。前后顶点距离不变，不缩小、不压扁。
- 底部四块异形土块被顶开、刚性旋转后落回；五向不规则地裂在出土期间展开，随残渣一起淡出。
- 出土、断裂与各块实际接地点各有少量土屑。碎块有极小的刚性回弹，聚成局部不规则小堆。
- 原碎块落地成为立体残渣，默认保留2.2秒，末段只淡出透明度。

左侧为1×游戏尺度和中性角色比尺；右侧默认相同状态4×最近邻放大；大尺寸或高外抛时自动改为2×宽视图，避免裁切。
Replay、New seed、Pause、Clear、亮暗地面、Reset、时间轴和0.3×慢放可交互。
尺寸、出土/保持/裂纹/坠落时长、晃动幅度和时长、错时、土屑、外抛、残渣寿命、厚度和地面顶开强度可调。
颜色在 `profile.gd` 配置；参数经有限值和上下界检查。

## 参考及差异

已实际免费调用 Sprite Fusion MCP `get_vfx(ice)`，阅读 Spikes 和 Shatter 的配方及源码，
并读取下列固定版本的 PixelFX 源码：

- [Sprite Fusion Ice](https://www.spritefusion.com/pixel-art-vfx/ice)：连续脊面、裂纹路径渐进、独立碎块旋转与重力。
- [PixelFX earth-spike](https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/nature/earth-spike.js)：快起势、土屑、裂纹、落地细屑三阶段。
- [PixelFX ice-shatter](https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/ice/ice-shatter.js)：主体短促轻晃、非等大面片、独立坠落。

这是按用户反馈重做的原创土元素试验，不宣称精确复刻；不照搬白闪、冰雾、光效或缩放消退。
岩体分区、裂纹网络、纯刚性变换重新编写。MIT 许可保留在 `licenses/`。
未复制素材，未执行收费生成，积分消费为0。

## 验证与录制

```sh
godot --headless --editor --path preview/single-earth-spike-godot --import --quit
godot --headless --path preview/single-earth-spike-godot --script tests/test_single.gd
godot --headless --path preview/single-earth-spike-godot --script tests/test_contact.gd
EARTH_CAPTURE_DIR=/absolute/output godot --path preview/single-earth-spike-godot --script tests/render_single.gd
godot --path preview/single-earth-spike-godot --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/single-earth.avi -- --capture
```

原生渲染测试输出22个关键阶段供逐帧审查。视频16秒/60fps，前4秒正常速度，后12秒亮底0.3×慢放，
两段都能看到完整的生成、渐裂、轻晃、分离、落地与残渣消失。
MovieWriter 是实际 Godot 固定步进画面，不代表真机实时帧率。
测试与录像只证明工程行为；视觉批准仍以用户反馈为准。没有伤害、碰撞、击退或其他玩法。

2026-11-06 的接触增强验证状态见 `QA-contact.md`。上方原生录像和逐帧验证是既有基线流程；新增接触变化须重新执行原生渲染，不继承旧版的视觉通过结论。
