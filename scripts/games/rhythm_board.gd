extends "res://scripts/games/touch_board.gd"

const NOTE_NAMES := ["小叶", "水滴", "小花", "太阳", "星星"]
const NOTE_ICONS := ["leaf", "drop", "lotus", "sun", "star"]
const NOTE_COLORS := [Color("66866d"), Color("598b9c"), Color("b46c71"), Color("b48c42"), Color("8c78a0")]

func _note_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var width := minf(170, (size.x - 180) / 5)
	var extent := width * 5 + 72
	for i in range(5): result.append(Rect2(Vector2((size.x - extent) / 2 + i * (width + 18), size.y * 0.48), Vector2(width, minf(166, size.y * 0.46))))
	return result

func _weight_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for i in range(3): result.append(Rect2(Vector2(size.x / 2 - 224 + i * 156, size.y - 88), Vector2(136, 76)))
	return result

func _balance_rect() -> Rect2:
	return Rect2(size.x * 0.67 - 102, 66, 204, 176)

func _star_centers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in Rules.STARS[session.state.round]:
		result.append(Vector2(size.x * 0.14 + point.x / 100 * size.x * 0.72, 38 + point.y / 100 * (size.y - 106)))
	return result

func interaction_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not session: return result
	match session.state.kind:
		"music":
			var rects := _note_rects()
			for i in range(5): result.append(region(rects[i], {"type": "note", "index": i}, "tap", NOTE_NAMES[i]))
		"trade":
			var rects := _weight_rects()
			for i in range(3): result.append(region(rects[i], {"type": "weight", "value": i + 1}, "weight", "%d点砝码" % (i + 1)))
			result.append(region(_balance_rect(), {"type": "balance"}, "balance", "右边的天平盘"))
		"stars":
			var points := _star_centers()
			for i in range(points.size()): result.append(region(Rect2(points[i] - Vector2(36, 36), Vector2(72, 72)), {"type": "cell", "index": i}, "stroke", "第%d颗星星" % (i + 1)))
	return result

func _draw() -> void:
	if not session: return
	match session.state.kind:
		"music": _draw_music()
		"trade": _draw_trade()
		"stars": _draw_stars()
	draw_interaction_feedback()

func _draw_music() -> void:
	var state: Dictionary = session.state
	var melody: Array = Rules.MELODIES[state.round]
	caption("第 %d / 3 段 · 跟着花朵唱" % (state.round + 1), Vector2(size.x / 2, 29), 26)
	for i in range(melody.size()):
		var point := Vector2(size.x / 2 + (i - (melody.size() - 1) / 2.0) * 112, size.y * 0.25)
		var note: int = melody[i]
		draw_circle(point, 35, Color("d2dfc2") if i < state.cursor else Color("e6cfa1"))
		illustration(NOTE_ICONS[note], point, 47)
		caption("✓" if i < state.cursor else str(i + 1), point + Vector2(0, 65), 23, TEAL)
	var rects := _note_rects()
	for i in range(5):
		var lit: bool = state.lit == i
		box(rects[i], Color("fae8a8") if lit else PAPER, lit)
		var center := rects[i].get_center() - Vector2(0, 20)
		var radius := minf(51, rects[i].size.y * 0.31)
		for petal in range(6):
			var offset := Vector2.from_angle(petal * TAU / 6) * radius * 0.53
			draw_circle(center + offset, radius * 0.44, NOTE_COLORS[i].lerp(PAPER, 0.4), true, -1, true)
		draw_circle(center, radius * 0.67, Color("faf1d1"), true, -1, true)
		draw_arc(center, radius * 0.67, 0, TAU, 48, GOLD, 1.4, true)
		illustration(NOTE_ICONS[i], center, radius * 1.05)
		caption(NOTE_NAMES[i], rects[i].get_center() + Vector2(0, 57), 25)

func _draw_trade() -> void:
	var state: Dictionary = session.state
	var target: int = state.round + 3
	var sum := 0
	for weight in state.weights: sum += int(weight)
	var tilt := clampf(float(sum - target) * 9, -32, 32)
	var center := Vector2(size.x / 2, 89)
	var left := Vector2(size.x * 0.33, 89 - tilt)
	var right := Vector2(size.x * 0.67, 89 + tilt)
	caption("第 %d / 3 位朋友 · 两边一样重才公平" % (state.round + 1), Vector2(size.x / 2, 28), 25)
	draw_line(center, center + Vector2(0, 150), RUST, 12, true)
	draw_line(center + Vector2(-60, 153), center + Vector2(60, 153), RUST, 12, true)
	draw_line(left, right, RUST, 10, true)
	draw_circle(center, 12, GOLD)
	for point in [left, right]:
		draw_line(point, point + Vector2(-87, 108), GOLD, 3, true)
		draw_line(point, point + Vector2(87, 108), GOLD, 3, true)
		var pan := PackedVector2Array([point + Vector2(-94, 108), point + Vector2(94, 108), point + Vector2(66, 127), point + Vector2(-66, 127)])
		draw_colored_polygon(pan, Color("b98d4d"))
		draw_line(point + Vector2(-94, 108), point + Vector2(94, 108), PAPER, 3, true)
	for i in range(target): draw_circle(left + Vector2((i - (target - 1) / 2.0) * 25, 88), 9, RUST)
	var row: Array = state.weights
	for i in range(row.size()):
		var position := right + Vector2((i % 3 - 1) * 42, 82 - (i / 3) * 35)
		box(Rect2(position - Vector2(18, 16), Vector2(36, 30)), TEAL)
		caption(str(row[i]), position + Vector2(0, 9), 22, PAPER)
	caption("货物 %d 点" % target, Vector2(left.x, 265), 23)
	caption("砝码 %d 点" % sum, Vector2(right.x, 265), 23, TEAL if sum == target else INK)
	var item_center := Vector2(size.x * 0.12, size.y * 0.4)
	symbol(["grape", "grain", "silk"][state.round], item_center, 75, RUST)
	caption(["一篮葡萄", "一包粮食", "一卷丝绸"][state.round], item_center + Vector2(0, 70), 23)
	var rects := _weight_rects()
	for i in range(3):
		box(rects[i], PAPER)
		for dot in range(i + 1): draw_circle(rects[i].get_center() + Vector2((dot - i / 2.0) * 26, -9), 9, TEAL)
		caption("%d点" % (i + 1), rects[i].get_center() + Vector2(0, 27), 21)

func _draw_stars() -> void:
	var state: Dictionary = session.state
	for i in range(55):
		var point := Vector2(fmod(i * 137.9 + 41, size.x), fmod(i * 73.1 + 17, size.y))
		draw_circle(point, 1 + i % 2, Color(0.8, 0.87, 0.85, 0.28))
	caption("第 %d / 3 幅 · " % (state.round + 1) + Rules.STAR_NAMES[state.round], Vector2(size.x / 2, 28), 26, PAPER)
	var points := _star_centers()
	var path := PackedVector2Array()
	for i in state.path: path.append(points[i])
	if path.size() > 1:
		if state.round == 1 and path.size() == points.size(): path.append(points[0])
		draw_polyline(path, Color(0.95, 0.75, 0.38, 0.2), 16, true)
		draw_polyline(path, GOLD, 4, true)
	for i in range(points.size()):
		var next: bool = i == state.path.size()
		var visited: bool = i < state.path.size()
		if next:
			draw_circle(points[i], 32, Color(0.95, 0.75, 0.38, 0.15))
			draw_arc(points[i], 33, 0, TAU, 40, GOLD, 2, true)
		draw_circle(points[i], 20, Color(0.94, 0.80, 0.56, 0.15), true, -1, true)
		illustration("star", points[i], 48 if next else 41)
		caption(str(i + 1), points[i] + Vector2(0, 48), 23, PAPER)
