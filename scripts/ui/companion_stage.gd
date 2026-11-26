extends Control

signal touched(actor: String)
signal sounded(action: String)

const RUG = preload("res://assets/characters/camp_rug.webp")
const Boy = preload("res://scripts/characters/boy_actor.gd")
const Deer = preload("res://scripts/characters/deer_actor.gd")
const Effects = preload("res://scripts/characters/effects.gd")
var boy: Node2D
var deer: Node2D
var accent: Node2D
var _finger := -3
var _first := Vector2.ZERO
var _target := ""
var _rug := Rect2()
var _covered := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	boy = Boy.new()
	boy.name = "Ouyoji"
	deer = Deer.new()
	deer.name = "Luling"
	add_child(deer)
	add_child(boy)
	accent = Effects.new()
	accent.name = "ActionInk"
	accent.z_index = 32
	add_child(accent)
	deer.set_locomotion(0,-1)
	boy.action_cue.connect(_boy_cue)
	deer.action_cue.connect(_deer_cue)
	resized.connect(_layout)
	Journey.changed.connect(refresh)
	refresh()
	_layout()

func _layout() -> void:
	var scale_factor := clampf(minf(size.y / 307.0, size.x / 409.0), .56, 2.05)
	var foot := size.y * .88
	var center := size.x * .50
	boy.scale = Vector2.ONE * scale_factor
	deer.scale = Vector2.ONE * (scale_factor * 1.06)
	boy.position = Vector2(center - 65 * scale_factor, foot)
	deer.position = Vector2(center + 85 * scale_factor, foot - 6 * scale_factor)
	accent.scale = Vector2.ONE * scale_factor
	var width := minf(433 * scale_factor,size.x * .92)
	var height := minf(width * .183,size.y * .28)
	_rug = Rect2(center-width*.5,foot-height*.51,width,height)
	queue_redraw()

func refresh() -> void:
	var reduced: bool = Journey.progress.settings.reducedMotion
	for node in [boy,deer,accent]: node.set_reduced_motion(reduced)

func play(action: String, held := false) -> void:
	if _covered: return
	boy.perform(action,held)
	deer.perform(action,held)

func _boy_cue(action: String) -> void:
	if action != "listen": _mark(action,boy)
	sounded.emit(action)

func _deer_cue(action: String) -> void:
	if action == "listen": _mark(action,deer)

func _mark(action: String, actor: Node2D) -> void:
	var tip: Vector2 = actor.to_global(actor.anchor_point(actor.cue_anchor(action)))
	accent.accent(action, accent.to_local(tip), actor.heading)

func set_covered(value: bool) -> void:
	_covered = value
	_clear_touch()
	for node in [boy,deer,accent]: node.set_active(not value)

func _clear_touch() -> void:
	_finger = -3
	_target = ""

func _whose(point: Vector2) -> String:
	for actor: Node2D in [boy, deer]:
		var local := actor.transform.affine_inverse() * point
		var body := Rect2(-67,-266,136,266) if actor == boy else Rect2(-77,-175,160,175)
		if body.has_point(local) or local.distance_to(actor.anchor_point("face")) < 32:
			return "boy" if actor == boy else "deer"
	return ""

func _gui_input(event: InputEvent) -> void:
	if _covered or event.device == InputEvent.DEVICE_ID_EMULATION: return
	var index := -2
	if event is InputEventScreenTouch: index = event.index
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if (event is InputEventMouseMotion and _finger == -2 or event is InputEventScreenDrag and event.index == _finger) and event.position.distance_to(_first) > 26: _target = ""
		return
	else: return
	if event.pressed and _finger == -3:
		_finger = index
		_first = event.position
		_target = _whose(_first)
	elif not event.pressed and _finger == index:
		if not event.canceled and not _target.is_empty() and _first.distance_to(event.position) <= 26 and _whose(event.position) == _target:
			touched.emit(_target)
		_clear_touch()
	accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]: _clear_touch()

func _draw() -> void:
	if not _rug.has_area(): return
	draw_texture_rect(RUG,_rug,false)
	for actor: Node2D in [boy,deer]:
		draw_set_transform(actor.position,0,actor.scale * Vector2(1,.18))
		draw_circle(Vector2.ZERO,38 if actor == deer else 29, Color("112f3246"),true,-1,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
