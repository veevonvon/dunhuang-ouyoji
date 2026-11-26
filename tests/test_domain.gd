extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _serial: int = 0
var _store_script: Script
var _catalog_script: Script
var _test_dir: String = "user://domain-tests-%d" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# All test-owned saves live below this process-specific directory.
	DirAccess.make_dir_recursive_absolute(_test_dir)
	if not FileAccess.file_exists("res://scripts/core/progress_store.gd"):
		_expect(false, "Journey must implement the protected v2 progress store")
		_finish()
		return
	if not FileAccess.file_exists("res://scripts/core/content_db.gd"):
		_expect(false, "Library must provide the complete migrated content")
		_finish()
		return
	_store_script = load("res://scripts/core/progress_store.gd")
	_catalog_script = load("res://scripts/core/content_db.gd")
	if _store_script == null or _catalog_script == null:
		_expect(false, "Domain scripts must load")
		_finish()
		return
	_test_content_and_assets()
	_test_defaults_and_legacy()
	_test_normalization_guards_rewards()
	_test_untrusted_types_and_claim_gaps()
	_test_camp_normalization()
	_test_all_six_chapters()
	_test_invalid_and_repeated_actions()
	_test_all_activities_and_observations()
	_test_letters_and_camp()
	_test_paint_and_settings()
	_test_import_validation_and_merge()
	_test_atomic_save_and_backup()
	_test_backup_failure_and_restart()
	_test_corrupt_save_recovery()
	_test_failed_import_preserves_good_progress()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: ", message)


func _new_store() -> Node:
	_serial += 1
	var store: Node = _store_script.new()
	store.set("save_path", "%s/progress-%d.json" % [_test_dir, _serial])
	root.add_child(store)
	return store


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_content_and_assets() -> void:
	var catalog: Variant = _catalog_script.new()
	var counts: Dictionary = {"stages": 6, "chapters": 6, "encounters": 18, "facts": 31,
		"historyEvents": 12, "activities": 11, "decorations": 9, "letters": 3,
		"campNotes": 6, "campVoices": 3, "campSpots": 6}
	for key: String in counts:
		_expect(catalog.all(key).size() == counts[key], "Preserve all %s" % key)
	_expect(catalog.by_id("chapters", "jiuquan").get("requiredGame") == "trade", "Jiuquan reward requires fair trade, not memory")
	_expect(catalog.by_id("facts", "missing").is_empty(), "Unknown content IDs have no invented fallback")
	_expect(catalog.all("missing").is_empty(), "Unknown collections are empty")
	for id: String in ["map", "boy", "deer", "wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang", "camp-night", "camp-dawn", "mural", "ending"]:
		_expect(FileAccess.file_exists(catalog.image_path(id)), "Local image exists: " + id)
	_expect(catalog.image_path("../../outside").is_empty(), "Image lookup rejects arbitrary paths")
	_expect(catalog.voice_path("../../outside").is_empty(), "Voice lookup rejects arbitrary paths")
	_expect(FileAccess.file_exists(catalog.voice_path("reply-colors")), "Final letter narration remains offline")
	_expect(FileAccess.file_exists("res://assets/fonts/chinese.ttf"), "Chinese font is bundled")
	catalog.free()


func _test_defaults_and_legacy() -> void:
	var store: Variant = _new_store()
	_expect(store.progress.version == 2, "New saves use v2")
	_expect(store.progress.completed.is_empty() and store.progress.journey.claimed.is_empty(), "A new journey earns no rewards")
	_expect(store.progress.journey.started == false and store.progress.journey.endingSeen == false, "A new story remains unseen")
	_expect(store.progress.camp.notes == [0, 2, 3, 2, 1, -1, 0, -1], "Legacy saves receive the original eight-beat composition: " + str(store.progress.camp.notes))
	_expect(store.available_decorations().size() == 6, "Six camp items are available before letters")
	var result: Dictionary = store.import_json('{"version":1,"completed":["pack","paint"],"discoveries":["qilian"],"paint":{"0":"#c36849"},"settings":{"sound":false,"reducedMotion":true}}')
	_expect(result.get("ok", false), "Version 1 exported luggage imports")
	_expect(store.progress.completed == ["pack", "paint"] and store.progress.paint == {"0": "#c36849"}, "Legacy stamps and paint survive")
	_expect(not store.progress.settings.sound and store.progress.settings.reducedMotion, "Legacy preferences survive")
	_expect(store.progress.journey.claimed.is_empty(), "Legacy stamps do not invent story bells")
	store.free()


func _test_normalization_guards_rewards() -> void:
	var store: Variant = _new_store()
	var raw: Dictionary = {"version": 2, "completed": ["pack", "pack", "unknown", 42], "discoveries": ["oasis", "unknown"],
		"paint": {"0": "#c36849", "15": "#315d83", "16": "#c36849", "00": "#c36849", "1": "red"},
		"settings": {"musicVolume": 2, "sound": "false"}, "journey": {
		"conversations": ["wuwei", "wuwei", "unknown"], "encounters": ["wuwei-well", "wuwei-camel", "wuwei-well", "unknown"],
		"choices": {"wuwei": "water", "zhangye": "injected"}, "claimed": ["wuwei", "zhangye", "dunhuang"], "endingSeen": true}}
	var p: Dictionary = store.normalize(raw)
	_expect(p.completed == ["pack"] and p.discoveries == ["oasis"], "Normalization filters and deduplicates IDs")
	_expect(p.paint == {"0": "#c36849", "15": "#315d83"}, "Only valid lotus slots and pigments survive")
	_expect(p.journey.choices == {"wuwei": "water"}, "Choices must belong to their chapter")
	_expect(p.journey.claimed == ["wuwei"] and not p.journey.endingSeen, "Unsupported bells and endings are removed")
	_expect(p.settings.musicVolume == 1 and p.settings.sound == true, "Volume is clamped and booleans stay typed")
	raw.completed = []
	_expect(store.normalize(raw).journey.claimed.is_empty(), "A claim without its activity is removed")
	raw.completed = ["pack"]
	raw.journey.encounters = ["wuwei-well", "wuwei-well"]
	_expect(store.normalize(raw).journey.claimed.is_empty(), "Duplicate observations cannot meet the two-discovery requirement")
	_expect(store.normalize({"version": 2, "settings": {"musicVolume": -5}}).settings.musicVolume == 0, "Negative volume is clamped")
	_expect(store.normalize({"version": 2, "settings": {"musicVolume": NAN}}).settings.musicVolume == 0.35, "Nonfinite volume uses its safe default")
	store.free()


func _test_camp_normalization() -> void:
	var store: Variant = _new_store()
	var p: Dictionary = store.normalize({"version": 2, "journey": {"conversations": ["wuwei"]}, "camp": {
		"accepted": ["seeds", "seeds", "melody", "unknown"], "delivered": ["seeds", "colors"],
		"layout": {"one": "tea", "two": "tea", "three": "flowers", "four": "chimes", "seven": "books"},
		"notes": [0, 1, 2, 3, 4, -1, 99, "bad"], "voice": "unknown", "tempo": 95, "sky": "unknown", "customized": true}})
	_expect(p.camp.accepted == ["seeds"] and p.camp.delivered == ["seeds"], "Letters need their source conversation before rewards survive normalization")
	_expect(p.camp.layout == {"one": "tea", "three": "flowers"}, "Locked, unknown, and duplicate camp items are removed")
	_expect(p.camp.notes == [0, 1, 2, 3, 4, -1, -1, -1], "Invalid imported notes turn into rests")
	_expect(p.camp.voice == "bell" and p.camp.tempo == 80 and p.camp.sky == "night", "Unknown camp choices restore safe defaults")
	store.free()


func _test_untrusted_types_and_claim_gaps() -> void:
	var store: Variant = _new_store()
	for bad: Variant in [null, true, 0, "true", [], {}]:
		var p: Dictionary = store.normalize({"version": 2, "completed": bad, "discoveries": bad, "paint": bad,
			"settings": {"musicVolume": bad, "sound": bad},
			"journey": {"started": bad, "endingSeen": bad, "conversations": bad, "choices": bad, "encounters": bad, "claimed": bad},
			"camp": {"accepted": bad, "delivered": bad, "layout": bad, "notes": bad, "voice": bad, "tempo": bad, "sky": bad, "customized": bad}})
		var complete_shape: bool = p.has_all(["completed", "journey", "camp"]) and p.get("journey", {}).has_all(["claimed", "started"]) and p.get("camp", {}).has_all(["notes", "voice", "sky"])
		_expect(complete_shape, "Malformed types must still normalize to a complete progress schema")
		if not complete_shape:
			continue
		_expect(p.completed.is_empty() and p.journey.claimed.is_empty(), "Unexpected external types cannot invent rewards")
		_expect(p.journey.started == (bad is bool and bad == true), "Started stays a strict boolean")
		_expect(p.camp.notes.size() == 8 and p.camp.voice == "bell" and p.camp.sky == "night", "Unexpected camp types retain a playable default")
	var gap: Dictionary = store.normalize({"version": 2, "completed": ["pack", "water"], "journey": {
		"conversations": ["wuwei", "zhangye"], "encounters": ["wuwei-well", "wuwei-camel", "zhangye-wheel", "zhangye-bird"], "claimed": ["zhangye"]}})
	_expect(gap.journey.claimed.is_empty(), "An imported later claim cannot skip an unclaimed prior bell")
	store.free()


func _test_all_six_chapters() -> void:
	var store: Variant = _new_store()
	var stages: Array = ["wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang"]
	var games: Array = ["pack", "water", "trade", "route", "music", "mural"]
	var choices: Array = ["water", "tree", "half", "again", "wind", "friends"]
	var observations: Array = [["wuwei-well", "wuwei-camel"], ["zhangye-wheel", "zhangye-bird"], ["jiuquan-grapes", "jiuquan-letter"], ["jiayuguan-brick", "jiayuguan-arch"], ["guazhou-pipa", "guazhou-reeds"], ["dunhuang-lotus", "dunhuang-moon"]]
	store.start_journey()
	_expect(store.progress.journey.started, "Starting a journey records intent")
	store.finish_ending()
	_expect(not store.progress.journey.endingSeen, "The ending cannot be marked seen early")
	# Complete the later chapter first; it must still wait for Wuwei's bell.
	store.complete_game("water")
	store.answer("zhangye", "tree")
	store.visit("zhangye-wheel")
	store.visit("zhangye-bird")
	_expect(not store.can_claim("zhangye") and not store.claim("zhangye"), "Early games cannot skip chapter order")
	for i: int in range(stages.size()):
		var stage: String = stages[i]
		store.answer(stage, choices[i])
		store.visit(observations[i][0])
		if i != 1:
			_expect(not store.can_claim(stage), "One discovery never earns " + stage)
		store.visit(observations[i][1])
		store.complete_game(games[i])
		_expect(store.can_claim(stage), "All prerequisites earn " + stage)
		_expect(store.claim(stage), "The ready bell can be claimed: " + stage)
		_expect(not store.claim(stage), "Each bell is earned once: " + stage)
	_expect(store.progress.journey.claimed == stages, "Six bells remain in travel order")
	_expect(store.has_ending(), "All six legitimate bells unlock the ending")
	store.finish_ending()
	_expect(store.progress.journey.endingSeen, "Unlocked ending can be recorded")
	var imported: Variant = _new_store()
	_expect(imported.import_json(store.export_json()).get("ok", false), "A complete v2 journey round-trips")
	_expect(imported.has_ending() and imported.progress.journey.endingSeen, "Ending eligibility survives export and import")
	imported.free()
	store.free()


func _test_invalid_and_repeated_actions() -> void:
	var store: Variant = _new_store()
	var before: String = store.export_json()
	store.answer("wuwei", "bad")
	store.answer("unknown", "water")
	store.visit("unknown")
	store.complete_game("unknown")
	_expect(not store.claim("unknown") and not store.can_claim("unknown"), "Unknown chapters cannot be claimed")
	_expect(store.export_json() == before, "Invalid actions do not mutate progress")
	store.visit("wuwei-well")
	store.visit("wuwei-well")
	store.complete_game("pack")
	store.complete_game("pack")
	_expect(store.progress.journey.encounters == ["wuwei-well"] and store.progress.completed == ["pack"], "Repeated callbacks do not duplicate rewards")
	_expect(store.progress.discoveries == ["oasis", "silk"], "Visits and games award their associated knowledge cards")
	store.free()


func _test_letters_and_camp() -> void:
	var store: Variant = _new_store()
	_expect(not store.accept_letter("seeds", "seeds"), "A letter is locked until its sender speaks")
	var letters: Array = [["seeds", "seeds", "wuwei", "water", "zhangye", "flowers"], ["melody", "bell", "jiuquan", "half", "guazhou", "chimes"], ["colors", "pigments", "jiayuguan", "again", "dunhuang", "lantern"]]
	for row: Array in letters:
		store.answer(row[2], row[3])
		_expect(not store.accept_letter(row[0], "wrong"), "A letter needs the requested gift: " + row[0])
		_expect(not store.deliver_letter(row[0], row[4]), "A parcel must be accepted before delivery")
		_expect(store.accept_letter(row[0], row[1]), "The requested gift can be accepted: " + row[0])
		_expect(not store.accept_letter(row[0], row[1]), "A letter can only be accepted once")
		_expect(not store.deliver_letter(row[0], row[2]), "A parcel cannot be delivered at the wrong station")
		_expect(store.deliver_letter(row[0], row[4]), "The intended recipient receives the parcel")
		_expect(not store.deliver_letter(row[0], row[4]), "A parcel reward is granted once")
		_expect(store.available_decorations().has(row[5]), "Letter delivery unlocks its camp reward")
	_expect(store.available_decorations().size() == 9, "All three letters unlock nine decorations")
	_expect(store.place_decoration("tea", "one"), "Unlocked decorations can be placed")
	store.place_decoration("books", "two")
	store.place_decoration("tea", "two")
	_expect(store.progress.camp.layout == {"two": "tea"}, "Moving furniture removes its former placement and replaces the target")
	_expect(not store.place_decoration("tea", "seven") and not store.place_decoration("unknown", "one"), "Invalid camp placement does not mutate layout")
	_expect(store.place_decoration("", "two") and store.progress.camp.layout.is_empty(), "An empty decoration clears a valid slot")
	store.set_camp("notes", [4, 3, -1, 2, 1, 0, 0, -1])
	store.set_camp("voice", "wood")
	store.set_camp("tempo", 100)
	store.set_camp("sky", "dawn")
	var before: Dictionary = store.progress.camp.duplicate(true)
	store.set_camp("notes", [0, 1])
	store.set_camp("notes", [0, 1, 2, 3, 4, 5, 0, -1])
	store.set_camp("tempo", 0)
	store.set_camp("voice", "unknown")
	store.set_camp("delivered", ["unknown"])
	_expect(store.progress.camp == before, "Invalid camp edits cannot inject rewards or corrupt music")
	_expect(store.progress.camp.customized and before.voice == "wood" and before.tempo == 100 and before.sky == "dawn", "Valid creative settings persist")
	store.free()


func _test_all_activities_and_observations() -> void:
	var store: Variant = _new_store()
	var catalog: Variant = _catalog_script.new()
	for activity: Dictionary in catalog.all("activities"):
		store.complete_game(activity.id)
		store.complete_game(activity.id)
	_expect(store.progress.completed.size() == 11, "All eleven activity callbacks award one stamp each")
	_expect(store.progress.discoveries.size() == 9, "Activities award all nine distinct linked knowledge cards")
	for encounter: Dictionary in catalog.all("encounters"):
		store.visit(encounter.id)
		store.visit(encounter.id)
	_expect(store.progress.journey.encounters.size() == 18, "All eighteen discoveries remain visitable without duplicates")
	_expect(store.progress.journey.claimed.is_empty() and not store.has_ending(), "Games and observations alone cannot invent conversations or bells")
	catalog.free()
	store.free()


func _test_paint_and_settings() -> void:
	var store: Variant = _new_store()
	store.set_paint(0, "#c36849")
	store.set_paint(16, "#c36849")
	store.set_paint(1, "red")
	store.set_setting("sound", false)
	store.set_setting("musicVolume", 4.0)
	store.set_setting("narration", "false")
	store.set_setting("completed", ["pack"])
	_expect(store.progress.paint == {"0": "#c36849"}, "Paint edits validate index and pigment")
	_expect(not store.progress.settings.sound and store.progress.settings.musicVolume == 1.0, "Typed preferences and clamped volume persist")
	_expect(not store.progress.settings.narration and store.progress.completed.is_empty(), "Settings cannot inject unrelated fields")
	store.free()


func _test_import_validation_and_merge() -> void:
	var store: Variant = _new_store()
	store.answer("wuwei", "water")
	store.accept_letter("seeds", "seeds")
	store.deliver_letter("seeds", "zhangye")
	store.place_decoration("flowers", "one")
	store.complete_game("pack")
	var before: String = store.export_json()
	var disk_before: String = _read(store.save_path)
	for invalid: String in ["{", "[]", "null", '{"version":99,"completed":[]}', '{"version":2}', '{"version":2,"completed":{}}', " ".repeat(100001)]:
		var result: Dictionary = store.import_json(invalid)
		_expect(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "Invalid luggage returns an actionable error")
		_expect(store.export_json() == before and _read(store.save_path) == disk_before, "Invalid imports never replace good memory or disk progress")
	_expect(store.import_json('{"version":1,"completed":["water"]}').get("ok", false), "A valid legacy import merges")
	_expect(store.progress.completed == ["pack", "water"], "Import unions existing and incoming stamps")
	_expect(store.progress.camp.layout == {"one": "flowers"} and store.progress.camp.delivered == ["seeds"], "Legacy import preserves a customized camp and deliveries")
	store.free()


func _test_atomic_save_and_backup() -> void:
	var store: Variant = _new_store()
	store.complete_game("pack")
	var first: String = _read(store.save_path)
	store.complete_game("water")
	var second: String = _read(store.save_path)
	_expect(JSON.parse_string(second).completed == ["pack", "water"], "Save writes the latest complete JSON")
	_expect(_read(store.save_path + ".bak") == first, "The previous good save is retained as backup")
	_expect(not FileAccess.file_exists(store.save_path + ".tmp"), "Successful saves leave no partial temporary file")
	DirAccess.make_dir_absolute(store.save_path + ".tmp")
	var errors: Array[String] = []
	store.save_failed.connect(func(message: String) -> void: errors.append(message))
	store.progress.completed.append("memory")
	_expect(not store.save(), "A real filesystem write failure is reported")
	_expect(errors.size() == 1 and not errors[0].is_empty(), "Save failures emit a readable signal")
	_expect(_read(store.save_path) == second and _read(store.save_path + ".bak") == first, "A failed temporary write preserves primary and backup byte-for-byte")
	DirAccess.remove_absolute(store.save_path + ".tmp")
	store.free()


func _test_corrupt_save_recovery() -> void:
	var store: Variant = _new_store()
	var path: String = store.save_path
	store.complete_game("pack")
	store.complete_game("water")
	store.free()
	_write(path, "{broken")
	var restored: Variant = _store_script.new()
	restored.save_path = path
	root.add_child(restored)
	_expect(restored.progress.completed == ["pack"], "A corrupt primary restores its valid backup")
	_expect(_read(path) == "{broken", "Recovery does not silently overwrite the corrupt source")
	restored.complete_game("memory")
	_expect(JSON.parse_string(_read(path)).completed == ["pack", "memory"], "A recovered journey can save new progress")
	_expect(JSON.parse_string(_read(path + ".bak")).completed == ["pack"], "Recovery never rotates a corrupt primary over a good backup")
	restored.free()
	_write(path, "not-json")
	_write(path + ".bak", "also-broken")
	var blocked: Variant = _store_script.new()
	blocked.save_path = path
	root.add_child(blocked)
	blocked.complete_game("stars")
	_expect(not blocked.save(), "Unreadable primary and backup put storage into protective mode")
	_expect(_read(path) == "not-json" and _read(path + ".bak") == "also-broken", "Protected storage leaves both original files untouched")
	_expect(blocked.progress.completed == ["stars"], "A temporary in-memory journey remains exportable")
	blocked.free()


func _test_backup_failure_and_restart() -> void:
	var store: Variant = _new_store()
	store.complete_game("pack")
	var path: String = store.save_path
	var first: String = _read(path)
	DirAccess.make_dir_absolute(path + ".bak.tmp")
	store.progress.completed.append("water")
	_expect(not store.save(), "A backup write failure aborts the save")
	_expect(_read(path) == first, "Backup failures cannot replace the primary save")
	_expect(not FileAccess.file_exists(path + ".tmp"), "Failed saves clean their temporary files")
	if DirAccess.dir_exists_absolute(path + ".bak.tmp"):
		DirAccess.remove_absolute(path + ".bak.tmp")
	_expect(store.save(), "Storage can recover after a transient failure")
	store.free()
	var restored: Variant = _store_script.new()
	restored.save_path = path
	root.add_child(restored)
	_expect(restored.progress.completed == ["pack", "water"], "A fresh store reloads the actual latest save")
	var valid_backup: String = _read(path + ".bak")
	_write(path, '{"version":99,"completed":[]}')
	restored.progress.completed.append("stars")
	_expect(not restored.save(), "Unexpected external corruption blocks overwriting the current file")
	_expect(_read(path + ".bak") == valid_backup, "Unknown on-disk versions cannot replace a good backup")
	restored.free()


func _test_failed_import_preserves_good_progress() -> void:
	var store: Variant = _new_store()
	store.complete_game("pack")
	var before: String = store.export_json()
	var disk_before: String = _read(store.save_path)
	DirAccess.make_dir_absolute(store.save_path + ".tmp")
	var result: Dictionary = store.import_json('{"version":2,"completed":["water"]}')
	_expect(not result.get("ok", true), "An import is unsuccessful if its atomic save fails")
	_expect(store.export_json() == before and _read(store.save_path) == disk_before, "Failed imports preserve the good in-memory and on-disk journey")
	DirAccess.remove_absolute(store.save_path + ".tmp")
	store.free()


func _remove_tree(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	DirAccess.remove_absolute(path)


func _finish() -> void:
	_remove_tree(_test_dir)
	print("Domain tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed else 0)
