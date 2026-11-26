extends RefCounted

const Catalog = preload("res://scripts/trails/trail_catalog.gd")
var info: Dictionary
var id: String
var trail: Array[int] = []
var mirrors: Array = []
var offsets: Array = []
var history: Array[Dictionary] = []
var done := false
var hint := -1
var wrong := -1
var message: String

func _init(stage_id: String) -> void:
	id = stage_id
	info = Catalog.get_trail(stage_id)
	mirrors = info.get("start_slash", []).duplicate()
	offsets = info.get("offsets", []).duplicate()
	message = info.start

func trace_light() -> Dictionary:
	var point: Vector2i = info.source
	var direction := Vector2i.RIGHT
	var points: Array[Vector2i] = [point]
	var seen: Array[int] = []
	for _step in 25:
		point += direction
		points.append(point)
		if point == info.goal: return {"points":points, "seen":seen, "lit":true}
		if not Rect2i(0, 0, 5, 3).has_point(point): break
		var m: int = info.mirrors.find(point)
		if m >= 0:
			seen.append(m)
			if mirrors[m]: direction = Vector2i(-direction.y, -direction.x)
			else: direction = Vector2i(direction.y, direction.x)
	return {"points":points, "seen":seen, "lit":false}

func next_target() -> int:
	match info.kind:
		"track": return -1 if done else int(info.route[trail.size()])
		"register":
			for i in offsets.size():
				if offsets[i] != 0: return i
		"mirror":
			for i in trace_light().seen:
				if mirrors[i] == info.start_slash[i]: return i
	return -1

func give_hint() -> void:
	if done: return
	hint = next_target()
	wrong = -1
	match info.kind:
		"track": message = "找一找金圈里的脚印。" if id == "wuwei" else "下一滴露珠在金圈里。"
		"mirror": message = "转一转金圈里的铜镜，看光怎样拐弯。"
		"register":
			var direction := "左" if offsets[hint] > 0 else "右"
			if id == "dunhuang": direction = "上" if offsets[hint] > 0 else "下"
			message = "把金边画带向%s滑一格。" % direction

func act(index: int, shift := 1) -> String:
	if done: return ""
	hint = -1
	wrong = -1
	var moved_away := false
	match info.kind:
		"track":
			if not trail.is_empty() and index == trail.back(): return ""
			if index != next_target():
				wrong = index
				message = info.miss
				return "miss"
			history.append({"index":index})
			trail.append(index)
			done = trail.size() == info.route.size()
		"mirror":
			history.append({"index":index})
			mirrors[index] = not mirrors[index]
			done = trace_light().lit
			moved_away = mirrors[index] == info.start_slash[index]
		"register":
			moved_away = offsets[index] == 0
			history.append({"index":index,"old":offsets[index]})
			offsets[index] = posmod(int(offsets[index]) + shift + 1, 3) - 1
			done = offsets.count(0) == offsets.size()
	if moved_away and not done:
		wrong = index
		message = "光转开了，再转一次就能回来。" if info.kind == "mirror" else "这条画带错开啦，试试退一步。"
		return "miss"
	message = "纹样合上啦！" if done else str(info.step)
	if info.kind == "register" and not done and offsets[index] == 0:
		message = "这一段接好啦，再看旁边的画带。"
	return "step"

func undo() -> void:
	if done or history.is_empty(): return
	var previous: Dictionary = history.pop_back()
	match info.kind:
		"track": trail.pop_back()
		"mirror": mirrors[previous.index] = not mirrors[previous.index]
		"register": offsets[previous.index] = previous.old
	wrong = -1
	hint = -1
	message = info.start if history.is_empty() else info.step
