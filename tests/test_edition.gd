extends SceneTree

var checks := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed += 1
		printerr("FAIL: ", message)

func touch_region(board: Control, index: int) -> void:
	var center: Vector2 = board.get_global_transform_with_canvas() * board.region_rect(index).get_center()
	for pressed: bool in [true, false]:
		var tap := InputEventScreenTouch.new()
		tap.position = center
		tap.index = 0
		tap.pressed = pressed
		root.push_input(tap, true)

func run() -> void:
	var save: Node = root.get_node("Journey")
	var folder := "user://qa-edition-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	save.save_path = folder.path_join("travel.json")
	save.progress = save.normalize({})
	save.set_setting("sound", false)
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.has_method("show_album") and app.has_method("show_trail"), "the game has working field and album entrances")
	if app.has_method("show_album") and app.has_method("show_trail"):
		var entry := app.screen.find_child("OpenAlbum", true, false) as Button
		check(is_instance_valid(entry), "home offers a directly reachable seal album")
		if entry: entry.pressed.emit()
		await process_frame
		check(app.view == "album", "using the home entrance mounts the album")
		var all_song := app.screen.find_child("PlaySealSong", true, false) as Button
		check(is_instance_valid(all_song) and all_song.disabled, "full ensemble waits for all six stations")
		app.show_trail("zhangye", "album")
		await process_frame
		check(app.view == "trail" and app.stage_id == "zhangye", "album launches the selected station mechanism")
		app.go_back()
		await process_frame
		check(app.view == "album", "Back from a trail returns to its originating album")
		app.go_back()
		await process_frame
		check(app.view == "home", "album remembers the home entrance")
		app.show_world("wuwei")
		await process_frame
		var marker := app.world.find_child("Observe_wuwei-camel", true, false) as Button
		check(is_instance_valid(marker), "world has the camel track landmark")
		if marker: marker.pressed.emit()
		check(app.world.pending_id == "wuwei-camel", "the guide marks a walking destination at the actual landmark")
		for tick in range(220):
			if app.view != "world": break
			await physics_frame
		check(app.view == "trail" and "wuwei" not in save.progress.journey.trailSeals, "the landmark opens a playable puzzle before awarding anything")
		var old_screen: Control = app.screen
		app.go_back()
		if old_screen.has_signal("solved"): old_screen.emit_signal("solved", "wuwei")
		await process_frame
		check(app.view == "world" and "wuwei" not in save.progress.journey.trailSeals, "a departed puzzle cannot award a late seal")
		app.show_trail("wuwei", "world")
		await process_frame
		await process_frame
		for index in [0, 2, 4, 5, 7]: touch_region(app.screen.board, index)
		check(is_instance_valid(app.modal) and save.progress.journey.trailSeals == ["wuwei"], "five actual hoofprint taps grant exactly one seal and open the illustrated reward")
		if is_instance_valid(app.modal):
			check(app.modal.heading == "拓得驼铃纹" and app.modal.illustration != null, "the newly earned seal has its own artwork and title")
			var open_album := app.modal.find_child("Choice_album", true, false) as Button
			open_album.pressed.emit()
			await process_frame
			check(app.view == "album" and not app.screen.listen.disabled and not app.modal, "the reward opens the exact collected page for listening")
			app.go_back()
			await process_frame
		check(app.view == "world" and app.stage_id == "wuwei", "album opened from an award remembers the original station")
		for item: Dictionary in root.get_node("Library").all("stages"): save.collect_seal(str(item.id))
		app.show_album("world", "wuwei")
		await process_frame
		var song := app.screen.find_child("PlaySealSong", true, false) as Button
		check(is_instance_valid(song) and not song.disabled, "six seals unlock the ensemble")
		save.set_setting("sound", true)
		song.pressed.emit()
		check(song.disabled and song.text == "六纹合奏中" and app.audio.is_seal_song_playing(), "the album locks replay while its real ensemble is playing")
		app.audio.ensemble.seek(app.audio.ensemble.stream.get_length() - .18)
		await create_timer(.6).timeout
		check(not song.disabled and song.text == "听六纹合奏", "the album restores replay when the last note ends")
		app.go_back()
		await process_frame
		check(app.view == "world" and app.stage_id == "wuwei", "returning from the album restores the original world")
	app.queue_free()
	await create_timer(.35).timeout
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("EDITION_CHECKS: %d; FAILURES: %d" % [checks, failed])
	quit(1 if failed else 0)
