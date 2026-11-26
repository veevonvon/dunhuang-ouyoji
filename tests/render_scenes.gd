extends SceneTree

var app: Node
var output := "res://test-results/screenshots-4.1"

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	for frame in range(8): await process_frame
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output.path_join(filename + ".png"))
	if error != OK:
		printerr("Screenshot failed: ", filename, ":", error)
		quit(1)
	print("CAPTURE: ", filename)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var data: Dictionary = root.get_node("Library").data
	var journey: Node = root.get_node("Journey")
	journey.save_path = "user://qa-render-%d.json" % OS.get_process_id()
	journey.progress = journey.normalize({})
	journey.progress.settings.sound = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await capture("home")
	app.show_map()
	await capture("map")
	app.show_world("wuwei")
	await capture("wuwei")
	app.open_story()
	await capture("story")
	app.close_dialog()
	app.show_trail("wuwei", "world")
	await capture("trail")
	var board: Control = app.screen.board
	for index in [0, 2, 4, 5, 7]:
		var point: Vector2 = board.get_global_transform_with_canvas() * board.region_rect(index).get_center()
		for pressed: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.position = point
			touch.index = 0
			touch.pressed = pressed
			root.push_input(touch, true)
	await capture("seal-earned")
	app.show_album("world", "wuwei")
	await capture("album")
	app.show_world("zhangye")
	await capture("zhangye")
	app.show_camp()
	await capture("camp")
	journey.place_decoration("cushion", "one")
	journey.place_decoration("tea", "two")
	journey.place_decoration("flag", "three")
	journey.place_decoration("books", "four")
	journey.place_decoration("plant", "five")
	journey.place_decoration("stone", "six")
	app.show_camp(1)
	await capture("camp-decorated")
	app.show_composer()
	await capture("composer")
	app.show_book("games")
	await capture("games")
	app.show_book("facts")
	await capture("facts")
	app.show_book("history")
	await capture("history")
	app.show_settings()
	await capture("settings")
	app.show_preferences()
	await capture("preferences")
	app.show_game("pack")
	await capture("play-pack")
	var all_progress := {"version": 2, "completed": [], "journey": {"started": true, "conversations": [], "encounters": [], "claimed": [], "choices": {}}, "camp": {"accepted": ["seeds", "melody", "colors"], "delivered": ["seeds", "melody", "colors"]}}
	for activity: Dictionary in data.activities: all_progress.completed.append(activity.id)
	for chapter: Dictionary in data.chapters:
		all_progress.journey.conversations.append(chapter.id)
		all_progress.journey.claimed.append(chapter.id)
	for point: Dictionary in data.encounters: all_progress.journey.encounters.append(point.id)
	journey.progress = journey.normalize(all_progress)
	journey.progress.settings.sound = false
	for stage: Dictionary in data.stages: journey.collect_seal(str(stage.id))
	app.show_album("home", "dunhuang")
	await capture("album-complete")
	app.show_camp(2)
	await capture("camp-long-labels")
	app.show_ending()
	await capture("ending")
	for size_value in [Vector2i(1560,720), Vector2i(1024,768)]:
		root.size = size_value
		app.show_home()
		await capture("home-%d" % size_value.x)
		app.show_map()
		await capture("map-%d" % size_value.x)
		app.show_world("wuwei")
		await capture("world-%d" % size_value.x)
		app.show_album("map", "jiayuguan")
		await capture("album-%d" % size_value.x)
	app.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(journey.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(journey.save_path + ".bak"))
	quit()
