extends RefCounted

const PATH := "res://data/landmarks.json"
const SEASONS := ["spring", "summer", "autumn", "winter"]
const PHASES := ["dawn", "day", "dusk", "night"]
const NAMES := {"spring":"春天","summer":"夏天","autumn":"秋天","winter":"冬天",
	"dawn":"清晨","day":"白天","dusk":"黄昏","night":"黑夜"}
static var _sites: Dictionary = {}

static func sites() -> Array:
	if _sites.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not raw is Dictionary or not raw.get("sites") is Array:
			push_error("山河写生册无法读取。")
			return []
		for site: Dictionary in raw.sites:
			_sites[site.id] = site
	return _sites.values()

static func lookup(id: String) -> Dictionary:
	if _sites.is_empty(): sites()
	return _sites.get(id, {})

static func for_station(station: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for site: Dictionary in sites():
		if site.station == station: found.append(site)
	return found

static func detail(site: Dictionary, id: String) -> Dictionary:
	for item: Dictionary in site.get("details", []):
		if item.id == id: return item
	return {}

static func painting(id: String) -> Texture2D:
	return load("res://assets/landmarks/paintings/%s.webp" % id) as Texture2D

static func fresh_page() -> Dictionary:
	return {"season":"spring", "phase":"day", "details":[], "prints":[]}

static func next_sky(season: String, phase: String) -> Array:
	var clock := (PHASES.find(phase) + 1) % PHASES.size()
	var year := SEASONS.find(season)
	if clock == 0: year = (year + 1) % SEASONS.size()
	return [SEASONS[year], PHASES[clock]]

static func fieldwork_done(site: Dictionary, page: Dictionary) -> bool:
	var task: Dictionary = site.fieldwork
	return task.detail in page.details and task.views[0] in page.prints and task.views[1] in page.prints

static func sky_name(key: String) -> String:
	var parts := key.split(":")
	return str(NAMES[parts[0]]) + str(NAMES[parts[1]])
