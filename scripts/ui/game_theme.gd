class_name GameTheme
extends RefCounted

const LIGHT := Color("fff0cf")
const GOLD := Color("ebcb89")
const INK := Color("173537")
const TEAL := Color("285b57")
const RUST := Color("af6246")
const Glyph = preload("res://scripts/ui/glyph.gd")
const Illustration = preload("res://scripts/ui/edition_art.gd")
const ScrollSkin = preload("res://scripts/ui/scroll_skin.gd")
static var _theme: Theme

static func surface(top: Color, bottom: Color, edge: Color, is_panel := false) -> StyleBox:
	var skin := ScrollSkin.new()
	skin.top = top
	skin.bottom = bottom
	skin.metal = edge
	skin.panel = is_panel
	if is_panel:
		skin.content_margin_left = 23
		skin.content_margin_right = 23
		skin.content_margin_top = 17
		skin.content_margin_bottom = 17
	return skin

static func make() -> Theme:
	if _theme: return _theme
	var result := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/chinese_regular.tres"):
		result.default_font = load("res://assets/fonts/chinese_regular.tres")
	result.default_font_size = 24
	result.set_color("font_color", "Label", LIGHT)
	result.set_color("font_shadow_color", "Label", Color(0.04, 0.1, 0.11, 0.42))
	result.set_constant("shadow_offset_y", "Label", 2)
	result.set_constant("separation", "VBoxContainer", 16)
	result.set_constant("separation", "HBoxContainer", 16)
	result.set_constant("h_separation", "GridContainer", 16)
	result.set_constant("v_separation", "GridContainer", 16)
	result.set_stylebox("normal", "Button", surface(Color("285556"), Color("16383b"), Color("ba9c69")))
	result.set_stylebox("hover", "Button", surface(Color("386966"), Color("245052"), GOLD))
	result.set_stylebox("pressed", "Button", surface(Color("113334"), Color("30605a"), LIGHT))
	result.set_stylebox("disabled", "Button", surface(Color("485957"), Color("384746"), Color("888871")))
	var focus := style(Color.TRANSPARENT, 9)
	focus.shadow_size = 0
	focus.border_color = LIGHT
	focus.set_border_width_all(3)
	result.set_stylebox("focus", "Button", focus)
	for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(role, "Button", LIGHT)
	result.set_font_size("font_size", "Button", 24)
	result.set_stylebox("panel", "PanelContainer", style(Color("163d43f0"), 24))
	_theme = result
	return result

static func style(color: Color, radius := 18) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("d9b371")
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.shadow_color = Color(0.05, 0.13, 0.14, 0.35)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 4)
	return box

static func button(caption: String, callback: Callable, min_size := Vector2(156, 64), accent := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = min_size
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.clip_text = false
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	if accent:
		b.add_theme_stylebox_override("normal", surface(Color("be6549"), Color("8a3e32"), Color("f0c785")))
		b.add_theme_stylebox_override("hover", surface(Color("cc7654"), Color("a24a37"), Color("ffde9e")))
		b.add_theme_stylebox_override("pressed", surface(Color("783829"), Color("b05d40"), LIGHT))
	if callback.is_valid(): b.pressed.connect(callback)
	return b

static func label(caption: String, font_size := 24, color := LIGHT) -> Label:
	var l := Label.new()
	l.text = caption
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func panel(dark := false) -> PanelContainer:
	var p := PanelContainer.new()
	if dark:
		p.add_theme_stylebox_override("panel", surface(Color("254e4e"), Color("142f34"), Color("c9a971"), true))
	else:
		p.add_theme_stylebox_override("panel", surface(Color("fbebc9"), Color("e7cca0"), Color("a77c48"), true))
	return p

static func heading(caption: String, font_size: int, color := LIGHT) -> Label:
	var result := label(caption, font_size, color)
	result.add_theme_font_override("font", load("res://assets/fonts/scroll_titles.tres"))
	return result

static func margin(amount := 20) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, amount)
	return m

static func icon(symbol: String, extent := Vector2(36, 36)) -> Control:
	var g := Glyph.new()
	g.symbol = symbol
	g.custom_minimum_size = extent
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

static func tile(caption: String, symbol: String, callback: Callable, extent := Vector2(156, 108), accent := false, art: Texture2D = null) -> Button:
	var b := button("", callback, extent, accent)
	b.tooltip_text = caption
	var inset := margin(10)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(inset)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	inset.add_child(stack)
	var symbol_art: Control
	if art:
		symbol_art = Illustration.picture(art,Vector2(50,48))
	else:
		symbol_art = icon(symbol, Vector2(38,38))
		symbol_art.color = GOLD
	symbol_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(symbol_art)
	var title := label(caption, 22, LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	return b
