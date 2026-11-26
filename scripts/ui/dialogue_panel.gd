extends Control

signal chosen(action: String)
signal dismissed
const Art = preload("res://scripts/ui/edition_art.gd")
const ActorPortrait = preload("res://scripts/ui/actor_portrait.gd")
const SafeFrame = preload("res://scripts/ui/safe_frame.gd")
var heading := "鹿铃的小提示"
var body := ""
var choices: Array = []
var symbol := "scroll"
var performance := ""
var animal := false
var live: Control
var illustration: Texture2D
var frame: PanelContainer
var holder: Control
var scroll: ScrollContainer
var actions: GridContainer

func configure(title: String, message: String, options: Array, glyph := "scroll", art: Texture2D = null, pose := "", deer := false) -> void:
	heading = title
	body = message
	choices = options
	symbol = glyph
	illustration = art
	performance = pose
	animal = deer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = GameTheme.make()
	var shade := ColorRect.new()
	shade.color = Color("122b3280") if has_picture() else Color("10292eaa")
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	var safe := SafeFrame.new()
	add_child(safe)
	holder = Control.new()
	safe.add_child(holder)
	frame = GameTheme.panel(false)
	frame.name = "DialogFrame"
	holder.add_child(frame)
	frame.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM if has_picture() else PRESET_CENTER)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	frame.add_child(stack)
	var top := HBoxContainer.new()
	stack.add_child(top)
	var ornament := GameTheme.icon(symbol, Vector2(34, 34))
	ornament.color = Color("966037")
	top.add_child(ornament)
	var nameplate := GameTheme.heading(heading, 32, GameTheme.INK)
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(nameplate)
	var close := GameTheme.button("收起", func(): dismissed.emit(), Vector2(98,64))
	close.size_flags_horizontal = SIZE_SHRINK_END
	top.add_child(close)
	var page := HBoxContainer.new()
	page.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 20)
	stack.add_child(page)
	if not performance.is_empty():
		live = ActorPortrait.new()
		live.name = "LivePortrait"
		live.action = performance
		live.animal = animal
		page.add_child(live)
	elif illustration:
		var portrait := Art.picture(illustration, Vector2(135,108))
		portrait.size_flags_horizontal = SIZE_SHRINK_BEGIN
		page.add_child(portrait)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 72
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var message := GameTheme.label(body, 26, GameTheme.INK)
	message.add_theme_constant_override("line_spacing", 5)
	message.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	scroll.add_child(message)
	actions = GridContainer.new()
	actions.columns = mini(choices.size(), 2) if choices.size() > 3 else maxi(1, choices.size())
	actions.add_theme_constant_override("v_separation", 8)
	actions.add_theme_constant_override("h_separation", 10)
	stack.add_child(actions)
	for option: Dictionary in choices:
		var id := str(option.get("action", "close"))
		var button := GameTheme.button(str(option.label), func(): chosen.emit(id), Vector2(158,64), bool(option.get("accent", false)))
		button.name = "Choice_" + id
		actions.add_child(button)
	holder.resized.connect(_fit_frame)
	_fit_frame()
	close.grab_focus(true)

func has_picture() -> bool:
	return illustration != null or not performance.is_empty()

func replay_actor() -> void:
	if is_instance_valid(live): live.actor.perform(performance,true)

func _fit_frame() -> void:
	if not is_instance_valid(holder) or holder.size.x < 1: return
	var width := minf(960 if has_picture() else 880, holder.size.x - 24)
	var text_width := maxf(1, width - (235 if has_picture() else 72))
	var lines := 0
	for paragraph in body.split("\n"):
		lines += maxi(1, ceili(theme.default_font.get_string_size(paragraph,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x / text_width))
		if lines >= 14: break
	var text_height := maxf(108 if has_picture() else 78, lines*40)
	var buttons_height := maxf(actions.get_combined_minimum_size().y, ceili(float(choices.size())/actions.columns)*72 - 8)
	var height := minf(holder.size.y - 12, 123 + text_height + buttons_height)
	frame.offset_left = -width / 2
	frame.offset_right = width / 2
	if has_picture():
		frame.offset_top = -height - 4
		frame.offset_bottom = -4
	else:
		frame.offset_top = -height / 2
		frame.offset_bottom = height / 2
