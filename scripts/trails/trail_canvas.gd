extends Control

const Ink = preload("res://scripts/trails/trail_ink.gd")
const PAPER := Color("eddab1")
const INK := Color("25464a")
const GOLD := Color("f3cd83")
const FRAME := Vector2(800, 400)
var state: RefCounted
var scenery: Texture2D
var painting: Texture2D
var reduced_motion := false
var pointer := -99
var origin := -1
var pressed_at := Vector2.ZERO
var fingertip := Vector2.ZERO
var pending: Array[int] = []
var focus_index := 0
var keyboard_focus := false
var ripple := 0.0
var rippled := -1
var from_offset := 0

func configure(model: RefCounted, quiet: bool) -> void:
	state = model
	reduced_motion = quiet
	scenery = load("res://assets/images/%s.jpg" % state.id)
	if state.info.kind == "register":
		painting = load("res://assets/trails/%s-scroll.svg" % ("pipa" if state.id == "guazhou" else "lotus"))

func unit() -> float:
	return minf(size.x / FRAME.x, size.y / FRAME.y)

func inset() -> Vector2:
	return (size - FRAME * unit()) * .5

func local_point(local: Vector2) -> Vector2:
	return (local - inset()) / maxf(.001, unit())

func region_count() -> int:
	match state.info.kind:
		"track": return state.info.nodes.size()
		"mirror": return state.mirrors.size()
	return state.offsets.size()

func grid(cell: Vector2i) -> Vector2:
	return Vector2(85 + cell.x * 157, 84 + cell.y * 114)

func canvas_region(i: int) -> Rect2:
	match state.info.kind:
		"track": return Rect2(state.info.nodes[i] - Vector2(41,41), Vector2(82,82))
		"mirror": return Rect2(grid(state.info.mirrors[i]) - Vector2(45,45), Vector2(90,90))
		_:
			var picture := painting_rect()
			if state.id == "guazhou":
				var lane := picture.size.y / 4
				return Rect2(picture.position + Vector2(0, (i+1)*lane), Vector2(picture.size.x,lane))
			var lane := picture.size.x / 4
			return Rect2(picture.position + Vector2((i+1)*lane,0), Vector2(lane,picture.size.y))

func painting_rect() -> Rect2:
	return Rect2(32,20,736,360)

func region_rect(i: int) -> Rect2:
	var r := canvas_region(i)
	return Rect2(inset()+r.position*unit(),r.size*unit())

func hit(local: Vector2) -> int:
	for i in region_count():
		if region_rect(i).has_point(local): return i
	return -1

func _draw() -> void:
	if state == null or minf(size.x,size.y)<1: return
	draw_set_transform(inset(), 0, Vector2.ONE * unit())
	var area := Rect2(Vector2.ZERO, FRAME)
	var dark: bool = state.info.kind != "track"
	draw_rect(area,Color("153d44") if dark else PAPER)
	var texture_size := scenery.get_size()
	var src := Rect2(Vector2.ZERO, texture_size)
	var ratio := FRAME.aspect()
	if texture_size.aspect() < ratio:
		src.size.y = texture_size.x / ratio
		src.position.y = (texture_size.y - src.size.y) * .5
	else:
		src.size.x = texture_size.y * ratio
		src.position.x = (texture_size.x - src.size.x) * .5
	draw_texture_rect_region(scenery,area,src,Color(1,1,1,.18 if dark else .22))
	if state.info.kind == "track": draw_tracks()
	elif state.info.kind == "mirror": draw_optics()
	else: draw_register()
	draw_rect(area.grow(-2),Color("a67c50"),false,4)
	draw_rect(area.grow(-6),Color("dcb67a"),false,1)
	Ink.flourish(self,area.grow(-12),GOLD if dark else Color("99774e"))
	if state.hint >= 0: mark_region(state.hint,GOLD,true)
	if state.wrong >= 0: mark_region(state.wrong,Color("a74536"),false)
	if keyboard_focus and has_focus(): mark_region(focus_index,Color("fdf1be"),true)
	if ripple > 0 and rippled >= 0 and state.info.kind != "register":
		var p := canvas_region(rippled).get_center()
		draw_arc(p,38+(1-ripple)*14,0,TAU,64,Color(1,.83,.48,ripple),3,true)

func mark_region(i: int, color: Color, corners: bool) -> void:
	var r := canvas_region(i)
	if state.info.kind == "register": draw_rect(r.grow(-3),color,false,5)
	else:
		var p := r.get_center()
		draw_arc(p,38,0,TAU,60,Color("6f503b"),7,true)
		draw_arc(p,38,0,TAU,60,color,4,true)
		if corners:
			Ink.shape(self,p+Vector2(0,-43),[Vector2(-5,-8),Vector2(5,-8),Vector2(0,0)],color)
		else:
			draw_line(p+Vector2(26,22),p+Vector2(36,32),color,4,true)
			draw_line(p+Vector2(36,22),p+Vector2(26,32),color,4,true)

func curve(a: Vector2, b: Vector2, bend: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var control := (a+b)*.5 + (b-a).orthogonal().normalized()*bend
	for i in 19:
		var t := i/18.0
		points.append(a.lerp(control,t).lerp(control.lerp(b,t),t))
	return points

func track_link(a: int, b: int, dry: bool) -> void:
	var nodes: Array = state.info.nodes
	var dashed: bool = state.id == "wuwei"
	var points := curve(nodes[a], nodes[b], (20 if a % 2 == 0 else -26))
	if dashed:
		for t in [5,9,13]:
			var angle := (points[t+1]-points[t]).angle()
			if dry:
				draw_dashed_line(points[t],points[t]+Vector2.from_angle(angle)*6,Color("8b7158a8"),2.5,3,true)
			else: Ink.hoof(self,points[t],angle,.28,Color("866448af"))
	else:
		draw_polyline(points,Color("876749") if dry else Color("3c7059"),3 if dry else 6,true)
		draw_polyline(points,Color("b4986a") if dry else Color("8ca579"),1.5,true)
		var side := 1 if a%2 == 0 else -1
		for t in [5,12]:
			var p := points[t]
			var tip := p + Vector2(7, side * 11)
			draw_line(p,tip,Color("817251"),2,true)
			Ink.leaf(self,tip,side*-.8,.35,dry)

func draw_tracks() -> void:
	var nodes: Array = state.info.nodes
	var route: Array = state.info.route
	var branches := [[0,1],[2,3],[4,6]] if state.id == "wuwei" else [[0,2],[3,4],[6,5]]
	for pair in branches: track_link(pair[0],pair[1],true)
	for index in range(1,route.size()): track_link(route[index-1],route[index],false)
	var shown: Array = state.trail.duplicate()
	for i in pending:
		if shown.size() < route.size() and i == route[shown.size()]: shown.append(i)
		elif shown.is_empty() or i != shown.back(): break
	for index in range(1,shown.size()):
		var line := curve(nodes[shown[index-1]],nodes[shown[index]],20 if int(shown[index-1])%2 == 0 else -26)
		draw_polyline(line,Color("955d3d"),8,true)
		draw_polyline(line,GOLD,4,true)
		if ripple > 0 and shown[index] == rippled:
			var mote := line[mini(line.size()-1, int((1-ripple)*line.size()))]
			draw_circle(mote,9,Color("f5c36266"),true,-1,true)
			draw_circle(mote,4,Color("fff6c5"),true,-1,true)
	for i in nodes.size():
		var p: Vector2 = nodes[i]
		var index: int = route.find(i)
		var active := i in shown
		if active or i in [0,route.back()]:
			draw_circle(p,31,Color("9c7859"),true,-1,true)
			draw_circle(p,28,Color("f6deb0"),true,-1,true)
			draw_arc(p,24,0,TAU,48,Color("c99b64"),1.6,true)
		if i == route.back():
			if state.id == "wuwei": Ink.bell(self,p,.96)
			else: Ink.grapes(self,p,.94)
		elif state.id == "wuwei":
			if index < 0: Ink.bird(self,p,-.65 + i*.29)
			else: Ink.hoof(self,p,(Vector2(nodes[route[index+1]])-p).angle(),.94,Ink.INK if not active else Ink.JADE)
		else:
			Ink.leaf(self,p,(-.38 if i%2 else .28),1.13,index<0)
		if i == 0:
			Ink.shape(self,p+Vector2(-26,-19),[Vector2(-8,-18),Vector2(5,-20),Vector2(7,9),Vector2(1,3),Vector2(-5,10)],Ink.RUST)
	if not shown.is_empty():
		var p: Vector2 = nodes[shown.back()]
		draw_arc(p,32,0,TAU,48,Ink.JADE,4,true)

func draw_optics() -> void:
	for x in 5:
		var a := grid(Vector2i(x,0))
		draw_dashed_line(a-Vector2(0,39),a+Vector2(0,267),Color("d6c69944"),1.5,5)
	for y in 3:
		var a := grid(Vector2i(0,y))
		draw_dashed_line(a-Vector2(37,0),a+Vector2(666,0),Color("d6c69944"),1.5,5)
	for x in 5:
		for y in 3:
			var joint := grid(Vector2i(x,y))
			draw_circle(joint,3.2,Color("c9ac77"),true,-1,true)
	var trace: Dictionary = state.trace_light()
	var beam := PackedVector2Array()
	for v: Vector2i in trace.points: beam.append(grid(v).clamp(Vector2(26,26),FRAME-Vector2(26,26)))
	draw_polyline(beam,Color("f3b46941"),16,true)
	draw_polyline(beam,Color("e7a35f"),7,true)
	draw_polyline(beam,Color("fff2b9"),3,true)
	for i in range(1,beam.size()):
		var d := (beam[i]-beam[i-1]).normalized()
		if beam[i].distance_to(beam[i-1]) > 78:
			var m := beam[i-1].lerp(beam[i],.55)
			Ink.shape(self,m,[Vector2(7,0),Vector2(-4,-5),Vector2(-4,5)],GOLD,1,d.angle())
	if ripple > 0:
		var length := 0.0
		for i in range(1,beam.size()): length += beam[i].distance_to(beam[i-1])
		var distance := (1.0-ripple)*length
		for i in range(1,beam.size()):
			var segment := beam[i].distance_to(beam[i-1])
			if distance <= segment:
				var spark := beam[i-1].move_toward(beam[i],distance)
				draw_circle(spark,10,Color("ffdc8466"),true,-1,true)
				draw_circle(spark,4.5,Color("fffbd9"),true,-1,true)
				break
			distance -= segment
	var source := grid(state.info.source)
	var target := grid(state.info.goal)
	for p: Vector2 in [source,target]:
		draw_circle(p,35,Color("264b50"),true,-1,true)
		draw_arc(p,34,0,TAU,48,Color("e3b779"),2,true)
	if state.id == "zhangye":
		Ink.sun(self,source)
		Ink.wheel(self,target)
	else:
		Ink.lantern(self,source)
		Ink.gate(self,target)
	for i in state.mirrors.size():
		Ink.mirror(self,grid(state.info.mirrors[i]),state.mirrors[i])
	if not trace.lit:
		var end := beam[beam.size()-1]
		draw_circle(end,6,GOLD,true,-1,true)
		draw_arc(end,10,0,TAU,32,Color("e7c999"),1.6,true)

func draw_register() -> void:
	var rect := painting_rect()
	var horizontal: bool = state.id == "guazhou"
	var tex_size := painting.get_size()
	# Each band shows a different crop of one painting. Sliding reveals a new registration.
	for band in 4:
		var cell := rect
		var src := Rect2(Vector2.ZERO,tex_size)
		if horizontal:
			cell.size.y /= 4
			cell.position.y += cell.size.y*band
			src.size.y /= 4
			src.position.y += src.size.y*band
		else:
			cell.size.x /= 4
			cell.position.x += cell.size.x*band
			src.size.x /= 4
			src.position.x += src.size.x*band
		var offset := 0.0 if band == 0 else float(state.offsets[band-1])*(82 if horizontal else 45)
		if band > 0 and ripple > 0 and rippled == band-1:
			offset = lerpf(offset,from_offset*(82.0 if horizontal else 45.0),ripple*ripple)
		if pointer != -99 and origin == band-1 and band > 0:
			var diff := local_point(fingertip)-local_point(pressed_at)
			offset += clampf(diff.x if horizontal else diff.y,-70,70)
		# Wrap the silk around the rollers. No empty margin discloses the solution.
		var length := cell.size.x if horizontal else cell.size.y
		var advance := fposmod(offset,length)
		for part in 2:
			var dest := cell
			var crop := src
			var start := advance if part == 0 else 0.0
			var extent := length-advance if part == 0 else advance
			if extent <= .01: continue
			var fraction := extent/length
			if horizontal:
				dest.position.x += start
				dest.size.x = extent
				crop.position.x += 0.0 if part == 0 else src.size.x*(1-fraction)
				crop.size.x *= fraction
			else:
				dest.position.y += start
				dest.size.y = extent
				crop.position.y += 0.0 if part == 0 else src.size.y*(1-fraction)
				crop.size.y *= fraction
			draw_texture_rect_region(painting,dest,crop)
		if band > 0:
			var edge := Vector2(cell.size.x,0) if horizontal else Vector2(0,cell.size.y)
			draw_line(cell.position,cell.position+edge,Color("254147"),3,true)
			draw_line(cell.position+Vector2(1,1),cell.position+edge+Vector2(1,1),Color("dbbd82"),1,true)
			var handle := Vector2(cell.end.x-18,cell.get_center().y) if horizontal else Vector2(cell.get_center().x,cell.end.y-15)
			draw_circle(handle,10,Color("285053"),true,-1,true)
			if state.offsets[band-1] == 0:
				draw_polyline(PackedVector2Array([handle+Vector2(-5,0),handle+Vector2(-1,4),handle+Vector2(5,-4)]),Color("bcdfbc"),2.5,true)
				continue
			for s in [-1,1]:
				var dir := Vector2(s,0) if horizontal else Vector2(0,s)
				var p := handle+dir*3
				draw_polyline(PackedVector2Array([p+dir.orthogonal()*3,p+dir*3,p-dir.orthogonal()*3]),GOLD,1.7,true)
	draw_rect(rect.grow(2),Color("d0ae72"),false,3)
