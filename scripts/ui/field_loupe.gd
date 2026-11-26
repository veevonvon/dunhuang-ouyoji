extends Control

const LensGlass = preload("res://scripts/ui/field_loupe.gdshader")
var target := Vector2.ZERO
var center := Vector2.ZERO
var diameter := 200.0
var finger := -99
var glass: ColorRect
var optics := ShaderMaterial.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_CROSS
	var source := BackBufferCopy.new()
	source.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	source.show_behind_parent = true
	add_child(source)
	optics.shader = LensGlass
	glass = ColorRect.new()
	glass.mouse_filter = MOUSE_FILTER_IGNORE
	glass.material = optics
	add_child(glass)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if size.x <= 0 or size.y <= 0: return
	diameter = clampf(minf(size.x,size.y)*.30,160,260)
	move_lens(size*.5 if target.is_zero_approx() else target)

func move_lens(point: Vector2) -> void:
	target = point.clamp(Vector2.ZERO,size)
	var radius := diameter * .5
	var offset := Vector2(0,-radius*.90) if target.y > diameter else Vector2(0,radius*.90)
	center = (target+offset).clamp(Vector2.ONE*(radius+4),size-Vector2.ONE*(radius+4))
	glass.position = center - Vector2.ONE*radius
	glass.size = Vector2.ONE*diameter
	var view_size := get_viewport_rect().size.max(Vector2.ONE)
	var transform := get_global_transform_with_canvas()
	optics.set_shader_parameter("sample_center", (transform * target) / view_size)
	optics.set_shader_parameter("sample_extent", Vector2.ONE * diameter / 2.35 / view_size)
	queue_redraw()

func _draw() -> void:
	var r := diameter*.47
	var brass := Color("edcf8f")
	var axis := Vector2(.65,.76)
	draw_line(center+axis*(r-8),center+axis*(r+36),Color("53382b"),15,true)
	draw_line(center+axis*(r+2),center+axis*(r+31),Color("be8a50"),7,true)
	draw_circle(center+axis*(r+34),7,brass,true,-1,true)
	draw_circle(center,r+4,Color("583d2d"),true,-1,true)
	draw_arc(center,r+3,0,TAU,105,brass,3.5,true)
	draw_arc(center,r-1,0,TAU,105,Color("ae753f"),2,true)
	draw_arc(target,10,0,TAU,32,brass,2,true)

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and finger == -99:
			finger = event.index
			move_lens(event.position)
		elif event.index == finger and not event.pressed: cancel_input()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		move_lens(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		finger = -1 if event.pressed else -99
		if event.pressed: move_lens(event.position)
		accept_event()
	elif event is InputEventMouseMotion and finger == -1:
		move_lens(event.position)
		accept_event()

func cancel_input() -> void:
	finger = -99
