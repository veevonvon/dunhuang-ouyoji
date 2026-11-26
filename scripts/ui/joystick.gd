extends Control

signal moved(direction: Vector2)
signal engaged(active: bool)
var finger := -1
var knob := Vector2.ZERO
var mouse_down := false

func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			engaged.emit(true)
			update_knob(event.position)
		elif not event.pressed and event.index == finger:
			cancel()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == finger: update_knob(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if finger != -1: return
		mouse_down = event.pressed
		if mouse_down:
			engaged.emit(true)
			update_knob(event.position)
		else: cancel()
		accept_event()
	elif event is InputEventMouseMotion and mouse_down:
		update_knob(event.position)
		accept_event()

func update_knob(point: Vector2) -> void:
	knob = ((point - size / 2.0) / 62.0).limit_length()
	moved.emit(knob)
	queue_redraw()

func cancel() -> void:
	finger = -1
	mouse_down = false
	knob = Vector2.ZERO
	engaged.emit(false)
	moved.emit(knob)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel()

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, 74, Color("123c4566"))
	draw_arc(center, 73, 0, TAU, 64, Color("e4b96d99"), 2, true)
	draw_arc(center, 62, 0, TAU, 64, Color("e4b96d33"), 1, true)
	for i in range(4):
		var axis := Vector2.from_angle(i * PI / 2)
		draw_line(center + axis * 52, center + axis * 61, Color("e4b96d99"), 3, true)
	draw_circle(center + knob * 49, 31, Color("f1dba9bb"))
	draw_arc(center + knob * 49, 30, 0, TAU, 48, Color("fff0c9"), 2, true)
