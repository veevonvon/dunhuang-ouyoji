extends SceneTree

var app: Node
var output := "res://test-results/landmarks-4.2"
var failed := false
const Landmarks := preload("res://scripts/landmarks/catalog.gd")
const Scenery := preload("res://scripts/landmarks/scenery.gd")

func _initialize() -> void:
	call_deferred("run")

func capture(id: String) -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	var picture := root.get_texture().get_image()
	if picture.save_png(output.path_join(id + ".png")) != OK: failed = true
	print("FIELD_CAPTURE: ",id)

func compare_skies(site_id: String) -> void:
	root.size = Vector2i(1280,720)
	var spread := Control.new()
	root.add_child(spread)
	spread.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var site := Landmarks.lookup(site_id)
	for i in 4:
		var tile := Control.new()
		tile.clip_contents = true
		tile.position = Vector2((i % 2) * 640, floori(i / 2.0) * 360)
		tile.size = Vector2(640,360)
		spread.add_child(tile)
		var landscape := Scenery.new()
		landscape.configure(site,Landmarks.SEASONS[i],Landmarks.PHASES[i],true)
		landscape.set_hotspots_visible(false)
		tile.add_child(landscape)
		var ink := ColorRect.new()
		ink.color = Color("103238dd")
		ink.position = Vector2(14,14)
		ink.size = Vector2(153,43)
		tile.add_child(ink)
		var nameplate := GameTheme.heading("%s · %s" % [Landmarks.NAMES[Landmarks.SEASONS[i]],Landmarks.NAMES[Landmarks.PHASES[i]]],23)
		nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ink.add_child(nameplate)
		nameplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await capture(site_id+"-four-seasons")
	spread.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var save: Node = root.get_node("Journey")
	var temp := "user://qa-field-render-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(temp)
	save.save_path = temp.path_join("journey.json")
	save.progress = save.normalize({})
	save.set_setting("sound",false)
	save.set_setting("reducedMotion",true)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await capture("home")
	app.show_atlas("home","dunhuang")
	await capture("dunhuang-atlas")
	app.show_landmark("crescent")
	app.screen.select_sky("summer","dawn")
	await capture("crescent-dawn")
	app.screen.keep_print()
	app.screen.select_sky("autumn","dusk")
	app.screen.keep_print()
	app.open_fieldwork()
	await capture("crescent-letter")
	app.close_dialog()
	app.show_landmark_detail("crescent_line")
	await capture("crescent-detail")
	app.return_to_landmark()
	app.screen.toggle_loupe()
	app.screen.loupe.move_lens(Vector2(548,390))
	await capture("crescent-loupe")
	app.screen.toggle_loupe()
	app.open_site_journal()
	await capture("crescent-journal")
	app.show_landmark("mogao")
	app.screen.select_sky("spring","dusk")
	await capture("mogao-dusk")
	app.show_landmark_detail("lotus_rabbits")
	await capture("mogao-three-hares")
	app.show_landmark("yardang")
	app.screen.select_sky("winter","night")
	await capture("yardang-night")
	for season: String in ["spring","summer","autumn","winter"]:
		app.show_landmark("poplar")
		app.screen.select_sky(season,"day")
		await capture("poplar-" + season)
	for window_size in [Vector2i(1560,720), Vector2i(1024,768)]:
		root.size = window_size
		app.show_atlas("map","wuwei")
		await capture("atlas-%d" % window_size.x)
		app.show_landmark("yardang")
		await capture("landmark-%d" % window_size.x)
		app.open_site_journal()
		await capture("journal-%d" % window_size.x)
	app.queue_free()
	await create_timer(.35).timeout
	await compare_skies("poplar")
	await compare_skies("crescent")
	for file in DirAccess.get_files_at(temp): DirAccess.remove_absolute(temp.path_join(file))
	DirAccess.remove_absolute(temp)
	quit(1 if failed else 0)
