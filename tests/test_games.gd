extends SceneTree

var checks := 0
var failures: Array[String] = []
var session_script: Script
var game_content: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FAIL: " + message)

func fresh(kind: String, progress: Dictionary = {}) -> RefCounted:
	var result: RefCounted = session_script.new()
	result.start(kind, {}, progress)
	return result

func act(game: RefCounted, action: String, index: int = -1) -> void:
	game.act({"type": action, "index": index}, 0)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	if not ResourceLoader.exists("res://scripts/games/game_session.gd"):
		expect(false, "11 个小游戏的原生规则模块尚未实现")
		_finish()
		return
	if FileAccess.file_exists("res://data/content.json"):
		game_content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	session_script = load("res://scripts/games/game_session.gd")
	_test_pack()
	_test_water()
	_test_memory()
	_test_route()
	_test_music()
	_test_mural()
	_test_paint()
	_test_history()
	_test_weave()
	_test_trade()
	_test_stars()
	_test_non_integer_actions()
	await _test_view_and_touch()
	await _test_gestures()
	_finish()

func _test_pack() -> void:
	var game := fresh("pack")
	game.act({"type": "item", "id": "phone"})
	expect(game.state.cargo.is_empty(), "装行囊拒绝现代手机")
	for id in ["water", "grain", "silk"]:
		game.act({"type": "item", "id": id})
	expect(not game.state.done, "装满四件前不完成")
	game.act({"type": "item", "id": "water"})
	expect(game.state.cargo.size() == 3, "重复物品不重复装入")
	game.act({"type": "item", "id": "scroll"})
	expect(game.state.done and game.state.cargo.size() == 4, "四件必需货物完成行囊")

func _test_water() -> void:
	var game := fresh("water")
	act(game, "cell", 99)
	expect(not game.state.done, "无效水渠格不能完成")
	# 入口旋转三次；弯管两次；中间、下方与出口各三次。
	for pair in [[0, 3], [1, 2], [4, 3], [7, 3], [8, 3]]:
		for step in range(pair[1]):
			act(game, "cell", pair[0])
	expect(game.state.done, "只靠真实连接入口和出口完成九格水渠")
	var rules: Script = load("res://scripts/games/game_rules.gd")
	expect(not rules.water_connected([[3, 1], [0, 2], [3, 1]], 3, 0, 2), "相邻却不相对的端口不能通水")
	expect(not rules.water_connected([[0, 1], [3, 1]], 2, 0, 1), "入口没有西向端口时不能通水")
	expect(rules.water_connected([[3, 1], [3, 1]], 2, 0, 1), "双向端口连接可以通水")

func _test_memory() -> void:
	var game := fresh("memory")
	var deck: Array = game.state.deck
	act(game, "cell", 0)
	act(game, "cell", 0)
	expect(game.state.face.size() == 1, "同一张记忆牌不能与自己配对")
	var wrong := 1
	while deck[wrong] == deck[0]:
		wrong += 1
	act(game, "cell", wrong)
	act(game, "cell", 7)
	expect(game.state.face.size() == 2 and game.state.matched.is_empty(), "不匹配时暂时锁定第三张")
	game.tick(749)
	expect(game.state.face.size() == 2, "翻牌延迟不能提前结束")
	game.tick(750)
	expect(game.state.face.is_empty(), "翻牌延迟结束后重新盖上")
	for name in ["silk", "grape", "scroll", "pipa"]:
		for i in range(deck.size()):
			if deck[i] == name:
				act(game, "cell", i)
	expect(game.state.done and game.state.matched.size() == 8, "四对不同记忆牌全部配对才能完成")
	game = fresh("memory")
	deck = game.state.deck
	act(game, "cell", 0)
	for i in range(1, 8):
		if deck[i] != deck[0]:
			act(game, "cell", i)
			break
	game.cancel()
	game.tick(10000)
	expect(game.state.face.is_empty() and not game.state.done, "取消记忆等待不会残留翻牌或奖励")

func _test_route() -> void:
	var game := fresh("route")
	act(game, "cell", 15)
	act(game, "cell", 4)
	act(game, "cell", 8)
	expect(game.state.path == [0, 4], "路线拒绝跨格跳跃和石头")
	act(game, "undo")
	expect(game.state.path == [0], "路线可退回一步")
	for index in [1, 5, 9, 10, 11, 15]:
		act(game, "cell", index)
	expect(game.state.done, "相邻路线抵达关城完成")
	var old: Array = game.state.path.duplicate()
	act(game, "undo")
	expect(game.state.path == old, "完成后动作不改变已获胜路线")

func _test_music() -> void:
	var game := fresh("music")
	act(game, "note", 4)
	expect(game.state.cursor == 0, "弹错音符重新开始乐句")
	act(game, "listen")
	act(game, "note", 0)
	expect(game.state.cursor == 0, "播放示范时不能抢答")
	expect(game.tick(120) == [0], "乐句示范按时播放第一个音符")
	expect(game.tick(121).is_empty(), "同一个示范音符只播放一次")
	game.cancel()
	expect(game.tick(9999).is_empty(), "离开后不会继续播放示范音符")
	for melody in [[0, 2], [0, 2, 3], [3, 2, 0, 4]]:
		for note in melody:
			act(game, "note", note)
		if game.state.round < 2:
			expect(not game.state.done, "音乐中间轮不能领奖")
			act(game, "next")
	expect(game.state.done, "完整复奏三段乐句完成")

func _test_mural() -> void:
	var game := fresh("mural")
	game.act({"type": "drop", "piece": 0, "target": 5})
	expect(game.state.slots.count(-1) == 6, "错误壁画位置不会放入")
	for i in range(6):
		game.act({"type": "drop", "piece": i, "target": i})
	expect(game.state.done and game.state.slots == [0, 1, 2, 3, 4, 5], "六片壁画按原图位置完成")

func _test_paint() -> void:
	var game := fresh("paint", {"paint": {"0": "#c36849", "3": "#2f7c79", "20": "#ffffff"}})
	expect(game.state.colors[0] == "#c36849" and game.state.colors[3] == "#2f7c79", "涂色载入原进度的花瓣颜色")
	act(game, "check")
	expect(not game.state.done, "未涂完十片不能完成")
	act(game, "color", 99)
	for i in range(10):
		act(game, "cell", i)
	act(game, "check")
	expect(game.state.done, "十片自由选择颜色的莲花完成")
	act(game, "color", 1)
	act(game, "cell", 0)
	expect(game.state.colors[0] != game.state.colors[1], "涂色完成后仍可自由改色")

func _test_history() -> void:
	var game := fresh("history")
	act(game, "check")
	expect(not game.state.done, "混乱的历史顺序不能完成")
	game.act({"type": "swap", "from": -1, "to": 0})
	expect(game.state.order[0] == "research", "越界历史卡交换不改变顺序")
	game.act({"type": "swap", "from": 0, "to": 2})
	game.act({"type": "swap", "from": 2, "to": 3})
	act(game, "check")
	expect(game.state.done, "汉代十六国明代近现代排序完成")

func _test_weave() -> void:
	var game := fresh("weave")
	act(game, "cell", 1)
	expect(game.state.cells[1] == "", "织带错色不填格")
	var pattern: Array = ["red", "teal", "gold", "teal", "teal", "gold", "teal", "red", "gold", "teal", "red", "teal"]
	for i in range(12):
		game.act({"type": "thread", "color": pattern[i]})
		act(game, "cell", i)
	expect(game.state.done and game.state.cells.count("") == 0, "十二格织带图案完整后完成")

func _test_trade() -> void:
	var game := fresh("trade")
	game.act({"type": "weight", "value": 0})
	game.act({"type": "weight", "value": 7})
	expect(game.state.weights.is_empty(), "天平拒绝非法砝码")
	game.act({"type": "weight", "value": 3})
	game.act({"type": "weight", "value": 1})
	act(game, "check")
	expect(game.state.round == 0 and not game.state.done, "过重天平不能过关")
	act(game, "undo")
	act(game, "check")
	expect(game.state.round == 1, "第一轮相等后才进入第二轮")
	game.act({"type": "weight", "value": 3})
	game.act({"type": "weight", "value": 1})
	act(game, "check")
	game.act({"type": "weight", "value": 3})
	game.act({"type": "weight", "value": 2})
	act(game, "check")
	expect(game.state.done, "三个货物分别称准3、4、5后完成")

func _test_stars() -> void:
	var game := fresh("stars")
	act(game, "cell", 2)
	expect(game.state.path.is_empty(), "星图不能跳过前面的星星")
	for count in [4, 5, 7]:
		for i in range(count):
			act(game, "cell", i)
		if game.state.round < 2:
			expect(not game.state.done, "星图中间轮不能领奖")
			act(game, "next")
	expect(game.state.done and game.state.path.size() == 7, "沙丘风铃小鹿三幅星图全部完成")


func _test_non_integer_actions() -> void:
	var game := fresh("water")
	var before: Array = game.state.rotations.duplicate()
	game.act({"type": "cell", "index": 1.5})
	expect(game.state.rotations == before, "小数格子编号不能被截断成有效水渠")
	game = fresh("trade")
	game.act({"type": "weight", "value": 1.8})
	game.act({"type": "weight", "value": "2"})
	expect(game.state.weights.is_empty(), "砝码只能接受数值整数")
	game = fresh("mural")
	game.act({"type": "drop", "piece": 0.4, "target": 0})
	expect(game.state.slots.count(-1) == 6, "小数壁画编号不能放入画片")

func _test_view_and_touch() -> void:
	if not ResourceLoader.exists("res://scripts/games/minigame_view.gd"):
		expect(false, "原生小游戏视图尚未实现")
		return
	var view_script: Script = load("res://scripts/games/minigame_view.gd")
	var view: Control = view_script.new()
	view.configure("paint", {}, {"paint": {"0": "#c36849"}})
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	var rewards: Array[String] = []
	var paints: Array[int] = []
	view.finished.connect(func(id: String): rewards.append(id))
	view.paint_changed.connect(func(index: int, _color: String): paints.append(index))
	for i in range(10):
		view.perform({"type": "cell", "index": i})
	view.perform({"type": "check"})
	view.perform({"type": "check"})
	expect(rewards == ["paint"], "重复完成涂色只发送一次奖励信号")
	expect(paints.size() == 9, "只对真正改变的花瓣发送保存信号")
	view.queue_free()
	await process_frame
	view = view_script.new()
	view.configure("music", {}, {})
	root.add_child(view)
	await process_frame
	var notes: Array[int] = []
	view.note_requested.connect(func(note: int, _voice: String): notes.append(note))
	view.perform({"type": "listen"})
	view.hide()
	await create_timer(0.3).timeout
	expect(notes.is_empty(), "隐藏带延时播放的棋盘不再发音")
	view.queue_free()
	await process_frame
	view = view_script.new()
	view.configure("music", {}, {})
	root.add_child(view)
	await process_frame
	view.note_requested.connect(func(note: int, _voice: String): notes.append(note))
	view.perform({"type": "listen"})
	view.queue_free()
	await create_timer(0.3).timeout
	expect(notes.is_empty(), "销毁等待中的乐句棋盘后没有陈旧回调")
	for width in [1280, 1560]:
		for id in ["pack", "water", "memory", "route", "music", "mural", "paint", "history", "weave", "trade", "stars"]:
			view = view_script.new()
			view.configure(id, game_content, {})
			root.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			view.size = Vector2(width, 720)
			await process_frame
			await process_frame
			var board: Control = view.board
			for arg in OS.get_cmdline_user_args():
				if width == 1280 and arg.begins_with("--capture-games="):
					var destination: String = arg.trim_prefix("--capture-games=")
					DirAccess.make_dir_recursive_absolute(destination)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(destination.path_join(id + ".png"))
			expect(board.size.y >= 330 and board.size.x > 650, "%s 在 %s 宽度拥有足够棋盘空间" % [id, width])
			for target in board.interaction_regions():
				var rect: Rect2 = target.rect
				expect(rect.size.x >= 64 and rect.size.y >= 64, "%s 的触摸目标不小于64像素" % id)
				expect(Rect2(Vector2.ZERO, board.size).encloses(rect), "%s 的所有交互区域留在棋盘以内" % id)
			if id == "pack":
				var target: Vector2 = board.interaction_regions()[0].rect.get_center()
				board.pointer_event(1, "press", target)
				board.pointer_event(2, "press", target)
				board.pointer_event(2, "release", target)
				expect(view.session.state.cargo.is_empty(), "第二个手指释放不触发第一个手指的物品")
				board.pointer_event(1, "cancel", target)
				board.pointer_event(1, "release", target)
				expect(view.session.state.cargo.is_empty(), "取消触摸后抬手不触发物品")
				board.pointer_event(3, "press", target)
				board.pointer_event(3, "release", target)
				expect(view.session.state.cargo.size() == 1, "正常点按会装入物品")
			view.queue_free()
			await process_frame


func _test_gestures() -> void:
	var view_script: Script = load("res://scripts/games/minigame_view.gd")
	var view: Control = view_script.new()
	view.configure("route", {}, {})
	root.add_child(view)
	await process_frame
	await process_frame
	var board: Control = view.board
	var regions: Array = board.interaction_regions()
	board.pointer_event(1, "press", regions[1].rect.get_center())
	board.pointer_event(1, "release", regions[5].rect.get_center())
	expect(view.session.state.path == [0, 1, 5], "快速划线包含只在抬手事件出现的最后一格")
	view.queue_free()
	await process_frame
	for kind in ["pack", "mural", "history", "paint", "weave", "stars"]:
		view = view_script.new()
		view.configure(kind, {}, {})
		root.add_child(view)
		await process_frame
		await process_frame
		board = view.board
		regions = board.interaction_regions()
		if kind == "pack":
			board.pointer_event(1, "press", regions[0].rect.get_center())
			board.pointer_event(1, "move", regions[6].rect.get_center())
			board.pointer_event(1, "release", regions[6].rect.get_center())
			expect(view.session.state.cargo == ["water"], "拖入行囊可以装入水壶")
			var touch := InputEventScreenTouch.new()
			touch.index = 4
			touch.pressed = true
			touch.position = board.get_global_transform_with_canvas() * regions[1].rect.get_center()
			Input.parse_input_event(touch)
			await process_frame
			touch = touch.duplicate()
			touch.pressed = false
			Input.parse_input_event(touch)
			await process_frame
			expect(view.session.state.cargo == ["water", "grain"], "真实InputEventScreenTouch点按只装入一件物品")
			for event_data in [[6, true, false, 2], [7, true, false, 3], [7, false, false, 3], [6, false, true, 2]]:
				var event := InputEventScreenTouch.new()
				event.index = event_data[0]
				event.pressed = event_data[1]
				event.canceled = event_data[2]
				event.position = board.get_global_transform_with_canvas() * regions[event_data[3]].rect.get_center()
				Input.parse_input_event(event)
				await process_frame
			expect(view.session.state.cargo == ["water", "grain"], "真实多点触摸的次指抬起和主指取消都不会装入物品")

		elif kind == "mural":
			board.pointer_event(1, "press", regions[6].rect.get_center())
			board.pointer_event(1, "move", regions[3].rect.get_center())
			board.pointer_event(1, "release", regions[3].rect.get_center())
			expect(view.session.state.slots[3] == 3, "原生壁画拖放把第三号图块放入正确槽位")
		elif kind == "history":
			board.pointer_event(1, "press", regions[0].rect.get_center())
			board.pointer_event(1, "move", regions[2].rect.get_center())
			board.pointer_event(1, "release", regions[2].rect.get_center())
			expect(view.session.state.order[0] == "zhangqian", "拖放历史卡交换顺序")
		elif kind == "paint":
			var first: Vector2 = regions[0].rect.get_center()
			var second: Vector2 = regions[1].rect.get_center()
			board.pointer_event(1, "press", first)
			board.pointer_event(1, "move", second)
			board.pointer_event(1, "cancel", second)
			expect(view.session.state.colors.count("") == 10, "取消涂色笔划不保存未完成的动作")
			board.pointer_event(1, "press", first)
			board.pointer_event(1, "move", second)
			board.pointer_event(1, "release", second)
			expect(view.session.state.colors[0] != "" and view.session.state.colors[1] != "", "连续划过两片花瓣同时着色")
		elif kind == "weave":
			view.perform({"type": "thread", "color": "teal"})
			board.pointer_event(1, "press", regions[1].rect.get_center())
			board.pointer_event(1, "move", regions[5].rect.get_center())
			board.pointer_event(1, "move", regions[4].rect.get_center())
			board.pointer_event(1, "release", regions[4].rect.get_center())
			expect(view.session.state.cells[1] == "teal" and view.session.state.cells[4] == "teal" and view.session.state.cells[5] == "", "织带划线填对图案并拒绝经过的错色格")
		elif kind == "stars":
			board.pointer_event(1, "press", regions[0].rect.get_center())
			for i in range(1, 4): board.pointer_event(1, "move", regions[i].rect.get_center())
			board.pointer_event(1, "release", regions[3].rect.get_center())
			expect(view.session.state.path == [0, 1, 2, 3], "一笔连续连接星图遵守数字顺序")
		view.queue_free()
		await process_frame

func _finish() -> void:
	print("小游戏测试：%d 项断言，%d 项失败" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
