extends "res://scripts/trails/trail_canvas.gd"

signal changed(cue: String)
signal complete

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_gesture()
	)
	set_process(false)

func can_undo() -> bool:
	return not state.done and not state.history.is_empty()

func apply(index: int, shift := 1) -> String:
	if state.info.kind == "register": from_offset = state.offsets[index]
	var cue: String = state.act(index,shift)
	if cue.is_empty(): return cue
	if cue == "miss": ripple = 0.0
	if cue == "step" and not reduced_motion:
		rippled = index
		ripple = 1.0
		set_process(true)
	queue_redraw()
	changed.emit(cue)
	if state.done: complete.emit()
	return cue

func _process(delta: float) -> void:
	ripple = maxf(0.0,ripple-delta*2.2)
	queue_redraw()
	if ripple == 0: set_process(false)

func cancel_gesture() -> void:
	pointer = -99
	origin = -1
	pending.clear()
	queue_redraw()

func begin(finger: int, p: Vector2) -> void:
	if pointer != -99 or state.done: return
	origin = hit(p)
	if origin < 0: return
	pointer = finger
	pressed_at = p
	fingertip = p
	if state.info.kind == "track": pending.append(origin)
	keyboard_focus = false
	grab_focus()
	queue_redraw()

func advance(p: Vector2) -> void:
	if state.info.kind == "track":
		var segments := maxi(1,ceili(p.distance_to(fingertip)/10))
		for n in range(1,segments+1):
			var index := hit(fingertip.lerp(p,n/float(segments)))
			if index >= 0 and pending.back() != index: pending.append(index)
	fingertip = p
	queue_redraw()

func finish(p: Vector2) -> void:
	advance(p)
	var index := origin
	var stroke := pending.duplicate()
	var diff := local_point(p) - local_point(pressed_at)
	var target := hit(p)
	cancel_gesture()
	if not Rect2(Vector2.ZERO,size).has_point(p): return
	match state.info.kind:
		"track":
			if target < 0: return
			for item: int in stroke:
				if apply(item) == "miss" or state.done: break
		"mirror":
			if target == index or (diff.length() >= 20 and diff.length() <= 115): apply(index)
		"register":
			var axis := diff.x if state.id == "guazhou" else diff.y
			if absf(axis) >= 20: apply(index,signi(int(axis)))
			elif target == index and diff.length() < 25: apply(index)

func _gui_input(event: InputEvent) -> void:
	if state.done: return
	if event is InputEventScreenTouch and event.pressed and not event.canceled and event.device != InputEvent.DEVICE_ID_EMULATION:
		begin(event.index,event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		begin(-1,event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		keyboard_focus = true
		match event.keycode:
			KEY_RIGHT, KEY_DOWN: focus_index = (focus_index+1)%region_count()
			KEY_LEFT, KEY_UP: focus_index = posmod(focus_index-1,region_count())
			KEY_ENTER, KEY_SPACE: apply(focus_index)
			_: return
		queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if pointer == -99: return
	if event is InputEventScreenTouch and event.index == pointer and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.canceled: cancel_gesture()
		elif not event.pressed: finish(get_global_transform_with_canvas().affine_inverse()*event.position)
		else: return
	elif event is InputEventScreenDrag and event.index == pointer and event.device != InputEvent.DEVICE_ID_EMULATION:
		advance(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseButton and pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		finish(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseMotion and pointer == -1 and event.device != InputEvent.DEVICE_ID_EMULATION:
		advance(get_global_transform_with_canvas().affine_inverse()*event.position)
	else: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		cancel_gesture()
