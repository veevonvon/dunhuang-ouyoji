extends Control

signal changed(cue: String)
signal note_requested(pitch: int)
signal demonstration_changed

const P = preload("res://scripts/landmarks/detail_patterns.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
const Rubbing = preload("res://scripts/landmarks/detail_rubbing.gd")
const NUMBERS := ["一","二","三"]
var state: RefCounted
var reduced_motion := false
var pointer := -99
var origin := -1
var finger := Vector2.ZERO
var stroke: Array[int] = []
var rubbing: RefCounted
var keyboard_slot := 0
var keyboard_mode := false
var demo_index := -1
var demo_elapsed := 0.0
var sounding := -1
var flash := 0.0
var last_action := -1
var body: Font
var title_font: Font

func configure(puzzle: RefCounted, reduced: bool) -> void:
	state=puzzle
	reduced_motion=reduced
	if puzzle.kind=="uncover": rubbing=Rubbing.new(puzzle.seed_value)

func _ready() -> void:
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	body=Ui.make().default_font
	title_font=load("res://assets/fonts/scroll_titles.tres")
	resized.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_input()
	)
	set_process(false)

func region_count() -> int:
	return 6 if state.kind=="pair" else 3

func progress_count() -> int:
	return state.found.size()

func target_name(index: int) -> String:
	return str(state.pieces[state.value_at(index)])

func note_for_pad(index: int) -> int:
	return state.pitches[state.value_at(index)]

func unit() -> float:
	return minf(size.x/730.,size.y/380.)

func _center(index: int) -> Vector2:
	var column:=index%3
	var x: float=[.19,.5,.81][column]
	var y:=.49
	match state.kind:
		"trace":
			var positions: Array=[[.57,.29,.58],[.38,.65,.32],[.64,.35,.49]][int(state.seed_value/13.)%3]
			y=float(positions[column])
		"pair": y=.28 if index<3 else .70
		"order": y=.69
		"echo": y=.48+(.03*(2-state.pitches[state.value_at(index)]))
		"uncover": y=[.48,.40,.52][column]
	return size*Vector2(x,y)

func region_rect(index: int) -> Rect2:
	var u:=unit()
	var extent := Vector2(145,135)*u
	if state.kind=="pair": extent=Vector2(145,103)*u
	if state.kind=="turn": extent=Vector2(165,168)*u
	extent=extent.max(Vector2(64,64)).min(Vector2(size.x*.31,size.y*.35))
	return Rect2(_center(index)-extent*.5,extent)

func _hit(p: Vector2) -> int:
	for i in region_count():
		if region_rect(i).has_point(p): return i
	return -1

func _text(caption: String, center: Vector2, width: float, font_size: int, ink: Color, heading := false) -> void:
	var font := title_font if heading else body
	draw_string(font,center-Vector2(width*.5,0),caption,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,ink)

func _numeral(p: Vector2, s: String, r: float, active: bool) -> void:
	draw_circle(p,r, P.RUBY if active else Color("ead8b2"),true,-1,true)
	draw_arc(p,r,0,TAU,40,Color("a57b52"),1.2,true)
	_text(s,p+Vector2(0,r*.46),r*2,int(r*1.26),P.PAPER if active else P.INK)

func _mark(i: int, p: Vector2, size_value: float) -> void:
	if state.is_marked(i): P.seal(self,p,size_value,P.JADE)
	elif state.hint and state.kind in ["trace","order"] and state.value_at(i)==state.found.size():
		draw_arc(p,size_value,0,TAU,32,P.RUBY,2.5,true)

func _draw() -> void:
	if not state or not body or unit()<.25: return
	match state.kind:
		"trace": _trace()
		"pair": _pair()
		"turn": _turn()
		"echo": _echo()
		"uncover": _uncover()
		"order": _order()
	if pointer!=-99 and state.kind!="uncover":
		draw_arc(finger,15*unit(),0,TAU,40,Color("9a735e9a"),2.0,true)
	if keyboard_mode and has_focus():
		var rect:=region_rect(keyboard_slot)
		draw_rect(rect.grow(2),P.RUBY,false,2.1,true)
	if flash>0 and last_action>=0 and not reduced_motion:
		draw_arc(_center(last_action),unit()*(45+(1.-flash)*23),0,TAU,52,Color(P.GOLD,flash*.64),2.3,true)

func _trace() -> void:
	var u:=unit()
	for n in 2:
		var a:=_center(state.index_of(n))
		var b:=_center(state.index_of(n+1))
		var direct:=(b-a).normalized()
		var color:=P.JADE if state.found.size()>n+1 else Color("a89770")
		P.curve(self,a+direct*41*u,b-direct*42*u,(13 if n==0 else -15)*u,color,2.*u,state.found.size()<=n+1)
	if pointer!=-99 and not stroke.is_empty():
		for n in range(stroke.size()-1): P.curve(self,_center(stroke[n]),_center(stroke[n+1]),0,Color(P.JADE,.66),3*u)
		P.line(self,_center(stroke.back()),finger,Color(P.JADE,.6),2.*u)
	for i in 3:
		var c:=_center(i)
		var item: int=state.value_at(i)
		P.oval(self,c+Vector2(0,22)*u,Vector2(48,9)*u,Color("967a4622"))
		P.art(self,state.cells[item],c,115*u)
		_numeral(c+Vector2(-48,-35)*u,NUMBERS[item],13*u,item==state.found.size())
		_text(target_name(i),c+Vector2.DOWN*64*u,150*u,int(23*u),P.INK,true)
		_mark(i,c+Vector2(47,29)*u,10*u)

func _pair() -> void:
	var u:=unit()
	for value: int in state.found:
		var a:=_center(state.index_of(value))+Vector2.DOWN*42*u
		var b:=_center(state.index_of(value,true))-Vector2.DOWN*37*u
		P.curve(self,a,b,(value-1)*8*u,Color(P.JADE,.7),2.4*u)
	if pointer!=-99 and origin>=0: P.line(self,_center(origin),finger,Color(P.GOLD,.65),2*u)
	for i in 6:
		var c:=_center(i)
		var item: int=state.value_at(i)
		var low:=i>=3
		if state.selected==i or (state.hint and state.selected>=0 and state.value_at(state.selected)==item and state.selected!=i):
			draw_arc(c,50*u,0,TAU,58,P.RUBY,2.*u,true)
		if low:
			var wash := Color("6ca4a441") if state.reflected_pair else Color("607a6930")
			P.oval(self,c+Vector2.DOWN*2*u,Vector2(58,40)*u,wash)
			var tint := Color(.41,.52,.43,.94) if not state.is_marked(i) else Color.WHITE
			if state.reflected_pair and not state.is_marked(i): tint=Color(.49,.66,.64,.94)
			P.art(self,state.cells[item],c,101*u,0,tint,state.reflected_pair)
		else: P.art(self,state.cells[item],c,103*u)
		if not low: _text(target_name(i),c+Vector2.DOWN*55*u,150*u,int(20*u),P.INK)
		_mark(i,c+Vector2(45,17)*u,10*u)
	if state.reflected_pair:
		P.curve(self,size*Vector2(.07,.49),size*Vector2(.93,.49),2.*u,Color("6d9794aa"),1.45*u)
		for riser in [.12,.43,.74]:
			P.curve(self,size*Vector2(riser,.504),size*Vector2(riser+.12,.504),2.*u,Color("88aaa473"),1.*u)
	else:
		P.line(self,size*Vector2(.07,.49),size*Vector2(.93,.49),Color("a58c603d"),1.)

func _turn() -> void:
	var u:=unit()
	for i in 3:
		var c:=_center(i)
		var item: int=state.value_at(i)
		var r:=64*u
		var target_angle: float = state.sightlines[item]*PI/2.-PI/2.
		var rotation: float = state.turns[item]*PI/2.
		var target_dir:=Vector2.from_angle(target_angle)
		var pointing:=Vector2.from_angle(target_angle+rotation)
		draw_circle(c+Vector2.DOWN*2*u,r,Color("8e774848"),true,-1,true)
		draw_circle(c,r,Color("e1c89b"),true,-1,true)
		draw_circle(c,r-7*u,Color("efe1bb"),true,-1,true)
		draw_arc(c,r,0,TAU,90,P.GOLD,1.6*u,true)
		draw_arc(c,r-7*u,0,TAU,90,Color("b39a6a"),1.25*u,true)
		for n in 16:
			var d:=Vector2.from_angle(n*TAU/16.)
			P.line(self,c+d*(r-3*u),c+d*(r+(4 if n%4==0 else 0)*u),P.GOLD,1.4*u)
		P.art(self,state.cells[item],c,85*u,rotation)
		P.line(self,c+target_dir*(r+3*u),c+target_dir*(r+14*u),P.RUBY,4*u)
		var tangent:=pointing.orthogonal()
		draw_colored_polygon(PackedVector2Array([c+pointing*(r-4*u),c+pointing*(r-16*u)+tangent*4.8*u,c+pointing*(r-16*u)-tangent*4.8*u]),Color("9a743c"))
		_text(target_name(i),c+Vector2.DOWN*100*u,155*u,int(23*u),P.INK,true)
		_mark(i,c+Vector2(48,48)*u,12*u)

func _echo() -> void:
	var u:=unit()
	var a:=Vector2(size.x*.06,size.y*.10)
	var b:=Vector2(size.x*.94,size.y*.10)
	P.curve(self,a,b,11*u,Color("957a51"),3.*u)
	for i in 3:
		var c:=_center(i)
		var value: int=state.value_at(i)
		var rad:=(56-float(state.pitches[value])*3)*u
		var lit:=sounding==i
		P.line(self,Vector2(c.x-9*u,a.y+7*u),c-Vector2(12*u,rad*.78),P.GOLD,1.7*u)
		P.line(self,Vector2(c.x+9*u,a.y+7*u),c+Vector2(12*u,-rad*.78),P.GOLD,1.7*u)
		P.oval(self,c+Vector2.DOWN*2*u,Vector2(rad,rad*.93),Color("a38551"))
		P.oval(self,c,Vector2(rad,rad*.91),Color("eed29a") if lit else Color("c4aa77"))
		draw_arc(c,rad*.75,0,TAU,58,Color("f3db9e"),2.1*u,true)
		P.art(self,state.cells[value],c,rad*1.32)
		if lit:
			for n in 2: draw_arc(c,rad+(7+n*7)*u,-2.8,2.8,52,Color(P.RUBY,.82-.32*n),2.0*u,true)
		_text(target_name(i),c+Vector2.DOWN*(rad+34*u),150*u,int(22*u),P.INK,true)
		if state.hint and not is_listening() and value==state.sequence[state.found.size()]:
			draw_circle(c+Vector2.DOWN*(rad+47*u),3*u,P.RUBY,true,-1,true)

func _rubbing_rect(index: int) -> Rect2:
	var extent:=Vector2(149,105)*unit()
	return Rect2(_center(index)-extent*.5,extent)

func _uncover() -> void:
	var u:=unit()
	for i in 3:
		var c:=_center(i)
		var item: int=state.value_at(i)
		P.art(self,state.cells[item],c,141*u)
		if not state.is_marked(i):
			draw_texture_rect(rubbing.picture(item),_rubbing_rect(i),false)
		_text(target_name(i),c+Vector2.DOWN*78*u,154*u,int(22*u),P.INK,true)
		_mark(i,c+Vector2(47,42)*u,11*u)
	if pointer!=-99: draw_arc(finger,20*u,.3,5.6,36,Color(P.RUBY,.65),1.6*u,true)

func _order() -> void:
	var u:=unit()
	for i in 3:
		var c:=Vector2(_center(i).x,size.y*.23)
		var e:=Vector2(112,79)*u
		P.line(self,c+Vector2(-e.x*.48,e.y*.44),c+Vector2(e.x*.48,e.y*.44),P.GOLD,2*u)
		if i<2:
			var mid:=Vector2((c.x+_center(i+1).x)*.5,c.y)
			P.line(self,mid-Vector2(14,0)*u,mid+Vector2(13,0)*u,Color("a68a5e"),1.6*u)
			draw_polyline(PackedVector2Array([mid+Vector2(7,-5)*u,mid+Vector2(14,0)*u,mid+Vector2(7,5)*u]),P.GOLD,1.6*u,true)
		if i<state.found.size(): P.art(self,state.cells[state.found[i]],c,100*u)
		else: _numeral(c,NUMBERS[i],15*u,i==state.found.size())
	for i in 3:
		var c:=_center(i)
		var item: int=state.value_at(i)
		if state.is_marked(i): P.seal(self,c,14*u,P.JADE)
		else:
			P.oval(self,c+Vector2(0,26)*u,Vector2(49,7)*u,Color("a2885726"))
			P.art(self,state.cells[item],c,110*u)
			_text(target_name(i),c+Vector2.DOWN*59*u,148*u,int(22*u),P.INK,true)
			_mark(i,c+Vector2(46,27)*u,9*u)

func is_listening() -> bool:
	return demo_index>=0

func start_demo() -> void:
	if state.kind!="echo" or state.done: return
	cancel_input()
	demo_index=0
	demo_elapsed=0.
	_sound_demo()
	set_process(true)

func _sound_demo() -> void:
	var value: int=state.sequence[demo_index]
	sounding=state.index_of(value)
	note_requested.emit(state.pitches[value])
	demonstration_changed.emit()
	queue_redraw()

func _process(delta: float) -> void:
	if is_listening():
		demo_elapsed+=delta
		if demo_elapsed>=.52:
			demo_elapsed=0.
			demo_index+=1
			if demo_index<3: _sound_demo()
			else:
				demo_index=-1
				sounding=-1
				demonstration_changed.emit()
		elif demo_elapsed>.37 and sounding>=0:
			sounding=-1
			queue_redraw()
	flash=maxf(0.,flash-delta*2.9)
	if not is_listening() and flash<=0:
		sounding=-1
		set_process(false)
	queue_redraw()

func cancel_gesture() -> void:
	pointer=-99
	origin=-1
	stroke.clear()
	if rubbing: rubbing.cancel()
	queue_redraw()

func cancel_input() -> void:
	cancel_gesture()
	var was_listening:=is_listening()
	demo_index=-1
	sounding=-1
	flash=0.
	set_process(false)
	if was_listening: demonstration_changed.emit()

func _apply(index: int) -> String:
	if state.done or is_listening(): return ""
	if state.kind=="echo":
		sounding=index
		note_requested.emit(note_for_pad(index))
	var cue: String=state.act(index)
	if cue.is_empty(): return cue
	last_action=index
	if not reduced_motion or state.kind=="echo":
		flash=1.
		set_process(true)
	queue_redraw()
	changed.emit(cue)
	return cue

func _begin(finger_id: int, p: Vector2) -> void:
	if pointer!=-99 or state.done or is_listening(): return
	origin=_hit(p)
	if origin<0: return
	pointer=finger_id
	finger=p
	stroke=[origin]
	if rubbing and not state.is_marked(origin):
		var cover:=_rubbing_rect(origin)
		rubbing.begin(state.value_at(origin),(p-cover.position)/cover.size)

	keyboard_mode=false
	grab_focus()
	queue_redraw()

func _move(p: Vector2) -> void:
	if state.kind=="trace":
		var steps:=maxi(1,ceili(finger.distance_to(p)/12.))
		for n in range(1,steps+1):
			var i:=_hit(finger.lerp(p,n/float(steps)))
			if i>=0 and stroke.back()!=i: stroke.append(i)
	elif rubbing and rubbing.active>=0:
		var cover:=_rubbing_rect(origin)
		rubbing.brush((p-cover.position)/cover.size)
	finger=p
	queue_redraw()

func _finish(p: Vector2) -> void:
	_move(p)
	var start:=origin
	var end:=_hit(p)
	var path:=stroke.duplicate()
	cancel_gesture()
	if end<0: return
	if state.kind=="trace":
		for index: int in path:
			if _apply(index) in ["win","miss"]: break
	elif state.kind=="pair" and start!=end and (start<3)!=(end<3):
		_apply(start)
		_apply(end)
	elif start==end: _apply(start)

func _gui_input(event: InputEvent) -> void:
	if not state or event.device==InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		_begin(event.index,event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_begin(-1,event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: keyboard_slot=posmod(keyboard_slot-1,region_count())
			KEY_RIGHT: keyboard_slot=posmod(keyboard_slot+1,region_count())
			KEY_DOWN,KEY_UP: keyboard_slot=posmod(keyboard_slot+(3 if state.kind=="pair" else 1),region_count())
			KEY_ENTER,KEY_SPACE: _apply(keyboard_slot)
			_: return
		keyboard_mode=true
		queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if pointer==-99 or event.device==InputEvent.DEVICE_ID_EMULATION: return
	var transform:=get_global_transform_with_canvas().affine_inverse()
	if event is InputEventScreenTouch and event.index==pointer:
		if event.canceled: cancel_gesture()
		elif not event.pressed: _finish(transform*event.position)
		else: return
	elif event is InputEventScreenDrag and event.index==pointer: _move(transform*event.position)
	elif event is InputEventMouseButton and pointer==-1 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: _finish(transform*event.position)
	elif event is InputEventMouseMotion and pointer==-1: _move(transform*event.position)
	else: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]: cancel_input()
