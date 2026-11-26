extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func tap(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = pressed
		root.push_input(touch, true)

func check_all_field_markers(app: Node) -> void:
	var places := preload("res://scripts/landmarks/catalog.gd")
	for viewport_size in [Vector2i(1280,720), Vector2i(1560,720), Vector2i(1024,768)]:
		root.size = viewport_size
		await process_frame
		for place: Dictionary in places.sites():
			for detail: Dictionary in place.details:
				app.show_landmark(place.id)
				await process_frame
				await process_frame
				var pin: Button = app.screen.find_child("Point_" + str(detail.id),true,false)
				if pin:
					var disc := Vector2(pin.size.x * .5,24)
					tap(pin.get_global_transform_with_canvas() * disc)
				check(app.view == "landmark_detail" and app.screen.detail.id == detail.id, "%s %s %s opens from its visible pin with the full HUD" % [viewport_size,place.id,detail.id])

func run() -> void:
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-atlas-ui-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("journey.json")
	store.progress = store.normalize({})
	store.set_setting("sound",false)
	store.set_setting("reducedMotion",true)
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var entry := app.screen.find_child("OpenAtlas",true,false) as Button
	check(entry != null, "four-season travel is reachable from the real title screen")
	if entry:
		entry.pressed.emit()
		await process_frame
		check(app.view == "atlas" and app.screen.station == "dunhuang", "first-time field trip starts at the requested Dunhuang sites")
		var atlas_backdrop: Control = app.screen.get_child(0)
		store.set_setting("reducedMotion",false)
		check(atlas_backdrop.motion, "the atlas backdrop follows the motion choice while open")
		store.set_setting("reducedMotion",true)
		check(not atlas_backdrop.motion, "reducing motion freezes the atlas behind its settings")
		var site := app.screen.find_child("Visit_crescent",true,false) as Button
		check(site != null and app.screen.find_child("Visit_mogao",true,false) != null and app.screen.find_child("Visit_yardang",true,false) != null, "Dunhuang's three signature destinations are all visible and reachable")
		site.pressed.emit()
		await process_frame
		check(app.view == "landmark" and app.landmark_id == "crescent", "the site opens as a native interactive landscape")
		store.set_setting("reducedMotion",false)
		check(not app.screen.scenery.reduced_motion and app.screen.scenery.is_processing(), "enabling motion animates the landscape immediately")
		store.set_setting("reducedMotion",true)
		check(app.screen.scenery.reduced_motion and not app.screen.scenery.is_processing(), "reducing motion freezes the current landscape immediately")
		check(app.has_method("open_fieldwork") and app.screen.find_child("Fieldwork",true,false) != null, "each landscape offers a playable seasonal commission")
		var magnify := app.screen.find_child("Loupe",true,false) as Button
		check(magnify != null, "children can inspect the actual painted details up close")
		if magnify:
			magnify.pressed.emit()
			await process_frame
			check(app.screen.loupe.visible and not app.screen.scenery.pins.visible, "the observation lens clears the marker labels")
			app.go_back()
			check(app.view == "landmark" and not app.screen.loupe.visible, "Android Back puts the lens away before leaving")
		app.screen.select_sky("autumn","dusk")
		app.screen.keep_print()
		check("autumn:dusk" in store.progress.atlas.places.crescent.prints, "the scene and the saved postcard share an exact season and time")
		app.open_sky_picker()
		await process_frame
		check(app.modal != null and app.modal.find_child("Choice_winter",true,false) != null, "all seasons can be selected by touch")
		app.go_back()
		app.open_fieldwork()
		var dawn := app.modal.find_child("Choice_summer_dawn",true,false) as Button
		check(dawn != null,"the child's commission offers a shortcut to its actual summer morning")
		dawn.pressed.emit()
		check(app.screen.season == "summer" and app.screen.phase == "dawn", "the letter puts the child into the requested light")
		app.screen.keep_print()
		app.open_fieldwork()
		app.modal.find_child("Choice_look",true,false).pressed.emit()
		await process_frame
		await process_frame
		check(app.view == "landmark_detail", "the same letter opens the geographical detail it describes")
		var board: Control = app.screen.board
		var target: Dictionary = app.screen.detail
		for word: String in target.pieces:
			for index in 3:
				if board.target_name(index) == word:
					tap(board.get_global_transform_with_canvas() * board.region_rect(index).get_center())
					break
		check(app.modal != null and target.id in store.progress.atlas.places.crescent.details,"the real three-point tracing task opens the discovery and records it")
		check(load("res://scripts/landmarks/catalog.gd").fieldwork_done(app.screen.site,store.landmark_page("crescent")),"both skies plus the local discovery earn this site's stamp")
		app.modal.find_child("Choice_site",true,false).pressed.emit()
		await process_frame
		app.open_fieldwork()
		var reread := app.modal.find_child("Choice_read_letter",true,false) as Button
		check(reread != null, "earning an unsolicited stamp keeps the original letter accessible")
		if reread:
			reread.pressed.emit()
			check(app.modal.find_child("Choice_summer_dawn",true,false) != null, "a completed commission can be read and followed again")
		app.close_dialog()
		app.screen.select_sky("autumn","dusk")
		app.open_site_journal()
		await process_frame
		check(app.view == "site_journal", "saved views can be revisited in the journal")
		var owned: Button = app.screen.find_child("Print_autumn_dusk",true,false)
		var open: Button = app.screen.find_child("Print_winter_night",true,false)
		check(owned.kept and not open.kept and owned.plate != null and owned.row == 2 and owned.column == 2, "the written page shows the stored sketch in the matching row and time column")
		open.pressed.emit()
		await process_frame
		check(app.view == "landmark" and app.screen.season == "winter" and app.screen.phase == "night", "an empty journal thumbnail takes the child into that site's actual sky")
		check("winter:night" not in store.landmark_page("crescent").prints, "previewing an uncollected time leaves its collection slot open")
		app.open_site_journal()
		await process_frame
		app.screen.find_child("Print_autumn_dusk",true,false).pressed.emit()
		await process_frame
		app.open_site_journal()
		await process_frame
		app.go_back()
		await process_frame
		check(app.view == "landmark" and app.screen.season == "autumn" and app.screen.phase == "dusk", "Back returns to the same view")
		app.go_back()
		await process_frame
		check(app.view == "atlas" and app.screen.station == "dunhuang", "leaving a place returns to this station's destinations")
		app.go_back()
		await process_frame
		check(app.view == "home", "the atlas remembers the home entrance")
		app.show_world("zhangye")
		app.screen.find_child("OpenAtlas",true,false).pressed.emit()
		await process_frame
		check(app.screen.station == "zhangye", "the city entrance opens that city's destinations")
		app.screen.choose_station("dunhuang")
		app.show_landmark("yardang")
		await process_frame
		app.screen.select_sky("winter","night")
		app.screen.toggle_clock()
		for tick in 7: app.screen._process(1)
		var time_before_book: float = app.screen.elapsed
		app.open_site_journal()
		await process_frame
		app.go_back()
		await process_frame
		check(app.screen.flowing and absf(app.screen.elapsed-time_before_book) < 1.0, "reading the journal pauses and resumes the same running clock")
		app.show_landmark_detail("fleet_shadow")
		await process_frame
		app.go_back()
		await process_frame
		check(app.screen.flowing and absf(app.screen.elapsed-time_before_book) < 1.0, "leaving an observation resumes the same partial time step")
		app.open_site_journal()
		await process_frame
		app.screen.find_child("Print_autumn_dusk",true,false).pressed.emit()
		check(app.screen.flowing and app.screen.elapsed < 1.0, "choosing a different sky in the book gives it a full time step")
		app.screen.select_sky("winter","night")
		app.open_sky_picker()
		for tick in 20: app.screen._process(1)
		check(app.screen.phase == "night","an open dialog pauses the automatic clock")
		app.close_dialog()
		app.choose_file(FileDialog.FILE_MODE_SAVE_FILE,"旅行.json","*.json","行囊","application/json",func(_path: String): pass)
		app.screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		for tick in 20: app.screen._process(1)
		check(app.screen.phase == "night", "the native or embedded file chooser pauses time even when the app retains focus")
		app._cancel_file_dialog()
		app.screen._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		for tick in 20: app.screen._process(1)
		check(app.screen.phase == "night","the landscape clock stays still in the background")
		app.screen._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		for tick in 18: app.screen._process(1)
		check(app.screen.season == "spring" and app.screen.phase == "dawn","automatic time goes from winter night to spring dawn")
		app.go_back()
		app.go_back()
		await process_frame
		check(app.view == "world" and app.stage_id == "zhangye","a cross-city field trip returns to the story station it started from")
		app.show_atlas("world","dunhuang")
		app.show_landmark("yardang")
		check(not app.screen.flowing, "a new visit starts with manual time after leaving the site")
		app.show_landmark("mogao")
		app.show_landmark_detail("lotus_rabbits")
		await process_frame
		app.screen.find_child("HareReference",true,false).pressed.emit()
		app.go_back()
		check(app.view == "landmark_detail" and not app.screen.folio.enlarged_reference.visible, "Android Back returns from the enlarged three-hares picture to the same unfinished activity")
		await check_all_field_markers(app)
	app.queue_free()
	await create_timer(.35).timeout
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("ATLAS_UI_CHECKS: %d; FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
