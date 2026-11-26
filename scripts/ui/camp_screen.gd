extends "res://scripts/ui/base_screen.gd"

const Boy = preload("res://scripts/characters/boy_actor.gd")
const Deer = preload("res://scripts/characters/deer_actor.gd")
const Slot = preload("res://scripts/ui/camp_slot.gd")
const Decoration = preload("res://scripts/ui/camp_decoration.gd")
var boy: Node2D
var deer: Node2D
var mode := "camp"
var selected := ""
var page := 0
var selected_note := 0
var hint: Label
var area: Control
var inventory: VBoxContainer
var beat_buttons: Array[Button] = []
var play_button: Button
var export_hidden: Array[CanvasItem] = []

func _ready() -> void:
	setup()
	if mode == "composer": composer()
	else: camp()

func camp() -> void:
	background("camp-" + str(Journey.progress.camp.sky), .12)
	var layout := column()
	export_hidden.append(header(layout, "欧哟几的小营地", "把一路的问候，安放在这里", app.show_map))
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(body)
	area = Control.new()
	area.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(area)
	area.resized.connect(refresh_spots)
	var drawer := GameTheme.panel(true)
	drawer.custom_minimum_size.x = 300
	body.add_child(drawer)
	export_hidden.append(drawer)
	inventory = VBoxContainer.new()
	drawer.add_child(inventory)
	inventory.add_child(GameTheme.label("旅行的小礼物", 26, GameTheme.GOLD))
	hint = GameTheme.label("选一件小物，再点营地里的位置。也可以拖过去。", 19)
	inventory.add_child(hint)
	var owned: Array = Journey.available_decorations()
	for item_id: String in owned.slice(page * 3, page * 3 + 3):
		var item: Dictionary = Library.by_id("decorations", item_id)
		var button := Slot.new()
		button.item_id = item_id
		button.text = str(item.name)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		button.custom_minimum_size = Vector2(240, 78)
		button.size_flags_vertical = SIZE_EXPAND_FILL
		button.pressed.connect(func():
			selected = item_id
			hint.text = "选好了：%s\n点一个位置，轻轻放好。" % item.name
			app.audio.note(2, "wood")
		)
		inventory.add_child(button)
	var bottom := HBoxContainer.new()
	layout.add_child(bottom)
	export_hidden.append(bottom)
	bottom.add_child(GameTheme.button("换一页小物", func(): app.show_camp(posmod(page + 1, ceili(owned.size() / 3.0))), Vector2(180, 68)))
	bottom.add_child(GameTheme.button("看晨光" if Journey.progress.camp.sky == "night" else "看星夜", func():
		Journey.set_camp("sky", "dawn" if Journey.progress.camp.sky == "night" else "night")
		app.show_camp(page)
	, Vector2(160, 68)))
	var meet := GameTheme.button("和旅伴玩",app.show_companions,Vector2(160,68),true)
	meet.name = "MeetCompanions"
	bottom.add_child(meet)
	bottom.add_child(GameTheme.button("自己的小乐队", app.show_composer, Vector2(220, 68), true))
	bottom.add_child(GameTheme.button("留一张明信片", app.export_camp, Vector2(220, 68)))
	call_deferred("refresh_spots")

func refresh_spots() -> void:
	if not is_instance_valid(area): return
	for child in area.get_children():
		if child != boy and child != deer: child.queue_free()
	for i in range(6):
		var spot: Dictionary = Library.all("campSpots")[i]
		var point := Vector2(area.size.x * [.22, .5, .78][i % 3], area.size.y * (.42 if i < 3 else .74))
		var item_id := str(Journey.progress.camp.layout.get(spot.id, ""))
		var object := Decoration.new()
		object.item_id = item_id
		object.size = Vector2(112, 112)
		object.position = point - object.size / 2
		object.mouse_filter = MOUSE_FILTER_IGNORE
		area.add_child(object)
		var slot := Slot.new()
		slot.item_id = item_id
		slot.size = Vector2(112, 112)
		slot.custom_minimum_size = Vector2(112, 112)
		slot.position = point - slot.size / 2
		slot.text = str(i + 1) if item_id.is_empty() else ""
		var style := GameTheme.style(Color(.1, .3, .3, .06), 48)
		style.border_color = Color(.9, .77, .48, .5)
		style.shadow_size = 0
		slot.add_theme_stylebox_override("normal", style)
		slot.pressed.connect(func(): place(selected if not selected.is_empty() else "", str(spot.id)))
		slot.item_dropped.connect(func(id: String): place(id, str(spot.id)))
		area.add_child(slot)
		export_hidden.append(slot)
	if not is_instance_valid(boy):
		boy = Boy.new()
		deer = Deer.new()
		area.add_child(boy)
		area.add_child(deer)
		boy.scale = Vector2.ONE * .84
		deer.scale = Vector2.ONE * .78
		deer.set_locomotion(0,-1)
		refresh()
		boy.perform("rest")
	boy.position = Vector2(64,area.size.y-4)
	deer.position = Vector2(area.size.x-67,area.size.y-5)

func refresh() -> void:
	if is_instance_valid(boy):
		boy.set_reduced_motion(Journey.progress.settings.reducedMotion)
		deer.set_reduced_motion(Journey.progress.settings.reducedMotion)

func set_covered(value: bool) -> void:
	if is_instance_valid(boy):
		boy.set_active(not value)
		deer.set_active(not value)

func place(item_id: String, slot: String) -> void:
	if Journey.place_decoration(item_id, slot):
		app.audio.note(3, "wood")
		refresh_spots()
		hint.text = "放好啦。可以接着摆，或点一个摆件把它收回。"
		selected = ""

func export_mode(value: bool) -> void:
	for object in export_hidden:
		if is_instance_valid(object): object.modulate.a = 0 if value else 1

func composer() -> void:
	background("camp-night", .55)
	var layout := column()
	header(layout, "营地小乐队", "先选声音，再点拍子。每一首小曲，都属于你。", app.show_camp)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(body)
	var steps := GameTheme.panel(true)
	steps.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(steps)
	var step_stack := VBoxContainer.new()
	steps.add_child(step_stack)
	step_stack.add_child(GameTheme.label("我的八拍小曲", 28, GameTheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	step_stack.add_child(grid)
	for i in range(8):
		var note: Dictionary = note_info(int(Journey.progress.camp.notes[i]))
		var button := GameTheme.tile("第 %d 拍" % (i + 1), str(note.icon), func(): change_beat(i), Vector2(138, 125))
		button.size_flags_vertical = SIZE_EXPAND_FILL
		grid.add_child(button)
		beat_buttons.append(button)
	var palette := GameTheme.panel(true)
	palette.custom_minimum_size.x = 460
	body.add_child(palette)
	var tones := VBoxContainer.new()
	palette.add_child(tones)
	tones.add_child(GameTheme.label("选一种颜色的声音", 26, GameTheme.GOLD))
	var notes := GridContainer.new()
	notes.columns = 3
	notes.size_flags_vertical = SIZE_EXPAND_FILL
	tones.add_child(notes)
	for info: Dictionary in Library.all("campNotes"):
		var button := GameTheme.tile(str(info.name), str(info.icon), func():
			selected_note = int(info.value)
			app.audio.note(selected_note, str(Journey.progress.camp.voice))
			for child: Button in notes.get_children(): child.modulate = Color.WHITE
			var index := int(info.value) if int(info.value) >= 0 else 5
			notes.get_child(index).modulate = Color("ffe1a0")
		, Vector2(128, 108), int(info.value) == selected_note)
		notes.add_child(button)
	var voices := HBoxContainer.new()
	tones.add_child(voices)
	for voice: Dictionary in Library.all("campVoices"):
		voices.add_child(GameTheme.button(str(voice.name), func():
			Journey.set_camp("voice", str(voice.id))
			app.show_composer()
		, Vector2(120, 64), Journey.progress.camp.voice == voice.id))
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	actions.add_child(GameTheme.button("慢慢唱" if Journey.progress.camp.tempo == 80 else "轻快唱", func():
		Journey.set_camp("tempo", 100 if Journey.progress.camp.tempo == 80 else 80)
		app.show_composer()
	, Vector2(190, 70)))
	play_button = GameTheme.button("听我的曲", toggle_play, Vector2(280, 70), true)
	actions.add_child(play_button)
	actions.add_child(GameTheme.button("回到小营地", app.show_camp, Vector2(190, 70)))
	app.audio.beat.connect(highlight_beat)
	app.audio.composition_finished.connect(func():
		if is_instance_valid(play_button): play_button.text = "听我的曲"
	)

func note_info(value: int) -> Dictionary:
	for item: Dictionary in Library.all("campNotes"):
		if int(item.value) == value: return item
	return Library.all("campNotes")[5]

func change_beat(index: int) -> void:
	app.audio.stop_composition()
	var notes: Array = Journey.progress.camp.notes.duplicate()
	notes[index] = selected_note
	Journey.set_camp("notes", notes)
	app.audio.note(selected_note, str(Journey.progress.camp.voice))
	var glyphs := beat_buttons[index].find_children("*", "Control", true, false)
	for glyph in glyphs:
		if glyph.get_script() == load("res://scripts/ui/glyph.gd"):
			glyph.set("symbol", str(note_info(selected_note).icon))
			glyph.queue_redraw()

func toggle_play() -> void:
	if not app.audio.composition.is_empty():
		app.audio.stop_composition()
	else:
		app.audio.play_composition(Journey.progress.camp.notes, str(Journey.progress.camp.voice), int(Journey.progress.camp.tempo))
		play_button.text = "停下来"

func highlight_beat(index: int) -> void:
	for i in range(beat_buttons.size()):
		beat_buttons[i].modulate = Color("ffe19b") if index == i else Color.WHITE
