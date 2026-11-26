extends Button

const Art = preload("res://scripts/ui/edition_art.gd")
var station := ""
var caption := ""
var collected := false
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var album := false
var treasure: Texture2D
var title_font: Font
var body_font: Font

func configure(id: String, title: String, earned: bool, in_album := false) -> void:
	station = id
	caption = title
	collected = earned
	album = in_album
	tooltip_text = title
	accessibility_name = title
	custom_minimum_size = Vector2(140, 154)

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	focus_mode = FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	treasure = Art.seal(station)
	title_font = load("res://assets/fonts/scroll_titles.tres")
	body_font = GameTheme.make().default_font
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if not treasure: return
	var font_height := 48 if album else 38
	var side := minf(size.x - 20, size.y - font_height)
	var center := Vector2(size.x / 2, (size.y - font_height) / 2 + 2)
	var radius := side * .47
	var offset := Vector2.DOWN * 2 if is_pressed() else Vector2.ZERO
	var ink := Color("204547") if album else Color("143a42eb")
	draw_circle(center + Vector2.DOWN * 3, radius + 1, Color("162f3344"), true, -1, true)
	draw_circle(center, radius, ink, true, -1, true)
	draw_arc(center, radius - 1, 0, TAU, 80, Color("bca475"), 1.6, true)
	if selected or has_focus() or is_hovered():
		draw_arc(center, radius + 3, 0, TAU, 80, GameTheme.GOLD, 2.4, true)
	var tint := Color("a2b9b1") if album and not collected else Color.WHITE
	draw_texture_rect(treasure, Rect2(center - Vector2.ONE * side / 2 + offset, Vector2.ONE * side), false, tint)
	var base_y := size.y - font_height
	if not album:
		var width := minf(size.x - 8, maxf(88, title_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x + 34))
		var left := (size.x - width) / 2
		var tag := PackedVector2Array([Vector2(left+7,base_y+2),Vector2(left+width-7,base_y+2),Vector2(left+width,base_y+18),
			Vector2(left+width-7,base_y+34),Vector2(left+7,base_y+34),Vector2(left,base_y+18)])
		draw_colored_polygon(tag, Color("163a3c"))
		tag.append(tag[0])
		draw_polyline(tag, Color("d3b577"), 1.5, true)
	draw_string(title_font, Vector2(0, base_y + 27), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, GameTheme.INK if album else GameTheme.LIGHT)
	if album:
		draw_string(body_font, Vector2(0, size.y), "已拓印" if collected else "待寻纹", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("435953"))
	if collected:
		var mark := center + Vector2(.65, .65) * radius
		draw_circle(mark, 10, Color("a6503a"), true, -1, true)
		draw_arc(mark, 10, 0, TAU, 24, GameTheme.GOLD, 1.5, true)
		draw_polyline(PackedVector2Array([mark+Vector2(-4,0),mark+Vector2(-1,3),mark+Vector2(5,-4)]), GameTheme.LIGHT, 2, true)
