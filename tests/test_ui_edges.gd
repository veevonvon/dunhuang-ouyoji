extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func touch(index: int, down: bool, point: Vector2, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.position = point
	event.canceled = canceled
	Input.parse_input_event(event)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var journey: Node = root.get_node("Journey")
	var folder := "user://qa-ui-edges-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	journey.save_path = folder.path_join("progress.json")
	journey.progress = journey.normalize({})
	journey.set_setting("sound", false)
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(not quit_on_go_back, "Android Back is handled by game navigation")
	app.show_album("home")
	var launch: Button = app.screen.solve
	launch.grab_focus()
	app.show_settings()
	await process_frame
	var focused := root.gui_get_focus_owner()
	check(focused != null and app.modal.is_ancestor_of(focused), "a dialog takes keyboard and controller focus")
	check(launch.get_focus_mode_with_override() == Control.FOCUS_NONE, "the covered puzzle shortcut cannot accept controller confirmation")
	app.close_dialog()
	check(launch.has_focus(), "closing a dialog restores the original control")
	app.show_world("wuwei")
	await process_frame
	await process_frame
	var stick: Control = app.screen.joystick
	var point: Vector2 = stick.get_global_transform_with_canvas() * (stick.size / 2 + Vector2(50, 0))
	touch(0, true, point)
	await process_frame
	check(app.world.hero.direction.x > .5, "primary finger controls walking")
	touch(1, true, Vector2(900, 400))
	await process_frame
	check(not app.world.hero.following_target, "second finger cannot replace joystick with tap target")
	touch(1, false, Vector2(900, 400))
	touch(0, false, Vector2(1000, 300), true)
	await process_frame
	check(stick.finger == -1 and app.world.hero.direction == Vector2.ZERO, "release outside joystick clears captured input")
	check(not app.world.hero.following_target, "released joystick leaves no walking target")
	app.open_story()
	await process_frame
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	check(app.modal == null and app.view == "world", "Back request closes only the top dialog")
	app.show_game("music")
	await process_frame
	app.screen.board.pointer_event(4, "press", app.screen.board.interaction_regions()[0].rect.get_center())
	app.screen.perform({"type": "listen"})
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.screen.session.state.play_at < 0, "Android pause cancels a music demonstration")
	check(app.screen.board.active_pointer == -999, "Android pause releases a held game gesture")
	app.show_game("pack")
	await process_frame
	DirAccess.make_dir_absolute(journey.save_path + ".tmp")
	for id in ["water", "grain", "silk", "scroll"]:
		app.screen.perform({"type": "item", "id": id})
	await process_frame
	check(not journey.last_error.is_empty(), "write failure is reproduced")
	check("pack" in journey.progress.completed, "unsaved reward stays exportable in memory")
	var notice: Variant = app.get("save_warning")
	check(is_instance_valid(notice) and notice.visible, "save failure stays visible after reward toast")
	app.show_home()
	await process_frame
	app.go_back()
	await process_frame
	check("没有保存" in app.modal.body, "exit prompt tells player about unsaved progress")
	check("force_quit" in str(app.modal.choices), "failed save requires an explicit exit choice")
	app.close_dialog()
	DirAccess.remove_absolute(journey.save_path + ".tmp")
	app.show_save_menu()
	app.modal.chosen.emit("retry")
	await process_frame
	check(journey.last_error.is_empty(), "retry saves the in-memory reward")
	if is_instance_valid(notice): check(not notice.visible, "successful retry clears persistent warning")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(journey.save_path))
	check("pack" in saved.completed, "retried reward is present on disk")
	app.queue_free()
	await create_timer(.3).timeout
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("UI_EDGE_CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
