class_name MiniGameView
extends Control

signal finished(game_id: String)
signal back_requested
signal narration_requested(id: String)
signal note_requested(note: int, voice: String)
signal paint_changed(index: int, color: String)

const Session = preload("res://scripts/games/game_session.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
const Backdrop = preload("res://scripts/ui/backdrop.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
const Ground = preload("res://assets/edition/props/silk-ground.webp")
const SafeFrame = preload("res://scripts/ui/safe_frame.gd")
const TravelBoard = preload("res://scripts/games/travel_board.gd")
const CreativeBoard = preload("res://scripts/games/creative_board.gd")
const RhythmBoard = preload("res://scripts/games/rhythm_board.gd")
const TITLES := {
	"pack": "小小商队出发", "water": "绿洲喝水啦", "memory": "丝路寻宝", "route": "穿过大关城", "music": "花雨小乐队",
	"mural": "壁画里的小鹿", "paint": "我的矿彩莲花", "history": "时光排排队", "weave": "织一条彩带", "trade": "公平小集市", "stars": "星光连连看",
}

var session: RefCounted = Session.new()
var board: Control
var game_id := "pack"
var content: Dictionary = {}
var progress: Dictionary = {}
var activity: Dictionary = {}
var _sent_completion := false
var _active := false
var _message: Label
var _counter: Label
var _main_button: Button
var _extra_button: Button
var _reset_button: Button

func configure(id: String, data: Dictionary, saved_progress: Dictionary) -> void:
	game_id = id if TITLES.has(id) else "pack"
	content = data
	progress = saved_progress.duplicate(true)
	activity = {}
	for item in content.get("activities", []):
		if item.get("id", "") == game_id: activity = item
	session.start(game_id, content, progress)
	_sent_completion = false

func _ready() -> void:
	if session.state.is_empty(): configure(game_id, content, progress)
	theme = Ui.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_active = true
	_build()
	visibility_changed.connect(_visibility_changed)
	_refresh()

func _build() -> void:
	var station := str(activity.get("stageId", "wuwei"))
	var background := Backdrop.new()
	background.picture = load("res://assets/images/%s.jpg" % station)
	background.shade = 0.25
	background.motion = false
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	Art.scrim(self, 150, Color("09252be8"), Color("12363b00"))
	Art.scrim(self, 110, Color.TRANSPARENT, Color("0a2229db"), true)
	var margin := SafeFrame.new()
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 77
	column.add_child(header)
	var back := Ui.button("返回旅途", _back, Vector2(148, 64))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	header.add_child(Art.picture(Art.seal(station), Vector2(72, 72)))
	var title := Ui.heading(str(activity.get("title", TITLES[game_id])), 39)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(title)
	_counter = Ui.label("", 22, Ui.GOLD)
	_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counter.size_flags_horizontal = Control.SIZE_SHRINK_END
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_counter)
	var voice := Ui.button("听提示", _narrate, Vector2(138, 64))
	voice.size_flags_horizontal = Control.SIZE_SHRINK_END
	voice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(voice)
	var frame := Ui.panel(game_id == "stars")
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 345
	column.add_child(frame)
	var surface := Control.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(surface)
	var ground := TextureRect.new()
	ground.texture = Ground
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if game_id == "stars": ground.self_modulate = Color("22404b")
	surface.add_child(ground)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.offset_left = -12
	ground.offset_top = -9
	ground.offset_right = 12
	ground.offset_bottom = 9
	if game_id in ["pack", "water", "memory", "route"]: board = TravelBoard.new()
	elif game_id in ["mural", "paint", "history", "weave"]: board = CreativeBoard.new()
	else: board = RhythmBoard.new()
	board.configure(session, content)
	board.action_requested.connect(perform)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var feedback := HBoxContainer.new()
	feedback.custom_minimum_size.y = 76
	feedback.add_theme_constant_override("separation", 10)
	column.add_child(feedback)
	var message_box := Ui.panel(true)
	message_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback.add_child(message_box)
	_message = Ui.label("", 22)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_box.add_child(_message)
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 10)
	feedback.add_child(actions)
	_reset_button = Ui.button("再试一次", _reset_or_undo)
	actions.add_child(_reset_button)
	_extra_button = Ui.button("看看小提示", _extra)
	actions.add_child(_extra_button)
	_main_button = Ui.button("听提示", _primary, Vector2(156, 64), true)
	actions.add_child(_main_button)

func perform(action: Dictionary) -> void:
	if not _active or not is_inside_tree() or not is_visible_in_tree(): return
	var previous: Array = session.state.get("colors", []).duplicate()
	var tones: Array = session.act(action, Time.get_ticks_msec())
	if game_id == "paint":
		for i in range(10):
			if previous[i] != session.state.colors[i]:
				progress.get_or_add("paint", {})[str(i)] = session.state.colors[i]
				paint_changed.emit(i, session.state.colors[i])
	for note in tones: note_requested.emit(int(note), "bell")
	_refresh()
	if session.state.done and not _sent_completion:
		_sent_completion = true
		finished.emit(game_id)

func _process(_delta: float) -> void:
	if not _active or not is_visible_in_tree(): return
	if game_id not in ["music", "memory"]: return
	var before: Dictionary = session.state.duplicate(true)
	var tones: Array = session.tick(Time.get_ticks_msec())
	for note in tones: note_requested.emit(int(note), "bell")
	if before != session.state: _refresh()

func _counter_text() -> String:
	var s: Dictionary = session.state
	match game_id:
		"pack": return "行囊 %d / 4" % s.cargo.size()
		"water": return "水渠接通啦" if s.done else "让水慢慢流过去"
		"memory": return "宝物 %d / 4 对" % (s.matched.size() / 2)
		"route": return "商队到关城啦" if s.done else "一步一格"
		"music", "trade", "stars": return "第 %d / 3 轮" % (s.round + 1)
		"mural": return "画片 %d / 6" % (6 - s.slots.count(-1))
		"paint": return "花瓣 %d / 10" % (10 - s.colors.count(""))
		"history": return "故事有先有后"
		"weave": return "彩带 %d / 12" % (12 - s.cells.count(""))
	return ""

func _refresh() -> void:
	if not is_instance_valid(_message): return
	_message.text = Session.INSTRUCTIONS[game_id] if session.state.message == activity.get("instruction", "") else session.state.message
	_counter.text = _counter_text()
	var done: bool = session.state.done
	_reset_button.text = "再玩一次" if done else "取回一块" if game_id == "trade" else "退回一步" if game_id == "route" else "重新连线" if game_id == "stars" else "重新开始"
	_extra_button.text = "帮一小步" if game_id in ["water", "history"] and not done else "换个花样" if game_id == "weave" and not done else "看看小提示"
	if done: _main_button.text = "收好印章 · 返回"
	elif game_id in ["paint", "history"]: _main_button.text = "做好啦"
	elif game_id == "trade": _main_button.text = "称好啦"
	elif game_id == "music":
		var s: Dictionary = session.state
		_main_button.text = "下一段乐句" if s.cursor == Session.Rules.MELODIES[s.round].size() else "停止示范" if s.play_at >= 0 else "听一遍示范"
	elif game_id == "stars" and session.state.path.size() == Session.Rules.STARS[session.state.round].size(): _main_button.text = "下一幅星图"
	else: _main_button.text = "听提示"
	_main_button.visible = _main_button.text != "听提示"
	board.queue_redraw()

func _primary() -> void:
	if session.state.done:
		_back()
	elif game_id in ["paint", "history", "trade"]: perform({"type": "check"})
	elif game_id == "music":
		var s: Dictionary = session.state
		perform({"type": "next" if s.cursor == Session.Rules.MELODIES[s.round].size() else "stop" if s.play_at >= 0 else "listen"})
	elif game_id == "stars" and session.state.path.size() == Session.Rules.STARS[session.state.round].size(): perform({"type": "next"})
	else: _narrate()

func _reset_or_undo() -> void:
	board.cancel_pointer()
	if not session.state.done and game_id in ["route", "trade", "stars"]:
		perform({"type": "undo"})
	else:
		session.cancel()
		session.start(game_id, content, progress)
		# One mounted activity can award at most once, even after replay.
		_refresh()

func _extra() -> void:
	if not session.state.done and game_id in ["water", "history"]: perform({"type": "hint"})
	elif not session.state.done and game_id == "weave": perform({"type": "pattern"})
	else:
		session.state.message = str(activity.get("hint", Session.INSTRUCTIONS[game_id]))
		_refresh()

func _narrate() -> void:
	_extra_hint()
	narration_requested.emit("game-" + game_id)

func _extra_hint() -> void:
	session.state.message = str(activity.get("hint", Session.INSTRUCTIONS[game_id]))
	_refresh()

func _back() -> void:
	_active = false
	cancel_input()
	back_requested.emit()

func cancel_input() -> void:
	session.cancel()
	if is_instance_valid(board): board.cancel_pointer()

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_input()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel_input()

func _exit_tree() -> void:
	_active = false
	session.cancel()
