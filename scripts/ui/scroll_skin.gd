extends StyleBox

var top := Color("225050")
var bottom := Color("122e33")
var metal := Color("c59b61")
var panel := false

func _init() -> void:
	content_margin_left = 18
	content_margin_right = 18
	content_margin_top = 10
	content_margin_bottom = 10

func bevel(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var q := rect.end
	cut = clampf(cut, 0, minf(rect.size.x, rect.size.y) * .3)
	return PackedVector2Array([Vector2(p.x + cut, p.y), Vector2(q.x - cut, p.y),
		Vector2(q.x, p.y + cut), Vector2(q.x, q.y - cut), Vector2(q.x - cut, q.y),
		Vector2(p.x + cut, q.y), Vector2(p.x, q.y - cut), Vector2(p.x, p.y + cut)])

func outline(canvas: RID, shape: PackedVector2Array, color: Color, width: float) -> void:
	shape.append(shape[0])
	RenderingServer.canvas_item_add_polyline(canvas, shape, PackedColorArray([color]), width, true)

func _draw(canvas: RID, rect: Rect2) -> void:
	if rect.size.x < 8 or rect.size.y < 8: return
	var cut := 14.0 if panel else 10.0
	var face := rect.grow(-1)
	var shadow := face
	shadow.position.y += 3
	RenderingServer.canvas_item_add_polygon(canvas, bevel(shadow, cut), PackedColorArray([Color("0b202167")]))
	var edge := bevel(face, cut)
	var colors := PackedColorArray()
	for point in edge:
		colors.append(top.lerp(bottom, (point.y - face.position.y) / face.size.y))
	RenderingServer.canvas_item_add_polygon(canvas, edge, colors)
	outline(canvas, edge, metal, 1.7)
	var inset := Color(metal, .45)
	outline(canvas, bevel(face.grow(-4), cut - 2), inset, 1)
	if panel and face.size.x > 220:
		for flip in [false, true]:
			var axis := -1.0 if flip else 1.0
			var start := Vector2(face.end.x - 11 if flip else face.position.x + 11, face.position.y + 9)
			var decor := PackedVector2Array([start + Vector2(0, 13), start + Vector2(0, 7),
				start + Vector2(7 * axis, 0), start + Vector2(23 * axis, 0)])
			RenderingServer.canvas_item_add_polyline(canvas, decor, PackedColorArray([metal]), 1, true)
