extends Button

var plate: Texture2D
var row: int
var column: int
var kept: bool

func configure(sheet: Texture2D, season: int, hour: int, owned: bool) -> void:
	plate = sheet
	row = season
	column = hour
	kept = owned
	flat = true
	custom_minimum_size = Vector2(88,68)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var frame := Rect2(Vector2(2,2),size-Vector2(4,4))
	draw_rect(frame,Color("e8c990") if kept else Color("9b9579"))
	if plate:
		var tile := plate.get_size() / 4
		var rect := frame.grow(-3.0)
		var ratio := minf(tile.x / rect.size.x, tile.y / rect.size.y)
		var crop := rect.size * ratio
		var origin := Vector2(column,row)*tile + (tile-crop)/2
		draw_texture_rect_region(plate,rect,Rect2(origin,crop),Color.WHITE if kept else Color("c4c5b7"))
	if kept:
		var seal := frame.end - Vector2(15,13)
		draw_rect(Rect2(seal-Vector2(11,10),Vector2(22,20)), Color("934332"))
		draw_polyline(PackedVector2Array([seal+Vector2(-6,0),seal+Vector2(-2,4),seal+Vector2(6,-6)]),GameTheme.LIGHT,2.3,true)
	if has_focus() or is_hovered(): draw_rect(frame,GameTheme.GOLD,false,3,true)
