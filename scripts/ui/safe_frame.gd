extends MarginContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()

func update_safe_area() -> void:
	var padding := Vector4(26, 22, 26, 22)
	if OS.get_name() == "Android":
		var pixels: Vector2 = DisplayServer.window_get_size()
		var safe: Rect2 = DisplayServer.get_display_safe_area()
		var logical := get_viewport_rect().size
		var ratio := logical / pixels.max(Vector2.ONE)
		padding.x += maxf(0, safe.position.x) * ratio.x
		padding.y += maxf(0, safe.position.y) * ratio.y
		padding.z += maxf(0, pixels.x - safe.end.x) * ratio.x
		padding.w += maxf(0, pixels.y - safe.end.y) * ratio.y
	add_theme_constant_override("margin_left", int(padding.x))
	add_theme_constant_override("margin_top", int(padding.y))
	add_theme_constant_override("margin_right", int(padding.z))
	add_theme_constant_override("margin_bottom", int(padding.w))
