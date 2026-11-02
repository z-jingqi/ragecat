# 参考与授权

制作前查看：
- https://www.spritefusion.com/pixel-art-vfx/lightning ：参考单次折线雷击、分叉服从主干的视觉分类；该页面标注其源码 MIT。本项没有复制或引入其 TypeScript、图像或视频。
- https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html ：使用官方自绘、queue_redraw 与像素中心线宽对齐机制。

本项运行时无需第三方资产或新增依赖；不分发参考网站内容。

用户指定的新参考：https://particlefx.studio/effects/pixel-art-lightning-strike 。已下载并查看其主图 https://particlefx.studio/posters/pixel-art-vfx/pixelLightningStrike.webp 与八时刻条带 https://particlefx.studio/strips/pixel-art-vfx/pixelLightningStrike.webp ，分析粗细层次、长分叉、落点及余波时序。参考图片仅存于仓库外研究目录，不作为生产贴图、动画帧或分发资产；本项没有复制网站代码或使用其付费引擎数据。

时序修订依据公开主图、八时刻条带与网页的多层错开说明，不声称完整逐帧复刻。当前70ms生长与分段回收为独立设计，并由自己的逐帧渲染验证。
