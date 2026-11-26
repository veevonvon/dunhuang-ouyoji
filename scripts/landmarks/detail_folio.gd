extends Control

signal reference_changed

const P = preload("res://scripts/landmarks/detail_patterns.gd")
const Reference = preload("res://scripts/landmarks/detail_reference.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
const HEADINGS := {"trace":"描出画里的路","pair":"给墨样配对","turn":"转正三块画片","echo":"听画里的声音","uncover":"轻擦出原纹","order":"按顺序入册"}
var site: Dictionary
var detail: Dictionary
var state: RefCounted
var board: Control
var painting: Texture2D
var source_rect: Rect2
var thumb: Rect2
var spine := 0.
var ink_title: Label
var instruction: Label
var keyline: Label
var right_title: Label
var shadow: Font
var reference: BaseButton
var enlarged_reference: BaseButton

func configure(place: Dictionary, activity: Dictionary, puzzle: RefCounted, game_board: Control, art: Texture2D) -> void:
	site=place
	detail=activity
	state=puzzle
	board=game_board
	painting=art

func _label(caption: String, size_value: int, color: Color, heading := false) -> Label:
	var l:=Ui.heading(caption,size_value,color) if heading else Ui.label(caption,size_value,color)
	l.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	add_child(l)
	return l

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	shadow=Ui.make().default_font
	ink_title=_label(detail.title,34,P.INK,true)
	instruction=_label(detail.instruction,22,P.INK)
	keyline=_label("",18,Color("765c42"))
	right_title=_label("在水里找倒影" if state.reflected_pair else HEADINGS.get(state.kind,"观察原纹"),24,P.INK,true)
	add_child(board)
	if site.id=="mogao" and detail.id=="lotus_rabbits":
		reference=Reference.new()
		reference.name="HareReference"
		reference.configure(false)
		add_child(reference)
		enlarged_reference=Reference.new()
		enlarged_reference.name="LargeHareReference"
		enlarged_reference.configure(true)
		enlarged_reference.hide()
		add_child(enlarged_reference)
		reference.pressed.connect(func(): set_reference_open(not enlarged_reference.visible))
		enlarged_reference.pressed.connect(func(): set_reference_open(false))
	resized.connect(_place)
	_place()

func set_reference_open(open: bool) -> void:
	if not enlarged_reference or open==enlarged_reference.visible: return
	board.cancel_input()
	enlarged_reference.visible=open
	board.visible=not open
	reference.set_enlarged(open)
	right_title.text="莲花井心 · 三兔共耳" if open else str(HEADINGS[state.kind])
	if open: enlarged_reference.grab_focus()
	else: reference.grab_focus()
	reference_changed.emit()

func _guide() -> String:
	match state.kind:
		"trace","order": return " → ".join(state.pieces)
		"turn": return "看金尖，找朱线。"
		"pair": return "上排看原样，下排找倒影。" if state.reflected_pair else "上排是彩稿，下排是墨样。"
		"echo": return "看亮起的图案，也听它的声音。"
		"uncover": return "点一下也能看清纹样。"
	return ""

func _place() -> void:
	if not board or not ink_title or size.x<300 or size.y<120: return
	var inset:=clampf(size.x*.032,25,50)
	spine=clampf(size.x*.31,293.,405.)
	var usable:=spine-inset*2.+3
	var y0:=clampf(size.y*.056,19,32)
	ink_title.position=Vector2(inset+3,y0)
	ink_title.size=Vector2(usable,53)
	thumb=Rect2(inset+3,y0+66,usable,minf(maxf(94,size.y*.29),170))
	if reference:
		thumb.size.y=clampf(size.y*.47,165.,265.)
		reference.position=thumb.position
		reference.size=thumb.size
	elif painting:
		var native_size:=painting.get_size()
		var center:=native_size*Vector2(float(detail.x),float(detail.y))
		var crop_w:=native_size.x*.49
		var crop_extent:=Vector2(crop_w,crop_w*thumb.size.y/thumb.size.x)
		if crop_extent.y>native_size.y*.78: crop_extent*=native_size.y*.78/crop_extent.y
		source_rect=Rect2((center-crop_extent*.5).clamp(Vector2.ZERO,native_size-crop_extent),crop_extent)
	var text_y:=thumb.end.y+(7 if reference else 21)
	instruction.position=Vector2(inset+3,text_y)
	instruction.size=Vector2(usable,76)
	keyline.text=_guide()
	keyline.position=Vector2(inset+3,maxf(text_y+74,size.y-74))
	keyline.size=Vector2(usable,55)
	right_title.position=Vector2(spine+inset+7,y0+3)
	right_title.size=Vector2(size.x-spine-inset*2-110,42)
	board.position=Vector2(spine+15,y0+58)
	board.size=Vector2(size.x-spine-inset*.55-21,size.y-board.position.y-21)
	if enlarged_reference:
		enlarged_reference.position=board.position
		enlarged_reference.size=board.size
	queue_redraw()

func _edge(y: float, h: float, right: float, offset: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(6,y+6)+Vector2.DOWN*offset,Vector2(spine-15,y+2)+Vector2.DOWN*offset,Vector2(spine,y+7)+Vector2.DOWN*offset,Vector2(spine+20,y)+Vector2.DOWN*offset,Vector2(right-10,y+3)+Vector2.DOWN*offset,Vector2(right,y+11)+Vector2.DOWN*offset,Vector2(right-3,h-7)+Vector2.DOWN*offset,Vector2(spine+16,h-11)+Vector2.DOWN*offset,Vector2(spine,h-5)+Vector2.DOWN*offset,Vector2(spine-15,h-10)+Vector2.DOWN*offset,Vector2(6,h-5)+Vector2.DOWN*offset,Vector2(1,y+22)+Vector2.DOWN*offset])

func _draw() -> void:
	if not painting or not shadow or size.x<300 or size.y<120: return
	var h:=size.y-5
	var end:=size.x-2
	var dark:=_edge(1,h,end,5)
	draw_colored_polygon(dark,Color("122d2fc9"))
	draw_colored_polygon(_edge(1,h,end,2),Color("ba9e74"))
	draw_colored_polygon(_edge(0,h,end,0),Color("efe1c0"))
	var right:=PackedVector2Array([Vector2(spine,8),Vector2(spine+22,2),Vector2(end-9,4),Vector2(end-1,11),Vector2(end-4,h-8),Vector2(spine+20,h-12),Vector2(spine,h-6)])
	draw_colored_polygon(right,Color("f7ebce"))
	for x in 15:
		var tint:=Color("876b47")
		tint.a=(1.-x/15.)*.075
		P.line(self,Vector2(spine-x,8),Vector2(spine-x,h-8),tint,1.2)
		P.line(self,Vector2(spine+x,9),Vector2(spine+x,h-7),Color(tint,tint.a*.6),1.1)
	P.line(self,Vector2(spine,9),Vector2(spine,h-8),Color("ac906b9c"),1.35)
	var rng:=RandomNumberGenerator.new()
	rng.seed=10481
	for i in 260:
		var p:=Vector2(rng.randf_range(12,end-12),rng.randf_range(13,h-16))
		var dx:=rng.randf_range(2,10)
		P.line(self,p,p+Vector2(dx,rng.randf_range(-1.2,1.2)),Color("936e4813"),.8)
	for y in [.20,.48,.79]:
		var c:=Vector2(spine,h*y)
		draw_circle(c-Vector2(6,0),1.8,Color("907655"),true,-1,true)
		draw_circle(c+Vector2(7,1),1.8,Color("907655"),true,-1,true)
		P.curve(self,c-Vector2(6,0),c+Vector2(7,1),3,Color("b29b72"),1.8)
	if thumb.has_area() and not reference:
		draw_rect(Rect2(thumb.position+Vector2(2,3),thumb.size).grow(4),Color("9e805c73"))
		draw_rect(thumb.grow(4),Color("f9efd2"))
		draw_texture_rect_region(painting,thumb,source_rect)
		draw_rect(thumb,Color("998560a6"),false,1.,true)
		for side in [-1,1]:
			var c:=thumb.position+Vector2(9,8) if side<0 else thumb.end-Vector2(9,8)
			P.line(self,c-Vector2(12,-8),c+Vector2(12,-8),Color("c39d5c9a"),4.)
	var family:=P.MOTIFS.find(str(state.motif))
	if family>=0:
		P.art(self,family*3,Vector2(spine-49,ink_title.position.y+25),52.,0.,Color(.82,.79,.65,.85))
	var at:=right_title.position+Vector2(-13,20) if right_title else Vector2.ZERO
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-5),at+Vector2(4,0),at+Vector2(0,5),at+Vector2(-4,0)]),P.RUBY)
	P.line(self,Vector2(spine+29,board.position.y-3),Vector2(end-27,board.position.y-3),Color("a98e654d"),1.)
	for i in 3:
		var c:=Vector2(end-92+i*22,at.y)
		if i<state.found.size(): P.seal(self,c,7.5,P.JADE)
		else: draw_arc(c,6.5,0,TAU,26,Color("ae9b77"),1.5,true)
