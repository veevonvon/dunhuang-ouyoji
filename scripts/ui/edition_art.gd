extends RefCounted

static func seal(station: String) -> Texture2D:
	return load("res://assets/edition/seals/%s.webp" % station)

static func face(station: String) -> Texture2D:
	return load("res://assets/edition/friends/%s.webp" % station)

static func picture(texture: Texture2D, extent: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = extent
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art

static func gradient(top: Color, bottom: Color) -> Texture2D:
	var image := GradientTexture2D.new()
	image.width = 2
	image.height = 256
	image.fill_to = Vector2(0, 1)
	image.gradient = Gradient.new()
	image.gradient.colors = PackedColorArray([top, bottom])
	return image

static func scrim(parent: Control, height: float, from: Color, to: Color, at_bottom := false) -> void:
	var shade := TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = gradient(from, to)
	parent.add_child(shade)
	if at_bottom:
		shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		shade.offset_top = -height
	else:
		shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		shade.offset_bottom = height
