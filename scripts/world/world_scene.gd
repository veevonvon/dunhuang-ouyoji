extends Node2D

signal encounter_requested(id: String)
signal trail_requested
signal walking_changed(active: bool)
signal companion_sound(action: String)
signal step_sound(terrain: String, animal: bool, side: int)

const Marker = preload("res://scripts/world/discovery_marker.gd")
const Trails = preload("res://scripts/trails/trail_catalog.gd")
const Art = preload("res://scripts/ui/edition_art.gd")

var stage_id := "wuwei"
var encounters: Array = []
var visited: Array = []
var reduced_motion := false:
	set(value):
		if reduced_motion == value: return
		reduced_motion = value
		if is_node_ready(): _apply_motion_setting()
var _covered := false
var _paused := false
var _unfocused := false
var _tapped_actor: Node2D
var _press_position := Vector2.ZERO
var _terrain := "sand"

var elapsed := 0.0
var primary_touch := -1
var mouse_held := false
var joystick_active := false
var pending_id := ""
var pending_target := Vector2.ZERO
var trail_encounter := ""
var owns_seal := false
var walking := false
@onready var hero: CharacterBody2D = $Hero
@onready var camera: Camera2D = $Camera
@onready var deer := $Deer
@onready var tracks := $Tracks
@onready var accents := $Accents

func configure(id: String, points: Array, observed: Array, reduce := false, collected := false) -> void:
	stage_id = id
	encounters = points
	visited = observed
	reduced_motion = reduce
	owns_seal = collected
	trail_encounter = str(Trails.get_trail(id).encounter)

func _ready() -> void:
	var texture: Texture2D = load("res://assets/images/%s.jpg" % stage_id)
	$Landscape.texture = texture
	$Landscape.scale = Vector2.ONE * (1920.0 / texture.get_width())
	$Landscape.position = Vector2(0, 720 - texture.get_height() * $Landscape.scale.y)
	hero.position = Vector2(680, 565)
	hero.update_depth()
	deer.position = hero.position + Vector2(-112, -9)
	_terrain = "grass" if stage_id in ["wuwei","zhangye"] else ("stone" if stage_id in ["jiayuguan","jiuquan"] else "sand")
	for actor: Node2D in [hero.rig, deer]:
		actor.footfall.connect(_footfall.bind(actor))
		actor.action_cue.connect(_accent.bind(actor))
	_apply_motion_setting()
	camera.position.x = 640
	get_viewport().size_changed.connect(_frame_world)
	_frame_world()
	for point: Dictionary in encounters:
		var marker := Node2D.new()
		marker.position = Vector2(clampf(float(point.x) * 19.2, 140, 1780), clampf(float(point.y) * 7.2, 350, 490))
		marker.z_index = 0
		var is_trail: bool = point.id == trail_encounter
		var action := Marker.new()
		action.configure(point, owns_seal if is_trail else point.id in visited, is_trail, Art.seal(stage_id) if is_trail else null)
		var destination := Vector2(marker.position.x, clampf(marker.position.y + 60, 450, 600))
		action.pressed.connect(func(): approach(str(point.id), destination))
		action.theme = GameTheme.make()
		action.position = Vector2(-56, -92)
		action.name = "Observe_" + str(point.id)
		marker.add_child(action)
		add_child(marker)
	queue_redraw()

func _frame_world() -> void:
	var view_height := get_viewport_rect().size.y
	camera.limit_top = mini(0, floori(720 - view_height))
	camera.position.y = 720 - view_height / 2
	camera.reset_smoothing()
	camera.force_update_scroll()

func _physics_process(delta: float) -> void:
	var keyboard := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if not keyboard.is_zero_approx():
		pending_id = ""
		hero.direction = keyboard
		hero.following_target = false
	if not pending_id.is_empty() and hero.position.distance_to(pending_target) <= 16:
		var arrived := pending_id
		pending_id = ""
		hero.cancel_movement()
		_set_walking(false)
		if arrived == trail_encounter and not owns_seal: trail_requested.emit()
		else: encounter_requested.emit(arrived)
		return
	_set_walking(hero.walk_amount > .045)
	camera.position.x = lerpf(camera.position.x, hero.position.x, minf(1, delta * 3))
	var offset: float = -118 * hero.facing
	var companion_target: Vector2 = hero.position + Vector2(offset, -9)
	if companion_target.x < 80 or companion_target.x > 1840:
		companion_target.x = hero.position.x - offset
	var previous: Vector2 = deer.position
	deer.position = deer.position.move_toward(companion_target, delta * 219)
	var stride: Vector2 = deer.position - previous
	var direction: float = signf(stride.x) if absf(stride.x) > .08 else signf(hero.position.x - deer.position.x)
	deer.set_locomotion(stride.length() / maxf(.001, delta * 219), direction)
	deer.scale = Vector2.ONE * remap(deer.position.y, hero.walk_area.position.y, hero.walk_area.end.y, .71, .95)
	deer.z_index = 48 if deer.position.y > hero.position.y else 0
	if not reduced_motion: elapsed += delta
	if not reduced_motion or not pending_id.is_empty(): queue_redraw()

func _apply_motion_setting() -> void:
	hero.reduced_motion = reduced_motion
	deer.set_reduced_motion(reduced_motion)
	tracks.set_reduced_motion(reduced_motion)
	accents.set_reduced_motion(reduced_motion)

func _footfall(side: int, actor: Node2D) -> void:
	var anchor := "left_foot" if side == 0 else "right_foot"
	var point: Vector2 = tracks.to_local(actor.to_global(actor.anchor_point(anchor)))
	tracks.step(point, side, actor.heading, _terrain, actor == deer)
	step_sound.emit(_terrain,actor == deer,side)

func _accent(action: String, actor: Node2D) -> void:
	var point: Vector2 = accents.to_local(actor.to_global(actor.anchor_point(actor.cue_anchor(action))))
	accents.accent(action, point, actor.heading)
	companion_sound.emit(action)

func set_covered(value: bool) -> void:
	_covered = value
	_refresh_activity()

func _refresh_activity() -> void:
	var active := not _covered and not _paused and not _unfocused and is_visible_in_tree()
	if not active: cancel_input()
	set_process_input(active)
	set_process_unhandled_input(active)
	set_physics_process(active)
	hero.set_physics_process(active)
	for node in [hero.rig, deer, tracks, accents]: node.set_active(active)

func approach(id: String, destination: Vector2) -> void:
	hero.cancel_movement()
	pending_id = id
	pending_target = destination
	hero.walk_to(destination)
	queue_redraw()

func _set_walking(active: bool) -> void:
	if active != walking:
		walking = active
		walking_changed.emit(active)

func set_move_direction(value: Vector2) -> void:
	if not value.is_zero_approx(): pending_id = ""
	hero.direction = value
	hero.following_target = false

func set_joystick_active(active: bool) -> void:
	joystick_active = active
	if active: pending_id = ""
	hero.cancel_movement()

func _actor_at(screen_point: Vector2) -> Node2D:
	# Bodies are generous touch targets. The nearer silhouette gets the first hit.
	var ordered: Array = [hero.rig, deer] if deer.z_index <= hero.z_index else [deer, hero.rig]
	for actor: Node2D in ordered:
		var at := actor.get_global_transform_with_canvas().affine_inverse() * screen_point
		var bounds := Rect2(-55, -260, 112, 249) if actor == hero.rig else Rect2(-67, -166, 139, 153)
		if bounds.has_point(at) or at.distance_to(actor.anchor_point("face")) < 32: return actor
	return null

func _press(point: Vector2) -> void:
	pending_id = ""
	_press_position = point
	_tapped_actor = _actor_at(point)
	if _tapped_actor:
		hero.cancel_movement()
	else:
		hero.walk_to(get_global_transform_with_canvas().affine_inverse() * point)

func _release(point: Vector2, canceled: bool) -> void:
	if canceled: hero.cancel_movement()
	elif is_instance_valid(_tapped_actor) and point.distance_to(_press_position) < 23 and _actor_at(point) == _tapped_actor:
		_tapped_actor.perform("greet" if _tapped_actor == hero.rig else "listen")
	_tapped_actor = null

func _input(event: InputEvent) -> void:
	# A finger that starts on the landscape can finish over a HUD button.
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch and not event.pressed and event.index == primary_touch:
		primary_touch = -1
		_release(event.position,event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mouse_held:
		mouse_held = false
		_release(event.position,event.canceled)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventKey and not event.pressed:
		hero.direction = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	elif event is InputEventScreenTouch:
		if event.pressed and primary_touch == -1 and not joystick_active:
			primary_touch = event.index
			_press(event.position)
		elif event.index == primary_touch and not event.pressed:
			primary_touch = -1
			_release(event.position,event.canceled)
	elif event is InputEventScreenDrag and event.index == primary_touch and event.position.distance_to(_press_position) >= 23:
		_tapped_actor = null
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not joystick_active and not mouse_held:
			mouse_held = true
			_press(event.position)
		elif not event.pressed and mouse_held:
			mouse_held = false
			_release(event.position,event.canceled)
	elif event is InputEventMouseMotion and mouse_held and event.position.distance_to(_press_position) >= 23:
		_tapped_actor = null

func cancel_input() -> void:
	_tapped_actor = null
	primary_touch = -1
	mouse_held = false
	joystick_active = false
	pending_id = ""
	_set_walking(false)
	hero.cancel_movement()
	queue_redraw()

func mark_observed(id: String) -> void:
	if id not in visited: visited.append(id)
	var button := find_child("Observe_" + id, true, false)
	if button: button.mark_observed()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: _paused = true
		NOTIFICATION_APPLICATION_RESUMED: _paused = false
		NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
		_: return
	if is_node_ready(): _refresh_activity()

func _draw() -> void:
	if not pending_id.is_empty():
		var path := pending_target - hero.position
		var steps := maxi(1, floori(path.length() / 38))
		for step in range(1, steps):
			var foot := hero.position.lerp(pending_target, float(step) / steps)
			foot.y += 4 if step % 2 else -4
			draw_set_transform(foot, path.angle(), Vector2(1, .5))
			draw_circle(Vector2.ZERO, 6, Color("ffe5a0c4"), true, -1, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_arc(pending_target, 11, 0, TAU, 30, GameTheme.GOLD, 2.5, true)
	for i in range(34):
		var point := Vector2(fposmod(i * 137.2 + sin(elapsed * .4 + i) * 16, 1920), 180 + fposmod(i * 97.2 - elapsed * 9, 460))
		draw_circle(point, 1.5 + i % 3, Color(1, .84, .47, .28))
