extends "res://scripts/ui/base_screen.gd"

const Catalog = preload("res://scripts/landmarks/catalog.gd")
const Card = preload("res://scripts/ui/landmark_card.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
var station := "dunhuang"
var cards: HBoxContainer
var tabs := {}
var summary: Label

func _ready() -> void:
	setup()
	background("map", .79)
	var layout := column()
	layout.add_theme_constant_override("separation", 12)
	var total: int = Journey.progress.atlas.places.size()
	header(layout, "四时山河", "欧哟几的写生册 · 已走过 %d / %d 处景点" % [total, Catalog.sites().size()], app.leave_atlas)
	var stops := HBoxContainer.new()
	stops.add_theme_constant_override("separation", 9)
	layout.add_child(stops)
	for city: Dictionary in Library.all("stages"):
		var id: String = city.id
		var button := GameTheme.button(city.name, func(): choose_station(id), Vector2(100,64))
		button.name = "Station_" + id
		button.toggle_mode = true
		button.icon = Art.seal(id)
		button.add_theme_constant_override("icon_max_width", 35)
		button.add_theme_stylebox_override("pressed", GameTheme.surface(Color("9c573e"), Color("733e32"), GameTheme.GOLD))
		stops.add_child(button)
		tabs[id] = button
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation",14)
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(cards)
	summary = GameTheme.label("", 21, GameTheme.GOLD)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(summary)
	choose_station(station)

func choose_station(id: String) -> void:
	station = id
	app.atlas_station = id
	for key: String in tabs: tabs[key].set_pressed_no_signal(key == id)
	for old in cards.get_children():
		cards.remove_child(old)
		old.queue_free()
	var places := Catalog.for_station(id)
	if places.is_empty(): return
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation",10)
	side.size_flags_horizontal = SIZE_EXPAND_FILL
	var known := 0
	for i in places.size():
		var place: Dictionary = places[i]
		var page: Dictionary = Journey.landmark_page(place.id)
		known += page.details.size()
		var card := Card.new()
		card.configure(place, page, i == 0)
		card.pressed.connect(func(): app.show_landmark(place.id))
		if i == 0:
			card.size_flags_stretch_ratio = 1.19
			cards.add_child(card)
			cards.add_child(side)
		else: side.add_child(card)
	summary.text = "点一幅画出发   ·   %s已发现 %d / %d 处细节" % [Library.by_id("stages", id).name, known, places.size()*3]
