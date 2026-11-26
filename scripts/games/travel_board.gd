extends "res://scripts/games/touch_board.gd"

const GOODS := ["water", "grain", "silk", "scroll", "ball", "phone"]
const GOOD_NAMES := ["水壶", "粮食", "丝绸", "书卷", "皮球", "手机"]
const MEMORY_NAMES := {"silk": "彩绸", "grape": "葡萄", "scroll": "书卷", "pipa": "琵琶"}

func _grid(columns: int, rows: int, cell: Vector2, center: Vector2, gap := 12.0) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var extent := Vector2(columns * cell.x + (columns - 1) * gap, rows * cell.y + (rows - 1) * gap)
	for i in range(columns * rows):
		result.append(Rect2(center - extent / 2 + Vector2(i % columns, i / columns) * (cell + Vector2.ONE * gap), cell))
	return result

func _pack_rects() -> Array[Rect2]:
	return _grid(3, 2, Vector2(minf(175, size.x * 0.145), minf(148, (size.y - 80) / 2)), Vector2(size.x * 0.285, size.y * 0.53), 18)

func _cargo_rect() -> Rect2:
	return Rect2(size.x * 0.56, 28, size.x * 0.4, size.y - 56)

func _water_rects() -> Array[Rect2]:
	var side := minf(118, (size.y - 40) / 3)
	return _grid(3, 3, Vector2.ONE * side, size / 2, 6)

func _memory_rects() -> Array[Rect2]:
	return _grid(4, 2, Vector2(minf(205, (size.x - 180) / 4), minf(142, (size.y - 96) / 2)), size / 2, 18)

func _route_rects() -> Array[Rect2]:
	var side := minf(89, (size.y - 52) / 4)
	return _grid(4, 4, Vector2.ONE * side, size / 2, 9)

func interaction_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not session: return result
	match session.state.kind:
		"pack":
			var rects := _pack_rects()
			for i in range(6): result.append(region(rects[i], {"type": "item", "id": GOODS[i]}, "cargo_item", GOOD_NAMES[i]))
			result.append(region(_cargo_rect(), {"type": "cargo"}, "cargo", "小骆驼的行囊"))
		"water":
			var rects := _water_rects()
			for i in range(9): result.append(region(rects[i], {"type": "cell", "index": i}, "tap", "转动第%d块水渠" % (i + 1)))
		"memory":
			var rects := _memory_rects()
			for i in range(8): result.append(region(rects[i], {"type": "cell", "index": i}, "tap", "翻第%d张宝物牌" % (i + 1)))
		"route":
			var rects := _route_rects()
			for i in range(16): result.append(region(rects[i], {"type": "cell", "index": i}, "stroke", "走到第%d格" % (i + 1)))
	return result

func _draw() -> void:
	if not session: return
	match session.state.kind:
		"pack": _draw_pack()
		"water": _draw_water()
		"memory": _draw_memory()
		"route": _draw_route()
	draw_interaction_feedback()

func _draw_pack() -> void:
	var state: Dictionary = session.state
	var rects := _pack_rects()
	for i in range(6):
		var item := rects[i]
		var packed: bool = state.cargo.has(GOODS[i])
		box(item, Color("dcead5") if packed else Color("f6e6c3"), packed)
		var art_size := minf(99, item.size.y - 43)
		illustration(GOODS[i], item.get_center() - Vector2(0, 16), art_size)
		caption(GOOD_NAMES[i], Vector2(item.get_center().x, item.end.y - 13), 24)
		if packed:
			var corner := item.position + Vector2(23, 22)
			draw_circle(corner, 13, TEAL)
			symbol("check", corner, 17, PAPER)
	var cargo := _cargo_rect()
	var center := cargo.get_center()
	var art_size := minf(cargo.size.y * 0.49, 201)
	var art_center := Vector2(center.x, cargo.position.y + cargo.size.y * 0.3)
	illustration("camel", art_center, art_size)
	caption("小骆驼的行囊", Vector2(center.x, art_center.y + art_size / 2 + 30), 27)
	var slots := _grid(4, 1, Vector2(76, 73), Vector2(center.x, cargo.end.y - 48), 12)
	for i in range(4):
		var packed: bool = state.cargo.has(Rules.PACKING[i])
		box(slots[i], Color("deebd5") if packed else Color("e3d2b1"), packed)
		illustration(Rules.PACKING[i], slots[i].get_center(), 49, Color.WHITE if packed else Color(0.65, 0.56, 0.45, 0.49))

func _draw_water() -> void:
	var rects := _water_rects()
	var tiles: Array = Rules.ports(session.state.rotations)
	var wet: Array = Rules.connected(tiles, 3, 0)
	var inlet := rects[0].get_center()
	var outlet := rects[8].get_center()
	var left := Vector2(rects[0].position.x - 130, inlet.y)
	var right := Vector2(rects[8].end.x + 130, outlet.y - 15)
	draw_texture_rect(preload("res://assets/edition/seals/zhangye.webp"), Rect2(left - Vector2(65, 86), Vector2(130, 130)), false)
	caption("雪山来水", left + Vector2(0, 76), 24)
	draw_line(left + Vector2(52, 0), inlet, Color("59aeb8"), 14, true)
	draw_line(outlet, right - Vector2(30, 0), Color("59aeb8") if session.state.done else Color("b6a887"), 14, true)
	illustration("sapling", right - Vector2(0, 27), 136, Color.WHITE if session.state.done else Color("c0b79d"))
	caption("小树喝饱啦！" if session.state.done else "小树等喝水", right + Vector2(0, 84), 24)
	var offsets := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for i in range(9):
		var tile := rects[i]
		var flowing := wet.has(i)
		box(tile, Color("dcc99d"))
		var center := tile.get_center()
		var start: Vector2 = center + offsets[tiles[i][0]] * tile.size.x / 2
		var end: Vector2 = center + offsets[tiles[i][1]] * tile.size.x / 2
		var channel := PackedVector2Array()
		for step in range(19):
			channel.append(start.bezier_interpolate(center, center, end, step / 18.0))
		draw_polyline(channel, Color("937a54"), 32, true)
		draw_polyline(channel, Color("e7c995"), 27, true)
		draw_polyline(channel, Color("479ca6") if flowing else Color("bda478"), 20, true)
		draw_polyline(channel, Color("b4e9df") if flowing else Color("d5bf96"), 4, true)

func _draw_memory() -> void:
	var state: Dictionary = session.state
	var rects := _memory_rects()
	for i in range(8):
		var matched: bool = state.matched.has(i)
		var face: bool = state.face.has(i) or matched
		box(rects[i], Color("c9e0cb") if matched else PAPER if face else Color("326b6c"), matched)
		if face:
			illustration(state.deck[i], rects[i].get_center() - Vector2(0, 15), minf(85, rects[i].size.y - 42))
			caption(MEMORY_NAMES[state.deck[i]], rects[i].get_center() + Vector2(0, 51), 24)
		else:
			draw_texture_rect(preload("res://assets/edition/props/card-back.webp"), rects[i].grow(-5), false)

func _draw_route() -> void:
	var state: Dictionary = session.state
	var rects := _route_rects()
	var current: int = state.path.back()
	var left := Vector2(rects[0].position.x - 135, size.y * 0.43)
	var right := Vector2(rects[3].end.x + 135, size.y * 0.5)
	illustration("camel", left - Vector2(0, 10), 150)
	caption("我们一起走", left + Vector2(0, 97), 25)
	caption("一步一格，慢慢来", left + Vector2(0, 128), 22)
	symbol("gate", right, 135, RUST)
	caption("前方就是关城", right + Vector2(0, 88), 25)
	for i in range(16):
		var blocked: bool = Rules.BLOCKED.has(i)
		var here: bool = current == i
		var traveled: bool = state.path.has(i)
		box(rects[i], Color("c2b38e") if blocked else Color("c7ded0") if traveled else PAPER, here)
		if blocked: symbol("mountain", rects[i].get_center(), 45, Color("7b8173"))
		elif here: symbol("camel", rects[i].get_center(), 43, RUST)
		elif i == 15: symbol("gate", rects[i].get_center(), 45, TEAL)
		elif traveled: symbol("check", rects[i].get_center(), 32, TEAL)
		else:
			draw_circle(rects[i].get_center(), 5, Color("cfbb8e"))
		if not blocked and not traveled and Rules.route_step(current, i):
			draw_rect(rects[i].grow(-7), Color("9bc6aa"), false, 2)
