extends "res://scripts/games/touch_board.gd"

var mural: Texture2D
const HISTORY_ART := {
	"zhangqian": preload("res://assets/images/wuwei.jpg"),
	"mogao": preload("res://assets/images/dunhuang.jpg"),
	"jiayuguan": preload("res://assets/images/jiayuguan.jpg"),
	"research": preload("res://assets/images/mural.jpg"),
}
const PIGMENT_NAMES := ["朱砂", "石绿", "石青", "金黄", "草绿", "月白"]
const THREAD_NAMES := {"red": "朱砂花", "teal": "青绿叶", "gold": "金太阳"}
const THREAD_SYMBOLS := {"red": "lotus", "teal": "leaf", "gold": "sun"}
const HISTORY_TITLES := {"zhangqian": "张骞通西域", "mogao": "莫高窟开窟", "jiayuguan": "嘉峪关建关", "research": "一起守护敦煌"}
const HISTORY_ERAS := {"zhangqian": "汉代", "mogao": "十六国", "jiayuguan": "明代", "research": "近现代"}

func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/images/mural.jpg"):
		mural = load("res://assets/images/mural.jpg")
	queue_redraw()

func _mural_slots() -> Array[Rect2]:
	var width := minf(size.x * 0.41, (size.y - 66) * 1.5)
	var whole := Rect2(Vector2(size.x * 0.27 - width / 2, (size.y - width / 1.5) / 2), Vector2(width, width / 1.5))
	var result: Array[Rect2] = []
	for i in range(6): result.append(Rect2(whole.position + Vector2(i % 3, i / 3) * whole.size / Vector2(3, 2), whole.size / Vector2(3, 2)))
	return result

func _mural_pieces() -> Array[Rect2]:
	var cell := Vector2(minf(132, size.x * 0.108), minf(112, (size.y - 115) / 2))
	var whole := Vector2(cell.x * 3 + 28, cell.y * 2 + 18)
	var start := Vector2(size.x * 0.76, size.y * 0.53) - whole / 2
	var result: Array[Rect2] = []
	for i in range(6): result.append(Rect2(start + Vector2(i % 3, i / 3) * (cell + Vector2(14, 18)), cell))
	return result

func _petal_centers() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var center := Vector2(size.x * 0.39, size.y * 0.46)
	for i in range(6): result.append(Vector3(center.x + (i - 2.5) * 70, center.y - 49 + absf(i - 2.5) * 13, (i - 2.5) * 0.22))
	for i in range(4): result.append(Vector3(center.x + (i - 1.5) * 83, center.y + 60 + absf(i - 1.5) * 6, (i - 1.5) * 0.24))
	return result

func _petal_polygon(petal: Vector3) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(13):
		var p := Vector2(0, 67).bezier_interpolate(Vector2(-50, 25), Vector2(-46, -33), Vector2(0, -72), float(i) / 12)
		result.append(p.rotated(petal.z) + Vector2(petal.x, petal.y))
	for i in range(13):
		var p := Vector2(0, -72).bezier_interpolate(Vector2(46, -33), Vector2(50, 25), Vector2(0, 67), float(i) / 12)
		result.append(p.rotated(petal.z) + Vector2(petal.x, petal.y))
	return result

func _palette_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var start := Vector2(size.x * 0.77 - 104, size.y / 2 - 142)
	for i in range(6): result.append(Rect2(start + Vector2(i % 2 * 112, i / 2 * 100), Vector2(100, 88)))
	return result

func _history_cards() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var width := minf(238, (size.x - 110) / 4)
	var start := Vector2((size.x - width * 4 - 54) / 2, 80)
	for i in range(4): result.append(Rect2(start + Vector2(i * (width + 18), 0), Vector2(width, size.y - 115)))
	return result

func _loom_cells(sample := false) -> Array[Rect2]:
	var cell := Vector2(54, 60) if sample else Vector2(86, minf(91, (size.y - 78) / 3))
	var origin_point := Vector2(size.x * 0.19, size.y * 0.54) if sample else Vector2(size.x * 0.57, size.y * 0.54)
	var start := origin_point - Vector2(cell.x * 4 + 24, cell.y * 3 + 16) / 2
	var result: Array[Rect2] = []
	for i in range(12): result.append(Rect2(start + Vector2(i % 4, i / 4) * (cell + Vector2(8, 8)), cell))
	return result

func _thread_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for i in range(3): result.append(Rect2(Vector2(size.x * 0.84, size.y / 2 - 142 + i * 100), Vector2(132, 84)))
	return result

func interaction_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not session: return result
	match session.state.kind:
		"mural":
			var slots := _mural_slots()
			var pieces := _mural_pieces()
			for i in range(6): result.append(region(slots[i], {"type": "cell", "index": i}, "target", "第%d个壁画位置" % (i + 1)))
			for i in range(6): result.append(region(pieces[i], {"type": "select", "index": session.state.order[i]}, "piece", "第%d片壁画" % (session.state.order[i] + 1)))
		"paint":
			var petals := _petal_centers()
			for i in range(10):
				var item := region(Rect2(Vector2(petals[i].x - 42, petals[i].y - 65), Vector2(84, 130)), {"type": "cell", "index": i}, "stroke", "第%d片花瓣" % (i + 1))
				item.polygon = _petal_polygon(petals[i])
				result.append(item)
			var palette := _palette_rects()
			for i in range(6): result.append(region(palette[i], {"type": "color", "index": i}, "tap", PIGMENT_NAMES[i]))
		"history":
			var cards := _history_cards()
			for i in range(4): result.append(region(cards[i], {"type": "select", "index": i}, "story", "第%d张故事卡" % (i + 1)))
		"weave":
			var cells := _loom_cells()
			for i in range(12): result.append(region(cells[i], {"type": "cell", "index": i}, "stroke", "第%d格彩带" % (i + 1)))
			var threads := _thread_rects()
			for i in range(3): result.append(region(threads[i], {"type": "thread", "color": ["red", "teal", "gold"][i]}, "tap", THREAD_NAMES[["red", "teal", "gold"][i]]))
	return result

func hit(point: Vector2) -> Dictionary:
	var regions := interaction_regions()
	for i in range(regions.size() - 1, -1, -1):
		if regions[i].has("polygon"):
			if Geometry2D.is_point_in_polygon(point, regions[i].polygon): return regions[i]
		elif regions[i].rect.has_point(point): return regions[i]
	return {}

func _draw() -> void:
	if not session: return
	match session.state.kind:
		"mural": _draw_mural()
		"paint": _draw_paint()
		"history": _draw_history()
		"weave": _draw_weave()
	draw_interaction_feedback()

func _draw_piece(rect: Rect2, index: int, opacity := 1.0) -> void:
	if mural:
		var cell := mural.get_size() / Vector2(3, 2)
		var source := Rect2(Vector2(index % 3, index / 3) * cell, cell)
		draw_texture_rect_region(mural, rect, source, Color(1, 1, 1, opacity))
	else:
		box(rect, PAPER)
		symbol("leaf" if index % 2 == 0 else "lotus", rect.get_center(), 48, RUST)

func _draw_mural() -> void:
	var slots := _mural_slots()
	var pieces := _mural_pieces()
	caption("让画里的小鹿慢慢出现", Vector2(size.x * 0.27, 24), 24)
	caption("选一片，送回它的位置", Vector2(size.x * 0.76, 24), 24)
	for i in range(6):
		var placed: bool = session.state.slots[i] == i
		_draw_piece(slots[i], i, 1.0 if placed else 0.2)
		draw_rect(slots[i], GOLD, false, 2)
		if not placed:
			draw_circle(slots[i].get_center(), 20, Color("ead7b0"))
			caption(str(i + 1), slots[i].get_center() + Vector2(0, 9), 25)
	for i in range(6):
		var piece: int = session.state.order[i]
		var placed: bool = session.state.slots.has(piece)
		box(pieces[i], PAPER, session.state.selected == piece)
		_draw_piece(pieces[i].grow(-5), piece, 0.2 if placed else 1.0)
		if placed: symbol("check", pieces[i].get_center(), 40, TEAL)
		else:
			draw_circle(pieces[i].position + Vector2(22, 22), 16, PAPER)
			caption(str(piece + 1), pieces[i].position + Vector2(22, 30), 21)
	caption("游戏原创插画 · 真正的壁画要交给专业人员保护", Vector2(size.x / 2, size.y - 7), 20)

func _draw_paint() -> void:
	var petals := _petal_centers()
	var center := Vector2(size.x * 0.39, size.y * 0.46)
	draw_line(center + Vector2(0, 95), Vector2(center.x, size.y - 12), TEAL, 8, true)
	symbol("leaf", Vector2(center.x - 42, size.y - 38), 87, Color("739b73"))
	symbol("leaf", Vector2(center.x + 46, size.y - 36), 71, Color("88a97a"))
	for i in range(10):
		var polygon := _petal_polygon(petals[i])
		var color := Color(session.state.colors[i]) if session.state.colors[i] != "" else Color("f8eccc")
		draw_colored_polygon(polygon, color)
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color("9e8159"), 2.3, true)
		var top := Vector2(0, -54).rotated(petals[i].z) + Vector2(petals[i].x, petals[i].y)
		var bottom := Vector2(0, 49).rotated(petals[i].z) + Vector2(petals[i].x, petals[i].y)
		draw_line(top, bottom, Color(1, 0.93, 0.72, 0.3), 2, true)
		caption(str(i + 1), Vector2(petals[i].x, petals[i].y + 8), 21, INK if color.get_luminance() > 0.4 else PAPER)
	var palette := _palette_rects()
	for i in range(6):
		box(palette[i], PAPER, session.state.color == i)
		draw_circle(palette[i].get_center() - Vector2(0, 14), 21, Color(Rules.PIGMENTS[i]))
		draw_arc(palette[i].get_center() - Vector2(0, 14), 21, 0, TAU, 32, Color("b79a69"), 1.5, true)
		caption(PIGMENT_NAMES[i], palette[i].get_center() + Vector2(0, 32), 22)
	caption("每一种颜色都很好看", Vector2(size.x * 0.77, size.y - 4), 22)

func _history_record(id: String) -> Dictionary:
	for item in content.get("historyEvents", []):
		if item.get("id", "") == id: return item
	return {"title": HISTORY_TITLES[id], "era": HISTORY_ERAS[id]}

func _draw_history() -> void:
	var cards := _history_cards()
	var labels := ["很久以前", "后来", "再后来", "近现代"]
	for i in range(4):
		var id: String = session.state.order[i]
		var record := _history_record(id)
		var rect := cards[i]
		caption(labels[i], Vector2(rect.get_center().x, 37), 24, TEAL)
		if i < 3: caption("→", Vector2(rect.end.x + 9, 38), 30, GOLD)
		box(rect, PAPER, session.state.selected == i)
		var vignette := Rect2(rect.position + Vector2(10, 10), Vector2(rect.size.x - 20, rect.size.y * 0.50))
		var texture: Texture2D = HISTORY_ART[id]
		var source_size := vignette.size / maxf(vignette.size.x / texture.get_width(), vignette.size.y / texture.get_height())
		draw_texture_rect_region(texture, vignette, Rect2((texture.get_size() - source_size) / 2, source_size))
		draw_circle(rect.position + Vector2(33, 33), 17, TEAL)
		caption(str(i + 1), rect.position + Vector2(33, 41), 21, PAPER)
		lines(str(record.get("title", HISTORY_TITLES[id])), Rect2(Vector2(rect.position.x + 11, vignette.end.y + 12), Vector2(rect.size.x - 22, 68)), 23)
		caption(str(record.get("era", HISTORY_ERAS[id])), Vector2(rect.get_center().x, rect.end.y - 20), 21, TEAL)

func _draw_weave() -> void:
	var state: Dictionary = session.state
	var pattern: Array = Rules.PATTERNS[state.pattern]
	var sample := _loom_cells(true)
	var loom := _loom_cells()
	caption("小样 · " + Rules.PATTERN_NAMES[state.pattern], Vector2(size.x * 0.19, 29), 23)
	caption("我的彩带", Vector2(size.x * 0.57, 29), 25)
	for pair in [[sample, true], [loom, false]]:
		var rectangles: Array = pair[0]
		var is_sample: bool = pair[1]
		if not is_sample:
			for y in [rectangles[0].position.y - 10, rectangles[11].end.y + 10]:
				draw_line(Vector2(rectangles[0].position.x - 16, y), Vector2(rectangles[3].end.x + 16, y), RUST, 12, true)
		for i in range(12):
			var color: String = pattern[i] if is_sample else state.cells[i]
			var rect: Rect2 = rectangles[i]
			box(rect, THREAD_COLORS[color] if color != "" else Color("e2cfa8"))
			if color != "": symbol(THREAD_SYMBOLS[color], rect.get_center(), 31 if is_sample else 39, PAPER)
			else:
				for x in range(7, int(rect.size.x), 10): draw_line(rect.position + Vector2(x, 4), rect.position + Vector2(x, rect.size.y - 4), Color("bca77d"), 1)
				caption(str(i + 1), rect.get_center() + Vector2(0, 8), 22)
	var threads := _thread_rects()
	for i in range(3):
		var color: String = ["red", "teal", "gold"][i]
		box(threads[i], PAPER, state.thread == color)
		symbol(THREAD_SYMBOLS[color], threads[i].get_center() - Vector2(0, 15), 36, THREAD_COLORS[color])
		caption(THREAD_NAMES[color], threads[i].get_center() + Vector2(0, 30), 22)
