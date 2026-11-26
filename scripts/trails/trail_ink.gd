extends RefCounted

const INK := Color("294c4c")
const JADE := Color("337a6e")
const GOLD := Color("edc47e")
const PAPER := Color("f5dfae")
const RUST := Color("ac5645")

static func shape(c: CanvasItem, at: Vector2, points: Array, fill: Color, scale := 1.0, angle := 0.0) -> void:
	var poly := PackedVector2Array()
	for p: Vector2 in points: poly.append(at + (p * scale).rotated(angle))
	c.draw_colored_polygon(poly, fill)

static func oval(c: CanvasItem, at: Vector2, radii: Vector2, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 36: points.append(at + (Vector2.from_angle(i * TAU / 36) * radii).rotated(angle))
	c.draw_colored_polygon(points, color)

static func hoof(c: CanvasItem, at: Vector2, angle: float, sc := 1.0, color := INK) -> void:
	for side: float in [-1.0, 1.0]:
		var piece: Array = []
		for p: Vector2 in [Vector2(-11,-3),Vector2(-16,-6),Vector2(-16,-11),Vector2(-11,-15),Vector2(-3,-16),Vector2(8,-12),Vector2(20,-3),Vector2(11,-4),Vector2(2,-3)]:
			piece.append(Vector2(p.x, p.y * side))
		shape(c, at, piece, color, sc, angle)

static func bird(c: CanvasItem, at: Vector2, angle: float) -> void:
	for diff: float in [-.65, 0.0, .65]:
		c.draw_line(at, at + Vector2.from_angle(angle + diff) * 22, RUST, 4, true)
	c.draw_line(at, at - Vector2.from_angle(angle) * 14, RUST, 4, true)

static func leaf(c: CanvasItem, at: Vector2, angle: float, sc := 1.0, dry := false) -> void:
	var col := Color("a27852") if dry else JADE
	var poly := [Vector2(-22,0),Vector2(-15,-9),Vector2(-6,-14),Vector2(3,-14),Vector2(15,-8),Vector2(24,0),Vector2(12,8),Vector2(4,12),Vector2(-7,12),Vector2(-17,6)]
	shape(c,at,poly,col,sc,angle)
	for k in [-1,0,1]:
		var a := Vector2(-12 + k * 5,0).rotated(angle) * sc
		var b := Vector2(18 if k == 0 else 3, k * 7).rotated(angle) * sc
		c.draw_line(at+a,at+b,Color("dfd29d"), 1.6 * sc, true)
	if not dry:
		var d := at + Vector2(5,-12) * sc
		c.draw_circle(d, 7 * sc, Color("8ccbc2"), true, -1, true)
		c.draw_circle(d + Vector2(-2,-2) * sc, 2 * sc, Color("fff4c7"), true, -1, true)

static func bell(c: CanvasItem, at: Vector2, sc := 1.0) -> void:
	c.draw_arc(at + Vector2(0,-12)*sc, 8*sc, PI, TAU, 20, RUST, 4*sc, true)
	shape(c,at,[Vector2(-20,12),Vector2(-15,4),Vector2(-13,-10),Vector2(-7,-16),Vector2(6,-16),Vector2(13,-11),Vector2(16,3),Vector2(21,12)],Color("bd8145"),sc)
	c.draw_line(at+Vector2(-17,8)*sc,at+Vector2(18,8)*sc,GOLD,3*sc,true)
	c.draw_circle(at+Vector2(0,15)*sc,5*sc,INK,true,-1,true)
	c.draw_arc(at,24*sc,-.65,.23,14,RUST,2*sc,true)

static func grapes(c: CanvasItem, at: Vector2, sc := 1.0) -> void:
	for p: Vector2 in [Vector2(-10,-6), Vector2(5,-8), Vector2(15,-3), Vector2(-6,4), Vector2(7,6), Vector2(2,16)]:
		c.draw_circle(at+p*sc,8.5*sc,Color("5d4864"),true,-1,true)
		c.draw_circle(at+(p+Vector2(-2,-2))*sc,4.7*sc,Color("96768c"),true,-1,true)
	leaf(c,at+Vector2(-5,-20)*sc,-.4,sc*.55,true)

static func wheel(c: CanvasItem, p: Vector2, sc := 1.0) -> void:
	c.draw_arc(p,22*sc,0,TAU,48,GOLD,4*sc,true)
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0)
		c.draw_line(p,p+dir*23*sc,GOLD,2.4*sc,true)
		c.draw_line(p+dir*22*sc,p+dir*27*sc+dir.orthogonal()*4*sc,GOLD,4*sc,true)
	c.draw_circle(p,4*sc,Color("f7e5b3"),true,-1,true)
	c.draw_line(p+Vector2(-5,26)*sc,p,Color("cf945b"),3*sc,true)
	c.draw_line(p+Vector2(6,26)*sc,p,Color("cf945b"),3*sc,true)

static func gate(c: CanvasItem, p: Vector2, sc := 1.0) -> void:
	shape(c,p,[Vector2(-30,-4),Vector2(-17,-12),Vector2(-12,-17),Vector2(12,-17),Vector2(17,-12),Vector2(30,-4)],GOLD,sc)
	shape(c,p,[Vector2(-25,-18),Vector2(-13,-24),Vector2(0,-30),Vector2(14,-23),Vector2(25,-18)],Color("d48560"),sc)
	c.draw_rect(Rect2(p+Vector2(-18,-4)*sc,Vector2(36,23)*sc),Color("d99567"))
	c.draw_circle(p+Vector2(0,11)*sc,7*sc,INK)
	c.draw_rect(Rect2(p+Vector2(-7,11)*sc,Vector2(14,10)*sc),INK)
	for x in [-12,0,12]: c.draw_line(p+Vector2(x,-16)*sc,p+Vector2(x,-11)*sc,PAPER,2.3*sc,true)

static func sun(c: CanvasItem, p: Vector2, sc := 1.0) -> void:
	c.draw_circle(p,13*sc,Color("ffe098"),true,-1,true)
	for i in 8:
		var dir := Vector2.from_angle(i*PI/4)
		c.draw_line(p+dir*17*sc,p+dir*23*sc,GOLD,3*sc,true)

static func lantern(c: CanvasItem, p: Vector2, sc := 1.0) -> void:
	oval(c,p,Vector2(16,19)*sc,0,Color("d2875b"))
	c.draw_arc(p,12*sc,-1.1,1.1,14,GOLD,2*sc,true)
	for y in [-18,18]: c.draw_line(p+Vector2(-12,y)*sc,p+Vector2(12,y)*sc,GOLD,4*sc,true)
	c.draw_line(p+Vector2(0,18)*sc,p+Vector2(0,28)*sc,GOLD,2*sc,true)

static func mirror(c: CanvasItem, p: Vector2, slash: bool, sc := 1.0) -> void:
	c.draw_circle(p,37*sc,Color("112e36"),true,-1,true)
	c.draw_arc(p,36*sc,0,TAU,64,Color("b78b57"),3*sc,true)
	c.draw_arc(p,30*sc,.15,1.15,16,GOLD,2*sc,true)
	c.draw_arc(p,30*sc,PI+.15,PI+1.15,16,GOLD,2*sc,true)
	var diagonal := Vector2(1,-1 if slash else 1)*19*sc
	c.draw_line(p-diagonal,p+diagonal,Color("b87d50"),11*sc,true)
	c.draw_line(p-diagonal-Vector2(0,2)*sc,p+diagonal-Vector2(0,2)*sc,Color("c5eada"),5*sc,true)

static func flourish(c: CanvasItem, rect: Rect2, col: Color) -> void:
	for edge: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
		var p := rect.position + rect.size * edge
		var d := Vector2.ONE - 2 * edge
		c.draw_polyline(PackedVector2Array([p+Vector2(36,0)*d,p,p+Vector2(0,34)*d]),col,2,true)
		c.draw_polyline(PackedVector2Array([p+Vector2(22,5)*d,p+Vector2(9,5)*d,p+Vector2(5,9)*d,p+Vector2(5,20)*d]),col,1.2,true)
		c.draw_circle(p+Vector2(10,10)*d,2.2,col,true,-1,true)
