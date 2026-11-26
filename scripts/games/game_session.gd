extends RefCounted

const Rules = preload("res://scripts/games/game_rules.gd")
const INSTRUCTIONS := {
	"pack": "帮小骆驼装好水壶、粮食、丝绸和书卷。点一下，也可以拖进右边的行囊。",
	"water": "点一下水渠，转一下。把雪山的水接到右下方的小树那里。",
	"memory": "翻开两张一样的宝物，帮它们找到好朋友。",
	"route": "从左上方出发，走相邻的一格，绕过石头到右下方的关城。",
	"music": "先听花朵唱歌，再按相同顺序点花朵。一起奏好三段乐句。",
	"mural": "先选一片画，再点它在底图的位置；也可以把画片拖过去。",
	"paint": "选喜欢的矿彩，点一片花瓣，也可以划着涂色。没有标准答案。",
	"history": "点两张故事卡交换位置，按汉代、十六国、明代、近现代排一排。",
	"weave": "对照左边的小样，选彩线，再点或划过右边相同图案的格子。",
	"trade": "给天平放上小砝码，称准三样货物。两边一样重才刚刚好。",
	"stars": "从第1颗星星开始，依次点按或连线，画出三个夜空里的故事。",
}

var state: Dictionary = {}

func start(kind: String, content: Dictionary = {}, progress: Dictionary = {}) -> void:
	state = {"kind": kind, "done": false, "message": INSTRUCTIONS.get(kind, "一起试试看吧。")}
	for item in content.get("activities", []):
		if item.get("id", "") == kind:
			state.message = str(item.get("instruction", state.message))
	match kind:
		"pack": state.merge({"cargo": []})
		"water": state.merge({"rotations": [1, 2, 1, 0, 1, 0, 3, 1, 1]})
		"memory":
			var deck: Array = ["silk", "grape", "scroll", "pipa", "silk", "grape", "scroll", "pipa"]
			deck.shuffle()
			state.merge({"deck": deck, "face": [], "matched": [], "hide_at": -1})
		"route": state.merge({"path": [0]})
		"music": state.merge({"round": 0, "cursor": 0, "play_at": -1, "played": -1, "lit": -1})
		"mural": state.merge({"slots": [-1, -1, -1, -1, -1, -1], "order": [3, 0, 5, 2, 1, 4], "selected": -1})
		"paint":
			var colors: Array = []
			for i in range(10):
				var color: String = str(progress.get("paint", {}).get(str(i), ""))
				colors.append(color if Rules.PIGMENTS.has(color) else "")
			state.merge({"colors": colors, "color": 0})
		"history": state.merge({"order": ["research", "mogao", "zhangqian", "jiayuguan"], "selected": -1})
		"weave": state.merge({"cells": ["", "", "", "", "", "", "", "", "", "", "", ""], "pattern": 0, "thread": "red"})
		"trade": state.merge({"weights": [], "round": 0})
		"stars": state.merge({"path": [], "round": 0})

func act(action: Dictionary, now: int = 0) -> Array:
	if state.is_empty() or (state.done and state.kind != "paint"):
		return []
	for key in ["index", "piece", "target", "from", "to", "value"]:
		if action.has(key):
			var value: Variant = action[key]
			if not (value is int or value is float): return []
			if not is_finite(float(value)) or float(value) != floorf(float(value)): return []
	var type: String = action.get("type", "")
	var index: int = int(action.get("index", -1))
	match state.kind:
		"pack": return _pack(type, str(action.get("id", "")))
		"water": return _water(type, index)
		"memory": return _memory(type, index, now)
		"route": return _route(type, index)
		"music": return _music(type, index, now)
		"mural": return _mural(action, type, index)
		"paint": return _paint(type, index)
		"history": return _history(action, type, index)
		"weave": return _weave(action, type, index)
		"trade": return _trade(action, type)
		"stars": return _stars(type, index)
	return []

func _won() -> Array:
	state.done = true
	state.message = "做好啦！欧哟几把这份小小的发现，收进了行囊。"
	return [0, 2, 4]

func _pack(type: String, id: String) -> Array:
	if type != "item": return []
	if not Rules.PACKING.has(id):
		state.message = "这一件先留在家里，找找旅途中要用的东西。"
		return []
	if state.cargo.has(id): return []
	state.cargo.append(id)
	state.message = "装好啦！小骆驼轻轻点了点头。"
	return _won() if state.cargo.size() == 4 else [state.cargo.size()]

func _water(type: String, index: int) -> Array:
	if type == "hint":
		for i in [0, 1, 4, 7, 8]:
			var current: Array = Rules.ports(state.rotations)[i]
			var wanted: Array = Rules.WATER[i].duplicate()
			current.sort()
			wanted.sort()
			if current != wanted:
				state.rotations[i] = 0
				break
	elif type == "cell" and Rules.valid(index, 9):
		state.rotations[index] = (int(state.rotations[index]) + 1) % 4
	else: return []
	state.message = "蓝色的水在前进，继续接到小树那里吧。"
	return _won() if Rules.water_connected(Rules.ports(state.rotations), 3, 0, 8) else [1]

func _memory(type: String, index: int, now: int) -> Array:
	if type != "cell" or not Rules.valid(index, 8) or state.hide_at >= 0 or state.face.has(index) or state.matched.has(index): return []
	state.face.append(index)
	if state.face.size() == 1:
		state.message = "记住这一件，找找它的好朋友。"
		return [1]
	if state.deck[state.face[0]] == state.deck[state.face[1]]:
		state.matched.append_array(state.face)
		state.face = []
		state.message = "找到一对啦！再找找别的宝物。"
		return _won() if state.matched.size() == 8 else [2]
	state.hide_at = now + 750
	state.message = "先记住它们的位置，我们再找一找。"
	return []

func _route(type: String, index: int) -> Array:
	if type == "undo":
		if state.path.size() > 1: state.path.pop_back()
		return []
	if type != "cell": return []
	if not Rules.route_step(int(state.path.back()), index):
		state.message = "选脚边相邻的一格，绕开石头慢慢走。"
		return []
	state.path.append(index)
	state.message = "小商队跟上啦，再走一小步。"
	return _won() if index == 15 else [state.path.size() % 5]

func _music(type: String, index: int, now: int) -> Array:
	var melody: Array = Rules.MELODIES[state.round]
	if type == "stop":
		cancel()
	elif type == "listen":
		state.merge({"cursor": 0, "play_at": now + 120, "played": -1, "lit": -1}, true)
		state.message = "先看花朵亮起来，再轮到你。"
	elif type == "next" and state.cursor == melody.size() and state.round < 2:
		state.merge({"round": state.round + 1, "cursor": 0, "play_at": -1, "played": -1, "lit": -1}, true)
		state.message = "新的一段，先听听，也可以看看小提示。"
	elif type == "note" and Rules.valid(index, 5) and state.play_at < 0 and state.cursor < melody.size():
		state.lit = index
		if index != melody[state.cursor]:
			state.cursor = 0
			state.message = "我们从第一朵重新来，看看上面的小提示。"
		else:
			state.cursor += 1
			state.message = "这一段奏好啦！" if state.cursor == melody.size() else "对啦，再点下一朵。"
			if state.round == 2 and state.cursor == melody.size(): return _won()
		return [index]
	return []

func _mural(action: Dictionary, type: String, index: int) -> Array:
	if type == "select" and Rules.valid(index, 6) and not state.slots.has(index):
		state.selected = index
		state.message = "选好这一片了，点它应该住的位置。"
		return []
	var piece: int = int(action.get("piece", state.selected))
	var target: int = int(action.get("target", index))
	if not ["drop", "cell"].has(type) or not Rules.valid(piece, 6) or not Rules.valid(target, 6) or state.slots.has(piece): return []
	if piece != target:
		state.message = "看看图案和小数字，这一片还有自己的位置。"
		return []
	state.slots[target] = piece
	state.selected = -1
	state.message = "拼好一片，画里的小鹿越来越清楚了。"
	return _won() if not state.slots.has(-1) else [piece % 5]

func _paint(type: String, index: int) -> Array:
	if type == "color" and Rules.valid(index, Rules.PIGMENTS.size()): state.color = index
	if type == "cell" and Rules.valid(index, 10):
		state.colors[index] = Rules.PIGMENTS[state.color]
		state.message = "颜色留下来啦，也可以轻轻划过更多花瓣。"
		return [state.color % 5]
	if type == "check":
		if not state.colors.has(""):
			return [] if state.done else _won()
		state.message = "还有花瓣在等颜色，给每一片都添上一点吧。"
	return []

func _history(action: Dictionary, type: String, index: int) -> Array:
	if type == "select" and Rules.valid(index, 4):
		if state.selected < 0:
			state.selected = index
			state.message = "再点另一张，两段故事就会交换位置。"
			return []
		return _history({"from": state.selected, "to": index}, "swap", -1)
	if type == "swap":
		var from: int = int(action.get("from", -1))
		var to: int = int(action.get("to", -1))
		if Rules.valid(from, 4) and Rules.valid(to, 4):
			var previous: String = state.order[from]
			state.order[from] = state.order[to]
			state.order[to] = previous
			state.selected = -1
		return []
	if type == "hint":
		for i in range(4):
			if state.order[i] != Rules.HISTORY[i]:
				return _history({"from": state.order.find(Rules.HISTORY[i]), "to": i}, "swap", -1)
	if type == "check":
		if state.order == Rules.HISTORY: return _won()
		state.message = "再想想：汉代、十六国、明代，再到近现代。"
	return []

func _weave(action: Dictionary, type: String, index: int) -> Array:
	if type == "thread" and ["red", "teal", "gold"].has(action.get("color", "")):
		state.thread = action.color
	elif type == "pattern":
		state.pattern = (int(state.pattern) + 1) % 3
		state.cells.fill("")
	elif type == "cell" and Rules.valid(index, 12):
		if Rules.PATTERNS[state.pattern][index] != state.thread:
			state.message = "对照小样，找同样的花、叶子或太阳。"
			return []
		if state.cells[index] != "": return []
		state.cells[index] = state.thread
		state.message = "织好啦，也可以轻轻划过同样图案的格子。"
		return _won() if not state.cells.has("") else [index % 5]
	return []

func _trade(action: Dictionary, type: String) -> Array:
	if type == "weight":
		var value: int = int(action.get("value", 0))
		if value >= 1 and value <= 3 and state.weights.size() < 6:
			state.weights.append(value)
			return [value]
	elif type == "undo" and not state.weights.is_empty(): state.weights.pop_back()
	elif type == "check":
		var sum: int = 0
		for value in state.weights: sum += int(value)
		if sum != int(state.round) + 3:
			state.message = "还没一样重，可以加一点，也可以取回一块。"
		elif state.round == 2: return _won()
		else:
			state.round += 1
			state.weights = []
			state.message = "刚刚好！再帮下一位朋友称一称。"
			return [3]
	return []

func _stars(type: String, index: int) -> Array:
	var total: int = Rules.STARS[state.round].size()
	if type == "next" and state.path.size() == total and state.round < 2:
		state.round += 1
		state.path = []
		state.message = "新的星图，从第一颗慢慢连起来。"
	elif type == "undo": state.path = []
	elif type == "cell":
		if index != state.path.size() or index >= total:
			state.message = "先找第 %d 颗亮起来的星星。" % (state.path.size() + 1)
			return []
		state.path.append(index)
		state.message = "这一幅亮起来啦！" if state.path.size() == total else "连上了，跟着金色的小路继续走。"
		return _won() if state.path.size() == total and state.round == 2 else [state.path.size() % 5]
	return []

func tick(now: int) -> Array:
	if state.kind == "memory" and state.hide_at >= 0 and now >= state.hide_at:
		state.face = []
		state.hide_at = -1
	if state.kind == "music" and state.play_at >= 0:
		var elapsed: int = now - int(state.play_at)
		if elapsed < 0: return []
		var index: int = elapsed / 700
		var melody: Array = Rules.MELODIES[state.round]
		if index >= melody.size():
			state.play_at = -1
			state.lit = -1
			state.message = "轮到你啦，跟着小提示点点花朵。"
		elif index != state.played:
			state.played = index
			state.lit = melody[index]
			return [melody[index]]
	return []

func cancel() -> void:
	if state.get("kind", "") == "music":
		state.merge({"play_at": -1, "played": -1, "lit": -1}, true)
	if state.get("kind", "") == "memory":
		state.face = []
		state.hide_at = -1
