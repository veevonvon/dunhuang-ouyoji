extends Button

const Art = preload("res://scripts/ui/edition_art.gd")
const Catalog = preload("res://scripts/landmarks/catalog.gd")
var place: Dictionary
var discoveries := 0
var featured := false
var has_stamp := false
var picture: Texture2D
var ink: Texture2D
var headline: Font

func configure(site: Dictionary, page: Dictionary, large: bool) -> void:
	place = site
	discoveries = page.details.size()
	has_stamp = Catalog.fieldwork_done(site, page)
	featured = large
	name = "Visit_" + str(site.id)
	accessibility_name = str(place.name)
	tooltip_text = str(place.name)
	custom_minimum_size = Vector2(215, 95)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	flat = true
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _ready() -> void:
	picture = Catalog.painting(place.id)
	ink = Art.gradient(Color("122e3100"), Color("112a30f5"))
	headline = load("res://assets/fonts/scroll_titles.tres")
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if not picture or not headline: return
	var area := Rect2(Vector2(4,4), size - Vector2(8,8))
	var extent := picture.get_size()
	var factor := maxf(area.size.x / extent.x, area.size.y / extent.y)
	var crop := area.size / factor
	draw_rect(Rect2(Vector2.ZERO, size), Color("302b24"))
	draw_texture_rect_region(picture, area, Rect2((extent-crop)/2, crop))
	var shadow := area
	shadow.position.y += area.size.y * (.40 if featured else .12)
	shadow.size.y = area.end.y - shadow.position.y
	draw_texture_rect(ink, shadow, false)
	var trim := GameTheme.LIGHT if has_focus() or is_hovered() else Color("d4b17b")
	draw_rect(area.grow(2), trim, false, 2, true)
	draw_rect(area.grow(-2), Color("cfad6f8a"), false, 1, true)
	if has_stamp:
		var seal := Rect2(Vector2(17, 15), Vector2(58, 34))
		draw_rect(seal, Color("984735"))
		draw_rect(seal.grow(-2.5), Color("f4d9a6"), false, 1.25, true)
		draw_string(headline,seal.position+Vector2(0,24),"采风",HORIZONTAL_ALIGNMENT_CENTER,seal.size.x,21,GameTheme.LIGHT)
	var font_size := 42 if featured else 28
	var x := 24.0
	var y := area.end.y - (50 if featured else 19)
	var label := str(place.name)
	while font_size > 18 and headline.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > area.size.x - 110: font_size -= 1
	draw_string(headline, Vector2(x,y), label, HORIZONTAL_ALIGNMENT_LEFT, area.size.x-66, font_size, GameTheme.LIGHT)
	if featured:
		draw_string(GameTheme.make().default_font, Vector2(x,y+31),"走进画中",HORIZONTAL_ALIGNMENT_LEFT,-1,20,GameTheme.GOLD)
	var start := Vector2(area.end.x-73, area.end.y-24)
	for i in 3:
		var dot := start + Vector2(20*i, 0)
		draw_circle(dot, 6.5, Color("1b3536"),true,-1,true)
		draw_arc(dot, 6.5, 0, TAU, 28, GameTheme.GOLD, 1.6,true)
		if i < discoveries: draw_circle(dot, 4, GameTheme.GOLD,true,-1,true)
