extends SceneTree

const IDS := ["wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang"]
const TITLES := ["沙上驼踪", "一束泉光", "藤间寻露", "点亮关楼", "合弦琵琶", "月下莲影"]
const ROUTES := {"wuwei": [0, 2, 4, 5, 7], "jiuquan": [0, 1, 3, 6, 7, 8]}
const SIZES := [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]
var checks := 0
var failures := 0
var awards: Array[String] = []
var cues: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func move(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)

func mark(board: Control, i: int) -> Vector2:
	return board.get_global_transform_with_canvas() * board.region_rect(i).get_center()

func tap(board: Control, i: int) -> void:
	var point := mark(board, i)
	touch(0, point, true)
	touch(0, point, false)

func capture(name: String) -> void:
	if "--capture-trails" not in OS.get_cmdline_user_args(): return
	var folder := "res://test-results/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(folder.path_join("trail-" + name + ".png")) == OK, "save screenshot " + name)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog: Variant = load("res://scripts/trails/trail_catalog.gd")
	var view_script: Variant = load("res://scripts/trails/trail_view.gd")
	check(catalog != null and view_script != null, "native trail view and catalog exist")
	if failures:
		quit(1)
		return
	for n in IDS.size():
		var id: String = IDS[n]
		var info: Dictionary = catalog.get_trail(id)
		check(info.title == TITLES[n] and not info.brief.is_empty(), id + " child-facing title and clue")
		var encounter: Dictionary = root.get_node("Library").by_id("encounters", info.encounter)
		check(not encounter.is_empty() and str(encounter.id).begins_with(id + "-"), id + " local discovery")
		for drag_mode: bool in [false, true]:
			root.size = SIZES[n % SIZES.size()] if drag_mode else SIZES[0]
			var view: Control = view_script.new()
			view.configure(id, not drag_mode)
			root.add_child(view)
			view.solved.connect(func(stage: String): awards.append(stage))
			view.sound_requested.connect(func(cue: String): cues.append(cue))
			await process_frame
			await process_frame
			var station := view.find_child("Station",true,false) as Label
			check(station != null and station.get_parent().size.y <= 76, id + " keeps station name on one line")
			if not drag_mode: await capture(id)
			var board: Control = view.board
			for i in board.region_count():
				var bounds: Rect2 = board.region_rect(i)
				check(bounds.size.x >= 64 and bounds.size.y >= 64, id + " finger-sized controls")
			var start := mark(board, 0)
			touch(0, start, true)
			touch(1, mark(board, 1), true)
			touch(1, mark(board, 1), false)
			touch(0, start, false, true)
			check(not board.can_undo(), id + " secondary finger and cancel preserve state")
			touch(0, start, true)
			view.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			touch(0, start, false)
			check(not board.can_undo(), id + " release after pause is inert")
			touch(0, start, true)
			move(0, Vector2(-25,-25))
			touch(0, Vector2(-25,-25), false)
			check(not board.can_undo(), id + " releasing outside abandons gesture")
			touch(0, start, true)
			view.hide()
			view.show()
			touch(0, start, false)
			check(not board.can_undo(), id + " hiding the view abandons gesture")
			var synthetic := InputEventMouseButton.new()
			synthetic.device = InputEvent.DEVICE_ID_EMULATION
			synthetic.button_index = MOUSE_BUTTON_LEFT
			synthetic.position = start
			synthetic.pressed = true
			root.push_input(synthetic, true)
			synthetic.pressed = false
			root.push_input(synthetic, true)
			check(not board.can_undo(), id + " synthesized mouse cannot rotate the same dial twice")
			view.show_hint()
			check(cues.back() == "hint" and not board.can_undo(), id + " hint is free")
			tap(board, 0)
			check(board.can_undo(), id + " action creates undo")
			view.undo()
			check(not board.can_undo(), id + " undo restores board")
			if info.kind == "mirror":
				tap(board, 0)
				tap(board, 0)
				check(cues.back() == "miss", id + " light redirected away gives a soft cue")
				view.undo()
				view.undo()
			elif info.kind == "register":
				while board.state.offsets[0] != 0: tap(board, 0)
				tap(board, 0)
				check(cues.back() == "miss", id + " displaced aligned drawing gives a soft cue")
				while board.can_undo(): view.undo()

			var before := awards.size()
			if info.kind == "track":
				tap(board, 7)
				check(cues.back() == "miss" and not board.can_undo(), id + " wrong branch preserves trail")
				var route: Array = ROUTES[id]
				if drag_mode:
					touch(0, mark(board, route.front()), true)
					for i in route.slice(1): move(0, mark(board, i))
					touch(0, mark(board, route.back()), false)
				else:
					for i in route: tap(board, i)
			elif info.kind == "mirror":
				for i in board.region_count():
					if drag_mode:
						var p := mark(board, i)
						touch(0, p, true)
						move(0, p + Vector2(31, 16))
						touch(0, p + Vector2(31, 16), false)
					else: tap(board, i)
			else:
				for i in 3:
					if drag_mode:
						var shift := -int(board.state.offsets[i])
						var axis := Vector2.RIGHT if id == "guazhou" else Vector2.DOWN
						var p := mark(board, i)
						touch(0, p, true)
						move(0, p + axis * shift * 52)
						touch(0, p + axis * shift * 52, false)
					else:
						for attempt in 3:
							if board.state.offsets[i] == 0: break
							tap(board, i)
			check(awards.size() == before + 1 and awards.back() == id, id + " full solve " + str(drag_mode))
			if not drag_mode and id in ["jiayuguan","dunhuang"]: await capture(id + "-solved")
			tap(board, 0)
			view.undo()
			check(awards.size() == before + 1, id + " award is idempotent")
			view.queue_free()
			await process_frame
	print("TRAIL_CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
