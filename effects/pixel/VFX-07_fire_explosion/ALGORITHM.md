# 火焰爆炸算法与来源

## 时间与形状

令 total = clamp(age / duration, 0, 1)，火团相位 t = clamp(total / 0.76, 0, 1)。所有形状直接从 t 计算，不积分位置、不逐帧抽随机数，因此相同时间输入不依赖模拟帧率。

- 膨胀：b = 1 − (1 − clamp(t / 0.24, 0, 1))³。
- 收缩：s = 1 − smoothstep(0.30, 0.89, t)。
- 每个火瓣有固定种子角度和半径；中心随 b 径向分离，同时按 rise × t² 上升；纵向拉伸逐渐形成火舌。
- 初期独立中心遮罩连接火团；t > 0.36 后四个不同偏心孔逐渐扩大，产生真实裂口；火团最晚 t = 0.89 清空。
- 颜色由归一椭圆距离分成四档，同时随热度移除热芯和亮黄色，不靠全体 alpha 渐变。
- 余烬有分散的发射/结束时刻，最多16条。径向路径使用二次 ease-out，叠加向上漂移；短线长度缩减，最后清空。没有运行时追加粒子。亮头与尾部独立分色，尾部横截面向后收窄；轨迹带轻微重力偏移，不再统一向上漂浮。
- 每个逻辑像素中心只采样一次，硬边 alpha。几何颜色不经线性过滤；主效果不依赖贴图。

- 烟团从 total = 0.22 开始，5个偏心团块扩大并上升，先褐色余热、后灰色。6个固定空间的孔洞随寿命扩大，外缘同步侵蚀，从连贯团块收成少量碎块，最终清空。不是整片透明度淡出，不将原烟团机械等比例缩小。smoke = 0 可关闭此层。

## 有界性与复现范围

每实例固定一个绘制矩形、一个 ShaderMaterial。Shader 固定上限10火瓣+4火团孔洞+5烟团+6烟团孔洞+16火星；画布半径由参数上界保守计算，最大173逻辑像素。无无限发射列表。

随机函数为 seed 与元素序号的 sin hash，只用于稳定差异。同一 GPU/Shader 输入重播应一致；不同 GPU 和未来引擎的浮点 sin 精度可能不同，不承诺跨引擎逐像素一致。需要逐平台完全一致时可替换为整数 hash。

## 成熟参考与许可

制作前参考了 [Sprite Fusion explosion 配方](https://www.spritefusion.com/pixel-art-vfx/explosion)，通过其免费 get_vfx MCP 阅读完整时间、层次和源码：采用“短热芯、分离火瓣、上升、冷却、余烬”通用视觉思路。没有复制其 TypeScript 实现，也没有打包该站素材。其原配方包含长烟尘、石块、地表波和焦痕，本项按需求明确不采用，首版改为0.48秒的轻量独立解析遮罩。本文与运行代码为本项目新写。

Godot API 参考：[CanvasItem Shader](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html)。参数和生命周期沿用本项目已存在原型风格，不引入外部依赖。

## 第二版参考研究

按用户指定，下载并查看 [ParticleFX Studio Midair Fireball Explosion](https://particlefx.studio/effects/midair-fireball-explosion) 的 [8时刻参考条](https://particlefx.studio/strips/explosions/midairExplosion.webp) 与 [海报](https://particlefx.studio/posters/explosions/midairExplosion.webp)。图像显示：早期周边是细短、密度和明暗不一的高速火星；热芯冷却后主体变为褐灰烟团，上升扩散并逐渐缺损。本文只记录视觉观察，没有复制其专有运行代码，也不将下载图像提交到生产项目。

本项目将其1.4秒HD表现压缩为默认0.60秒有限色阶像素版本，选择细火星＋短烟团冷却，不照搬56火星、光晕或柔和alpha烟雾。火星、烟团、空洞都由独立解析公式生成。
