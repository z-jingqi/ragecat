# 一圈土锥 · 硬质开裂试验

只验证一圈土锥的快速破土和硬质崩坏，等待视觉反馈后才考虑其他元素或多圈。
独立 Godot 4.6.3 工程，不修改已发布的四元素预览、范围几何或层间速度。

## 运行

```sh
godot --path preview/earth-break-study-godot
```

默认同圈9根石锥，生成时间仅相差不到8ms，不存在内外层。
破土45ms，完整保持320ms，末段裂纹加深，然后320ms内分成7块、抛开坠落、轻微反弹。
主体以完整尺寸从地面下平移揭露，不用慢慢拉长；裂块全程只平移和旋转。
每块的所有顶点间距保持不变。落地后仍是原块，绝不压扁成软泥。
少量小土屑伴随破土。落地碎石默认2.4秒后淡出，可关闭。
中性30px角色只用于1×/2×尺度和前后遮挡，不是新增角色素材。

可调项：数量4–16、半径36–100、尺寸0.6–1.5、破土25–150ms、保持60–800ms、
崩落180–600ms、土屑0–2、外抛0–2、碎石停留0–5秒。参数只影响本试验。
Replay、New seed、Pause、Clear、亮暗地面、Reset、时间轴和0.35×慢放可直接检查。

## 算法与参考

- stone.gd 把完整截面分成7个不重叠多边形，碎块拥有固定局部形状。
- fragment_points 只改变旋转角和重心，抛物线落地后固定姿态。最后淡出只改透明度。
- emergence通过地平面裁切，碎块阶段没有顶点缩放、形变、插值成另一种形状或压扁。
- 整个绘制只依赖种子、时间和参数；支持任意跳帧、反向查看和完全重播。
- 方法参考已通过免费 Sprite Fusion MCP 读取的 Ice Spikes/Shatter，以及 PixelFX
  [earth-spike](https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/nature/earth-spike.js)和
  [ice-shatter](https://github.com/patch-gg/pixelfx/blob/a84159688af3ca37a4be05a0d422b94451b2e24e/src/fx/ice/ice-shatter.js)：
  破土伴飞屑，先开裂再分块，独立抛物线与落地。新 Godot 实现没有复制素材。
- 现有 MIT 来源许可复制保留在licenses/，没有新增收费生成或积分消费。

## 验证与录制

```sh
godot --headless --editor --path preview/earth-break-study-godot --import --quit
godot --headless --path preview/earth-break-study-godot --script tests/test_study.gd
EARTH_CAPTURE_DIR=/absolute/output godot --path preview/earth-break-study-godot --script tests/render_study.gd
godot --path preview/earth-break-study-godot --audio-driver Dummy --fixed-fps 60 --write-movie /absolute/output/earth-study.avi -- --capture
```

原生检查保存独立石锥与整圈的连续关键阶段。视频12秒/60fps，前4秒正常速度，后8秒亮底0.35×慢放。
MovieWriter 是实际 Godot 固定步进渲染，不代表真机实时帧率。没有玩法、伤害、碰撞或其他元素调整。
所有日志与二进制录像保存在仓库外。代码/像素检查不替代用户视觉确认。
