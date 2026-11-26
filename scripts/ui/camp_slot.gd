extends Button

signal item_dropped(item_id: String)
var item_id := ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty(): return null
	var preview := GameTheme.label("轻轻放好", 24)
	set_drag_preview(preview)
	return {"decoration": item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("decoration") is String

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(str(data.decoration))
