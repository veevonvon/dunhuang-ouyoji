extends Node2D

const Tracks := preload("res://scripts/characters/effects_footprints.gd")
const Gestures := preload("res://scripts/characters/effects_accents.gd")
const TRACK_LIMIT := 16
const ACCENT_LIMIT := 4
const GROUND_TIME := {"sand": 1.42, "stone": 1.02, "grass": 1.18}
const ACTION_TIME := {
	"greet": 0.85, "look": 0.92, "think": 1.16, "listen": 1.04,
	"surprise": 0.78, "celebrate": 1.22, "draw": 1.18, "rest": 1.20,
}

class Mark:
	var kind: String
	var at: Vector2
	var heading: float
	var duration: float
	var age := 0.0
	var side := 0
	var animal := false

	func _init(id: String, point: Vector2, direction: float, lifetime: float) -> void:
		kind = id
		at = point
		heading = -1.0 if direction < 0.0 else 1.0
		duration = lifetime

var _tracks: Array[Mark] = []
var _accents: Array[Mark] = []
var _active := true
var _reduced := false
var _unfocused := false
var _background := false

func _ready() -> void:
	set_process(not (_tracks.is_empty() and _accents.is_empty()))

func step(at: Vector2, side: int, heading: float, terrain: String, animal := false) -> void:
	if not _can_emit():
		return
	var ground := terrain if GROUND_TIME.has(terrain) else "sand"
	var mark := Mark.new(ground, at, heading, GROUND_TIME[ground])
	mark.side = side
	mark.animal = animal
	_add_mark(_tracks, mark, TRACK_LIMIT)

func accent(action: String, at: Vector2, heading := 1.0) -> void:
	if not _can_emit() or not ACTION_TIME.has(action):
		return
	_add_mark(_accents, Mark.new(action, at, heading, ACTION_TIME[action]), ACCENT_LIMIT)

func set_reduced_motion(value: bool) -> void:
	_reduced = value
	if value:
		_clear_marks()

func set_active(value: bool) -> void:
	_active = value
	if not value:
		_clear_marks()

func _can_emit() -> bool:
	return _active and not _reduced and not _unfocused and not _background and is_inside_tree() and is_visible_in_tree() and can_process()

func _add_mark(marks: Array[Mark], mark: Mark, limit: int) -> void:
	if marks.size() >= limit:
		marks.pop_front()
	marks.append(mark)
	set_process(true)
	queue_redraw()

func _clear_marks() -> void:
	_tracks.clear()
	_accents.clear()
	set_process(false)
	if is_inside_tree():
		queue_redraw()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_background = true
			_clear_marks()
		NOTIFICATION_APPLICATION_RESUMED:
			_background = false
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_unfocused = true
			_clear_marks()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_unfocused = false
		NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			_clear_marks()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_clear_marks()

func _process(delta: float) -> void:
	for marks: Array[Mark] in [_tracks, _accents]:
		for i in range(marks.size() - 1, -1, -1):
			var mark := marks[i]
			mark.age += delta
			if mark.age >= mark.duration:
				marks.remove_at(i)
	if _tracks.is_empty() and _accents.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for mark in _tracks:
		Tracks.paint(self, mark.at, mark.side, mark.heading, mark.kind, mark.animal, mark.age, mark.duration)
	for mark in _accents:
		Gestures.paint(self, mark.at, mark.heading, mark.kind, mark.age / mark.duration)
	draw_set_transform(Vector2.ZERO)
