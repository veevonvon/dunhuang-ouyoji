# 4.3《旅伴有灵》角色表演设计与实施

六岁的欧哟几与鹿铃沿用 4.2 形象。欧哟几的黑发、红围巾、青绿背心、布包和卷轴，鹿铃的金角、金纹、飘带和颈铃都应从手机画面上认得出来。目标是在孩子操控移动、遇到朋友、观察和庆祝时，让眼睛、四肢、衣饰和脚下的反应共同讲清动作。

## 表演与入口

- 六站旅行中使用真正的 Godot Skeleton2D 与 Bone2D，按实际位移驱动步态，左右转身、起停和远近透视沿用原主线。脚印或轻尘落在脚接触地面的位置，手部与铃声的效果跟随各自的骨骼。
- 动作包括招手、望远、思考、倾听、惊喜、庆祝、提笔和休息。表情区分平静、微笑、好奇、专注、惊讶、欢喜和困倦，搭配自然眨眼。鹿铃用耳朵、尾巴、四足及铃带作相应回应。
- 首页听欧哟几讲、实地观察、得到采风印及收风铃时选择对应演出。营地里的旅伴互动提供同一对角色的近景和可重玩的动作。猜动作时可以重看，猜错继续观察，猜中后两位旅伴一起庆祝。角色演出不写行囊，也不改变发现、奖励或解谜条件。
- 少动态使用清晰的静止关键姿态，取消弹跳、飞散和重复眨眼。弹窗、切页、失焦及后台不得残留手势、移动、效果或待发事件。

## 原生接口与所有权

共享脚本为 `scripts/characters/travel_actor.gd`，根节点为 Node2D，坐标原点在双脚之间，朝右，欧哟几原始身高约 256、鹿铃约 160 个逻辑像素。两种角色分别由 `scripts/characters/boy_actor.gd` 和 `deer_actor.gd` 提供，拥有各自的画稿与专用测试。父类负责共同的可见性、生命周期、动作时间、转向、步态相位、眨眼和挂点。

子类实现 `build_character()`、`pose_character()`。父类预建 `skeleton: Skeleton2D` 在 `Facing/Skeleton2D`，提供 `joint(parent, id, at, length)`、`register_anchor(id,node)` 和 `anchor_point(id)`。姿态可读 `clock`、`gait`（弧度）、`move_weight`、`acting`、`action_progress`、`action_weight`、`blink_amount`、`reduced_motion`。稳定动作名为 `greet/look/think/listen/surprise/celebrate/draw/rest`。两个角色都登记 `face/hand/bell/left_foot/right_foot`。

应用通过 `set_locomotion(amount, direction)`、`perform(action, hold=false)`、`set_reduced_motion(value)`、`set_active(value)` 驱动，接收 `footfall(side:int)`（0 为左侧接地，1 为右侧）和 `action_cue(action:String)`（按已更新的骨骼挂点，在动作约 38% 处触发一次）。地面与动作特效由独立 Node2D 的 `scripts/characters/effects.gd` 提供，效果是手绘式的有限时长图元。三种地面的布鞋和鹿蹄、笔锋与颈铃有八个独立音色，在落地或动作提示时播放。

## 交付顺序

1. 从缺少角色骨骼、动作、表情及效果的失败用例开始，分别实现两副骨架、表演时钟和有上限的动作特效。检查实际骨骼位置和实际出图。
2. 接入真实移动、向导、发现与营地。以原生触摸验证动作可辨、奖励去重、方向与落脚、减动态即时生效、后台暂停和返回。比较常规、宽屏和平板布局。
3. 用 Godot Compatibility 连续取帧检查头部表情、关节衔接和动作效果，复跑旧主线与 19 处景点。以原签名导出不同名的 4.3 APK，在 Android 模拟器从 4.2 升级验证并交付独立源码。

骨架结构和骨骼的休息变换按 Godot 官方说明实现。[Skeleton2D](https://docs.godotengine.org/en/stable/classes/class_skeleton2d.html) · [Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html) · [二维骨骼](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html)
