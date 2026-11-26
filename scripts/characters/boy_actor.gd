extends "res://scripts/characters/travel_actor.gd"

const Cloth := preload("res://scripts/characters/boy_cloth.gd")
const COAT := preload("res://assets/characters/boy/coat.png")
const SLEEVE := preload("res://assets/characters/boy/sleeve.png")
const TROUSERS := [preload("res://assets/characters/boy/trouser.png"), preload("res://assets/characters/boy/trouser_far.png")]
const SHOES := [preload("res://assets/characters/boy/shoe_near.png"), preload("res://assets/characters/boy/shoe_far.png")]
const POUCH := preload("res://assets/characters/boy/pouch.png")
const SCARF := preload("res://assets/characters/boy/scarf.png")
const FACES := preload("res://assets/characters/boy/faces.png")
const EYELIDS := preload("res://assets/characters/boy/eyelids.png")
const HANDS := preload("res://assets/characters/boy/hands.png")

const ARM := 31.0
const FOREARM := 28.0
const THIGH := 46.0
const SHIN := 47.0
const SOLE := Vector2(6, 12)
const NEAR_REST := Vector3(16, 9, 5)
const FAR_REST := Vector3(-20, -154, -143)
const FAR_CLOTH := Color(.86, .84, .80)
const HEAD_SIZE := Vector2(71.2, 73.5)
const HEAD_ORIGIN := Vector2(-40.25, -69.1)
const HAND_SIZES := [Vector2(12,22), Vector2(18.7,27.8), Vector2(26,13.2), Vector2(15.8,20.2),
	Vector2(15.2,24), Vector2(13.6,18.2), Vector2(36,36), Vector2(25.6,32)]
const HAND_PIVOTS := [Vector2(.53,.10), Vector2(.34,.91), Vector2(.10,.62), Vector2(.19,.88),
	Vector2(.40,.89), Vector2(.42,.88), Vector2(.10,.87), Vector2(.12,.87)]
const HAND_ANGLES := [0, 180, 90, 140, 176, 180, 135, 145]
const HAND_CONTACTS := [Vector2(.42,.66), Vector2(.54,.38), Vector2(.76,.31), Vector2(.93,.10),
	Vector2(.58,.28), Vector2(.51,.28), Vector2(.977,.971), Vector2(.70,.20)]

# Arm components are upper arm, forearm and fingers, measured from the downward
# vertical of the chest. The first gesture before each reach is its preparation.
const GESTURES := {
	"greet": {"near":Vector3(105,132,143), "far":Vector3(-17,-145,-136), "prep":Vector3(-12,21,12), "torso":Vector3(1,-4,-1), "face":1, "hand":1},
	"look": {"near":Vector3(151,212,-87), "far":Vector3(-8,-151,-132), "prep":Vector3(18,8,16), "torso":Vector3(-2,-8,-.5), "face":2, "hand":2},
	"think": {"near":Vector3(-63,-162,-148), "far":Vector3(-13,-138,-128), "prep":Vector3(8,19,23), "torso":Vector3(2,6,.8), "face":3, "hand":3},
	"listen": {"near":Vector3(107,235,184), "far":Vector3(-15,-151,-145), "prep":Vector3(-8,4,-16), "torso":Vector3(-2,-9,.2), "face":4, "hand":4},
	"surprise": {"near":Vector3(61,199,188), "far":Vector3(-51,-146,-134), "prep":Vector3(-14,14,-10), "torso":Vector3(-5,-5,1.6), "face":5, "hand":1},
	"celebrate": {"near":Vector3(132,145,151), "far":Vector3(-118,-148,-155), "prep":Vector3(-18,-23,-14), "torso":Vector3(1,-7,-2), "face":6, "hand":5},
	"draw": {"near":Vector3(-46,-92,-136), "far":Vector3(-8,-115,-114), "prep":Vector3(18,11,23), "torso":Vector3(4,11,1.4), "face":7, "hand":6},
	"rest": {"near":Vector3(-17,17,3), "far":Vector3(-8,-103,-119), "prep":Vector3(9,-11,-8), "torso":Vector3(4,13,6), "face":8, "hand":0}
}

class Limb:
	var upper: Bone2D
	var hinge: Bone2D
	var lower: Bone2D
	var end: Bone2D
	var art: Sprite2D
	var contact: Node2D

var pelvis: Bone2D
var chest: Bone2D
var head: Bone2D
var scarf: Bone2D
var pouch: Bone2D
var face_paint: Sprite2D
var eyelids: Sprite2D
var arms: Array[Limb] = []
var legs: Array[Limb] = []


func build_character() -> void:
	pelvis = joint(skeleton, "Pelvis", Vector2(0,-100), 31)
	chest = joint(pelvis, "Spine", Vector2.ZERO, 80)
	var coat := _sprite(chest, COAT, "Waistcoat", 10)
	_place(coat, Vector2(68,98), Vector2(-34,-97))
	head = joint(chest, "Neck", Vector2(-3,-85), 46)
	face_paint = _sprite(head, FACES, "Expression", 8)
	face_paint.hframes = 3
	face_paint.vframes = 3
	_place(face_paint, HEAD_SIZE, HEAD_ORIGIN)
	eyelids = _sprite(head, EYELIDS, "PaintedEyelids", 9)
	eyelids.hframes = 9
	eyelids.vframes = 3
	var head_scale := HEAD_SIZE / Vector2(361,372)
	_place(eyelids, Vector2(169,100) * head_scale, HEAD_ORIGIN + Vector2(176,148) * head_scale)
	register_anchor("face", _marker(head, "Eyes", Vector2(12,-29)))
	scarf = joint(chest, "ScarfKnot", Vector2(16,-79), 20)
	var tails := _sprite(scarf, SCARF, "EmbroideredEnds", 11)
	_place(tails, Vector2(24,22), Vector2(-3,-3))
	pouch = joint(chest, "SatchelClasp", Vector2(-20,-22), 27)
	var bag := _sprite(pouch, POUCH, "Satchel", 12)
	_place(bag, Vector2(33,36), Vector2(-14,-3))
	register_anchor("bell", _marker(pouch, "Tassel", Vector2(-4,27)))
	for i in 2:
		var near := i == 0
		var side := "Left" if near else "Right"
		var arm := _chain(chest, side, "Shoulder", "Elbow", "Wrist", Vector2(-20 if near else 17,-74), ARM, FOREARM)
		Cloth.bind_cloth(skeleton, arm.upper, arm.hinge, arm.lower, SLEEVE, 23.5 if near else 22.5,
			-8.2, ARM + FOREARM + 2, 10.0, 14 if near else 5, Color.WHITE if near else FAR_CLOTH)
		arm.art = _sprite(arm.end, HANDS, "HandArt", 13 if near else 12)
		arm.art.hframes = 4
		arm.art.vframes = 2
		arm.contact = _marker(arm.end, "Palm", Vector2.ZERO)
		if near:
			register_anchor("hand", arm.contact)
		else:
			arm.art.self_modulate = Color(.97,.94,.88)
		arms.append(arm)
		var leg := _chain(pelvis, side, "Hip", "Knee", "Ankle", Vector2(-9 if near else 9,0), THIGH, SHIN)
		Cloth.bind_cloth(skeleton, leg.upper, leg.hinge, leg.lower, TROUSERS[i], 36 if near else 32,
			-9, THIGH + SHIN - 2, 14.0, 3 if near else 1, Color.WHITE if near else FAR_CLOTH)
		leg.art = _sprite(leg.end, SHOES[i], "CloudShoe", 2 if near else 0)
		var shoe_size := Vector2(32.8,25.9) if near else Vector2(33.5,25.2)
		_place(leg.art, shoe_size, Vector2(-9, SOLE.y - shoe_size.y))
		if not near: leg.art.self_modulate = FAR_CLOTH
		leg.contact = _marker(leg.end, "Ground", SOLE)
		register_anchor("left_foot" if near else "right_foot", leg.contact)
		legs.append(leg)


func _chain(parent: Bone2D, side: String, top_name: String, middle_name: String, end_name: String,
		at: Vector2, first_length: float, second_length: float) -> Limb:
	var limb := Limb.new()
	limb.upper = joint(parent, side + top_name, at, first_length)
	limb.lower = joint(limb.upper, side + middle_name, Vector2(0,first_length), second_length)
	limb.hinge = joint(limb.upper, side + middle_name + "Fold", Vector2(0,first_length), 7)
	limb.end = joint(limb.lower, side + end_name, Vector2(0,second_length), 12)
	return limb


func _marker(parent: Node2D, id: String, at: Vector2) -> Node2D:
	var marker := Node2D.new()
	marker.name = id
	marker.position = at
	parent.add_child(marker)
	return marker


func _sprite(parent: Node2D, texture: Texture2D, id: String, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = id
	sprite.texture = texture
	sprite.centered = false
	sprite.z_index = layer
	parent.add_child(sprite)
	return sprite


func _place(sprite: Sprite2D, size: Vector2, at: Vector2) -> void:
	sprite.position = at
	sprite.scale = size * Vector2(sprite.hframes, sprite.vframes) / sprite.texture.get_size()


func pose_character() -> void:
	if arms.size() != 2: return
	var stride := 0.0 if reduced_motion else move_weight
	var breath := 0.0 if reduced_motion else sin(clock * 2.07)
	var swing := cos(gait) * stride
	var near_arm := NEAR_REST + Vector3(21,15,15) * swing
	var far_arm := FAR_REST - Vector3(16,9,8) * swing
	var back := Vector3(0,breath * .85,breath * .42)
	var face := 0
	var hand := 0
	var spring := 0.0
	if GESTURES.has(acting) and action_weight > 0.0:
		var gesture: Dictionary = GESTURES[acting]
		var p := action_progress
		var reach := smoothstep(.095,.35,p)
		var anticipation := sin(clampf(p / .24, 0, 1) * PI)
		var near_target: Vector3 = gesture.near
		var far_target: Vector3 = gesture.far
		var posture: Vector3 = gesture.torso
		var flourish := sin((p - .35) * 4.8 * PI) * smoothstep(.32,.42,p)
		match acting:
			"greet": near_target += Vector3(2,5,14) * flourish
			"look": posture.y -= 2.2 * flourish
			"think": near_target += Vector3(-2,2,4) * flourish
			"listen": posture.y -= 3 * flourish
			"surprise": posture.y -= 3.5 * sin(reach * PI)
			"celebrate":
				if not reduced_motion:
					spring = maxf(0, sin(clampf((p - .265) / .44,0,1) * PI)) * action_weight
				near_target += Vector3(3,3,6) * flourish
				far_target -= Vector3(3,3,4) * flourish
			"draw":
				near_target += Vector3(3,-8,9) * flourish
				posture.y += 1.8 * flourish
			"rest": posture.y += 1.7 * smoothstep(.43,.70,p)
		var preparation: Vector3 = gesture.prep
		var weighted_reach := reach * action_weight * smoothstep(0,.22,action_weight)
		near_arm = (near_arm + preparation * anticipation * action_weight).lerp(near_target, weighted_reach)
		far_arm = (far_arm - preparation * anticipation * action_weight * .42).lerp(far_target, weighted_reach)
		back += posture * weighted_reach
		back.y -= posture.y * anticipation * action_weight * .48
		back.z += anticipation * action_weight * (4.0 if acting == "celebrate" else 1.15)
		if weighted_reach > .34:
			face = gesture.face
			hand = gesture.hand
	_set_expression(face)
	var bounce := 2.5 * absf(sin(gait)) * stride
	pelvis.position = Vector2(.9 * sin(gait) * stride, -104 + stride * 6.7 + back.z - bounce - 5.5 * spring)
	var left_step := _footstep(0, stride, spring)
	var right_step := _footstep(1, stride, spring)
	pelvis.position.y = maxf(pelvis.position.y, maxf(_highest_hip(0,left_step),_highest_hip(1,right_step)))
	chest.rotation = deg_to_rad(back.x + swing * 2.8 + breath * .35)
	head.rotation = deg_to_rad(back.y - swing * 2.2)
	scarf.rotation = deg_to_rad(-4 + 10 * sin(gait - .75) * stride + 1.9 * breath - back.x * .8 + spring * 11)
	pouch.rotation = deg_to_rad(2 + 7 * sin(gait - .5) * stride + breath * .8 - back.x * .5 + spring * 6)
	_pose_arm(arms[0], near_arm, hand)
	_pose_arm(arms[1], far_arm, 7)
	_pose_leg(0,left_step)
	_pose_leg(1,right_step)


func _set_expression(index: int) -> void:
	face_paint.frame = index
	var closure := 0.0 if reduced_motion or index == 6 or index == 8 else blink_amount
	eyelids.visible = closure >= .20
	if eyelids.visible:
		var step := 2 if closure >= .82 else (1 if closure >= .53 else 0)
		eyelids.frame = index + step * 9


func _pose_arm(limb: Limb, angles: Vector3, kind: int) -> void:
	limb.upper.rotation = deg_to_rad(angles.x)
	limb.lower.rotation = wrapf(deg_to_rad(angles.y - angles.x),-PI,PI)
	limb.hinge.rotation = limb.lower.rotation * .5
	limb.end.rotation = deg_to_rad(angles.z - angles.y)
	limb.art.frame = kind
	var size: Vector2 = HAND_SIZES[kind]
	var pivot: Vector2 = HAND_PIVOTS[kind]
	var ink_angle := deg_to_rad(float(HAND_ANGLES[kind]))
	limb.art.rotation = ink_angle
	_place(limb.art, size, (-pivot * size).rotated(ink_angle))
	limb.contact.position = ((HAND_CONTACTS[kind] - pivot) * size).rotated(ink_angle)


func _footstep(index: int, stride: float, spring: float) -> Vector3:
	var phase := fposmod(gait + float(index) * PI, TAU) / TAU
	var t := fmod(phase * 2.0, 1.0)
	var travel: float
	var roll: float
	var contact_x: float
	var lift := 0.0
	if phase < .5:
		travel = lerpf(33,-33,t)
		roll = -12.0 * (1.0 - smoothstep(0,.27,t)) + 13.0 * smoothstep(.62,1.0,t)
		contact_x = lerpf(-5,14,smoothstep(0,1,t))
	else:
		# The swing begins behind the body, comes past the standing knee and
		# approaches the next heel strike already moving back relative to the hip.
		var passing := smoothstep(0,1,t) - t * (1.0-t) * (1.0-2.0*t) * .65
		travel = lerpf(-33,33,passing)
		roll = lerpf(13,-12,smoothstep(.08,.66,t))
		contact_x = lerpf(14,-5,smoothstep(0,1,t))
		lift = 17 * pow(maxf(0.0,sin(t * PI)),1.25)
	var shoe_angle := deg_to_rad(roll * stride)
	var contact := Vector2(lerpf(SOLE.x,contact_x,stride), SOLE.y)
	legs[index].contact.position = contact
	var track := lerpf(-17 if index == 0 else 20,-4 if index == 0 else 4,stride)
	var sole_goal := Vector2(track + travel * stride, -lift * stride - spring * (9 if index == 0 else 6))
	var ankle := sole_goal - contact.rotated(shoe_angle)
	return Vector3(ankle.x,ankle.y,shoe_angle)


func _highest_hip(index: int, step: Vector3) -> float:
	var side := step.x - (pelvis.position.x + legs[index].upper.position.x)
	var full_length := THIGH + SHIN - .10
	return step.y - sqrt(maxf(0.0, full_length * full_length - side * side))


func _pose_leg(index: int, step: Vector3) -> void:
	var limb := legs[index]
	var ankle_goal := Vector2(step.x,step.y)
	var hip := pelvis.position + limb.upper.position
	var reach := ankle_goal - hip
	var length := clampf(reach.length(),absf(THIGH-SHIN)+.01,THIGH+SHIN-.01)
	var knee_angle := acos(clampf((length*length + THIGH*THIGH - SHIN*SHIN) / (2.0 * length * THIGH),-1,1))
	limb.upper.rotation = reach.angle() - PI * .5 - knee_angle
	var knee := Vector2(0,THIGH).rotated(limb.upper.rotation)
	var shin_direction := (reach - knee).angle() - PI * .5
	limb.lower.rotation = wrapf(shin_direction - limb.upper.rotation,-PI,PI)
	limb.hinge.rotation = limb.lower.rotation * .5
	limb.end.rotation = step.z - shin_direction
