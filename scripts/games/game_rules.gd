extends RefCounted

const PACKING := ["water", "grain", "silk", "scroll"]
const BLOCKED := [2, 6, 7, 8, 14]
const WATER := [[3, 1], [3, 2], [0, 1], [0, 2], [0, 2], [3, 1], [0, 1], [0, 1], [3, 1]]
const MELODIES := [[0, 2], [0, 2, 3], [3, 2, 0, 4]]
const PIGMENTS := ["#c36849", "#2f7c79", "#315d83", "#d7ad58", "#97aa79", "#f8edcf"]
const PATTERNS := [
	["red", "teal", "gold", "teal", "teal", "gold", "teal", "red", "gold", "teal", "red", "teal"],
	["red", "red", "gold", "gold", "teal", "teal", "red", "red", "gold", "gold", "teal", "teal"],
	["gold", "teal", "red", "gold", "red", "gold", "teal", "red", "teal", "red", "gold", "teal"],
]
const PATTERN_NAMES := ["绿洲的小路", "花开两相伴", "沙丘的彩虹"]
const STARS := [
	[Vector2(15, 70), Vector2(38, 30), Vector2(60, 56), Vector2(85, 24)],
	[Vector2(50, 15), Vector2(20, 43), Vector2(22, 80), Vector2(78, 80), Vector2(80, 43)],
	[Vector2(15, 80), Vector2(26, 44), Vector2(46, 59), Vector2(59, 28), Vector2(78, 11), Vector2(87, 45), Vector2(65, 82)],
]
const STAR_NAMES := ["一座小沙丘", "一枚小风铃", "一只星光小鹿"]
const HISTORY := ["zhangqian", "mogao", "jiayuguan", "research"]

static func valid(index: int, length: int) -> bool:
	return index >= 0 and index < length

static func ports(rotations: Array) -> Array:
	var result: Array = []
	for i in range(WATER.size()):
		var tile: Array = []
		for direction in WATER[i]:
			tile.append(posmod(int(direction) + int(rotations[i]), 4))
		result.append(tile)
	return result

static func connected(tiles: Array, width: int, start: int) -> Array:
	if width < 1 or not valid(start, tiles.size()) or not tiles[start].has(3):
		return []
	var seen: Array = [start]
	var queue: Array = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var row: int = current / width
		var column: int = current % width
		for direction in tiles[current]:
			var delta: Vector2i = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][int(direction)]
			var next_column: int = column + delta.x
			var next_row: int = row + delta.y
			var next: int = next_row * width + next_column
			if next_column < 0 or next_column >= width or next_row < 0 or not valid(next, tiles.size()):
				continue
			if not seen.has(next) and tiles[next].has((int(direction) + 2) % 4):
				seen.append(next)
				queue.append(next)
	return seen

static func water_connected(tiles: Array, width: int, start: int, end: int) -> bool:
	return valid(end, tiles.size()) and tiles[end].has(1) and connected(tiles, width, start).has(end)

static func route_step(from: int, to: int) -> bool:
	if not valid(from, 16) or not valid(to, 16) or BLOCKED.has(to):
		return false
	return absi(from / 4 - to / 4) + absi(from % 4 - to % 4) == 1
