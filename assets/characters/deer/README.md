# 鹿铃的分层画稿

鹿铃沿用 4.2 的奶白皮毛、金角、金色云纹、红绿飘带和颈铃。4.3 以项目原画 `assets/images/deer.png` 为形象参考，使用内置 ImageGen 生成透明的部件原画。眼睛、眉毛、眼睫、嘴和高光由 `deer_face.gd` 在头骨坐标中绘制。

| 画件 | 用途 |
| --- | --- |
| `head.webp`、`near_ear.webp`、`far_ear.webp` | 头部连角和金斑，两耳分别转向 |
| `trunk.webp`、`tail.webp` | 连续的颈肩和躯干、可扬起的尾巴 |
| `foreleg.webp`、`hindleg.webp` | 近侧与远侧四肢各自加权到上段、膝或飞节、蹄 |
| `folded_fore.webp`、`folded_hind.webp` | 深屈膝的两种遮挡关系，沿用四个落蹄位置 |
| `red_silk.webp`、`jade_silk.webp` | 朱红与青绿色丝带，每条有带根、带中和带尖 |
| `bell.webp`、`tassel.webp` | 颈铃与铃穗独立摆动 |

共 13 张透明 WebP。第一批绘制要求是参考原画的水粉纸纹与赭色勾线，朝右画无眼眉嘴的鹿头、大小耳、四足站姿所需的前后腿、双带、铃、穗与尾。第二批要求连续画出从后胯到系带颈部的站姿躯体，并分别画出趴卧时膝向前折的前肢和飞节向后折的后肢。生成画稿经透明边缘裁切，游戏按相邻部件遮挡顺序装配。

`tests/test_deer_rig.gd` 验证四拍接地、八种动作、双耳与铃带的跟随，以及减少动态。使用 Compatibility 运行会额外对比固定头部下的眼眉嘴实绘像素，检查蹄色、翻转和趴卧足底。传入 `-- --deer-output=/绝对路径 --deer-film` 可保存各动作、步态和连续演出的透明帧。
