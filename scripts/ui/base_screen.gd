extends Control

const Backdrop = preload("res://scripts/ui/backdrop.gd")
const SafeFrame = preload("res://scripts/ui/safe_frame.gd")
var app: Node

func setup() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = GameTheme.make()
	mouse_filter = MOUSE_FILTER_IGNORE

func background(id: String, dim := .35) -> void:
	var layer := Backdrop.new()
	layer.picture = load(id if id.begins_with("res://") else Library.image_path(id))
	layer.shade = dim
	Journey.changed.connect(layer.follow_motion_setting)
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(layer)
	layer.follow_motion_setting()

func column() -> VBoxContainer:
	var safe := SafeFrame.new()
	safe.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(safe)
	var stack := VBoxContainer.new()
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	safe.add_child(stack)
	return stack

func header(stack: VBoxContainer, title: String, subtitle: String, callback: Callable) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(bar)
	var back := GameTheme.button("返回", callback, Vector2(112, 64))
	back.size_flags_horizontal = SIZE_SHRINK_BEGIN
	bar.add_child(back)
	var words := VBoxContainer.new()
	words.mouse_filter = MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	bar.add_child(words)
	words.add_child(GameTheme.heading(title, 34))
	words.add_child(GameTheme.label(subtitle, 19, GameTheme.GOLD))
	var menu := GameTheme.button("行囊", app.show_settings, Vector2(112, 64))
	menu.size_flags_horizontal = SIZE_SHRINK_END
	bar.add_child(menu)
	return bar

func space(parent: Node) -> Control:
	var empty := Control.new()
	empty.mouse_filter = MOUSE_FILTER_IGNORE
	empty.size_flags_horizontal = SIZE_EXPAND_FILL
	empty.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(empty)
	return empty

func portrait(id: String, rectangle: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = load(Library.image_path(id))
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = rectangle.position
	picture.size = rectangle.size
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture
