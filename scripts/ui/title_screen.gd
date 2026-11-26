extends "res://scripts/ui/base_screen.gd"

func _ready() -> void:
	setup()
	background("res://assets/edition/opening.webp", .05)
	var layout := column()
	var top := HBoxContainer.new()
	layout.add_child(top)
	space(top)
	var menu := GameTheme.button("行囊", app.show_settings, Vector2(102, 64))
	menu.size_flags_horizontal = SIZE_SHRINK_END
	top.add_child(menu)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(body)
	space(body)
	var words := VBoxContainer.new()
	words.custom_minimum_size.x = 484
	words.add_theme_constant_override("separation", 13)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(words)
	var subtitle := GameTheme.label("欧哟几的河西之旅", 23, GameTheme.GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(subtitle)
	var title := GameTheme.heading("敦煌奇游记", 76)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(title)
	var divider := Control.new()
	divider.custom_minimum_size.y = 15
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(divider)
	divider.draw.connect(func():
		var mid := divider.size / 2
		for axis in [-1, 1]:
			divider.draw_line(mid + Vector2(17 * axis, 0), mid + Vector2(110 * axis, 0), Color("cfb67c"), 1, true)
			divider.draw_circle(mid + Vector2(12 * axis, 0), 1.6, GameTheme.GOLD, true, -1, true)
		divider.draw_polyline(PackedVector2Array([mid+Vector2(-6,0),mid+Vector2(0,-4),mid+Vector2(6,0),mid+Vector2(0,4),mid+Vector2(-6,0)]), GameTheme.GOLD, 1.4, true)
	)
	var guide := GameTheme.label("和鹿铃一起，走进河西四季的山河。", 22)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(guide)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(gap)
	var depart := GameTheme.button("继续旅行" if Journey.progress.journey.started else "和欧哟几出发", app.depart, Vector2(312, 78), true)
	depart.name = "Depart"
	depart.size_flags_horizontal = SIZE_SHRINK_CENTER
	depart.add_theme_font_size_override("font_size", 29)
	words.add_child(depart)
	var shortcuts := HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcuts.add_theme_constant_override("separation", 12)
	words.add_child(shortcuts)
	for item: Array in [["四时山河",func(): app.show_atlas("home")],["旅行地图", app.show_map], ["纹印谱", func(): app.show_album("home")]]:
		var action := GameTheme.button(item[0], item[1], Vector2(138, 64), item[0] == "四时山河")
		action.size_flags_horizontal = SIZE_SHRINK_CENTER
		if item[0] == "纹印谱": action.name = "OpenAlbum"
		if item[0] == "四时山河": action.name = "OpenAtlas"
		shortcuts.add_child(action)
	var foot := HBoxContainer.new()
	layout.add_child(foot)
	var welcome := GameTheme.button("听欧哟几讲", app.welcome, Vector2(166, 64))
	welcome.size_flags_horizontal = SIZE_SHRINK_BEGIN
	foot.add_child(welcome)
	space(foot)
	var camp := GameTheme.button("小营地",app.show_camp,Vector2(108,64))
	camp.size_flags_horizontal = SIZE_SHRINK_END
	foot.add_child(camp)
