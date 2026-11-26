extends Node

const JourneyScreen = preload("res://scripts/ui/journey_screen.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const RouteScreen = preload("res://scripts/ui/route_screen.gd")
const CollectionScreen = preload("res://scripts/ui/collection_screen.gd")
const CampScreen = preload("res://scripts/ui/camp_screen.gd")
const CompanionScreen = preload("res://scripts/ui/companion_screen.gd")
const DialogPanel = preload("res://scripts/ui/dialogue_panel.gd")
const AudioDirector = preload("res://scripts/audio/audio_director.gd")
const WorldScene = preload("res://scenes/world/world.tscn")
const GameView = preload("res://scripts/games/minigame_view.gd")
const TrailView = preload("res://scripts/trails/trail_view.gd")
const Trails = preload("res://scripts/trails/trail_catalog.gd")
const Album = preload("res://scripts/ui/seal_album.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
const Places = preload("res://scripts/landmarks/catalog.gd")
const AtlasScreen = preload("res://scripts/ui/atlas_screen.gd")
const LandmarkScreen = preload("res://scripts/ui/landmark_screen.gd")
const SiteJournal = preload("res://scripts/ui/site_journal.gd")
const DetailView = preload("res://scripts/landmarks/detail_view.gd")

var view := "home"
var stage_id := "wuwei"
var screen: Control
var world: Node2D
var modal: Control
var focus_before_dialog: WeakRef
var audio: Node
var layer: CanvasLayer
var overlays: CanvasLayer
var generation := 0
var file_dialog: FileDialog
var toast_panel: PanelContainer
var toast_tween: Tween
var capture_busy := false
var resting := false
var save_warning: Button
var trail_origin := "world"
var album_origin := "map"
var album_world := "wuwei"
var atlas_origin := "home"
var atlas_world := "wuwei"
var atlas_station := "dunhuang"
var landmark_id := ""
var detail_origin := "landmark"
var paused_field_clock := {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	audio = AudioDirector.new()
	add_child(audio)
	audio.configure(Journey.progress.settings)
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	overlays = CanvasLayer.new()
	overlays.name = "Overlays"
	overlays.layer = 30
	add_child(overlays)
	Journey.changed.connect(_progress_changed)
	Journey.save_failed.connect(func(message: String):
		_update_storage_notice()
		toast(message)
	)
	var notices := CanvasLayer.new()
	notices.layer = 40
	add_child(notices)
	save_warning = GameTheme.button("旅行还没有保存 · 请让大人帮忙", storage_notice, Vector2(720, 64))
	save_warning.theme = GameTheme.make()
	save_warning.add_theme_stylebox_override("normal", GameTheme.style(GameTheme.RUST))
	notices.add_child(save_warning)
	save_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	save_warning.offset_left = -360
	save_warning.offset_right = 360
	save_warning.offset_top = 22
	_update_storage_notice()
	show_home()
	if not Journey.last_error.is_empty(): call_deferred("storage_notice")

func storage_notice() -> void:
	show_dialog("行囊需要照顾", Journey.last_error + "\n可以先导出本次旅行，原存档会被保留。", [{"label": "看看保存与搬家", "action": "saves"}, {"label": "继续看看", "action": "close"}], func(action: String):
		if action == "saves": show_save_menu()
		else: close_dialog()
	)

func _progress_changed() -> void:
	audio.configure(Journey.progress.settings)
	_update_storage_notice()
	if screen and screen.has_method("refresh"): screen.refresh()
	if is_instance_valid(world): world.reduced_motion = Journey.progress.settings.reducedMotion

func _update_storage_notice() -> void:
	if is_instance_valid(save_warning): save_warning.visible = not Journey.last_error.is_empty()

func _clear(next_view: String) -> void:
	generation += 1
	if next_view not in ["landmark","landmark_detail","site_journal"]:
		paused_field_clock.clear()
	elif view == "landmark" and is_instance_valid(screen):
		paused_field_clock = {"site":landmark_id,"season":screen.season,"phase":screen.phase,"elapsed":screen.elapsed} if screen.flowing else {}
	close_dialog()
	_cancel_file_dialog()
	audio.stop_voice()
	audio.stop_composition()
	if is_instance_valid(world):
		world.cancel_input()
		world.hide()
		world.set_covered(true)
		world.get_node("Camera").enabled = false
		world.queue_free()
		world = null
	if is_instance_valid(screen):
		screen.hide()
		screen.queue_free()
		screen = null
	view = next_view
	audio.set_context(view)

func _mount(node: Control) -> void:
	screen = node
	layer.add_child(screen)
	if not Journey.progress.settings.reducedMotion:
		screen.modulate.a = 0
		screen.create_tween().tween_property(screen, "modulate:a", 1.0, .25)

func show_home() -> void:
	_clear("home")
	var next := TitleScreen.new()
	next.app = self
	_mount(next)
	audio.play_music("map")

func show_map() -> void:
	_clear("map")
	var next := RouteScreen.new()
	next.app = self
	_mount(next)
	audio.play_music("map")

func show_atlas(origin := "home", station := "") -> void:
	if origin != "again":
		atlas_origin = origin
		atlas_world = stage_id
		var last := Places.lookup(str(Journey.progress.atlas.lastSite))
		atlas_station = station if not Library.by_id("stages",station).is_empty() else str(last.get("station","dunhuang"))
	elif not station.is_empty(): atlas_station = station
	_clear("atlas")
	var next := AtlasScreen.new()
	next.app = self
	next.station = atlas_station
	_mount(next)
	audio.play_music("map")

func leave_atlas() -> void:
	match atlas_origin:
		"world": show_world(atlas_world)
		"map": show_map()
		_: show_home()

func return_to_atlas() -> void:
	show_atlas("again", atlas_station)

func show_landmark(id: String) -> void:
	var place := Places.lookup(id)
	if place.is_empty(): return
	_clear("landmark")
	landmark_id = id
	stage_id = place.station
	atlas_station = place.station
	Journey.visit_landmark(id)
	var next := LandmarkScreen.new()
	next.app = self
	next.place = place
	if paused_field_clock.get("site") == id:
		next.flowing = true
		var page: Dictionary = Journey.landmark_page(id)
		if page.season == paused_field_clock.season and page.phase == paused_field_clock.phase:
			next.elapsed = paused_field_clock.elapsed
	_mount(next)
	audio.play_music(place.station)
	audio.set_landscape(place.profile, next.season, next.phase, place.id)

func return_to_landmark() -> void:
	show_landmark(landmark_id)

func open_landmark_intro() -> void:
	var place := Places.lookup(landmark_id)
	show_dialog(place.name, place.intro, [
		{"label":"开始找细节","action":"close","accent":true},
		{"label":"资料出处","action":"source"}], func(action: String):
		if action == "source":
			show_dialog("景点资料", str(place.get("sourceName",place.name)) + "\n" + str(place.source), [
				{"label":"复制资料链接","action":"copy"},{"label":"回到风景","action":"close","accent":true}], func(choice: String):
				if choice == "copy":
					DisplayServer.clipboard_set(str(place.source))
					toast("景点资料链接已复制。")
				else: close_dialog()
			, "scroll")
		else: close_dialog()
	, "scroll", null, "look")

func show_fieldwork_stamp() -> void:
	var place := Places.lookup(landmark_id)
	show_dialog("拓得采风印", "鹿铃收到了你在%s留下的两幅时景和一项发现。\n写生题《%s》完成啦！" % [place.short,place.fieldwork.title],
		[{"label":"翻开写生页","action":"journal","accent":true},{"label":"重读鹿铃来信","action":"read_letter"},{"label":"收好采风印","action":"close"}],func(action: String):
			match action:
				"journal": open_site_journal()
				"read_letter": open_fieldwork(true)
				_: close_dialog()
	, "leaf", null, "celebrate")
	audio.cue("win",place.station)

func open_fieldwork(read_letter := false) -> void:
	var place := Places.lookup(landmark_id)
	var page: Dictionary = Journey.landmark_page(landmark_id)
	var completed := Places.fieldwork_done(place,page)
	if completed and not read_letter:
		show_fieldwork_stamp()
		return
	var task: Dictionary = place.fieldwork
	var options := []
	for sky: String in task.views:
		options.append({"label":("已收 · " if sky in page.prints else "去看 · ") + Places.sky_name(sky),"action":sky.replace(":","_")})
	var target := Places.detail(place, task.detail)
	options.append({"label":("已发现 · " if target.id in page.details else "去找 · ") + str(target.title),"action":"look","accent":true})
	var footer := "两幅时景和这件发现都收好啦。可以再去看一看。" if completed else "把两幅时景收进写生页，再完成这件观察，就能盖上采风印。"
	show_dialog("鹿铃来信 · " + str(task.title), str(task.note) + "\n" + footer, options, func(action: String):
		if action == "look": show_landmark_detail(target.id, "journal" if view == "site_journal" else "landmark")
		else:
			var sky := action.split("_")
			close_dialog()
			if view == "landmark": screen.select_sky(sky[0], sky[1])
			else: visit_sky(sky[0],sky[1])
			if ":".join(sky) not in page.prints: toast("点“收进写生页”，留下这幅时景。")
	, "leaf")

func open_sky_picker(group := "season") -> void:
	if view != "landmark": return
	var is_season := group == "season"
	var values: Array = Places.SEASONS if is_season else Places.PHASES
	var current: String = screen.season if is_season else screen.phase
	var options := []
	for id: String in values:
		options.append({"label":Places.NAMES[id], "action":id, "accent":current == id})
	show_dialog("去哪个季节" if is_season else "去哪个时辰", "选一个，看看同一个地方有什么变化。", options, func(id: String):
		close_dialog()
		if view == "landmark":
			screen.select_sky(id if is_season else screen.season, screen.phase if is_season else id)
	, "leaf" if is_season else "sun")

func show_landmark_detail(which: String, origin := "landmark") -> void:
	var place := Places.lookup(landmark_id)
	var item := Places.detail(place, which)
	if item.is_empty(): return
	_clear("landmark_detail")
	detail_origin = origin
	var next := DetailView.new()
	next.configure(place, item, Journey.progress.settings.reducedMotion)
	var token := generation
	next.solved.connect(func(id: String):
		if generation == token and id == which: receive_field_note(place,item)
	)
	next.back_requested.connect(leave_landmark_detail)
	next.sound_requested.connect(func(cue: String): audio.cue(cue, place.station))
	next.note_requested.connect(func(index: int): audio.note(index, "bell"))
	_mount(next)
	audio.play_music(place.station)

func leave_landmark_detail() -> void:
	if detail_origin == "journal": open_site_journal()
	else: return_to_landmark()

func receive_field_note(place: Dictionary, item: Dictionary) -> void:
	var had_stamp := Places.fieldwork_done(place, Journey.landmark_page(place.id))
	var first: bool = Journey.complete_landmark_detail(place.id, item.id)
	var page: Dictionary = Journey.landmark_page(place.id)
	var title := "发现了" + str(item.title) if first else "又见" + str(item.title)
	var text := str(item.result)
	if first and page.details.size() == 3: text += "\n这一处的三个发现都收进写生页了！"
	if not had_stamp and Places.fieldwork_done(place,page): text += "\n鹿铃的写生题也完成了，采风印已经盖好。"
	show_dialog(title, text, [{"label":"回风景里","action":"site","accent":true},{"label":"翻开写生页","action":"journal"}], func(action: String):
		if action == "journal": open_site_journal()
		else: return_to_landmark()
	, "leaf", null, "surprise" if first else "look")
	audio.cue("win",place.station)

func open_site_journal() -> void:
	var place := Places.lookup(landmark_id)
	if place.is_empty(): return
	_clear("site_journal")
	var next := SiteJournal.new()
	next.app = self
	next.place = place
	_mount(next)
	audio.play_music(place.station)

func visit_sky(season: String, phase: String) -> void:
	Journey.set_landmark_sky(landmark_id,season,phase)
	return_to_landmark()

func journal_detail(which: String) -> void:
	var place := Places.lookup(landmark_id)
	var item := Places.detail(place, which)
	if item.is_empty(): return
	if which not in Journey.landmark_page(landmark_id).details:
		show_landmark_detail(which, "journal")
		return
	show_dialog(item.title, item.result, [{"label":"再玩一次","action":"play","accent":true},{"label":"收好发现","action":"close"}], func(action: String):
		if action == "play": show_landmark_detail(which, "journal")
		else: close_dialog()
	, "scroll")

func depart() -> void:
	Journey.start_journey()
	show_world(next_story_stop())

func next_story_stop() -> String:
	for chapter: Dictionary in Library.all("chapters"):
		if chapter.id not in Journey.progress.journey.claimed:
			return str(chapter.id)
	return "wuwei"

func show_world(id: String) -> void:
	if Library.by_id("stages", id).is_empty(): return
	_clear("world")
	stage_id = id
	var points := []
	for point: Dictionary in Library.all("encounters"):
		if point.stageId == id: points.append(point)
	world = WorldScene.instantiate()
	world.configure(id, points, Journey.progress.journey.encounters.duplicate(), Journey.progress.settings.reducedMotion, id in Journey.progress.journey.trailSeals)
	world.encounter_requested.connect(observe)
	world.trail_requested.connect(func(): show_trail(id))
	world.walking_changed.connect(audio.set_walking)
	world.companion_sound.connect(audio.companion_action)
	world.step_sound.connect(audio.companion_step)
	add_child(world)
	var next := JourneyScreen.new()
	next.app = self
	next.mode = "world"
	_mount(next)
	audio.play_music(id)

func show_game(id: String) -> void:
	var activity: Dictionary = Library.by_id("activities", id)
	if activity.is_empty(): return
	_clear("game")
	stage_id = str(activity.stageId)
	var next := GameView.new()
	next.configure(id, Library.data, Journey.progress)
	next.finished.connect(_game_finished)
	next.back_requested.connect(func(): show_world(stage_id))
	next.narration_requested.connect(audio.speak)
	next.note_requested.connect(audio.note)
	next.paint_changed.connect(Journey.set_paint)
	_mount(next)
	audio.play_music(stage_id)
	if Journey.progress.settings.narration: audio.speak("game-" + id)

func _game_finished(id: String) -> void:
	Journey.complete_game(id)
	audio.cue("win", stage_id)
	toast("做到了！这枚印章，已经收进行囊。" if Journey.last_error.is_empty() else "做到了！印章暂时留在本次游戏里，请先保存行囊。")

func show_trail(id: String, origin := "world") -> void:
	if Trails.get_trail(id).is_empty(): return
	_clear("trail")
	stage_id = id
	trail_origin = origin
	var next := TrailView.new()
	next.configure(id, Journey.progress.settings.reducedMotion)
	var token := generation
	next.solved.connect(func(solved_id: String):
		if generation == token and solved_id == id: _receive_seal(id)
	)
	next.back_requested.connect(leave_trail)
	next.sound_requested.connect(func(kind: String): audio.cue(kind, id))
	_mount(next)
	audio.play_music(id)

func _receive_seal(id: String) -> void:
	var first: bool = Journey.collect_seal(id)
	var trail: Dictionary = Trails.get_trail(id)
	var scene: Dictionary = Library.by_id("encounters", trail.encounter)
	var title := "拓得" + str(trail.seal) if first else "再听" + str(trail.seal)
	var message := "%s\n\n%s" % [scene.text, "六枚纹印齐了，去听一首完整的合奏吧。" if Journey.progress.journey.trailSeals.size() == 6 else "纹印里藏着这一站的声音。"]
	show_dialog(title, message, [{"label":"听纹音","action":"listen"},{"label":"打开纹印谱","action":"album","accent":true},{"label":"回到旅途","action":"world"}], func(action: String):
		match action:
			"listen": listen_to_seal(id)
			"album": show_album("again" if trail_origin == "album" else "world", id)
			_: show_world(id)
	, "bell", Art.seal(id))
	audio.cue("seal", id)

func listen_to_seal(id: String) -> void:
	if Journey.progress.settings.sound: audio.cue("seal", id)
	else: toast("打开行囊里的声音，就能听见纹音。")

func leave_trail() -> void:
	if trail_origin == "album": show_album("again", stage_id)
	else: show_world(stage_id)

func show_album(origin := "map", selection := "") -> void:
	if origin != "again":
		album_origin = origin
		album_world = stage_id
	_clear("album")
	var next := Album.new()
	next.app = self
	next.selected_id = selection if not Trails.get_trail(selection).is_empty() else stage_id
	_mount(next)
	audio.play_music("map")

func leave_album() -> void:
	match album_origin:
		"home": show_home()
		"world": show_world(album_world)
		_: show_map()

func show_book(category := "games", page := 0) -> void:
	_clear("book")
	var next := CollectionScreen.new()
	next.app = self
	next.category = category
	next.page = page
	_mount(next)
	audio.play_music("map")

func show_camp(page := 0) -> void:
	_clear("camp")
	var next := CampScreen.new()
	next.app = self
	next.mode = "camp"
	next.page = page
	_mount(next)
	audio.play_music("guazhou")

func show_companions() -> void:
	_clear("companions")
	var next := CompanionScreen.new()
	next.app = self
	_mount(next)
	audio.play_music("guazhou")

func show_composer() -> void:
	_clear("composer")
	var next := CampScreen.new()
	next.app = self
	next.mode = "composer"
	_mount(next)
	audio.play_music("guazhou")

func show_ending() -> void:
	if not Journey.has_ending():
		toast("六枚风铃都找回来，就能听见这段合奏。")
		return
	_clear("ending")
	var next := JourneyScreen.new()
	next.app = self
	next.mode = "ending"
	_mount(next)
	audio.play_music("ending")

func show_dialog(title: String, text: String, options: Array, action: Callable, icon := "scroll", illustration: Texture2D = null, performance := "", animal := false) -> void:
	close_dialog()
	var previous := get_viewport().gui_get_focus_owner()
	focus_before_dialog = weakref(previous) if previous else null
	_set_covered_focus(true)
	if is_instance_valid(screen) and screen.has_method("cancel_input"): screen.cancel_input()
	audio.set_context("dialog")
	audio.stop_composition()
	if is_instance_valid(world): world.set_covered(true)
	if is_instance_valid(screen) and screen.has_method("set_covered"): screen.set_covered(true)
	var dialog := DialogPanel.new()
	if not illustration and view == "world":
		var chapter: Dictionary = Library.by_id("chapters", stage_id)
		if title == chapter.npc.name: illustration = Art.face(stage_id)
	dialog.configure(title, text, options, icon, illustration, performance, animal)
	dialog.chosen.connect(action)
	dialog.dismissed.connect(close_dialog)
	modal = dialog
	overlays.add_child(dialog)

func _set_covered_focus(covered: bool) -> void:
	var behavior := Control.FOCUS_BEHAVIOR_DISABLED if covered else Control.FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(screen): screen.focus_behavior_recursive = behavior
	if is_instance_valid(save_warning): save_warning.focus_behavior_recursive = behavior
	if is_instance_valid(world):
		for marker: Control in world.find_children("Observe_*", "Button", true, false):
			marker.focus_behavior_recursive = behavior

func close_dialog() -> void:
	var was_open := is_instance_valid(modal)
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	if was_open:
		_set_covered_focus(false)
		var previous: Control = focus_before_dialog.get_ref() if focus_before_dialog else null
		focus_before_dialog = null
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus(true)
	if was_open:
		if is_instance_valid(world): world.set_covered(false)
		if is_instance_valid(screen) and screen.has_method("set_covered"): screen.set_covered(false)
	if audio: audio.stop_voice()
	if was_open: audio.set_context(view)

func welcome() -> void:
	show_dialog("你好，我是欧哟几", "我今年六岁，喜欢听风铃，也喜欢交朋友。\n鹿铃和我想去河西走廊看看。我们会走过绿洲、关城和沙丘，找回六枚温暖的风铃。\n不用跑得很快，我们一起慢慢来。", [{"label": "听我说说", "action": "listen"}, {"label": "一起出发吧", "action": "depart", "accent": true}], func(action: String):
		if action == "listen":
			modal.replay_actor()
			audio.speak("welcome")
		else: depart()
	, "bell", null, "greet")

func open_story(page := 0) -> void:
	var chapter: Dictionary = Library.by_id("chapters", stage_id)
	if chapter.is_empty(): return
	if page < chapter.dialogue.size():
		var voice_id := "story-%s-%d" % [stage_id, page]
		show_dialog(str(chapter.npc.name), str(chapter.dialogue[page]), [{"label": "听朋友说", "action": "listen"}, {"label": "接着听" if page < chapter.dialogue.size() - 1 else "欧哟几想说", "action": "next", "accent": true}], func(action: String):
			if action == "listen": audio.speak(voice_id)
			else: open_story(page + 1)
		, str(chapter.npc.icon))
		if Journey.progress.settings.narration: audio.speak(voice_id)
	else:
		var options := []
		for choice: Dictionary in chapter.choices: options.append({"label": choice.label, "action": choice.id, "accent": true})
		show_dialog("欧哟几的小心意", str(chapter.question), options, func(action: String):
			for choice: Dictionary in chapter.choices:
				if choice.id == action:
					Journey.answer(stage_id, action)
					show_dialog(str(chapter.npc.name), str(choice.response), [{"label": "去帮帮朋友", "action": "play", "accent": true}, {"label": "再看看风景", "action": "close"}], func(next_action: String):
						if next_action == "play": show_game(str(chapter.requiredGame))
						else: close_dialog()
					, str(chapter.npc.icon))
					if Journey.progress.settings.narration: audio.speak("choice-%s-%s" % [stage_id, action])
		, "leaf", null, "think")
		if Journey.progress.settings.narration: audio.speak("question-" + stage_id)

func observe(id: String) -> void:
	var point: Dictionary = Library.by_id("encounters", id)
	if point.is_empty(): return
	Journey.visit(id)
	if is_instance_valid(world): world.mark_observed(id)
	show_dialog(str(point.name), "%s\n\n%s" % [point.text, point.response], [{"label": "听一听", "action": "listen"}, {"label": "收好这个发现", "action": "close", "accent": true}], func(action: String):
		if action == "listen": audio.speak("encounter-" + id)
		else: close_dialog()
	, str(point.icon), null, "look")
	audio.cue("discover", stage_id)
	if Journey.progress.settings.narration: audio.speak("encounter-" + id)

func guide() -> void:
	var story: Dictionary = Journey.progress.journey
	var chapter: Dictionary = Library.by_id("chapters", stage_id)
	if stage_id not in story.conversations:
		show_dialog("鹿铃轻轻说", "我们先和%s聊一聊吧。听完故事，你可以选一个自己的回答。" % chapter.npc.name, [{"label": "去听朋友的故事", "action": "story", "accent": true}], func(_action: String): open_story(), "leaf", null, "listen", true)
		return
	var count: int = Journey.explored_count(stage_id)
	if count < 2:
		show_dialog("鹿铃轻轻说", "去两个景点，各发现一个小细节，就找到了两处风景。也可以在这张画卷里找标记或寻纹。", [{"label":"逛景点","action":"atlas","accent":true},{"label":"去寻纹","action":"trail"},{"label":"自己找风景","action":"close"}], func(action: String):
			if action == "atlas": show_atlas("world", stage_id)
			elif action == "trail": show_trail(stage_id)
			else: close_dialog()
		, "star", null, "look", true)
	elif chapter.requiredGame not in Journey.progress.completed:
		show_dialog("鹿铃轻轻说", "朋友还在等我们帮一个小忙呢。不着急，游戏里也有小提示。", [{"label": "我们一起帮朋友", "action": "play", "accent": true}], func(_action: String): show_game(str(chapter.requiredGame)), str(chapter.npc.icon), null, "think", true)
	else:
		claim_bell()

func claim_bell() -> void:
	var chapter: Dictionary = Library.by_id("chapters", stage_id)
	if Journey.claim(stage_id):
		show_dialog("找回了" + str(chapter.bell), str(chapter.closing), [{"label": "让风铃一起唱" if Journey.has_ending() else "看看下一站", "action": "next", "accent": true}, {"label": "再陪朋友一会儿", "action": "close"}], func(action: String):
			if action == "next":
				if Journey.has_ending(): show_ending()
				else: show_map()
			else: close_dialog()
		, "bell", null, "celebrate")
		audio.cue("win", stage_id)
		if Journey.progress.settings.narration: audio.speak("closing-" + stage_id)
	elif stage_id in Journey.progress.journey.claimed:
		show_dialog("风铃已经收好啦", str(chapter.journal), [{"label": "去看看其他朋友", "action": "map", "accent": true}, {"label": "留在这里玩", "action": "close"}], func(action: String):
			if action == "map": show_map()
			else: close_dialog()
		, "bell")
	else:
		show_dialog("风铃还在等你", "听完这一站的故事，找到两处风景，再完成朋友的小游戏。风铃会从武威开始，一枚一枚亮起来。", [{"label": "看看旅行地图", "action": "map"}, {"label": "继续找一找", "action": "close", "accent": true}], func(action: String):
			if action == "map": show_map()
			else: close_dialog()
		, "bell")

func open_letters() -> void:
	for letter: Dictionary in Library.all("letters"):
		if letter.to == stage_id and letter.id in Journey.progress.camp.accepted and letter.id not in Journey.progress.camp.delivered:
			show_dialog(str(letter.recipient) + "的回信", str(letter.reply), [{"label": "收下营地的小礼物", "action": "deliver", "accent": true}], func(_action: String):
				Journey.deliver_letter(str(letter.id), stage_id)
				close_dialog()
				toast("新礼物已送到小营地。")
			, "letter")
			if Journey.progress.settings.narration: audio.speak("reply-" + str(letter.id))
			return
		if letter.from == stage_id and letter.id not in Journey.progress.camp.accepted and stage_id in Journey.progress.journey.conversations:
			var options := []
			for choice: Dictionary in letter.choices: options.append({"label": choice.name, "action": choice.id})
			show_dialog(str(letter.title), str(letter.request), options, func(action: String):
				if Journey.accept_letter(str(letter.id), action):
					show_dialog("问候装好了", str(letter.packed), [{"label": "去看看旅行地图", "action": "map", "accent": true}], func(_next: String): show_map(), "letter")
				else:
					toast("再想一想，朋友现在最需要什么？")
			, "letter")
			if Journey.progress.settings.narration: audio.speak("letter-" + str(letter.id))
			return
	show_dialog("路上的问候", "先和朋友聊完故事，再看看有没有想托你带走的小礼物。\n种子送到张掖，铃铛送到瓜州，矿彩送到敦煌。收到回信，就会得到营地的新摆件。", [{"label": "知道啦", "action": "close", "accent": true}], func(_action: String): close_dialog(), "letter")

func show_settings() -> void:
	var storage := "旅行会自动保存在这台设备上。" if Journey.last_error.is_empty() else "还有旅行没有保存，请先到“保存与搬家”里重试或导出。"
	show_dialog("欧哟几的小行囊", "已经收好 %d 枚风铃、%d 枚游戏印章。\n%s" % [Journey.progress.journey.claimed.size(), Journey.progress.completed.size(), storage], [{"label": "声音和画面", "action": "sound"}, {"label": "保存与搬家", "action": "saves"}, {"label": "给大人看的说明", "action": "parents"}], func(action: String):
		match action:
			"sound": show_preferences()
			"saves": show_save_menu()
			"parents": show_parent_notes()
	, "bag")

func show_preferences() -> void:
	var prefs: Dictionary = Journey.progress.settings
	var options := []
	for pair: Array in [["sound", "所有声音"], ["music", "场景音乐"], ["narration", "自动讲故事"], ["reducedMotion", "减少动态"]]:
		options.append({"label": "%s：%s" % [pair[1], "开" if prefs[pair[0]] else "关"], "action": pair[0]})
	options.append({"label": "音乐音量  %d%%" % roundi(float(prefs.musicVolume)*100), "action":"volume"})
	show_dialog("声音和画面", "可以随时调整音乐和朗读。", options, func(action: String):
		if action == "volume":
			show_volume()
			return
		Journey.set_setting(action, not bool(Journey.progress.settings[action]))
		show_preferences()
	, "sound")

func show_volume() -> void:
	var levels := []
	for level: Array in [["静音",0], ["轻轻听",20], ["适中",40], ["响一些",70], ["最大",100]]:
		var value: int = level[1]
		levels.append({"label": "%s  %d%%" % [level[0], value], "action":str(value), "accent":is_equal_approx(float(Journey.progress.settings.musicVolume), value/100.0)})
	show_dialog("音乐音量", "选一个听起来舒服的音量。", levels, func(action: String):
		Journey.set_setting("musicVolume", float(action)/100.0)
		show_preferences()
	, "sound")

func show_parent_notes() -> void:
	show_dialog("陪孩子一起看看", "适合约六岁儿童，在成人陪伴下每次探索一两站。\n\n欧哟几、鹿铃和六枚风铃是原创想象。画卷融合了不同时代的风景，不是文物原貌复原；真实知识与来源收在“发现图鉴”里。\n\n没有广告、账号、内购或数据上传。原创插画和音乐本地保存，离线也能游玩。", [{"label": "看看山河与时光", "action": "book", "accent": true}, {"label": "引擎与字体许可", "action": "license"}], func(action: String):
		if action == "book": show_book("facts")
		else: show_licenses()
	, "book")

func show_licenses() -> void:
	show_dialog("制作与许可", "Godot Engine 使用 MIT 许可。正文字体 Noto Sans SC 与标题所用的 Noto Serif SC 子集采用 SIL Open Font License 1.1。", [{"label": "引擎许可原文", "action": "engine"}, {"label": "正文字体许可", "action": "font"}, {"label":"标题字体许可","action":"title_font"}, {"label": "引擎第三方声明", "action": "third"}], func(action: String):
		var path := "res://assets/licenses/Godot.txt"
		if action == "font": path = "res://assets/fonts/OFL.txt"
		elif action == "title_font": path = "res://assets/fonts/TITLE-OFL.txt"
		elif action == "third": path = "res://assets/licenses/Godot-third-party.txt"
		show_dialog("许可原文", FileAccess.get_file_as_string(path), [{"label": "返回制作说明", "action": "back"}], func(_next: String): show_licenses(), "book")
	, "book")

func show_source(item: Dictionary) -> void:
	show_dialog(str(item.title), "%s\n\n资料来源：%s\n%s" % [item.get("parent", ""), item.get("sourceName", "资料原文"), item.get("source", "")], [{"label": "复制资料来源链接", "action": "copy"}, {"label": "收好手记", "action": "close", "accent": true}], func(action: String):
		if action == "copy":
			DisplayServer.clipboard_set(str(item.get("source", "")))
			toast("链接已经复制。")
		else: close_dialog()
	, "book")

func show_save_menu() -> void:
	var options := [{"label": "导出行囊文件", "action": "export"}, {"label": "导入行囊文件", "action": "import"}, {"label": "复制行囊文字", "action": "copy"}, {"label": "从剪贴板导入", "action": "paste"}]
	if not Journey.last_error.is_empty(): options.push_front({"label": "再试一次保存", "action": "retry", "accent": true})
	show_dialog("带着行囊去旅行", "可以导出行囊文件，在另一台设备导入。\n也能读取原来电脑版或微信版的 JSON 行囊。导入会合并收藏，同一份画作与营地布置以导入内容为准。", options, func(action: String):
		match action:
			"retry":
				var saved: bool = Journey.save()
				_update_storage_notice()
				if saved:
					show_save_menu()
					toast("这次旅行已经保存好了。")
			"export": export_save()
			"import": import_save()
			"copy":
				DisplayServer.clipboard_set(Journey.export_json())
				toast("行囊文字已复制，请妥善保管。")
			"paste": apply_import(DisplayServer.clipboard_get())
	, "bag")

func export_save() -> void:
	var contents := Journey.export_json()
	choose_file(FileDialog.FILE_MODE_SAVE_FILE, "欧哟几-我的行囊.json", "*.json", "行囊文件", "application/json", func(path: String):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(contents)
			file.flush()
			var success := file.get_error() == OK
			file.close()
			toast("行囊已经导出。" if success else "未能写好这份文件，请重试。")
		else: toast("没能保存到这个位置，请换一个位置。")
	)

func import_save() -> void:
	choose_file(FileDialog.FILE_MODE_OPEN_FILE, "", "*.json", "行囊文件", "application/json", func(path: String):
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			toast("没有读到这份行囊，原来的进度还在。")
			return
		if file.get_length() > 100000:
			file.close()
			toast("这份文件太大，请选择之前导出的行囊。")
			return
		var contents := file.get_as_text()
		file.close()
		apply_import(contents)
	)

func apply_import(contents: String) -> void:
	var result: Dictionary = Journey.import_json(contents)
	if result.ok:
		show_home()
		toast("行囊合在一起了，继续我们的旅行吧。")
	else: toast(str(result.error))

func choose_file(mode: FileDialog.FileMode, filename: String, pattern: String, description: String, mime: String, selected: Callable) -> void:
	close_dialog()
	_cancel_file_dialog()
	var token := generation
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.mode_overrides_title = false
	dialog.title = "选择保存位置" if mode == FileDialog.FILE_MODE_SAVE_FILE else "选择行囊文件"
	dialog.current_file = filename
	dialog.add_filter(pattern, description, mime)
	dialog.get_ok_button().text = "保存" if mode == FileDialog.FILE_MODE_SAVE_FILE else "打开"
	dialog.get_cancel_button().text = "取消"
	dialog.file_selected.connect(func(path: String):
		if token == generation and file_dialog == dialog:
			file_dialog = null
			selected.call(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		if file_dialog == dialog: file_dialog = null
		dialog.queue_free()
	)
	file_dialog = dialog
	add_child(dialog)
	dialog.popup_centered_ratio(.8)

func _cancel_file_dialog() -> void:
	if is_instance_valid(file_dialog):
		file_dialog.hide()
		file_dialog.queue_free()
	file_dialog = null

func export_camp() -> void:
	if view != "camp" or capture_busy: return
	capture_busy = true
	var token := generation
	var camp := screen
	camp.export_mode(true)
	await RenderingServer.frame_post_draw
	if token != generation or not is_instance_valid(camp):
		capture_busy = false
		return
	var image := get_viewport().get_texture().get_image()
	camp.export_mode(false)
	capture_busy = false
	var bytes := image.save_png_to_buffer()
	choose_file(FileDialog.FILE_MODE_SAVE_FILE, "欧哟几-我的营地.png", "*.png", "营地明信片", "image/png", func(path: String):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			toast("暂时没能保存画作，请换一个位置。")
			return
		file.store_buffer(bytes)
		file.flush()
		var success := file.get_error() == OK
		file.close()
		toast("明信片已经收好了。" if success else "画作没有写完整，请再试一次。")
	)

func toast(message: String) -> void:
	if not layer: return
	if toast_tween and toast_tween.is_valid(): toast_tween.kill()
	if is_instance_valid(toast_panel): toast_panel.queue_free()
	toast_panel = GameTheme.panel(true)
	toast_panel.theme = GameTheme.make()
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.z_index = 32
	overlays.add_child(toast_panel)
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_panel.offset_left = -300
	toast_panel.offset_right = 300
	toast_panel.offset_top = 110
	var label := GameTheme.label(message, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(label)
	toast_tween = create_tween()
	toast_tween.tween_interval(3.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, .3)
	toast_tween.tween_callback(toast_panel.queue_free)

func go_back() -> void:
	if resting: return
	if is_instance_valid(file_dialog):
		_cancel_file_dialog()
		return
	if is_instance_valid(modal):
		close_dialog()
		return
	match view:
		"atlas": leave_atlas()
		"landmark":
			if screen.loupe.visible: screen.toggle_loupe()
			else: return_to_atlas()
		"landmark_detail":
			if not screen.close_reference(): leave_landmark_detail()
		"site_journal": return_to_landmark()
		"trail": leave_trail()
		"album": leave_album()
		"world", "camp", "book", "ending": show_map()
		"game": show_world(stage_id)
		"composer", "companions": show_camp()
		"map": show_home()
		_: confirm_exit()

func confirm_exit() -> void:
	var message := "风铃和朋友会在这里等你。旅行已经自动记好啦。"
	var options := [{"label": "再玩一会儿", "action": "close", "accent": true}, {"label": "下次再见", "action": "quit"}]
	if not Journey.last_error.is_empty():
		message = "还有旅行没有保存。直接退出会丢失本次未保存的进度。\n请让大人帮忙重试保存，或先导出行囊文件。"
		options = [{"label": "去保存行囊", "action": "save", "accent": true}, {"label": "继续玩一会儿", "action": "close"}, {"label": "放弃未保存的进度并退出", "action": "force_quit"}]
	show_dialog("要歇一会儿吗", message, options, func(action: String):
		match action:
			"quit":
				if Journey.save(): rest()
				else: confirm_exit()
			"force_quit": rest()
			"save": show_save_menu()
			_: close_dialog()
	, "moon")

func rest() -> void:
	if resting: return
	resting = true
	get_viewport().gui_disable_input = true
	audio.shutdown()
	# 同步音轨的播放引用由混音线程在后续缓冲周期释放。
	await get_tree().create_timer(.35, true, false, true).timeout
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_node_ready(): go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready(): Journey.save()
