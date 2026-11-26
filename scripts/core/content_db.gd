extends Node

const CONTENT_PATH: String = "res://data/content.json"

var data: Dictionary = load_content()


static func load_content() -> Dictionary:
	var file: FileAccess = FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("旅行内容无法读取：" + CONTENT_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("旅行内容格式有误：" + CONTENT_PATH)
		return {}
	return parsed


func all(collection: String) -> Array:
	var items: Variant = data.get(collection, [])
	return items if items is Array else []


func by_id(collection: String, id: String) -> Dictionary:
	for item: Variant in all(collection):
		if item is Dictionary and item.get("id") == id:
			return item
	return {}


func image_path(id: String) -> String:
	return str(data.get("images", {}).get(id, ""))


func voice_path(id: String) -> String:
	return str(data.get("voices", {}).get(id, ""))
