extends "res://scripts/ui/base_screen.gd"

var category := "games"
var page := 0

func _ready() -> void:
	setup()
	background("map", .65)
	var layout := column()
	header(layout, "我的旅行手记", "每一个小发现，都有自己的故事", app.show_map)
	var tabs := HBoxContainer.new()
	layout.add_child(tabs)
	for tab: Array in [["games", "玩一玩"], ["facts", "看山河"], ["history", "听时光"], ["bells", "六枚风铃"]]:
		tabs.add_child(GameTheme.button(str(tab[1]), func(): app.show_book(str(tab[0])), Vector2(140, 64), category == tab[0]))
	var content := Control.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(content)
	var total := 1
	if category == "games":
		total = ceili(Library.all("activities").size() / 6.0)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.add_child(grid)
		for activity: Dictionary in Library.all("activities").slice(page * 6, page * 6 + 6):
			var caption := str(activity.title)
			if activity.id in Journey.progress.completed: caption += " ✓"
			var button := GameTheme.tile(caption, str(activity.icon), func(): app.show_game(str(activity.id)), Vector2(270, 150), activity.id in Journey.progress.completed)
			button.size_flags_vertical = SIZE_EXPAND_FILL
			grid.add_child(button)
	else:
		var collection := "facts" if category == "facts" else "historyEvents" if category == "history" else "chapters"
		var items: Array = Library.all(collection)
		total = items.size()
		var item: Dictionary = items[posmod(page, total)]
		var paper := GameTheme.panel(false)
		paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.add_child(paper)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 36)
		paper.add_child(row)
		var glyph := GameTheme.icon(str(item.get("icon", "bell")), Vector2(170, 170))
		glyph.set("color", GameTheme.RUST)
		glyph.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(glyph)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(GameTheme.label(str(item.get("bell", item.get("title", ""))), 34, GameTheme.INK))
		if category == "history": words.add_child(GameTheme.label("%s · %s" % [item.era, item.date], 20, GameTheme.RUST))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		words.add_child(scroll)
		var message: String
		if category == "bells":
			message = str(item.journal) if item.id in Journey.progress.journey.claimed else "听听朋友的故事，看看两处风景，再帮朋友完成小游戏。一路向西，就能找回这枚风铃。"
		else:
			message = str(item.child)
		var text := GameTheme.label(message, 28, GameTheme.INK)
		text.add_theme_constant_override("line_spacing", 12)
		scroll.add_child(text)
		var actions := HBoxContainer.new()
		words.add_child(actions)
		if category == "bells":
			actions.add_child(GameTheme.button("去看看这位朋友", func(): app.show_world(str(item.id)), Vector2(250, 68), true))
		else:
			var voice_prefix := "fact-" if category == "facts" else "history-"
			actions.add_child(GameTheme.button("听一听", func(): app.audio.speak(voice_prefix + str(item.id)), Vector2(170, 68), true))
			actions.add_child(GameTheme.button("给大人看", func(): app.show_source(item), Vector2(170, 68)))
	var foot := HBoxContainer.new()
	layout.add_child(foot)
	var last := GameTheme.button("上一页", func(): app.show_book(category, posmod(page - 1, total)), Vector2(150, 64))
	last.size_flags_horizontal = SIZE_SHRINK_BEGIN
	foot.add_child(last)
	var count := GameTheme.label("%d / %d    ·    已收好 %d 枚印章" % [page + 1, total, Journey.progress.completed.size()], 22)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(count)
	var next := GameTheme.button("下一页", func(): app.show_book(category, posmod(page + 1, total)), Vector2(150, 64))
	next.size_flags_horizontal = SIZE_SHRINK_END
	foot.add_child(next)
