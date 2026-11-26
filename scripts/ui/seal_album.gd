extends "res://scripts/ui/base_screen.gd"

const Trails = preload("res://scripts/trails/trail_catalog.gd")
const Medallion = preload("res://scripts/ui/seal_medallion.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
var selected_id := "wuwei"
var tokens := {}
var large_art: TextureRect
var detail_title: Label
var description: Label
var listen: Button
var solve: Button
var song: Button

func _ready() -> void:
	setup()
	background("camp-night", .72)
	var layout := column()
	header(layout, "河西纹印谱", "已拓 %d / 6 枚" % Journey.progress.journey.trailSeals.size(), app.leave_album)
	var spread := HBoxContainer.new()
	spread.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(spread)
	var page := GameTheme.panel(false)
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	page.size_flags_stretch_ratio = 1.45
	spread.add_child(page)
	var grid := GridContainer.new()
	grid.columns = 3
	page.add_child(grid)
	for station: Dictionary in Library.all("stages"):
		var token := Medallion.new()
		token.configure(station.id, str(Trails.get_trail(station.id).seal), station.id in Journey.progress.journey.trailSeals, true)
		token.size_flags_horizontal = SIZE_EXPAND_FILL
		token.size_flags_vertical = SIZE_EXPAND_FILL
		token.pressed.connect(func(): select_seal(station.id))
		grid.add_child(token)
		tokens[station.id] = token
	var leaf := GameTheme.panel(true)
	leaf.size_flags_horizontal = SIZE_EXPAND_FILL
	spread.add_child(leaf)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 9)
	leaf.add_child(info)
	large_art = Art.picture(null, Vector2(128, 126))
	large_art.size_flags_vertical = SIZE_EXPAND_FILL
	info.add_child(large_art)
	detail_title = GameTheme.heading("", 33, GameTheme.LIGHT)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(detail_title)
	description = GameTheme.label("", 22)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(description)
	var actions := HBoxContainer.new()
	info.add_child(actions)
	listen = GameTheme.button("听纹音", play_selected, Vector2(122, 66))
	actions.add_child(listen)
	solve = GameTheme.button("去寻纹", func(): app.show_trail(selected_id, "album"), Vector2(132, 66), true)
	actions.add_child(solve)
	song = GameTheme.button("听六纹合奏", play_ensemble, Vector2(280, 66), true)
	song.name = "PlaySealSong"
	song.size_flags_horizontal = SIZE_SHRINK_CENTER
	layout.add_child(song)
	app.audio.seal_song_finished.connect(_restore_song)
	select_seal(selected_id)

func select_seal(id: String) -> void:
	selected_id = id
	var trail: Dictionary = Trails.get_trail(id)
	var owned: bool = id in Journey.progress.journey.trailSeals
	for key: String in tokens: tokens[key].selected = key == id
	large_art.texture = Art.seal(id)
	detail_title.text = "%s · %s" % [trail.place, trail.seal]
	description.text = trail.brief
	listen.disabled = not owned
	solve.text = "再拓一次" if owned else "去寻纹"
	_restore_song()

func play_selected() -> void:
	app.listen_to_seal(selected_id)

func _restore_song() -> void:
	song.disabled = Journey.progress.journey.trailSeals.size() != 6
	song.text = "集齐六纹可合奏" if song.disabled else "听六纹合奏"
	if app.audio.is_seal_song_playing():
		song.text = "六纹合奏中"
		song.disabled = true

func play_ensemble() -> void:
	if Journey.progress.journey.trailSeals.size() != 6: return
	if app.audio.play_seal_song():
		song.text = "六纹合奏中"
		song.disabled = true
	else: app.toast("打开行囊里的声音和音乐，就能听合奏。")
