extends "res://scripts/ui/base_screen.gd"

const Joystick = preload("res://scripts/ui/joystick.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
const Dial = preload("res://scripts/ui/action_dial.gd")
var mode := "world"
var status: Button
var ending_status: Label
var claim_button: Button
var ending_lit: Array[String] = []
var joystick: Control

func _ready() -> void:
	setup()
	if mode == "ending": ending()
	else: world_hud()

func world_hud() -> void:
	Art.scrim(self, 170, Color("102c32d4"), Color("102c3200"))
	Art.scrim(self, 132, Color("102c3200"), Color("132f366b"), true)
	var layout := column()
	var chapter: Dictionary = Library.by_id("chapters", app.stage_id)
	var station: Dictionary = Library.by_id("stages", app.stage_id)
	var bar := header(layout, "%s · %s" % [station.name, chapter.title], chapter.ambience, app.show_map)
	var field := GameTheme.button("逛景点", func(): app.show_atlas("world", app.stage_id),Vector2(119,64),true)
	field.name = "OpenAtlas"
	field.size_flags_horizontal = SIZE_SHRINK_END
	bar.add_child(field)
	bar.move_child(field, bar.get_child_count()-2)
	var letter := GameTheme.button("送问候", app.open_letters, Vector2(120,64))
	letter.size_flags_horizontal = SIZE_SHRINK_END
	bar.add_child(letter)
	bar.move_child(letter, bar.get_child_count() - 2)
	status = GameTheme.button("", app.guide, Vector2(342,64))
	status.name = "Guide"
	status.add_theme_font_size_override("font_size", 20)
	status.size_flags_horizontal = SIZE_SHRINK_BEGIN
	layout.add_child(status)
	space(layout)
	var actions := HBoxContainer.new()
	actions.mouse_filter = MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	var stick := Joystick.new()
	joystick = stick
	stick.engaged.connect(app.world.set_joystick_active)
	stick.moved.connect(app.world.set_move_direction)
	actions.add_child(stick)
	space(actions)
	add_dial(actions, "聊一聊", Art.face(app.stage_id), "scroll", func(): app.open_story())
	add_dial(actions, "帮朋友", null, str(station.icon), func(): app.show_game(str(chapter.requiredGame)))
	claim_button = add_dial(actions, "收风铃", null, "bell", app.claim_bell)
	var trail := add_dial(actions, "寻纹", Art.seal(app.stage_id), "lotus", func(): app.show_trail(app.stage_id), true)
	trail.name = "FindSeal"
	refresh()

func add_dial(parent: Control, caption: String, texture: Texture2D, glyph: String, callback: Callable, primary := false) -> Button:
	var button := Dial.new()
	button.configure(caption, texture, glyph, primary)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func cancel_input() -> void:
	if is_instance_valid(joystick): joystick.cancel()

func refresh() -> void:
	if mode != "world" or status == null: return
	var story: Dictionary = Journey.progress.journey
	var count: int = Journey.explored_count(app.stage_id)
	var chapter: Dictionary = Library.by_id("chapters", app.stage_id)
	var goal := "聊聊这一站的故事"
	if app.stage_id in story.conversations:
		if count < 2: goal = "发现风景 %d / 2" % count
		elif chapter.requiredGame not in Journey.progress.completed: goal = "帮朋友做一件事"
		elif app.stage_id in story.claimed: goal = "这一站的风铃收好了"
		else: goal = "去收风铃"
	status.text = "鹿铃引路 · " + goal
	claim_button.modulate = Color.WHITE if Journey.can_claim(app.stage_id) else Color(.85, .88, .8)

func ending() -> void:
	background("ending", .3)
	var layout := column()
	header(layout, "风铃唱起来了", "准备 · 照顾 · 分享 · 勇气 · 倾听 · 创造", app.show_map)
	space(layout)
	ending_status = GameTheme.label("点亮每一枚风铃，让旅程一起唱起来。", 32)
	ending_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(ending_status)
	var chimes := HBoxContainer.new()
	chimes.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(chimes)
	for i in range(6):
		var chapter: Dictionary = Library.all("chapters")[i]
		var button := GameTheme.tile(str(chapter.quality), "bell", Callable(), Vector2(156, 130))
		button.pressed.connect(func():
			if str(chapter.id) in ending_lit: return
			ending_lit.append(str(chapter.id))
			button.modulate = Color("fff4b1")
			app.audio.cue("seal", str(chapter.id))
			if ending_lit.size() == 6:
				Journey.finish_ending()
				ending_status.text = "小小的我，也能给世界温柔的光。"
				app.audio.play_composition([0, 2, 3, 4, 3, 2, 1, 0], "bell", 80)
		)
		chimes.add_child(button)
	space(layout)
	var finish := HBoxContainer.new()
	layout.add_child(finish)
	finish.add_child(GameTheme.button("去营地庆祝", app.show_camp, Vector2(240, 72), true))
	finish.add_child(GameTheme.button("再看看朋友", app.show_map, Vector2(240, 72)))
