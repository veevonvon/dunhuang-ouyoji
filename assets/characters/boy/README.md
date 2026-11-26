# 欧哟几的分层画稿

4.3 沿用六岁欧哟几朝右的三分之二侧面、黑发和红围巾。以本项目的 4.2 原创人物画为形象参照，用会话内置 ImageGen 绘制透明身体部件、手势和同机位表情，再裁切并对齐衣领、手腕、脚踝与颈部。画稿随游戏离线使用。[原角色画](../../images/boy.png)

| 画稿 | 用法 |
| --- | --- |
| `coat.png`、`pouch.png`、`scarf.png` | 青绿金纹背心带斜挎带和独立肩袖衬布，布包与红围巾末端各有转轴 |
| `sleeve.png` | 左右完整衣袖。肩、肘、肘弯的蒙皮权重让刺绣与褶皱随手臂弯曲 |
| `trouser.png`、`trouser_far.png` | 近腿是青金大云纹，远腿是小金云，膝和裤脚保留各自的织物走势 |
| `shoe_near.png`、`shoe_far.png` | 两个不同视角的蓝布鞋与踝部绑带，可分别从脚跟滚到前掌 |
| `hands.png` | 上排依次是垂手、挥掌、遮眉、触颏，下排是拢耳、握拳、提笔、持卷 |
| `faces.png` | 从左到右逐行排列为平静、问好、望远、思考、倾听、惊喜、庆祝、提笔、休息 |
| `eyelids.png` | 每列表情保留自己的眉、颊和口形，每行叠印不同闭合程度的绘制眼睑 |

角色共有 21 根原生骨骼。每条衣袖和裤腿由独立的 `Polygon2D` 蒙皮，肘弯与膝弯各有辅助骨。落脚时，触地点从后跟移动到前掌。手部挂点会跟随掌心、指端或笔锋，腰间挂点跟随布包流苏。[人物绑定](../../../scripts/characters/boy_actor.gd) · [衣料蒙皮](../../../scripts/characters/boy_cloth.gd)

在工程根目录运行骨架测试。实际画面取自有显示设备的 Godot Compatibility 渲染，可在本地生成完整透明 PNG 序列和近景。

```sh
tools/godot.sh --headless --path . --script tests/test_boy_rig.gd
tools/godot.sh --path . --script tests/test_boy_rig.gd -- --boy-capture=/tmp/ouyoji-boy-frames
```
