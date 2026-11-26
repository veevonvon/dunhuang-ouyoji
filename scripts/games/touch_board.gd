extends Control

signal action_requested(action: Dictionary)

const Rules = preload("res://scripts/games/game_rules.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
const INK := Color("24474a")
const PAPER := Color("f3e3bd")
const GOLD := Color("d5a453")
const TEAL := Color("377d79")
const RUST := Color("bc7256")
const THREAD_COLORS := {"red": Color("bc7256"), "teal": Color("377d79"), "gold": Color("d5a453")}

var session: RefCounted
var content: Dictionary = {}
var active_pointer := -999
var pointer_position := Vector2.ZERO
var origin: Dictionary = {}
var pending: Array[Dictionary] = []
var moved := false
var keyboard_index := 0
var _ignore_mouse_until := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_pointer()
	)

func configure(game_session: RefCounted, game_content: Dictionary) -> void:
	session = game_session
	content = game_content

func interaction_regions() -> Array[Dictionary]:
	return []

func region(rect: Rect2, action: Dictionary, role := "tap", label := "") -> Dictionary:
	return {"rect": rect, "action": action, "role": role, "label": label}

func hit(point: Vector2) -> Dictionary:
	var regions := interaction_regions()
	for i in range(regions.size() - 1, -1, -1):
		if regions[i].rect.has_point(point): return regions[i]
	return {}

func pointer_event(pointer: int, phase: String, point: Vector2) -> void:
	if phase == "press":
		if active_pointer != -999: return
		var target := hit(point)
		if target.is_empty(): return
		active_pointer = pointer
		origin = target
		pointer_position = point
		pending = [target]
		moved = false
		grab_focus()
		queue_redraw()
		return
	if pointer != active_pointer: return
	if phase == "cancel":
		cancel_pointer()
		return
	if phase == "move":
		if point.distance_to(pointer_position) > 5: moved = true
		if origin.get("role", "") == "stroke":
			# Sampling the segment keeps a fast stroke from skipping a narrow tile.
			var count := maxi(1, int(pointer_position.distance_to(point) / 8.0))
			for i in range(1, count + 1):
				var crossed := hit(pointer_position.lerp(point, float(i) / count))
				if crossed.get("role", "") == "stroke" and (pending.is_empty() or crossed.action != pending.back().action):
					pending.append(crossed)
		pointer_position = point
		queue_redraw()
		return
	if phase != "release": return
	if point != pointer_position:
		pointer_event(pointer, "move", point)
	var source := origin.duplicate(true)
	var destination := hit(point)
	var stroke := pending.duplicate(true)
	var was_moved := moved
	cancel_pointer()
	if destination.is_empty(): return
	var kind: String = session.state.kind
	if source.get("role", "") == "stroke":
		for item in stroke: action_requested.emit(item.action)
	elif kind == "mural" and source.role == "piece" and destination.role == "target":
		action_requested.emit({"type": "drop", "piece": source.action.index, "target": destination.action.index})
	elif kind == "history" and was_moved and destination.role == "story":
		action_requested.emit({"type": "swap", "from": source.action.index, "to": destination.action.index})
	elif kind == "pack" and source.role == "cargo_item" and destination.role == "cargo":
		action_requested.emit(source.action)
	elif kind == "trade" and source.role == "weight" and destination.role == "balance":
		action_requested.emit(source.action)
	elif source.action == destination.action and not ["cargo", "balance"].has(source.role):
		action_requested.emit(source.action)

func cancel_pointer() -> void:
	active_pointer = -999
	origin = {}
	pending.clear()
	moved = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_ignore_mouse_until = Time.get_ticks_msec() + 500
		pointer_event(event.index, "cancel" if event.canceled else "press", event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Time.get_ticks_msec() >= _ignore_mouse_until and event.device != InputEvent.DEVICE_ID_EMULATION:
			pointer_event(-1, "press", event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		var regions := interaction_regions()
		if regions.is_empty(): return
		if event.keycode in [KEY_RIGHT, KEY_DOWN]: keyboard_index = (keyboard_index + 1) % regions.size()
		elif event.keycode in [KEY_LEFT, KEY_UP]: keyboard_index = posmod(keyboard_index - 1, regions.size())
		elif event.keycode in [KEY_ENTER, KEY_SPACE]: action_requested.emit(regions[keyboard_index % regions.size()].action)
		else: return
		queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if active_pointer == -999: return
	if event is InputEventScreenTouch and not event.pressed and event.index == active_pointer:
		pointer_event(event.index, "cancel" if event.canceled else "release", get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == active_pointer:
		pointer_event(event.index, "move", get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and active_pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pointer_event(-1, "release", get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active_pointer == -1:
		pointer_event(-1, "move", get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		cancel_pointer()

static var _card_skins: Dictionary[Color, StyleBox] = {}

func box(rect: Rect2, color := PAPER, selected := false) -> void:
	if not _card_skins.has(color):
		_card_skins[color] = Ui.surface(color.lightened(0.14), color.darkened(0.065), Color("b28c55"))
	draw_style_box(_card_skins[color], rect)
	if selected:
		draw_rect(rect.grow(-6), Color(TEAL, 0.65), false, 2, true)

func caption(value: String, point: Vector2, font_size := 24, color := INK, width := -1.0, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := get_theme_default_font()
	var measured: float = font.get_string_size(value, alignment, -1, font_size).x
	var draw_width: float = measured if width < 0 else width
	var left: float = point.x - draw_width / 2 if alignment == HORIZONTAL_ALIGNMENT_CENTER else point.x
	draw_string(font, Vector2(left, point.y), value, alignment, draw_width, font_size, color)

func lines(value: String, rect: Rect2, font_size := 22, color := INK) -> void:
	draw_multiline_string(get_theme_default_font(), rect.position + Vector2(0, font_size), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, -1, color)

func draw_interaction_feedback() -> void:
	if has_focus() and active_pointer == -999:
		var regions := interaction_regions()
		if not regions.is_empty():
			draw_rect(regions[keyboard_index % regions.size()].rect.grow(3), Color(0.2, 0.48, 0.47, 0.55), false, 3)
	if active_pointer != -999:
		if origin.get("role", "") == "stroke":
			for item in pending:
				draw_rect(item.rect.grow(-3), Color(1, 0.83, 0.35, 0.6), false, 4)
		else:
			draw_circle(pointer_position, 28, Color(1, 0.83, 0.35, 0.25))
			draw_arc(pointer_position, 30, 0, TAU, 36, GOLD, 3, true)

const PROP_NAMES := ["camel", "water", "grain", "scroll", "silk", "grape", "pipa", "ball", "phone", "leaf", "drop", "lotus", "sun", "star", "sapling"]
static var _illustrations: Dictionary[String, Texture2D] = {}

func illustration(name: String, center: Vector2, extent: float, tint := Color.WHITE) -> void:
	if not _illustrations.has(name):
		_illustrations[name] = load("res://assets/edition/props/%s.webp" % name)
	draw_texture_rect(_illustrations[name], Rect2(center - Vector2.ONE * extent / 2, Vector2.ONE * extent), false, tint)

func symbol(name: String, center: Vector2, extent: float, color := TEAL) -> void:
	if name in PROP_NAMES:
		illustration(name, center, extent)
		return
	draw_set_transform(center, 0, Vector2.ONE * extent / 40.0)
	match name:
		"mountain":
			draw_colored_polygon(PackedVector2Array([Vector2(-21, 17), Vector2(-6, -18), Vector2(6, 2), Vector2(13, -8), Vector2(24, 17)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -6), Vector2(-6, -18), Vector2(2, -6), Vector2(-5, -9)]), PAPER)
		"gate":
			draw_texture_rect(preload("res://assets/edition/seals/jiayuguan.webp"), Rect2(-20, -20, 40, 40), false)
		"check": draw_polyline(PackedVector2Array([Vector2(-14, 0), Vector2(-3, 12), Vector2(17, -13)]), color, 4, true)
	draw_set_transform(Vector2.ZERO)
