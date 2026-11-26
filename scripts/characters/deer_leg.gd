extends RefCounted

const Actor = preload("res://scripts/characters/travel_actor.gd")
const DeerSkin = preload("res://scripts/characters/deer_skin.gd")
const FORE := preload("res://assets/characters/deer/foreleg.webp")
const HIND := preload("res://assets/characters/deer/hindleg.webp")
const FOLDED_FORE := preload("res://assets/characters/deer/folded_fore.webp")
const FOLDED_HIND := preload("res://assets/characters/deer/folded_hind.webp")

var upper: Bone2D
var lower: Bone2D
var hoof: Bone2D
var ground: Vector2
var phase_offset: float
var hind: bool
var far: bool
var upper_length: float
var lower_length: float
var rest_upper_angle: float
var rest_lower_angle: float
var skeleton: Skeleton2D
var standing_ink: Polygon2D
var tucked_ink: Sprite2D
var tucked_size: Vector2

func _init(actor: Actor, pelvis: Bone2D, id: String, hip: Vector2, sole_x: float,
		is_hind: bool, is_far: bool, offset: float) -> void:
	skeleton = actor.skeleton
	hind = is_hind
	far = is_far
	phase_offset = offset
	ground = Vector2(sole_x, 0)
	var hip_at := skeleton.to_local(pelvis.to_global(hip))
	var reach := hip_at.distance_to(ground) + (9.0 if hind else 4.6)
	upper_length = reach * (.50 if hind else .49)
	lower_length = reach - upper_length
	var knee := bend_point(hip_at, ground)
	rest_upper_angle = (knee - hip_at).angle()
	rest_lower_angle = (ground - knee).angle()
	upper = actor.joint(pelvis, id, hip, upper_length)
	lower = actor.joint(upper, id + "Knee", knee - hip_at, lower_length)
	hoof = actor.joint(lower, id + "Hoof", ground - knee, 5.0)
	upper.bone_angle = rest_upper_angle
	lower.bone_angle = rest_lower_angle

func bend_point(start: Vector2, end: Vector2) -> Vector2:
	var direction := start.direction_to(end)
	var reach := clampf(start.distance_to(end), absf(upper_length - lower_length) + .01,
			upper_length + lower_length - .001)
	var along := (upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * reach)
	var side := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	return start + direction * along + direction.orthogonal() * side * (-1 if hind else 1)

func paint(parent: Node2D) -> void:
	var texture: Texture2D = HIND if hind else FORE
	var hip := skeleton.to_local(upper.global_position)
	var knee := skeleton.to_local(lower.global_position)
	var cap := 12.0 if hind else 7.0
	var width := 29.0 if hind else 23.0
	var top := hip.y - cap
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var influences := PackedFloat32Array()
	var knee_row := inverse_lerp(top, ground.y, knee.y)
	for i in 21:
		var t := i / 20.0
		var y := lerpf(top, ground.y + .35, t)
		var center_x := lerpf(hip.x, knee.x, clampf(inverse_lerp(hip.y, knee.y, y), 0, 1))
		if y > knee.y:
			center_x = lerpf(knee.x, ground.x, clampf(inverse_lerp(knee.y, ground.y, y), 0, 1))
		var center_on_paper: float
		if hind:
			center_on_paper = .54 - .28 * smoothstep(.32, .55, t) + .31 * smoothstep(.64, .98, t)
		else:
			center_on_paper = .43 - .06 * smoothstep(.1, .45, t) + .38 * smoothstep(.55, 1.0, t)
		var x := center_x - width * center_on_paper
		vertices.append(Vector2(x, y))
		vertices.append(Vector2(x + width, y))
		uvs.append(Vector2(0, texture.get_height() * t))
		uvs.append(Vector2(texture.get_width(), texture.get_height() * t))
		influences.append(smoothstep(knee_row - .14, knee_row + .14, t) + smoothstep(.83, .97, t))
	var bones: Array[Bone2D] = [upper, lower, hoof]
	var tint := Color("#c7aa90") if far else Color.WHITE
	standing_ink = DeerSkin.paint_strip(parent, skeleton, str(upper.name) + "Ink", texture, bones, vertices, uvs, influences, tint)
	tucked_ink = Sprite2D.new()
	tucked_ink.name = str(upper.name) + "Tucked"
	tucked_ink.centered = false
	tucked_ink.texture = FOLDED_HIND if hind else FOLDED_FORE
	tucked_size = Vector2(39, 21.5) if hind else Vector2(34, 18.5)
	tucked_ink.scale = tucked_size / tucked_ink.texture.get_size()
	tucked_ink.self_modulate = tint
	tucked_ink.hide()
	parent.add_child(tucked_ink)

func walking_target(angle: float, weight: float) -> Vector2:
	# Front hooves touch down at 0 and PI. Hind hooves precede the corresponding
	# fore hoof by one quarter cycle, giving a lateral-sequence, four-beat walk.
	var t := fposmod(angle / TAU + phase_offset, 1.0)
	var stride := 30.0 if hind else 32.0
	var duty := .64
	var travel := Vector2.ZERO
	if t < duty:
		travel.x = lerpf(stride * .5, -stride * .5, t / duty)
	else:
		var swing := (t - duty) / (1.0 - duty)
		travel.x = lerpf(-stride * .5, stride * .5, smoothstep(0, 1, swing))
		travel.y = -pow(sin(PI * swing), 1.20) * (13.0 if hind else 17.0)
	return ground + travel * weight

func set_target(target: Vector2, toe_angle: float, resting: float) -> void:
	# Solve in torso space so a mirrored or scaled actor still plants its hoof.
	var root_joint := upper.get_parent() as Bone2D
	var end := root_joint.to_local(skeleton.to_global(target))
	var start := upper.position
	var knee := bend_point(start, end)
	upper.rotation = (knee - start).angle() - rest_upper_angle
	lower.rotation = (end - knee).angle() - rest_lower_angle - upper.rotation
	hoof.rotation = toe_angle - root_joint.rotation - upper.rotation - lower.rotation
	# Near full flexion the shin lies *in front of* the thigh. Each leg has a
	# second drawing for that change in occlusion and shares the same hoof pivot.
	var tuck := smoothstep(.47, .70, resting)
	standing_ink.visible = tuck < 1.0
	standing_ink.self_modulate.a = 1.0 - tuck
	tucked_ink.visible = tuck > 0.0
	if tucked_ink.visible:
		tucked_ink.self_modulate.a = tuck
		var planted := skeleton.to_local(hoof.global_position)
		tucked_ink.position = planted - Vector2(tucked_size.x * (.90 if hind else .11), tucked_size.y - .1)
