extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button and node.is_visible_in_tree():
		found.append(node)
	for child in node.get_children():
		found.append_array(buttons(child))
	return found

func run() -> void:
	check(ResourceLoader.exists("res://scenes/main.tscn"), "native main scene exists")
	if not failures.is_empty():
		quit(1)
		return
	var journey: Node = root.get_node("Journey")
	journey.save_path = "user://qa-app-%d.json" % OS.get_process_id()
	journey.progress = journey.normalize({})
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var font: Font = GameTheme.make().default_font
	font.get_string_size("欧哟几的旅行", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	var coordinates: Dictionary = TextServerManager.get_primary_interface().font_get_variation_coordinates(font.get_rids()[0])
	check(float(coordinates.get(2003265652, coordinates.get("weight", 100))) >= 400, "Chinese font uses readable regular-or-heavier weight")
	for window_size in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1024, 768)]:
		root.size = window_size
		await process_frame
		for view in ["home", "map", "camp", "companions", "composer", "book", "album", "trail", "atlas", "landmark", "site_journal", "landmark_detail", "world"]:
			match view:
				"home": app.show_home()
				"map": app.show_map()
				"camp": app.show_camp()
				"composer": app.show_composer()
				"companions": app.show_companions()
				"book": app.show_book("games")
				"album": app.show_album("map")
				"trail": app.show_trail("jiayuguan", "world")
				"atlas": app.show_atlas("home","dunhuang")
				"landmark": app.show_landmark("yardang")
				"site_journal": app.open_site_journal()
				"landmark_detail": app.show_landmark_detail("fleet_shadow")
				"world": app.show_world("wuwei")
			await process_frame
			await process_frame
			if view == "world":
				var painted_bottom: Vector2 = app.world.get_global_transform_with_canvas() * Vector2(960, 720)
				check(painted_bottom.y >= root.get_visible_rect().end.y - 1, "world painting reaches the bottom edge at %s" % window_size)
			var controls := buttons(app.screen)
			check(not controls.is_empty(), "%s contains native controls" % view)
			for button in controls:
				check(button.size.y >= 63.9, "%s button height: %s" % [view, button.text])
				check(button.get_rect().has_area(), "button has a layout rectangle")
				var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
				var r := button.get_global_rect()
				check(viewport_rect.encloses(r.grow(-1.0)), "%s button visible: %s %s" % [view, button.text, r])
				if not button.text.is_empty():
					var inset := button.get_theme_stylebox("normal").get_minimum_size()
					var text_size := button.get_theme_font("font").get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - inset.x, button.get_theme_font_size("font_size"))
					check(text_size.y <= button.size.y - inset.y + 1, "%s full button text fits vertically: %s" % [view, button.text])
					if view == "landmark" and button.name in ["Seasons","Times","Clock","Loupe","FieldPage","KeepPrint"]:
						var line := button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_CENTER,-1,button.get_theme_font_size("font_size"))
						check(line.x <= button.size.x - inset.x + 1, "field tool keeps its full caption on one line: " + button.text)
	app.show_home()
	await process_frame
	var start: Button
	for button in buttons(app):
		if "出发" in button.text or "继续旅行" in button.text:
			start = button
	check(start != null, "home has a journey action")
	if start != null:
		start.pressed.emit()
		await process_frame
		check(app.view == "world", "journey action enters real world")
	app.show_world("wuwei")
	await process_frame
	var world: Node = app.world
	check(world != null and world.get_node("Hero") is CharacterBody2D, "world contains movable native protagonist")
	if world != null:
		var before: Vector2 = world.get_node("Hero").position
		world.set_move_direction(Vector2.RIGHT)
		for frame in range(12):
			await physics_frame
		world.set_move_direction(Vector2.ZERO)
		check(world.get_node("Hero").position.x > before.x, "protagonist physically walks")
	app.show_settings()
	await process_frame
	check(app.modal != null, "settings opens native modal")
	var paused_position: Vector2 = world.get_node("Hero").position
	Input.action_press("ui_right")
	for frame in range(8): await physics_frame
	Input.action_release("ui_right")
	check(world.get_node("Hero").position.is_equal_approx(paused_position), "a modal blocks held movement behind it")
	app.go_back()
	await process_frame
	check(app.modal == null and app.view == "world", "back closes dialog before leaving world")
	app.queue_free()
	await process_frame
	await create_timer(.3).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(journey.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(journey.save_path + ".bak"))
	print("APP_CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
