extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func run() -> void:
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-atlas-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("journey.json")
	store.progress = store.normalize({"version":2, "completed":["pack"]})
	check(store.has_method("visit_landmark") and store.has_method("save_sky_print"), "landmark records are implemented through the actual save service")
	check(store.progress.has("atlas") and store.progress.completed == ["pack"], "4.1 progress upgrades without losing the pack stamp")
	if failures == 0:
		var catalog = load("res://scripts/landmarks/catalog.gd")
		var site: Dictionary = catalog.lookup("crescent")
		var detail_id: String = site.details[0].id
		check(store.progress.atlas.places.is_empty(), "a migrated album starts empty")
		check(not store.visit_landmark("unknown"), "an unknown site cannot enter the album")
		check(store.visit_landmark("crescent"), "first entry opens the local page")
		check(store.progress.atlas.lastSite == "crescent", "the latest site can be resumed")
		check(not store.set_landmark_sky("crescent", "autumn", "typo"), "invalid time cannot change a saved view")
		check(store.set_landmark_sky("crescent", "autumn", "night"), "autumn night is selected")
		check(store.save_sky_print("crescent"), "child can stamp autumn night")
		check(not store.save_sky_print("crescent"), "repeated stamps are idempotent")
		check(not store.complete_landmark_detail("crescent", "bogus"), "unknown detail cannot be awarded")
		check(store.complete_landmark_detail("crescent", detail_id), "completed local interaction is recorded")
		check(not store.complete_landmark_detail("crescent", detail_id), "replay cannot duplicate a discovery")
		check(store.explored_count("dunhuang") == 1, "one actual site counts as one main-story landscape")
		store.complete_landmark_detail("crescent", site.details[1].id)
		check(store.explored_count("dunhuang") == 1, "several details at the same site count once for the story")
		var first_save: String = store.export_json()
		store.set_landmark_sky("crescent", "winter", "dusk")
		store.save_sky_print("crescent")
		store.visit_landmark("mogao")
		check(store.import_json(first_save).ok, "the old page merges with newer sketches")
		var page: Dictionary = store.progress.atlas.places.crescent
		check(page.prints.size() == 2 and page.details.size() == 2 and store.progress.atlas.places.has("mogao"), "import preserves sketches, details, and other pages")
		var damaged: Dictionary = JSON.parse_string(store.export_json())
		damaged.atlas.places.crescent = {"season":"bad","phase":7,"details":[detail_id,detail_id,"bad",false],"prints":["spring:day","bad","spring:day"]}
		damaged.atlas.places.fake = {"details":[1]}
		damaged.atlas.lastSite = "fake"
		var clean: Dictionary = store.normalize(damaged).atlas
		check(clean.places.crescent.season == "spring" and clean.places.crescent.phase == "day", "invalid viewing choices recover to a real scene")
		check(clean.places.crescent.details == [detail_id] and clean.places.crescent.prints == ["spring:day"] and not clean.places.has("fake") and clean.lastSite != "fake", "import discards invented places, activities, postcards and repeats")
		check(store.import_json('{"version":1,"completed":["memory"]}').ok and store.progress.atlas.places.has("crescent"), "importing an old journey preserves new discoveries")
		for id in ["leitai", "wenmiao"]:
			var place: Dictionary = catalog.lookup(id)
			store.complete_landmark_detail(id, place.details[0].id)
		store.answer("wuwei", root.get_node("Library").by_id("chapters","wuwei").choices[0].id)
		check(store.can_claim("wuwei") and store.claim("wuwei"), "two different field visits can earn the existing Wuwei bell")
		check(store.normalize(JSON.parse_string(store.export_json())).journey.claimed == ["wuwei"], "a bell earned with fieldwork survives loading")
		var full_album := {"places":{}, "lastSite":"yumen"}
		for place: Dictionary in catalog.sites():
			var filled: Dictionary = catalog.fresh_page()
			for note: Dictionary in place.details: filled.details.append(note.id)
			for season: String in catalog.SEASONS:
				for phase: String in catalog.PHASES: filled.prints.append(season + ":" + phase)
			full_album.places[place.id] = filled
		var portable: Dictionary = JSON.parse_string(store.export_json())
		portable.atlas = full_album
		var payload: String = JSON.stringify(portable)
		check(store.import_json(payload).ok and store.import_json(payload).ok, "a full album can be imported twice")
		var packed: String = store.export_json()
		check(packed.length() < 100000 and store.progress.atlas.places.size() == 19, "all 304 sketches fit within the real portable save limit")
		for place: Dictionary in catalog.sites():
			var restored: Dictionary = store.landmark_page(place.id)
			check(restored.prints.size() == 16 and restored.details.size() == 3 and catalog.fieldwork_done(place,restored), "all discoveries and the stamp survive merging: " + place.id)
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("ATLAS_STORE_CHECKS: %d; FAILURES: %d" % [checks,failures])
	quit(1 if failures else 0)
