extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, clue: String) -> void:
	checks += 1
	if not ok:
		failures.append(clue)
		printerr("FAIL ", clue)

func touch(index: int, pressed: bool, point: Vector2, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	event.canceled = canceled
	root.push_input(event, true)

func run() -> void:
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-performance-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("progress.json")
	store.progress = store.normalize({})
	store.set_setting("sound", false)
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.has_method("show_companions"):
		printerr("camp has no playable companion performance")
		quit(1)
		return
	app.welcome()
	check(app.modal.has_node("LivePortrait") or app.modal.find_child("LivePortrait", true, false) != null, "welcome shows the real expressive boy")
	app.close_dialog()
	app.show_world("dunhuang")
	await process_frame
	await physics_frame
	var world: Node = app.world
	var rig = world.hero.rig
	check(world.accents.z_index > world.hero.z_index + 14, "front effects remain visible over the entire boy rig")
	check(rig.skeleton.get_bone_count() >= 12 and world.deer.skeleton.get_bone_count() >= 12, "both moving characters use native articulated rigs")
	var contacts: Array[int] = []
	rig.footfall.connect(func(side: int): contacts.append(side))
	var foot_points: Array[Vector2] = []
	rig.footfall.connect(func(side: int):
		var key := "left_foot" if side == 0 else "right_foot"
		foot_points.append(world.tracks.to_local(rig.to_global(rig.anchor_point(key))))
	)
	var start: Vector2 = world.hero.position
	world.set_move_direction(Vector2.RIGHT)
	for i in 58: await physics_frame
	check(world.hero.position.x > start.x + 80 and contacts.size() >= 2 and contacts[0] != contacts[1], "walking travels and strikes with alternating feet")
	check(foot_points.size() >= 2 and foot_points[0].distance_to(foot_points[1]) > 10, "foot contacts persist at distinct ground positions")
	world.cancel_input()
	var point: Vector2 = rig.get_global_transform_with_canvas() * rig.anchor_point("face")
	touch(2,true,point)
	touch(2,false,point)
	await process_frame
	check(rig.acting == "greet" and not world.hero.following_target, "a tap on the boy greets without redirecting his walk")
	var other: Vector2 = world.deer.get_global_transform_with_canvas() * world.deer.anchor_point("face")
	touch(2,true,other)
	touch(2,false,other,true)
	await process_frame
	check(world.deer.acting != "listen", "canceled deer touch is discarded")
	touch(2,true,other)
	touch(2,false,other)
	await process_frame
	check(world.deer.acting == "listen", "touching the deer makes it listen")
	app.guide()
	check(app.modal.find_child("LivePortrait",true,false) != null, "the guide speaks through the animated deer")
	check(not rig.is_processing() and not world.deer.is_processing(), "the modal parks the covered world")
	world.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.close_dialog()
	check(not rig.is_processing() and not world.hero.is_physics_processing(), "closing a dialog cannot resume a background world")
	world.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(rig.is_processing(), "returning to travel wakes the rig")
	for side: int in [1,-1]:
		world.hero.position.x = world.hero.walk_area.position.x if side == 1 else world.hero.walk_area.end.x
		world.hero.facing = side
		world.deer.position = world.hero.position
		for tick in 90: world._physics_process(1.0 / 60)
		check(world.deer.position.x >= 80 and world.deer.position.x <= 1840 and absf(world.deer.position.x-world.hero.position.x) >= 90,"the entire companion is reachable at either map edge")
	app.show_camp()
	var enter := app.screen.find_child("MeetCompanions", true, false) as Button
	check(enter != null, "camp offers the encounter")
	enter.pressed.emit()
	await process_frame
	check(app.view == "companions", "camp encounter opens")
	var before := JSON.stringify(store.progress)
	for dimensions in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1024,768)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for id in ["greet","look","think","listen","surprise","celebrate","draw","rest"]:
			var button := app.screen.find_child("Act_" + id,true,false) as Button
			check(button != null and button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect()) and button.size.y >= 60, "action fits " + id + str(dimensions))
			button.pressed.emit()
			check(app.screen.stage.boy.acting == id and app.screen.stage.deer.acting == id, "both respond to " + id)
	app.screen.start_riddle()
	var answer: String = app.screen.riddle
	app.screen.start_riddle()
	check(app.screen.riddle == answer, "guessing can replay the same silhouette")
	app.screen.choose("draw" if answer != "draw" else "rest")
	check(app.screen.riddle == answer, "another guess keeps the same clue")
	app.screen.choose(answer)
	check(app.screen.riddle.is_empty() and app.screen.stage.boy.acting == "celebrate", "correct gesture earns a visible celebration")
	check(before == JSON.stringify(store.progress), "repeating gestures never modifies the satchel")
	store.set_setting("reducedMotion",true)
	check(app.screen.stage.boy.reduced_motion and app.screen.stage.deer.reduced_motion, "live preference affects both actors")
	app.screen.choose("surprise")
	var face: Sprite2D = app.screen.stage.boy.find_child("Expression",true,false)
	check(face.frame > 0, "reduced surprise draws its expression immediately")
	app.show_settings()
	check(not app.screen.stage.boy.is_processing(), "modal parks camp gestures")
	check(app.modal.get_canvas_layer_node().layer > app.screen.get_canvas_layer_node().layer, "the whole satchel covers every colored bone and sprite")
	app.close_dialog()
	check(face.frame == 0 and app.screen.stage.boy.acting.is_empty(), "canceling a reduced gesture also clears its painted face")
	app.go_back()
	check(app.view == "camp", "Android Back leads to camp")
	store.set_setting("music",false)
	store.set_setting("sound",true)
	store.set_setting("narration",false)
	var letter: Dictionary = root.get_node("Library").all("letters")[0]
	app.show_world(letter.from)
	store.progress.journey.conversations.append(letter.from)
	app.open_letters()
	check(not app.audio.voice.playing, "a quiet letter honors automatic narration")
	app.audio.shutdown()
	app.free()
	await create_timer(.35).timeout
	DirAccess.remove_absolute(store.save_path)
	print("旅伴实机路径检查 ", checks, "，失败 ", failures.size())
	quit(0 if failures.is_empty() else 1)
