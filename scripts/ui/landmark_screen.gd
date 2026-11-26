extends "res://scripts/ui/base_screen.gd"

const Catalog = preload("res://scripts/landmarks/catalog.gd")
const Scenery = preload("res://scripts/landmarks/scenery.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
const Loupe = preload("res://scripts/ui/field_loupe.gd")
const CLOCK_STEP := 18.0
var place: Dictionary
var scenery: Control
var season := "spring"
var phase := "day"
var flowing := false
var elapsed := 0.0
var in_background := false
var out_of_focus := false
var caption: Label
var season_key: Button
var phase_key: Button
var flow_key: Button
var print_key: Button
var journal_key: Button
var fieldwork_key: Button
var loupe_key: Button
var loupe: Control

func _ready() -> void:
	setup()
	var page: Dictionary = Journey.landmark_page(place.id)
	season = page.season
	phase = page.phase
	scenery = Scenery.new()
	scenery.configure(place, season, phase, Journey.progress.settings.reducedMotion)
	scenery.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scenery.detail_requested.connect(func(id: String): app.show_landmark_detail(id))
	add_child(scenery)
	loupe = Loupe.new()
	loupe.visible = false
	add_child(loupe)
	Art.scrim(self, 155, Color("10262ce5"), Color("0d242900"))
	Art.scrim(self, 215, Color("10262c00"), Color("102629f4"), true)
	var layout := column()
	layout.add_theme_constant_override("separation", 7)
	var bar := header(layout, place.name, "%s · 点画里的标记，和欧哟几一起找细节" % Library.by_id("stages", place.station).name, app.return_to_atlas)
	var intro := GameTheme.button("景点故事", app.open_landmark_intro, Vector2(137, 64))
	intro.size_flags_horizontal = SIZE_SHRINK_END
	bar.add_child(intro)
	bar.move_child(intro, bar.get_child_count()-2)
	fieldwork_key = GameTheme.button("鹿铃来信", app.open_fieldwork,Vector2(139,64),true)
	fieldwork_key.name = "Fieldwork"
	fieldwork_key.size_flags_horizontal = SIZE_SHRINK_END
	bar.add_child(fieldwork_key)
	bar.move_child(fieldwork_key, bar.get_child_count()-2)
	space(layout)
	caption = GameTheme.label("", 23)
	caption.name = "SeasonalObservation"
	caption.add_theme_constant_override("line_spacing", 2)
	layout.add_child(caption)
	var bar_bottom := HBoxContainer.new()
	bar_bottom.add_theme_constant_override("separation",10)
	bar_bottom.mouse_filter = MOUSE_FILTER_IGNORE
	layout.add_child(bar_bottom)
	season_key = add_action(bar_bottom, "Seasons", "", func(): app.open_sky_picker("season"), 158)
	phase_key = add_action(bar_bottom, "Times", "", func(): app.open_sky_picker("phase"), 158)
	flow_key = add_action(bar_bottom, "Clock", "", toggle_clock, 157)
	space(bar_bottom)
	loupe_key = add_action(bar_bottom, "Loupe", "观景镜", toggle_loupe, 131)
	journal_key = add_action(bar_bottom, "FieldPage", "", app.open_site_journal, 165)
	print_key = add_action(bar_bottom, "KeepPrint", "", keep_print, 192, true)
	refresh()

func add_action(parent: Control, id: String, label: String, callback: Callable, width: int, accent := false) -> Button:
	var key := GameTheme.button(label, callback, Vector2(width, 65), accent)
	key.name = id
	key.add_theme_font_size_override("font_size",22)
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.size_flags_horizontal = SIZE_SHRINK_CENTER
	parent.add_child(key)
	return key

func refresh() -> void:
	if not is_instance_valid(print_key): return
	var page: Dictionary = Journey.landmark_page(place.id)
	season = page.season
	phase = page.phase
	scenery.reduced_motion = Journey.progress.settings.reducedMotion
	scenery.set_sky(season, phase)
	scenery.set_found(page.details)
	season_key.text = Catalog.NAMES[season] + " · 换季"
	phase_key.text = Catalog.NAMES[phase] + " · 换时"
	flow_key.text = "暂停流转" if flowing else "时光流转"
	flow_key.tooltip_text = "每十八秒换一个时辰，黑夜过后进入下一季。"
	journal_key.text = "写生页 %d/3" % page.details.size()
	fieldwork_key.text = "采风印" if Catalog.fieldwork_done(place,page) else "鹿铃来信"
	var kept: bool = season + ":" + phase in page.prints
	print_key.text = "此景已收好" if kept else "收进写生页"
	print_key.disabled = kept
	caption.text = str(place.seasons[season]) + "  " + str(place.times[phase])

func select_sky(next_season: String, next_phase: String) -> void:
	if not Catalog.SEASONS.has(next_season) or not Catalog.PHASES.has(next_phase): return
	elapsed = 0
	Journey.set_landmark_sky(place.id, next_season, next_phase)
	app.audio.set_landscape(place.profile, next_season, next_phase, place.id)

func keep_print() -> void:
	var had_stamp := Catalog.fieldwork_done(place, Journey.landmark_page(place.id))
	if Journey.save_sky_print(place.id):
		app.audio.cue("discover", place.station)
		if not had_stamp and Catalog.fieldwork_done(place,Journey.landmark_page(place.id)):
			app.show_fieldwork_stamp()
		else: app.toast("%s的%s%s，收进写生页啦。" % [place.short, Catalog.NAMES[season], Catalog.NAMES[phase]])

func toggle_clock() -> void:
	flowing = not flowing
	elapsed = 0
	refresh()
	if flowing: app.toast("时光开始流转。过了黑夜，画卷会翻到下一季。")

func toggle_loupe() -> void:
	loupe.visible = not loupe.visible
	loupe.cancel_input()
	scenery.set_hotspots_visible(not loupe.visible)
	loupe_key.text = "收起镜子" if loupe.visible else "观景镜"
	if loupe.visible: app.toast("点住画面，拖动观景镜看细节。")

func cancel_input() -> void:
	if is_instance_valid(loupe): loupe.cancel_input()
	if is_instance_valid(scenery) and scenery.has_method("cancel_input"): scenery.cancel_input()

func _process(delta: float) -> void:
	if not flowing or in_background or out_of_focus or not is_visible_in_tree(): return
	if is_instance_valid(app.modal) or is_instance_valid(app.file_dialog): return
	elapsed += minf(delta, 1.0)
	if elapsed >= CLOCK_STEP:
		var next := Catalog.next_sky(season, phase)
		select_sky(next[0], next[1])

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			in_background = true
			cancel_input()
		NOTIFICATION_APPLICATION_RESUMED: in_background = false
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			out_of_focus = true
			cancel_input()
		NOTIFICATION_APPLICATION_FOCUS_IN: out_of_focus = false
