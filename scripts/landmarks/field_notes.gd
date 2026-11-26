extends RefCounted

const Catalog = preload("res://scripts/landmarks/catalog.gd")

static func normalize(raw: Variant) -> Dictionary:
	var clean := {"lastSite":"", "places":{}}
	if not raw is Dictionary or not raw.get("places") is Dictionary: return clean
	for key: Variant in raw.places:
		if not key is String: continue
		var site := Catalog.lookup(key)
		var incoming: Variant = raw.places[key]
		if site.is_empty() or not incoming is Dictionary: continue
		var page := Catalog.fresh_page()
		if Catalog.SEASONS.has(incoming.get("season")): page.season = incoming.season
		if Catalog.PHASES.has(incoming.get("phase")): page.phase = incoming.phase
		if incoming.get("details") is Array:
			for item: Dictionary in site.details:
				if item.id in incoming.details: page.details.append(item.id)
		if incoming.get("prints") is Array:
			for season: String in Catalog.SEASONS:
				for phase: String in Catalog.PHASES:
					var print_id := season + ":" + phase
					if print_id in incoming.prints: page.prints.append(print_id)
		clean.places[key] = page
	if clean.places.has(raw.get("lastSite")): clean.lastSite = raw.lastSite
	return clean

static func merge(local: Dictionary, imported: Dictionary) -> Dictionary:
	var result := local.duplicate(true)
	for id: String in imported.places:
		var page: Dictionary = imported.places[id].duplicate(true)
		if local.places.has(id):
			page.details.append_array(local.places[id].details)
			page.prints.append_array(local.places[id].prints)
		result.places[id] = page
	if imported.lastSite != "": result.lastSite = imported.lastSite
	return result

static func observed_in(station: String, book: Dictionary) -> int:
	var count := 0
	for id: String in book.get("places", {}):
		if not book.places[id].details.is_empty() and Catalog.lookup(id).get("station") == station:
			count += 1
	return count
