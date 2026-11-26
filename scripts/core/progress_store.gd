extends Node

signal changed
signal save_failed(message: String)

const Catalog: Script = preload("res://scripts/core/content_db.gd")
const Schema: Script = preload("res://scripts/core/progress_schema.gd")
const ProgressFile: Script = preload("res://scripts/core/progress_file.gd")
const Trails: Script = preload("res://scripts/trails/trail_catalog.gd")
const Landmarks = preload("res://scripts/landmarks/catalog.gd")
const FieldNotes = preload("res://scripts/landmarks/field_notes.gd")

var _data: Dictionary = Catalog.load_content()
var _schema: RefCounted = Schema.new(_data)
var _file: RefCounted
var progress: Dictionary = _schema.normalize(null)
var last_error: String = ""
var save_path: String = "user://progress.json":
	set(value):
		save_path = value
		_file = ProgressFile.new(save_path, _decode)


func _ready() -> void:
	_file = ProgressFile.new(save_path, _decode)
	var result: Dictionary = _file.read()
	if result.get("ok", false) and not result.get("missing", false):
		progress = result.progress
	elif not result.get("ok", false):
		_report_error(result.error)


func normalize(raw: Variant) -> Dictionary:
	return _schema.normalize(raw)


func start_journey() -> void:
	var next: Dictionary = progress.duplicate(true)
	next.journey.started = true
	_commit(next)


func landmark_page(id: String) -> Dictionary:
	return progress.atlas.places.get(id, Landmarks.fresh_page()).duplicate(true)


func _write_place(id: String, page: Dictionary) -> bool:
	var next := progress.duplicate(true)
	next.atlas.lastSite = id
	next.atlas.places[id] = page
	if next == progress: return false
	_commit(next)
	return true


func visit_landmark(id: String) -> bool:
	if Landmarks.lookup(id).is_empty(): return false
	return _write_place(id, landmark_page(id))


func set_landmark_sky(id: String, season: String, phase: String) -> bool:
	if not Landmarks.SEASONS.has(season) or not Landmarks.PHASES.has(phase) or Landmarks.lookup(id).is_empty(): return false
	var page := landmark_page(id)
	page.season = season
	page.phase = phase
	return _write_place(id, page)


func save_sky_print(id: String) -> bool:
	if not progress.atlas.places.has(id): return false
	var page := landmark_page(id)
	var key: String = page.season + ":" + page.phase
	if key in page.prints: return false
	page.prints.append(key)
	return _write_place(id, page)


func complete_landmark_detail(id: String, which: String) -> bool:
	if Landmarks.detail(Landmarks.lookup(id), which).is_empty(): return false
	var page := landmark_page(id)
	if which in page.details: return false
	page.details.append(which)
	return _write_place(id, page)


func explored_count(id: String) -> int:
	return _schema.observed_in(id, progress.journey.encounters) + FieldNotes.observed_in(id, progress.atlas)


func visit(encounter_id: String) -> void:
	var encounter: Dictionary = _schema.by_id("encounters", encounter_id)
	if encounter.is_empty() or progress.journey.encounters.has(encounter_id):
		return
	var next: Dictionary = progress.duplicate(true)
	next.journey.started = true
	next.journey.encounters.append(encounter_id)
	_add_discovery(next, encounter.fact)
	_commit(next)


func collect_seal(station: String) -> bool:
	var trail: Dictionary = Trails.get_trail(station)
	if trail.is_empty() or station in progress.journey.trailSeals:
		return false
	var encounter: Dictionary = _schema.by_id("encounters", str(trail.encounter))
	if encounter.get("stageId") != station:
		return false
	var next := progress.duplicate(true)
	next.journey.started = true
	next.journey.trailSeals.append(station)
	if encounter.id not in next.journey.encounters:
		next.journey.encounters.append(encounter.id)
	_add_discovery(next, encounter.fact)
	_commit(next)
	return true


func answer(stage_id: String, choice_id: String) -> void:
	var chapter: Dictionary = _schema.by_id("chapters", stage_id)
	if chapter.is_empty():
		return
	var valid: bool = false
	for choice: Dictionary in chapter.choices:
		if choice.id == choice_id:
			valid = true
	if not valid:
		return
	var next: Dictionary = progress.duplicate(true)
	next.journey.started = true
	if not next.journey.conversations.has(stage_id):
		next.journey.conversations.append(stage_id)
	next.journey.choices[stage_id] = choice_id
	_commit(next)


func complete_game(game_id: String) -> void:
	var activity: Dictionary = _schema.by_id("activities", game_id)
	if activity.is_empty() or progress.completed.has(game_id):
		return
	var next: Dictionary = progress.duplicate(true)
	next.completed.append(game_id)
	_add_discovery(next, activity.fact)
	_commit(next)


func can_claim(stage_id: String) -> bool:
	var chapter: Dictionary = _schema.by_id("chapters", stage_id)
	if chapter.is_empty() or progress.journey.claimed.has(stage_id):
		return false
	for previous: Dictionary in _data.chapters:
		if previous.id == stage_id:
			break
		if not progress.journey.claimed.has(previous.id):
			return false
	return _requirements_met(chapter)


func claim(stage_id: String) -> bool:
	if not can_claim(stage_id):
		return false
	var next: Dictionary = progress.duplicate(true)
	next.journey.started = true
	next.journey.claimed.append(stage_id)
	_commit(next)
	return true


func has_ending() -> bool:
	for chapter: Dictionary in _data.chapters:
		if not progress.journey.claimed.has(chapter.id) or not _requirements_met(chapter):
			return false
	return _data.chapters.size() == 6


func accept_letter(id: String, gift: String) -> bool:
	var letter: Dictionary = _schema.by_id("letters", id)
	if letter.is_empty() or gift != letter.gift or not progress.journey.conversations.has(letter.from) or progress.camp.accepted.has(id):
		return false
	var next: Dictionary = progress.duplicate(true)
	next.camp.accepted.append(id)
	_commit(next)
	return true


func deliver_letter(id: String, stage: String) -> bool:
	var letter: Dictionary = _schema.by_id("letters", id)
	if letter.is_empty() or stage != letter.to or not progress.camp.accepted.has(id) or progress.camp.delivered.has(id):
		return false
	var next: Dictionary = progress.duplicate(true)
	next.camp.delivered.append(id)
	_commit(next)
	return true


func available_decorations() -> Array:
	return _schema.decoration_ids(progress.camp.delivered)


func place_decoration(id: String, slot: String) -> bool:
	if not _schema.ids("campSpots").has(slot) or (not id.is_empty() and not available_decorations().has(id)):
		return false
	if progress.camp.layout.get(slot, "") == id:
		return false
	var next: Dictionary = progress.duplicate(true)
	for key: String in next.camp.layout.keys():
		if key == slot or next.camp.layout[key] == id:
			next.camp.layout.erase(key)
	if not id.is_empty():
		next.camp.layout[slot] = id
	next.camp.customized = true
	_commit(next)
	return true


func set_camp(field: String, value: Variant) -> void:
	match field:
		"sky":
			if not value is String or not ["night", "dawn"].has(value):
				return
		"voice":
			if not value is String or not _schema.ids("campVoices").has(value):
				return
		"tempo":
			if not Schema.is_number(value) or not [80, 100].has(value):
				return
		"notes":
			if not value is Array or value.size() != 8:
				return
			for note: Variant in value:
				if not Schema.valid_note(note):
					return
		_:
			return
	if progress.camp[field] == value:
		return
	var next: Dictionary = progress.duplicate(true)
	next.camp[field] = value.duplicate() if value is Array else value
	next.camp.customized = true
	_commit(next)


func set_paint(index: int, color: String) -> void:
	if index < 0 or index > 15 or not _data.pigmentColors.has(color):
		return
	var next: Dictionary = progress.duplicate(true)
	next.paint[str(index)] = color
	_commit(next)


func set_setting(key: String, value: Variant) -> void:
	if ["sound", "music", "narration", "reducedMotion"].has(key):
		if not value is bool:
			return
	elif key == "musicVolume":
		if not Schema.is_number(value) or not is_finite(float(value)):
			return
		value = clampf(float(value), 0.0, 1.0)
	else:
		return
	var next: Dictionary = progress.duplicate(true)
	next.settings[key] = value
	_commit(next)


func finish_ending() -> void:
	if not has_ending():
		return
	var next: Dictionary = progress.duplicate(true)
	next.journey.endingSeen = true
	_commit(next)


func export_json() -> String:
	return JSON.stringify(normalize(progress), "\t")


func import_json(text: String) -> Dictionary:
	var decoded: Dictionary = _decode(text)
	if not decoded.get("ok", false):
		return {"ok": false, "error": decoded.error}
	var previous: Dictionary = progress
	progress = _schema.merge(previous, decoded.progress)
	if not save():
		progress = previous
		return {"ok": false, "error": last_error}
	changed.emit()
	return {"ok": true}


func save() -> bool:
	if _file == null:
		_file = ProgressFile.new(save_path, _decode)
	var result: Dictionary = _file.write(export_json())
	if not result.get("ok", false):
		_report_error(result.error)
		return false
	last_error = ""
	return true


func _decode(text: String) -> Dictionary:
	if text.length() > 100000:
		return {"ok": false, "error": "这份行囊文件太大了，请选择之前导出的行囊。"}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "行囊文件不完整或格式有误，原来的进度还在。"}
	var raw: Variant = json.data
	if not raw is Dictionary or not Schema.valid_version(raw.get("version")) or not raw.get("completed") is Array:
		return {"ok": false, "error": "这不是《敦煌奇游记》的行囊文件，原来的进度还在。"}
	return {"ok": true, "progress": normalize(raw)}


func _requirements_met(chapter: Dictionary) -> bool:
	return progress.journey.conversations.has(chapter.id) and progress.completed.has(chapter.requiredGame) and explored_count(chapter.id) >= 2


func _add_discovery(next: Dictionary, fact_id: String) -> void:
	if not next.discoveries.has(fact_id):
		next.discoveries.append(fact_id)


func _commit(next: Dictionary) -> void:
	if next == progress:
		return
	progress = next
	save()
	changed.emit()


func _report_error(message: String) -> void:
	last_error = message
	save_failed.emit(message)
