extends SceneTree

var checks := 0
var failures: Array[String] = []
var writes := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func run() -> void:
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-seals-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("progress.json")
	store.progress = store.normalize({"version": 2, "completed": ["water"], "journey": {"encounters": ["zhangye-wheel"]}})
	check(store.progress.journey.get("trailSeals") == [], "4.0 saves start with an empty seal album and keep their game stamps")
	check(store.progress.completed == ["water"], "legacy game reward remains earned")
	check(store.has_method("collect_seal"), "the game can award a seal together with its discovery")
	if store.has_method("collect_seal"):
		store.changed.connect(func(): writes += 1)
		check(not store.collect_seal("elsewhere"), "unknown station cannot earn a seal")
		check(store.collect_seal("wuwei"), "a first solve earns its station seal")
		var catalog: Script = load("res://scripts/trails/trail_catalog.gd")
		var encounter_id := str(catalog.get_trail("wuwei").encounter)
		var encounter: Dictionary = root.get_node("Library").by_id("encounters", encounter_id)
		check(store.progress.journey.encounters.has(encounter_id) and store.progress.discoveries.has(encounter.fact), "seal, scene discovery and knowledge card arrive together")
		check(writes == 1 and store.progress.journey.started, "one progress transaction starts the journey")
		check(not store.collect_seal("wuwei") and writes == 1, "replaying cannot duplicate rewards or write again")
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.save_path))
		check(saved.journey.trailSeals == ["wuwei"] and encounter_id in saved.journey.encounters, "the disk contains a complete reward")
		check(store.collect_seal("dunhuang"), "independent stations can be explored out of order")
		check(store.import_json(JSON.stringify(saved)).ok, "an exported album merges into local progress")
		check(store.progress.journey.trailSeals.size() == 2, "merging a smaller album retains both seals")
		var damaged: Dictionary = saved.duplicate(true)
		damaged.journey.trailSeals = ["wuwei", "wuwei", 12, "elsewhere", "jiuquan"]
		check(store.normalize(damaged).journey.trailSeals == ["wuwei"], "invalid seals and seals without their discovery are discarded")
		check(store.import_json('{"version":1,"completed":["memory"]}').ok and "dunhuang" in store.progress.journey.trailSeals, "a v1 import retains a newer collection")
		check(store.progress.journey.claimed.is_empty(), "collecting a seal never bypasses a story bell")
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	print("SEAL_CHECKS: %d; FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
