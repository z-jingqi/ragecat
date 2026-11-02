# 山海经像素 Roguelike — VFX 特效制作任务书 V1.0

## 一、项目背景

| 项目 | 说明 |
|---|---|
| 游戏类型 | 2D 俯视角 Roguelike |
| 玩法参考 | Brotato（土豆兄弟） |
| 题材 | 中国上古神话《山海经》 |
| 美术风格 | 精致 16-bit 像素风 |
| 正式引擎 | Unity 2D URP |
| 特效制作工具 | Blender、Pixelorama |
| 特效预览工具 | Godot |
| 最终资源格式 | PNG、Sprite Sheet、BLEND |

Godot 仅用于预览和验证视觉效果，不作为正式游戏引擎。

## 二、统一制作规范

所有特效必须遵守以下规范：

### 视觉规范
1. 统一使用精致 16-bit 像素风。
2. 保持清晰的像素边缘，不允许模糊、柔化和明显抗锯齿。
3. 使用透明背景。
4. 颜色风格统一，避免不同素材包拼接产生的违和感。
5. 特效需要符合 2D 俯视角游戏的视角。
6. 特效要有明确的起始、爆发和结束过程。
7. 特效缩小到实际游戏尺寸时仍然清晰可辨。

### 推荐制作参数

| 参数 | 推荐值 |
|---|---|
| 普通特效帧尺寸 | 64×64 |
| 中型特效帧尺寸 | 128×128 |
| 大型特效帧尺寸 | 256×256 |
| 动画帧率 | 8～12 FPS |
| 普通特效帧数 | 6～12 帧 |
| 大型特效帧数 | 12～24 帧 |
| 图片格式 | PNG RGBA |
| Sprite Sheet | PNG |
| Blender 工程 | BLEND |
| 像素过滤 | Nearest / Point |
| 图片压缩 | 关闭 |

以上尺寸是制作参考，实际根据特效大小调整。

## 三、特效制作清单

### A. 主角战斗特效

| ID | 特效 | 用途 | 制作工具 | 参考方向 |
|---|---|---|---|---|
| VFX-01 | 武器挥砍 | 刀、剑、斧、戈近战攻击 | Pixelorama | 像素刀光 |
| VFX-02 | 武器拖尾 | 武器攻击时的残影 | Blender + Pixelorama | 能量拖尾 |
| VFX-03 | 远程弹道 | 飞刀、箭矢、法球 | Pixelorama | 像素弹道 |
| VFX-04 | 攻击命中 | 命中怪物时的火花和冲击 | Pixelorama | Hit Impact |
| VFX-05 | 主角受击 | 受击闪白、短暂反馈 | Unity Shader | Brotato 受击反馈 |
| VFX-06 | 闪避残影 | 冲刺、闪避时的残影 | Pixelorama + Unity | Afterimage |

### B. 五行元素与技能特效

这是项目的重点，需要优先保证视觉质量。

| ID | 特效 | 用途 | 制作工具 | 参考方向 |
|---|---|---|---|---|
| VFX-07 | 火焰 | 火球、火焰爆炸、持续燃烧 | Blender + Unity Particle | Fire VFX |
| VFX-08 | 雷电 | 雷击、闪电链、电弧 | Blender + Pixelorama | Lightning VFX |
| VFX-09 | 冰霜 | 冰锥、冰冻、冰霜爆裂 | Blender + Pixelorama | Ice VFX |
| VFX-10 | 毒雾 | 毒液喷溅、毒雾区域 | Unity Particle + Shader | Poison VFX |
| VFX-11 | 旋风 | 龙卷风、旋转攻击、吸附 | Blender + Unity Particle | Tornado VFX |
| VFX-12 | 震地 | 地裂、岩石爆发、地面冲击 | Blender | Earth Impact |

五行技能要具有各自独特的颜色、形状和运动方式，不能只是更换颜色。

### C. 怪物与 Boss 特效

| ID | 特效 | 用途 | 制作工具 | 参考方向 |
|---|---|---|---|---|
| VFX-13 | 怪物出生 | 怪物出现、传送、召唤 | Blender + Pixelorama | Spawn VFX |
| VFX-14 | 怪物受击 | 怪物受到攻击时的反馈 | Pixelorama | Hit Effect |
| VFX-15 | 怪物死亡 | 爆炸、消散、化成灰烬 | Blender + Unity Shader | Dissolve VFX |
| VFX-16 | 精英怪强化 | 精英怪登场、强化、狂暴 | Blender + Unity Particle | Aura VFX |
| VFX-17 | Boss 警告 | Boss 蓄力、范围攻击预警 | Blender + Pixelorama | Boss Telegraph |

### D. 状态与战斗反馈特效

| ID | 特效 | 用途 | 制作工具 | 参考方向 |
|---|---|---|---|---|
| VFX-18 | 异常状态 | 燃烧、中毒、冰冻、感电 | Unity Particle + Shader | Status Effect |
| VFX-19 | 暴击 | 暴击时的特殊闪光、冲击波 | Pixelorama + Blender | Critical Hit |
| VFX-20 | 护盾与治疗 | 护盾生成、回血、恢复 | Blender + Unity Particle | Shield / Heal |

### E. 游戏系统特效

| ID | 特效 | 用途 | 制作工具 | 参考方向 |
|---|---|---|---|---|
| VFX-21 | 经验拾取 | 经验球掉落、吸附、进入角色 | Pixelorama + Unity | XP Orb |
| VFX-22 | 升级觉醒 | 升级、技能觉醒、能量爆发 | Blender + Pixelorama | Level Up |

## 四、参考素材与工具资源

优先参考以下资源，不要求直接照搬，允许二次设计和像素化处理。

### 1. CrunchyVFX
https://crunchyvfx.com/

用途：
- 刀光
- 火球
- 爆炸
- 闪电
- 冲击波
- 护盾和治疗

用于快速生成像素特效参考。

注意：工具本身不是开源软件。

### 2. OpenGameArt - 2D Spell Effects
https://opengameart.org/content/2d-spell-effects

用途：
- 火焰
- 雷电
- 魔法爆炸
- 法术动画

作为技能特效参考素材。

### 3. Kenney Particle Pack
https://kenney.nl/assets/particle-pack

用途：
- 火星
- 烟雾
- 爆炸
- 光效
- 粒子

需要根据项目风格进行像素化处理。

### 4. GitHub - 2d-assets
https://github.com/Tiddybub/2d-assets/tree/main/effects

用途：
- 搜索现成 2D 特效
- 寻找可复用的 Sprite Sheet
- 参考不同类型的特效动画

注意：使用素材前逐个核对原始素材包的许可证，保留来源和授权记录，不要默认所有收录素材均为 CC0。

## 五、制作工具分工

| 工具 | 主要职责 |
|---|---|
| Blender | 复杂爆炸、法术、剑气、法阵、Boss 特效预渲染 |
| Pixelorama | 像素动画、刀光、火花、弹道、简单爆炸 |
| Unity Particle System | 持续火焰、烟雾、毒雾、碎片、火星 |
| Unity Shader Graph | 闪白、溶解、发光、冰冻、扭曲 |
| Unity Tween | 镜头震动、缩放、冲击反馈 |
| Godot | Sprite Sheet 预览、动画播放、特效组合测试 |

重要原则：

Blender 和 Pixelorama 负责生产可复用的视觉素材；Unity 负责正式游戏中的实时特效逻辑。

不要为了 Godot 预览而开发一套复杂的 Godot 特效系统。

## 六、每个特效的交付要求

每个特效必须独立建立文件夹。

目录结构：

VFX/
- VFX-01_Slash/
  - Source/
    - source.blend（如果使用 Blender）
    - source.aseprite 或 Pixelorama 原始工程（如果适用）
  - Export/
    - spritesheet.png
    - frame_000.png
    - frame_001.png
  - Preview/
    - preview.gif
  - README.md

每个特效必须提供：

1. 原始工程文件（适用时）。
2. 透明背景 PNG 序列。
3. Sprite Sheet。
4. GIF 预览。
5. 动画帧数。
6. 推荐播放帧率。
7. 特效尺寸。
8. 动画播放方式（循环或单次）。
9. Unity 导入建议。
10. 特效说明。

所有文件命名必须统一，禁止使用 final、final2、new 等不明确名称。

## 七、Godot 特效预览器要求

建立一个独立的 Godot VFX Previewer。

功能：

1. 加载 PNG 图片序列。
2. 加载 Sprite Sheet。
3. 自定义行列和切片尺寸。
4. 调整 FPS。
5. 调整缩放比例。
6. 播放、暂停、单帧播放。
7. 循环播放和单次播放。
8. 支持透明背景、黑色背景、白色背景。
9. 支持多个特效同时播放。
10. 支持调整特效位置和旋转。
11. 支持导出 GIF 或录制预览。

注意：预览器只负责检查视觉效果，不需要模拟 Unity 的完整粒子系统和 Shader。

## 八、第一阶段制作顺序

不要一次性制作全部 22 种。

第一批先完成以下 10 种：

| 顺序 | 特效 | 优先级 |
|---|---|---|
| 1 | 武器挥砍 | P0 |
| 2 | 武器拖尾 | P0 |
| 3 | 远程弹道 | P0 |
| 4 | 攻击命中 | P0 |
| 5 | 主角受击 | P0 |
| 6 | 火焰爆炸 | P0 |
| 7 | 雷电攻击 | P0 |
| 8 | 怪物出生 | P0 |
| 9 | 怪物死亡 | P0 |
| 10 | 经验拾取 | P0 |

完成后再制作剩余 12 种。

## 九、质量验收标准

每个特效必须通过以下检查：

- [ ] 像素风格统一。
- [ ] 透明背景正常。
- [ ] 没有模糊边缘和明显抗锯齿。
- [ ] 动画播放流畅。
- [ ] 起始、爆发、结束阶段清晰。
- [ ] 缩小后仍然容易识别。
- [ ] 可以在 Godot 预览器中正常播放。
- [ ] PNG 序列和 Sprite Sheet 均可正常导入。
- [ ] 具有完整的原始工程和使用说明。
- [ ] 素材授权已核实并记录。

## 十、执行要求

请按照第一阶段的 10 种特效逐个制作。

每完成一个特效：

1. 输出完整资源文件。
2. 输出预览 GIF。
3. 展示最终视觉效果。
4. 说明制作工具和参数。
5. 检查资源是否符合 Unity 导入要求。
6. 等待确认后再进入下一个特效。

不要一次性批量生成大量未经检查的特效。

最终目标是建立一套统一、可复用、可持续扩展的山海经像素游戏 VFX 资源库。