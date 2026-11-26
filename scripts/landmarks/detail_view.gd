extends Control

signal solved(local_id: String)
signal back_requested
signal sound_requested(cue: String)
signal note_requested(pitch: int)

const State = preload("res://scripts/landmarks/detail_state.gd")
const Board = preload("res://scripts/landmarks/detail_board.gd")
const Folio = preload("res://scripts/landmarks/detail_folio.gd")
const Safe = preload("res://scripts/ui/safe_frame.gd")
const Ui = preload("res://scripts/ui/game_theme.gd")
var site: Dictionary
var detail: Dictionary
var reduced_motion:=false
var state: RefCounted
var board: Control
var folio: Control
var feedback: Label
var hint_button: Button
var listen: Button
var again: Button
var _awarded:=false

func configure(place: Dictionary, activity: Dictionary, reduced: bool) -> void:
	site=place
	detail=activity
	reduced_motion=reduced
	state=State.new(site,detail)

func _ready() -> void:
	theme=Ui.make()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var path:="res://assets/landmarks/paintings/%s.webp" % site.id
	if not ResourceLoader.exists(path): path="res://assets/images/%s.jpg" % site.get("station","dunhuang")
	var art:=load(path) as Texture2D
	var backdrop:=TextureRect.new()
	backdrop.texture=art
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var wash:=ColorRect.new()
	wash.color=Color("123438d9")
	wash.mouse_filter=MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(wash)
	var safe:=Safe.new()
	add_child(safe)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	safe.add_child(stack)
	var header:=HBoxContainer.new()
	stack.add_child(header)
	var back:=Ui.button("返回景点",_go_back,Vector2(142,64))
	back.size_flags_horizontal=SIZE_SHRINK_BEGIN
	header.add_child(back)
	var place:=Ui.heading(site.name,33)
	place.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	place.autowrap_mode=TextServer.AUTOWRAP_OFF
	place.size_flags_horizontal=SIZE_EXPAND_FILL
	header.add_child(place)
	var title:=Ui.heading("观察册",31,Ui.GOLD)
	title.autowrap_mode=TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal=SIZE_SHRINK_END
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	board=Board.new()
	board.configure(state,reduced_motion)
	board.changed.connect(_changed)
	board.note_requested.connect(func(pitch: int): note_requested.emit(pitch))
	board.demonstration_changed.connect(_update_feedback)
	folio=Folio.new()
	folio.configure(site,detail,state,board,art)
	folio.reference_changed.connect(_update_feedback)
	folio.size_flags_vertical=SIZE_EXPAND_FILL
	stack.add_child(folio)
	var footer:=HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	stack.add_child(footer)
	feedback=Ui.label("",22,Ui.LIGHT)
	feedback.size_flags_vertical=SIZE_EXPAND_FILL
	feedback.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	footer.add_child(feedback)
	listen=Ui.button("听示范",play_demo,Vector2(134,64))
	hint_button=Ui.button("看提示",show_hint,Vector2(134,64),true)
	again=Ui.button("再玩一次",replay,Vector2(152,64),true)
	for button in [listen,hint_button,again]:
		button.size_flags_horizontal=SIZE_SHRINK_END
		footer.add_child(button)
	_update_feedback()
	if state.kind=="echo": call_deferred("play_demo")

func _go_back() -> void:
	cancel_input()
	back_requested.emit()

func close_reference() -> bool:
	if not folio or not folio.enlarged_reference or not folio.enlarged_reference.visible: return false
	folio.set_reference_open(false)
	return true

func cancel_input() -> void:
	if board: board.cancel_input()

func show_hint() -> void:
	if state.done: return
	board.cancel_input()
	folio.set_reference_open(false)
	state.give_hint()
	_changed("hint")

func play_demo() -> void:
	if is_inside_tree() and is_visible_in_tree() and not state.done and state.kind=="echo": board.start_demo()

func replay() -> void:
	if not state.done: return
	board.cancel_input()
	folio.set_reference_open(false)
	state=State.new(site,detail)
	board.configure(state,reduced_motion)
	folio.state=state
	_update_feedback()
	if state.kind=="echo": play_demo()

func _changed(cue: String) -> void:
	_update_feedback()
	sound_requested.emit(cue)
	if state.done and not _awarded:
		_awarded=true
		solved.emit(str(detail.id))

func _update_feedback() -> void:
	if not feedback or not is_instance_valid(feedback): return
	var sample: String=state.message
	if board.is_listening():
		var value: int=state.sequence[board.demo_index]
		sample="看第%s声，%s。" % [["一","二","三"][board.demo_index],state.pieces[value]]
	elif state.done: sample=detail.result
	elif folio.enlarged_reference and folio.enlarged_reference.visible:
		sample="从一个兔头沿两边看，找找它和邻居共用的两只耳朵。"
	elif sample.is_empty():
		match state.kind:
			"trace": sample="从第一处出发，可以一笔连过去，也可以逐处点。"
			"pair": sample="两张可以先后点，也可以用手指连起来。"
			"turn": sample="每点一下，画片就转过一格。"
			"echo": sample="轮到你了，按听见的顺序敲三声。"
			"uncover": sample="在画稿上用指腹轻轻擦过。"
			"order": sample="看看左页的顺序，依次把三幅小画放好。"
	feedback.text=sample
	hint_button.visible=not state.done
	again.visible=state.done
	listen.visible=state.kind=="echo" and not state.done
	folio.queue_redraw()
	board.queue_redraw()
