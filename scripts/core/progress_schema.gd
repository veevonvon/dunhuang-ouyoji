extends RefCounted

const Trails = preload("res://scripts/trails/trail_catalog.gd")
const FieldNotes = preload("res://scripts/landmarks/field_notes.gd")

var _data: Dictionary


func _init(content: Dictionary) -> void:
	_data = content


func normalize(input: Variant) -> Dictionary:
	var raw: Dictionary = input if input is Dictionary and valid_version(input.get("version")) else {}
	var settings: Dictionary = _record(raw.get("settings"))
	var story: Dictionary = _record(raw.get("journey")) if raw.get("version") == 2 else {}
	var completed: Array = known_ids(raw.get("completed"), ids("activities"))
	var conversations: Array = known_ids(story.get("conversations"), ids("chapters"))
	var observed: Array = known_ids(story.get("encounters"), ids("encounters"))
	var atlas := FieldNotes.normalize(raw.get("atlas") if raw.get("version") == 2 else null)
	var seals: Array = []
	for station: String in known_ids(story.get("trailSeals"), ids("stages")):
		if Trails.get_trail(station).get("encounter", "") in observed:
			seals.append(station)
	var choices: Dictionary = {}
	var requested: Array = known_ids(story.get("claimed"), ids("chapters"))
	var claimed: Array = []
	var incoming_choices: Dictionary = _record(story.get("choices"))
	for chapter: Dictionary in _data.get("chapters", []):
		var choice: Variant = incoming_choices.get(chapter.id)
		for option: Dictionary in chapter.choices:
			if choice is String and choice == option.id:
				choices[chapter.id] = choice
	for chapter: Dictionary in _data.get("chapters", []):
		if not requested.has(chapter.id) or not completed.has(chapter.requiredGame) or not conversations.has(chapter.id) or observed_in(chapter.id, observed) + FieldNotes.observed_in(chapter.id, atlas) < 2:
			break
		claimed.append(chapter.id)
	var paint: Dictionary = {}
	var incoming_paint: Dictionary = _record(raw.get("paint"))
	for index: int in range(16):
		var key: String = str(index)
		var color: Variant = incoming_paint.get(key)
		if color is String and _data.get("pigmentColors", []).has(color):
			paint[key] = color
	var volume: Variant = settings.get("musicVolume")
	return {
		"version": 2, "completed": completed,
		"atlas": atlas,
		"discoveries": known_ids(raw.get("discoveries"), ids("facts")), "paint": paint,
		"settings": {
			"sound": _boolean(settings, "sound", true),
			"narration": _boolean(settings, "narration", false),
			"reducedMotion": _boolean(settings, "reducedMotion", false),
			"music": _boolean(settings, "music", true),
			"musicVolume": clampf(float(volume), 0.0, 1.0) if is_number(volume) and is_finite(float(volume)) else 0.35,
		},
		"journey": {
			"started": _boolean(story, "started", false) or not conversations.is_empty() or not claimed.is_empty() or not seals.is_empty(),
			"conversations": conversations, "encounters": observed, "claimed": claimed, "choices": choices,
			"trailSeals": seals,
			"endingSeen": _boolean(story, "endingSeen", false) and claimed.size() == _data.get("chapters", []).size(),
		},
		"camp": normalize_camp(raw.get("camp") if raw.get("version") == 2 else null, conversations),
	}


func normalize_camp(input: Variant, conversations: Array) -> Dictionary:
	var raw: Dictionary = _record(input)
	var accepted: Array = []
	var delivered: Array = []
	var requested_accepted: Array = raw.get("accepted", []) if raw.get("accepted") is Array else []
	var requested_delivered: Array = raw.get("delivered", []) if raw.get("delivered") is Array else []
	for letter: Dictionary in _data.get("letters", []):
		if requested_accepted.has(letter.id) and conversations.has(letter.from):
			accepted.append(letter.id)
			if requested_delivered.has(letter.id):
				delivered.append(letter.id)
	var available: Array = decoration_ids(delivered)
	var layout: Dictionary = {}
	var requested_layout: Dictionary = _record(raw.get("layout"))
	for spot: Dictionary in _data.get("campSpots", []):
		var item: Variant = requested_layout.get(spot.id)
		if item is String and available.has(item) and not layout.values().has(item):
			layout[spot.id] = item
	var notes: Array = []
	for note: Variant in _data.get("defaultCampNotes", [0, 2, 3, 2, 1, -1, 0, -1]):
		notes.append(int(note))
	var requested_notes: Variant = raw.get("notes")
	if requested_notes is Array and requested_notes.size() == 8:
		notes = []
		for note: Variant in requested_notes:
			notes.append(int(note) if valid_note(note) else -1)
	return {
		"accepted": accepted, "delivered": delivered, "layout": layout,
		"sky": "dawn" if raw.get("sky") is String and raw.get("sky") == "dawn" else "night", "notes": notes,
		"voice": raw.get("voice") if ids("campVoices").has(raw.get("voice")) else "bell",
		"tempo": 100 if is_number(raw.get("tempo")) and raw.get("tempo") == 100 else 80,
		"customized": _boolean(raw, "customized", false),
	}


func merge(current: Dictionary, incoming: Dictionary) -> Dictionary:
	var result: Dictionary = incoming.duplicate(true)
	result.completed = current.completed + incoming.completed
	result.discoveries = current.discoveries + incoming.discoveries
	result.paint = current.paint.duplicate(true)
	result.paint.merge(incoming.paint, true)
	result.camp = (incoming.camp if incoming.camp.customized else current.camp).duplicate(true)
	result.camp.accepted = current.camp.accepted + incoming.camp.accepted
	result.camp.delivered = current.camp.delivered + incoming.camp.delivered
	result.journey.started = current.journey.started or incoming.journey.started
	for field: String in ["conversations", "encounters", "claimed", "trailSeals"]:
		result.journey[field] = current.journey[field] + incoming.journey[field]
	result.journey.choices = current.journey.choices.duplicate(true)
	result.journey.choices.merge(incoming.journey.choices, true)
	result.journey.endingSeen = current.journey.endingSeen or incoming.journey.endingSeen
	result.atlas = FieldNotes.merge(current.atlas, incoming.atlas)
	return normalize(result)


func decoration_ids(delivered: Array) -> Array:
	var result: Array = []
	for item: Dictionary in _data.get("decorations", []):
		var unlocked: bool = true
		for letter: Dictionary in _data.get("letters", []):
			if letter.reward == item.id and not delivered.has(letter.id):
				unlocked = false
		if unlocked:
			result.append(item.id)
	return result


func observed_in(stage_id: String, observed: Array) -> int:
	var count: int = 0
	for item: Dictionary in _data.get("encounters", []):
		if item.stageId == stage_id and observed.has(item.id):
			count += 1
	return count


func ids(collection: String) -> Array:
	var result: Array = []
	for item: Dictionary in _data.get(collection, []):
		result.append(item.id)
	return result


func by_id(collection: String, id: String) -> Dictionary:
	for item: Dictionary in _data.get(collection, []):
		if item.id == id:
			return item
	return {}


static func known_ids(value: Variant, allowed: Array) -> Array:
	var result: Array = []
	if value is Array:
		for id: Variant in value:
			if id is String and allowed.has(id) and not result.has(id):
				result.append(id)
	return result


static func valid_version(value: Variant) -> bool:
	return is_number(value) and (value == 1 or value == 2)


static func valid_note(value: Variant) -> bool:
	return is_number(value) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= -1 and value <= 4


static func is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _record(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _boolean(value: Dictionary, key: String, fallback: bool) -> bool:
	return value[key] if value.get(key) is bool else fallback
