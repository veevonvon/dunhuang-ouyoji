extends Button

const Ui = preload("res://scripts/ui/game_theme.gd")
const NUMBERS := ["一", "二", "三"]
var detail: Dictionary
var number := 0
var found := false
var scene: Control
var body: Font

func configure(owner_scene: Control, item: Dictionary, index: int) -> void:
	scene = owner_scene
	detail = item
	number = index
	name = "Point_" + str(detail.id)
	custom_minimum_size = Vector2(116,81)
	size = custom_minimum_size
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button_mask = 0
	flat = true
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	body = Ui.make().default_font
	set_found(false)

func set_found(value: bool) -> void:
	found = value
	tooltip_text = str(detail.title)
	accessibility_name = str(detail.title) + ("，已观察" if value else "，开始观察")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		scene.begin_point(self,event.index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		scene.begin_point(self,-1)
		accept_event()

func _draw() -> void:
	if not body: return
	var p := Vector2(size.x*.5,24)
	var gold := Color("f6d899")
	var deep := Color("163e40")
	var fill := Color("934f39") if found else deep
	var emph := has_focus() or is_hovered()
	draw_circle(p+Vector2.DOWN*2,21.7,Color("111e2280"),true,-1,true)
	draw_circle(p,20.7,fill,true,-1,true)
	draw_arc(p,19.3,0,TAU,48,gold,2.1,true)
	draw_arc(p,15.5,0,TAU,42,Color("ccb58a90"),1,true)
	if found:
		draw_polyline(PackedVector2Array([p+Vector2(-7,0),p+Vector2(-2,5),p+Vector2(8,-6)]),Ui.LIGHT,3,true)
	else:
		draw_string(body,p+Vector2(-16,7),NUMBERS[number],HORIZONTAL_ALIGNMENT_CENTER,32,20,Ui.LIGHT)
	if emph: draw_arc(p,23.8,0,TAU,48,Ui.LIGHT,1.8,true)
	var label := str(detail.title)
	var width := clampf(body.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+21,54,size.x-2)
	var x := (size.x-width)*.5
	var strip:=PackedVector2Array([Vector2(x+5,43),Vector2(x+width-5,43),Vector2(x+width,54),Vector2(x+width-5,65),Vector2(x+5,65),Vector2(x,54)])
	draw_colored_polygon(strip,deep)
	strip.append(strip[0])
	draw_polyline(strip,Color("d7b880"),1.2,true)
	draw_string(body,Vector2(0,60),label,HORIZONTAL_ALIGNMENT_CENTER,size.x,17,Ui.LIGHT)
	draw_line(Vector2(p.x,65),Vector2(p.x,76),Color("433b2c"),3,true)
	draw_line(Vector2(p.x,65),Vector2(p.x,76),gold,1.4,true)
	draw_circle(Vector2(p.x,77),3.3,gold,true,-1,true)
