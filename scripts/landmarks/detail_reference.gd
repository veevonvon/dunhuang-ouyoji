extends Button

const Figure = preload("res://scripts/landmarks/detail_shared_ears.svg")
const Ui = preload("res://scripts/ui/game_theme.gd")
const INK := Color("38605a")
var large := false
var enlarged := false
var lettering: Font

func configure(big: bool) -> void:
	large = big
	flat = true
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	lettering = Ui.make().default_font
	set_enlarged(false)

func set_enlarged(open: bool) -> void:
	enlarged = open
	accessibility_name = "收起三兔共耳整图，回到转盘" if large or open else "放大第407窟莲花井心的三兔共耳整图"
	tooltip_text = accessibility_name
	queue_redraw()

func figure_rect() -> Rect2:
	var h := maxf(1.,size.y-35.)
	var span := maxf(1.,minf(size.x-12.,h))
	return Rect2(Vector2((size.x-span)*.5,(h-span)*.5+1.),Vector2.ONE*span)

func _draw() -> void:
	if not lettering or size.y<40: return
	var bounds := figure_rect()
	draw_texture_rect(Figure,bounds,false)
	var caption := "点图回到转盘" if large or enlarged else "第407窟 · 点图放大"
	var font_size := 19 if large else 17
	var half := lettering.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5
	var center := Vector2(size.x*.5,size.y-12)
	var color := Color("944f3c") if is_hovered() or has_focus() else INK
	draw_string(lettering,Vector2(0,center.y),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,font_size,color)
	draw_line(center+Vector2(-half,5),center+Vector2(half,5),Color(color,.60),1.,true)
	if has_focus(): draw_rect(bounds.grow(1.5),Color("b38d59"),false,1.5,true)
