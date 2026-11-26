extends Button

const Art = preload("res://scripts/ui/edition_art.gd")
var caption := ""
var art: Texture2D
var bright := false
var icon_id := ""
var font: Font

func configure(title: String, image: Texture2D, glyph: String, main := false) -> void:
	caption = title
	art = image
	icon_id = glyph
	bright = main
	tooltip_text = title
	accessibility_name = title
	custom_minimum_size = Vector2(114, 117) if main else Vector2(96, 102)
	size_flags_vertical = SIZE_SHRINK_END
	size_flags_horizontal = SIZE_SHRINK_END
	flat = true
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _ready() -> void:
	font = GameTheme.make().default_font
	if not art:
		var icon := GameTheme.icon(icon_id, Vector2(35,35))
		icon.position = Vector2(size.x / 2 - 17.5, size.y - 81)
		add_child(icon)

func _draw() -> void:
	if not font: return
	var center := Vector2(size.x / 2, size.y - (63 if bright else 58))
	var radius := 43.0 if bright else 34.0
	if is_pressed(): center.y += 2
	draw_circle(center + Vector2(1,3), radius+3, Color("182d31a5"), true, -1, true)
	draw_circle(center, radius+2, Color("4c3d2c"), true, -1, true)
	draw_circle(center, radius, Color("86493b") if bright else Color("204849f4"), true, -1, true)
	draw_arc(center, radius, 0, TAU, 76, GameTheme.GOLD, 2, true)
	draw_arc(center, radius-4, 0, TAU, 72, Color("d8b47e7d"), 1.0, true)
	if art:
		var diameter := (radius - 3) * 2
		draw_texture_rect(art, Rect2(center-Vector2.ONE*diameter/2, Vector2.ONE*diameter), false)
	if has_focus() or is_hovered(): draw_arc(center, radius+5, 0, TAU, 80, GameTheme.LIGHT, 2, true)
	var label_width := maxf(74, font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+16)
	var x := (size.x-label_width)/2
	var y := size.y-30
	var tag := PackedVector2Array([Vector2(x+7,y),Vector2(x+label_width-7,y),Vector2(x+label_width,y+12),Vector2(x+label_width-7,y+26),Vector2(x+7,y+26),Vector2(x,y+12)])
	draw_colored_polygon(tag,Color("873d32") if bright else Color("183d3f"))
	tag.append(tag[0])
	draw_polyline(tag,Color("d0b278"),1.3,true)
	draw_string(font,Vector2(0,y+20),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,20,GameTheme.LIGHT)
