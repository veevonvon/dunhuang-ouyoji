extends Node2D

signal footfall(side: int)
signal action_cue(action: String)

const DURATIONS := {
	"greet": 1.65, "look": 1.9, "think": 2.05, "listen": 1.85,
	"surprise": 1.45, "celebrate": 1.95, "draw": 2.3, "rest": 2.4
}
const KEY_POSE := .54
var skeleton: Skeleton2D
var facing_node: Node2D
var heading := 1.0
var clock := 0.0
var gait := 0.0
var move_weight := 0.0
var acting := ""
var action_progress := 0.0
var action_weight := 0.0
var blink_amount := 0.0
var reduced_motion := false
var _anchors := {}
var _speed := 0.0
var _action_time := 0.0
var _held := false
var _cue_sent := false
var _enabled := true
var _paused := false
var _unfocused := false
var _blink_time := 0.0
var _blink_index := 0
var _next_blink := 2.8

func _ready() -> void:
	facing_node = Node2D.new()
	facing_node.name = "Facing"
	add_child(facing_node)
	facing_node.scale.x = heading
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	facing_node.add_child(skeleton)
	_next_blink += (absi(get_script().resource_path.hash()) % 93) / 80.0
	build_character()
	pose_character()
	visibility_changed.connect(_sync_activity)
	_sync_activity()

func build_character() -> void:
	pass

func pose_character() -> void:
	pass

func joint(parent: Node2D, id: String, at: Vector2, length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = id
	bone.set_autocalculate_length_and_angle(false)
	bone.length = length
	bone.position = at
	bone.rest = bone.transform
	parent.add_child(bone)
	return bone

func register_anchor(id: String, node: Node2D) -> void:
	_anchors[id] = node

func anchor_point(id: String) -> Vector2:
	var node: Node2D = _anchors.get(id)
	return to_local(node.global_position) if is_instance_valid(node) else Vector2.ZERO

func cue_anchor(action: String) -> String:
	if action == "listen": return "bell"
	if action in ["greet","draw","celebrate"]: return "hand"
	return "face"

func set_locomotion(amount: float, direction: float) -> void:
	_speed = clampf(amount, 0, 1)
	if not is_zero_approx(direction):
		heading = signf(direction)
		if facing_node: facing_node.scale.x = heading

func perform(action: String, hold := false) -> void:
	if not DURATIONS.has(action) or not _enabled or (is_node_ready() and not _can_advance()): return
	acting = action
	_held = hold
	_action_time = 0
	_cue_sent = reduced_motion
	_update_action(0)
	if is_node_ready():
		pose_character()
		_sync_activity()
		if reduced_motion: action_cue.emit(action)

func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value: return
	reduced_motion = value
	if value:
		blink_amount = 0
		move_weight = 0
		gait = 0
		_cue_sent = true
		if _held and not acting.is_empty(): _action_time = float(DURATIONS[acting]) * KEY_POSE
		_update_action(0)
	if is_node_ready():
		pose_character()
		_sync_activity()

func set_active(value: bool) -> void:
	_enabled = value
	_sync_activity()

func _can_advance() -> bool:
	return _enabled and not _paused and not _unfocused and is_inside_tree() and is_visible_in_tree() and can_process()

func _sync_activity() -> void:
	var active := _can_advance()
	set_process(active and (not reduced_motion or (not acting.is_empty() and not _held)))
	if not active:
		_speed = 0
		move_weight = 0
		gait = 0
		_cue_sent = true
		blink_amount = 0
		if not _held:
			acting = ""
			action_progress = 0
			action_weight = 0
			_action_time = 0
		if is_node_ready() and is_instance_valid(skeleton) and skeleton.is_inside_tree():
			pose_character()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: _paused = true
		NOTIFICATION_APPLICATION_RESUMED: _paused = false
		NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
		_: return
	if is_inside_tree(): _sync_activity()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _can_advance() or delta <= 0: return
	# A late frame never replays a burst of missed steps or effects.
	var dt := minf(delta, .1)
	if reduced_motion:
		if acting.is_empty() or _held: return
		_update_action(dt)
		if acting.is_empty():
			pose_character()
			set_process(false)
		return
	var contact := -1
	clock += dt
	move_weight = move_toward(move_weight, _speed, dt * 5)
	if _speed > .035:
		var next := gait + dt * TAU * 1.28 * _speed
		if floori(next / PI) != floori(gait / PI):
			contact = floori(next / PI) % 2
		gait = fposmod(next, TAU)
	elif is_zero_approx(move_weight):
		gait = 0
	_blink_time += dt
	blink_amount = maxf(0, 1 - absf(_blink_time - _next_blink) / .105)
	if _blink_time > _next_blink + .105:
		_blink_time = 0
		_blink_index += 1
		_next_blink = 2.7 + fposmod(_blink_index * 1.17, 2.15)
	var cue := _update_action(dt)
	pose_character()
	if contact >= 0: footfall.emit(contact)
	if cue: action_cue.emit(acting)

func _update_action(delta: float) -> bool:
	if acting.is_empty(): return false
	var duration := float(DURATIONS[acting])
	_action_time += delta
	var progress := _action_time / duration
	if _held:
		progress = minf(progress, KEY_POSE)
		_action_time = progress * duration
	if progress >= 1:
		acting = ""
		action_weight = 0
		action_progress = 0
		return false
	action_progress = KEY_POSE if reduced_motion else progress
	action_weight = 1.0 if reduced_motion else smoothstep(0, .20, progress) * (1.0 - smoothstep(.76, 1.0, progress))
	if not _cue_sent and progress >= .38:
		_cue_sent = true
		return true
	return false
