extends Button

const SHORT_NAMES := {
	"wuwei-well": "井台", "wuwei-camel": "小骆驼", "wuwei-ribbon": "彩旗",
	"zhangye-wheel": "水车", "zhangye-bird": "水鸟", "zhangye-snow": "雪峰",
	"jiuquan-grapes": "葡萄架", "jiuquan-letter": "信箱", "jiuquan-lantern": "灯笼",
	"jiayuguan-brick": "城砖", "jiayuguan-horizon": "远山", "jiayuguan-arch": "拱门",
	"guazhou-pipa": "琵琶", "guazhou-reeds": "芦苇", "guazhou-caves": "小花",
	"dunhuang-lotus": "莲花", "dunhuang-moon": "月牙泉", "dunhuang-stars": "星星",
}
var caption := ""
var observed := false
var trail := false
var emblem: Texture2D
var glyph: Control
var font: Font

func configure(point: Dictionary, found: bool, is_trail: bool, art: Texture2D) -> void:
	caption = SHORT_NAMES.get(point.id, point.name)
	observed = found
	trail = is_trail
	emblem = art
	tooltip_text = str(point.name)
	accessibility_name = tooltip_text
	custom_minimum_size = Vector2(112, 93)
	flat = true
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	if not trail:
		glyph = GameTheme.icon(str(point.icon), Vector2(28, 28))
		glyph.position = Vector2(42, 12)
		add_child(glyph)

func _ready() -> void:
	font = GameTheme.make().default_font

func mark_observed() -> void:
	observed = true
	queue_redraw()

func _draw() -> void:
	if not font: return
	var center := Vector2(56, 26)
	var ring := 26.0 if trail else 22.0
	draw_line(center + Vector2.DOWN * ring, Vector2(56, 85), Color("f4daa1"), 2, true)
	draw_circle(Vector2(56, 88), 3, GameTheme.GOLD, true, -1, true)
	draw_circle(center, ring, Color("1a4344e8"), true, -1, true)
	draw_arc(center, ring, 0, TAU, 48, GameTheme.GOLD, 2, true)
	if has_focus() or is_hovered(): draw_arc(center, ring + 4, 0, TAU, 48, GameTheme.LIGHT, 2, true)
	if emblem: draw_texture_rect(emblem, Rect2(center-Vector2(28,28), Vector2(56,56)), false)
	var label := "寻纹" if trail and not observed else caption
	var width := maxf(58, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 20)
	var plate := Rect2(56-width/2, 49, width, 29)
	draw_rect(plate, Color("143c3fea"))
	draw_line(plate.position, Vector2(plate.end.x, plate.position.y), Color("d8bd85"), 1, true)
	draw_string(font, Vector2(0, 71), label, HORIZONTAL_ALIGNMENT_CENTER, 112, 19, GameTheme.LIGHT)
	if observed:
		draw_circle(center + Vector2(17, 15), 7, Color("9c4d38"), true, -1, true)
		draw_arc(center + Vector2(17, 15), 7, 0, TAU, 20, GameTheme.GOLD, 1, true)
