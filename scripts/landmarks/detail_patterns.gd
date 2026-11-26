extends RefCounted

# The atlas contains three original ink drawings per subject. Parts with their own
# name borrow that subject, so a sketched hoof, flower or roof can be recognized by shape.
const Specimens = preload("res://scripts/landmarks/detail_specimens.gd")
const ATLAS = preload("res://scripts/landmarks/detail_motifs.svg")
const MOTIFS := ["camel","water","sand","horse","roof","arch","lotus","ribbon","cloud","star","leaf","reed","rock","brick","bell","tower","bird","wave","sun","snow"]
const VOCABULARY := {
	"camel":"驼", "horse":"马蹄鬃", "water":"泉滴露池湖水", "sand":"沙丘砾",
	"roof":"檐脊瓦顶屋阁", "arch":"拱门洞券", "lotus":"莲瓣蕊花", "ribbon":"彩带绸织",
	"cloud":"云烟", "star":"星斗", "leaf":"叶杨柳芽枝树果", "reed":"苇芦穗草", "rock":"岩石峰山崖坡",
	"brick":"砖垛墙夯", "bell":"铃铎鼓钟", "tower":"塔楼台烽", "bird":"鸟翼羽雁燕鸽",
	"wave":"波纹浪涟漪", "sun":"日阳晖照", "snow":"冰雪霜",
}
const INK := Color("2f514e")
const PALE_INK := Color("73897b")
const PAPER := Color("f7e8c6")
const RUBY := Color("ac604c")
const GOLD := Color("bd9458")
const JADE := Color("649586")

static func subject(motif: String, words: Array, seed_value: int) -> Array[int]:
	var cells: Array[int] = []
	for i in words.size():
		var specimen: int = Specimens.BY_NAME.get(str(words[i]),-1)
		if specimen>=0 and 60+specimen not in cells:
			cells.append(60+specimen)
			continue
		var choice := motif
		for family: String in VOCABULARY:
			if family==motif: continue
			var applicable := false
			for character in str(words[i]):
				if str(VOCABULARY[family]).contains(character): applicable=true
			if applicable:
				choice=family
				break
		var start := maxi(0,MOTIFS.find(choice))*3
		var cell:=start+posmod(i+int(seed_value%3),3)
		if choice in ["camel","horse"] and (str(words[i]).contains("蹄") or str(words[i]).contains("脚印")):
			cell=start+(1 if choice=="camel" else 2)
		if choice=="bird" and (str(words[i]).contains("羽") or str(words[i]).contains("翅")): cell=start+1
		while cell in cells: cell=start+posmod(cell-start+1,3)
		cells.append(cell)
	return cells

static func art(c: CanvasItem, cell: int, at: Vector2, span: float, angle := 0., tint := Color.WHITE, reflect_vertical := false) -> void:
	var atlas: Texture2D=Specimens.SHEET if cell>=60 else ATLAS
	var grid: Vector2=Specimens.GRID if cell>=60 else Vector2(6,10)
	var index:=cell-60 if cell>=60 else cell
	var unit:=atlas.get_size()/grid
	var src:=Rect2(Vector2(index%int(grid.x),floori(index/grid.x))*unit,unit)
	var extent:=Vector2(span,span*.8)
	c.draw_set_transform(at,angle,Vector2(1,-1) if reflect_vertical else Vector2.ONE)
	c.draw_texture_rect_region(atlas,Rect2(-extent*.5,extent),src,tint)
	c.draw_set_transform(Vector2.ZERO)

static func line(c: CanvasItem, a: Vector2,b: Vector2,color: Color,width := 1.4) -> void:
	c.draw_line(a,b,color,width,true)

static func curve(c: CanvasItem, a: Vector2,b: Vector2,bend: float, color: Color,width: float,dotted := false) -> void:
	var points:=PackedVector2Array()
	var side:=(b-a).normalized().orthogonal()*bend
	for i in 33:
		var t:=i/32.
		var at:=a.bezier_interpolate(a+(b-a)*.28+side,b-(b-a)*.28+side,b,t)
		if dotted and i%3==0: c.draw_circle(at,maxf(1.,width*.64),color,true,-1,true)
		points.append(at)
	if not dotted: c.draw_polyline(points,color,width,true)

static func oval(c: CanvasItem, at: Vector2, extent: Vector2, color: Color) -> void:
	var vertices:=PackedVector2Array()
	for i in 40: vertices.append(at+extent*Vector2.from_angle(TAU*i/40.))
	c.draw_colored_polygon(vertices,color)

static func seal(c: CanvasItem, p: Vector2, radius: float, fill: Color) -> void:
	c.draw_circle(p,radius,fill,true,-1,true)
	c.draw_arc(p,radius-.8,0,TAU,36,PAPER,1.15,true)
	c.draw_polyline(PackedVector2Array([p+Vector2(-.42,-.01)*radius,p+Vector2(-.09,.30)*radius,p+Vector2(.50,-.31)*radius]),PAPER,maxf(1.6,radius*.18),true)
