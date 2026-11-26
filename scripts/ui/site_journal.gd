extends "res://scripts/ui/base_screen.gd"

const Catalog = preload("res://scripts/landmarks/catalog.gd")
const Scenery = preload("res://scripts/landmarks/scenery.gd")
const Print = preload("res://scripts/ui/scenic_print.gd")
var place: Dictionary

func _ready() -> void:
	setup()
	background("camp-night", .78)
	var page: Dictionary = Journey.landmark_page(place.id)
	var layout := column()
	header(layout, "%s的写生页" % place.short, "发现 %d / 3 件细节   ·   留下 %d / 16 幅时景" % [page.details.size(),page.prints.size()], app.return_to_landmark)
	var spread := HBoxContainer.new()
	spread.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(spread)
	var leaf := GameTheme.panel(false)
	leaf.size_flags_horizontal = SIZE_EXPAND_FILL
	spread.add_child(leaf)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	leaf.add_child(left)
	var scene := Scenery.new()
	scene.configure(place, page.season, page.phase, true)
	scene.custom_minimum_size = Vector2(175,110)
	scene.size_flags_vertical = SIZE_EXPAND_FILL
	scene.clip_contents = true
	left.add_child(scene)
	scene.set_hotspots_visible(false)
	var label := GameTheme.heading("欧哟几的发现",27,GameTheme.INK)
	left.add_child(label)
	for item: Dictionary in place.details:
		var finished: bool = item.id in page.details
		var button := GameTheme.button(("回看 · " if finished else "去发现 · ") + str(item.title), func(): app.journal_detail(item.id), Vector2(176,64), false)
		button.name = "Note_" + str(item.id)
		left.add_child(button)
	var facing := GameTheme.panel(true)
	facing.size_flags_horizontal = SIZE_EXPAND_FILL
	facing.size_flags_stretch_ratio = 1.35
	spread.add_child(facing)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation",10)
	facing.add_child(right)
	right.add_child(GameTheme.heading("四季留影",32))
	right.add_child(GameTheme.label("点小画去看风景。盖朱印的是你留下的时景。",20,GameTheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	right.add_child(grid)
	var sheet := load("res://assets/landmarks/prints/%s.webp" % place.id) as Texture2D
	grid.add_child(Control.new())
	for phase: String in Catalog.PHASES:
		var nameplate := GameTheme.label(Catalog.NAMES[phase], 20, GameTheme.GOLD)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(nameplate)
	for season: String in Catalog.SEASONS:
		var season_name := GameTheme.label(Catalog.NAMES[season], 21)
		season_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(season_name)
		for phase: String in Catalog.PHASES:
			var kept: bool = season + ":" + phase in page.prints
			var stamp := Print.new()
			stamp.configure(sheet,Catalog.SEASONS.find(season),Catalog.PHASES.find(phase),kept)
			stamp.pressed.connect(func(): app.visit_sky(season,phase))
			stamp.name = "Print_" + season + "_" + phase
			stamp.accessibility_name = Catalog.NAMES[season] + Catalog.NAMES[phase] + ("，已留影" if kept else "，去看看")
			stamp.tooltip_text = stamp.accessibility_name
			grid.add_child(stamp)
	var task := GameTheme.button(("已得采风印 · " if Catalog.fieldwork_done(place,page) else "鹿铃来信 · ") + str(place.fieldwork.title),app.open_fieldwork,Vector2(240,64),true)
	right.add_child(task)
