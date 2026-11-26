extends "res://scripts/characters/travel_actor.gd"

const Leg = preload("res://scripts/characters/deer_leg.gd")
const DeerSkin = preload("res://scripts/characters/deer_skin.gd")
const Face = preload("res://scripts/characters/deer_face.gd")
const TRUNK := preload("res://assets/characters/deer/trunk.webp")
const HEAD := preload("res://assets/characters/deer/head.webp")
const NEAR_EAR := preload("res://assets/characters/deer/near_ear.webp")
const FAR_EAR := preload("res://assets/characters/deer/far_ear.webp")
const RED_SILK := preload("res://assets/characters/deer/red_silk.webp")
const JADE_SILK := preload("res://assets/characters/deer/jade_silk.webp")
const BELL := preload("res://assets/characters/deer/bell.webp")
const TASSEL := preload("res://assets/characters/deer/tassel.webp")
const TAIL := preload("res://assets/characters/deer/tail.webp")
const HIP_HEIGHT := Vector2(0, -63)
const NECK_BASE := Vector2(23, -9)

var torso: Bone2D
var neck: Bone2D
var head: Bone2D
var near_ear: Bone2D
var far_ear: Bone2D
var tail: Bone2D
var bell: Bone2D
var tassel: Bone2D
var red_silk: Array[Bone2D] = []
var jade_silk: Array[Bone2D] = []
var legs: Array[Leg] = []
var face: Face
var paint_stack: Node2D
var layers: Array[Node2D] = []
var bindings: Array[Bone2D] = []

func build_character() -> void:
	torso = joint(skeleton, "Torso", HIP_HEIGHT, 43)
	neck = joint(torso, "Neck", NECK_BASE, 33)
	head = joint(neck, "Head", Vector2(12, -30), 29)
	near_ear = joint(head, "NearEar", Vector2(-10, -24), 40)
	far_ear = joint(head, "FarEar", Vector2(16, -26), 30)
	tail = joint(torso, "Tail", Vector2(-44, -2), 21)
	bell = joint(neck, "Bell", Vector2(18.4, -8.5), 15)
	tassel = joint(bell, "Tassel", Vector2(.1, 14.6), 13)
	red_silk = silk_bones("RedStreamer", Vector2(1, -16), 88)
	jade_silk = silk_bones("JadeStreamer", Vector2(1.7, -14), 93)
	legs = [
		Leg.new(self, torso, "NearFore", Vector2(23, 3), 28, false, false, 0.0),
		Leg.new(self, torso, "FarFore", Vector2(17, 2), 11, false, true, .5),
		Leg.new(self, torso, "NearHind", Vector2(-31, 5), -40, true, false, .25),
		Leg.new(self, torso, "FarHind", Vector2(-24, 3), -23, true, true, .75)
	]
	register_anchor("face", marker(head, Vector2(12, -18)))
	register_anchor("hand", legs[0].hoof)
	register_anchor("bell", marker(bell, Vector2(.25, 9.4)))
	register_anchor("left_foot", legs[0].hoof)
	register_anchor("right_foot", legs[1].hoof)

	# Keep the whole illustration contiguous at its actor's world Z. Texture
	# order is independent of parentage, notably for the far ear and four legs.
	paint_stack = Node2D.new()
	paint_stack.name = "Paint"
	skeleton.add_child(paint_stack)
	legs[3].paint(paint_stack)
	legs[1].paint(paint_stack)
	DeerSkin.paint_silk(paint_stack, skeleton, RED_SILK, red_silk, Vector2(88, 24), .39)
	DeerSkin.paint_silk(paint_stack, skeleton, JADE_SILK, jade_silk, Vector2(93, 25), .36)
	paint_part(tail, TAIL, Rect2(-24, -27, 28, 32))
	legs[2].paint(paint_stack)
	legs[0].paint(paint_stack)
	DeerSkin.paint_trunk(paint_stack, skeleton, TRUNK, torso, neck, Rect2(-51, -106, 98, 62))
	paint_part(bell, BELL, Rect2(-5.9, -.6, 12.2, 16))
	paint_part(tassel, TASSEL, Rect2(-5.15, -.3, 9.7, 13.5))
	paint_part(far_ear, FAR_EAR, Rect2(-4, -33, 28, 35))
	paint_part(near_ear, NEAR_EAR, Rect2(-43, -22, 46, 29))
	var face_layer := paint_part(head, HEAD, Rect2(-28, -59, 64, 66))
	face = Face.new()
	face.name = "Expression"
	face.position = Vector2(8.1, -18.8)
	face_layer.add_child(face)

func marker(parent: Bone2D, at: Vector2) -> Marker2D:
	var node := Marker2D.new()
	node.position = at
	parent.add_child(node)
	return node

func silk_bones(id: String, at: Vector2, length: float) -> Array[Bone2D]:
	var seam := joint(neck, id, at, length * .40)
	var middle := joint(seam, id + "Middle", Vector2(-length * .40, 0), length * .33)
	var tip := joint(middle, id + "Tip", Vector2(-length * .33, 0), length * .27)
	return [seam, middle, tip]

func paint_part(bone: Bone2D, texture: Texture2D, rect: Rect2) -> Node2D:
	var layer := Node2D.new()
	layer.name = str(bone.name) + "Ink"
	paint_stack.add_child(layer)
	var pigment := Sprite2D.new()
	pigment.texture = texture
	pigment.centered = false
	pigment.position = rect.position
	pigment.scale = rect.size / texture.get_size()
	layer.add_child(pigment)
	layers.append(layer)
	bindings.append(bone)
	return layer

func pose_character() -> void:
	var w := action_weight
	var locomotion := 0.0 if reduced_motion else move_weight * (1.0 - w)
	var breath := 0.0 if reduced_motion else sin(clock * 2.08 + .45)
	var beat := 0.0 if reduced_motion else sin((action_progress - .27) * TAU * 1.45)
	var suspension := 1.0 - cos(gait * 2)
	var body_offset := Vector2(0, breath * .43 + suspension * .72 * locomotion)
	var pitch := sin(gait * 2 - .3) * .022 * locomotion
	var neck_slide := Vector2.ZERO
	var nod := breath * .014 + sin(gait * 2 - .54) * .054 * locomotion
	var chin := -nod * .47
	var ear_l := .015
	var ear_r := -.02
	var tail_lift := 0.0
	var drape := 0.0
	var near_hoof := Vector2.ZERO
	var far_hoof := Vector2.ZERO
	var back_hoof := Vector2.ZERO
	match acting:
		"greet":
			body_offset += Vector2(-2.8, 1.8) * w
			pitch -= .040 * w
			nod += (-.11 + beat * .07) * w
			chin += (-.11 + beat * .055) * w
			ear_l += (.18 + beat * .10) * w
			ear_r -= .12 * w
			tail_lift += .31 * w
			near_hoof = Vector2(12 + beat * 2.5, -25 - beat * 2.0) * w
		"look":
			neck_slide += Vector2(2.1, -2.4) * w
			nod -= .25 * w
			chin -= .10 * w
			ear_l += .22 * w
			ear_r -= .15 * w
			tail_lift += .11 * w
		"think":
			body_offset += Vector2(-1.1, 1.4) * w
			nod += .16 * w
			chin -= .29 * w
			ear_l -= .25 * w
			ear_r -= .23 * w
			tail_lift -= .18 * w
			near_hoof = Vector2(-7, -5) * w
		"listen":
			neck_slide += Vector2(-1.5, -.5) * w
			nod -= .18 * w
			chin += .13 * w
			ear_l -= (.42 + beat * .045) * w
			ear_r += .27 * w
			tail_lift -= .12 * w
		"surprise":
			body_offset += Vector2(-3.4, -.9) * w
			pitch -= .085 * w
			nod -= .16 * w
			chin += .17 * w
			ear_l += .52 * w
			ear_r -= .38 * w
			tail_lift += .45 * w
			drape += .15 * w
			near_hoof = Vector2(5, -9) * w
			far_hoof = Vector2(1, -2) * w
		"celebrate":
			body_offset += Vector2(-4.2, -1.6 - beat * 1.8) * w
			pitch -= .12 * w
			nod += (-.27 + beat * .07) * w
			chin -= .10 * w
			ear_l += .32 * w
			ear_r -= .30 * w
			tail_lift += (.62 + beat * .12) * w
			drape += (.19 + beat * .09) * w
			near_hoof = Vector2(12, -29 - beat * 3.5) * w
			far_hoof = Vector2(3, -13 + beat * 2.6) * w
		"draw":
			body_offset += Vector2(1.5, 3.0) * w
			pitch += .075 * w
			neck_slide += Vector2(2, 4.3) * w
			nod += (.50 + beat * .028) * w
			chin += .12 * w
			ear_l -= .10 * w
			ear_r += .23 * w
			tail_lift -= .11 * w
			near_hoof = Vector2(9 + beat * 2.0, -3) * w
		"rest":
			body_offset += Vector2(-2.8, 38.5) * w
			pitch -= .052 * w
			neck_slide += Vector2(-2, 4.2) * w
			nod += .43 * w
			chin += .20 * w
			ear_l -= .34 * w
			ear_r += .32 * w
			tail_lift -= .36 * w
			drape -= .24 * w
			near_hoof = Vector2(-8, -.5) * w
			far_hoof = Vector2(-5, 0) * w
			back_hoof = Vector2(13, 0) * w
	torso.position = HIP_HEIGHT + body_offset
	torso.rotation = pitch
	neck.position = NECK_BASE + neck_slide
	neck.rotation = nod
	head.rotation = chin
	near_ear.rotation = ear_l + breath * .023 + sin(gait * 2 - .88) * .078 * locomotion
	far_ear.rotation = ear_r - breath * .018 - sin(gait * 2 - 1.18) * .061 * locomotion
	tail.rotation = tail_lift + breath * .042 + sin(gait * 2 - .94) * .21 * locomotion
	bell.rotation = -(pitch + nod) * .91 + sin(gait * 2 - 1.34) * .24 * locomotion + beat * .10 * w
	tassel.rotation = sin(gait * 2 - 1.98) * .26 * locomotion + breath * .025 + beat * .16 * w
	pose_silk(red_silk, drape + .06, nod, pitch, locomotion, breath, 0.0)
	pose_silk(jade_silk, drape - .09, nod, pitch, locomotion, breath, .83)
	var leg_offsets: Array[Vector2] = [near_hoof, far_hoof, back_hoof, back_hoof * .72]
	var rest_flex := w if acting == "rest" else 0.0
	for i in legs.size():
		var target := legs[i].walking_target(gait, locomotion) + leg_offsets[i]
		var rolling := (-target.y / 17.0) * (.31 if legs[i].hind else .24)
		legs[i].set_target(target, rolling, rest_flex)
	var local_space := skeleton.global_transform.affine_inverse()
	for i in layers.size():
		layers[i].transform = local_space * bindings[i].global_transform
	face.show_pose(acting, w, 0.0 if reduced_motion else blink_amount)

func pose_silk(bones: Array[Bone2D], drape: float, nod: float, pitch: float,
		walk: float, breath: float, delay: float) -> void:
	bones[0].rotation = drape - (nod + pitch) * .74 + sin(gait * 2 - 1.0 - delay) * .063 * walk
	bones[1].rotation = breath * .040 + sin(gait * 2 - 1.57 - delay) * .14 * walk
	bones[2].rotation = breath * .055 + sin(gait * 2 - 2.26 - delay) * .20 * walk
