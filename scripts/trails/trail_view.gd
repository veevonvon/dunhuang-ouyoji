extends Control

signal solved(stage_id: String)
signal back_requested
signal sound_requested(cue: String)

const Catalog = preload("res://scripts/trails/trail_catalog.gd")
const State = preload("res://scripts/trails/trail_state.gd")
const Board = preload("res://scripts/trails/trail_board.gd")
const Guide = preload("res://scripts/trails/trail_guide.gd")
const Safe = preload("res://scripts/ui/safe_frame.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
var stage_id := "wuwei"
var reduced_motion := false
var state: RefCounted
var board: Control
var message: Label
var undo_button: Button
var guide_button: Button
var _sent := false

func configure(id: String, quiet: bool) -> void:
	stage_id = id if not Catalog.get_trail(id).is_empty() else "wuwei"
	reduced_motion = quiet
	state = State.new(stage_id)

func _ready() -> void:
	if state == null: configure(stage_id,reduced_motion)
	theme = Ui.make()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var image := TextureRect.new()
	image.texture = load("res://assets/images/%s.jpg" % stage_id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	image.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(image)
	var wash := ColorRect.new()
	wash.color = Color("102e36b8")
	wash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	wash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(wash)
	var safe := Safe.new()
	add_child(safe)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	safe.add_child(stack)
	var bar := HBoxContainer.new()
	stack.add_child(bar)
	var back := Ui.button("返回",func(): board.cancel_gesture(); back_requested.emit(),Vector2(108,64))
	back.size_flags_horizontal = SIZE_SHRINK_BEGIN
	bar.add_child(back)
	var title := Ui.label(state.info.title,38)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var location := Ui.label("%s · 寻纹" % state.info.place,22,Ui.GOLD)
	location.name = "Station"
	location.autowrap_mode = TextServer.AUTOWRAP_OFF
	location.size_flags_horizontal = SIZE_SHRINK_END
	location.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(location)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation",18)
	middle.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_child(middle)
	var reference := Ui.panel(true)
	reference.custom_minimum_size.x = 242
	reference.size_flags_vertical = SIZE_SHRINK_CENTER
	middle.add_child(reference)
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation",8)
	reference.add_child(notes)
	var prompt := Ui.label(state.info.guide,24,Ui.GOLD)
	notes.add_child(prompt)
	var guide := Guide.new()
	guide.state = state
	guide.custom_minimum_size = Vector2(204,132)
	guide.mouse_filter = MOUSE_FILTER_IGNORE
	notes.add_child(guide)
	var clue := Ui.label(state.info.clue,21)
	clue.autowrap_mode = TextServer.AUTOWRAP_OFF
	notes.add_child(clue)
	board = Board.new()
	board.configure(state, reduced_motion)
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	board.size_flags_vertical = SIZE_EXPAND_FILL
	guide.painting = board.painting
	middle.add_child(board)
	board.changed.connect(_changed)
	board.complete.connect(_complete)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	var info_bar := Ui.panel(true)
	info_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(info_bar)
	message = Ui.label(state.info.start,23)
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_bar.add_child(message)
	undo_button = Ui.button("退一步",undo,Vector2(118,66))
	guide_button = Ui.button("看提示",show_hint,Vector2(128,66),true)
	for b in [undo_button,guide_button]:
		b.size_flags_horizontal = SIZE_SHRINK_END
		footer.add_child(b)
	_refresh()

func _refresh() -> void:
	message.text = state.message
	undo_button.disabled = not board.can_undo()
	guide_button.disabled = state.done
	board.queue_redraw()

func cancel_input() -> void:
	board.cancel_gesture()

func _changed(cue: String) -> void:
	_refresh()
	sound_requested.emit(cue)

func _complete() -> void:
	if _sent: return
	_sent = true
	solved.emit(stage_id)

func show_hint() -> void:
	if state.done: return
	board.cancel_gesture()
	state.give_hint()
	_changed("hint")

func undo() -> void:
	if not board.can_undo(): return
	board.cancel_gesture()
	state.undo()
	_changed("step")
