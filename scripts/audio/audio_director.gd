extends Node

signal beat(index: int)
signal composition_finished
signal seal_song_finished

const SCORE_DIR := "res://assets/score/"
const STATIONS := ["wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang"]
const CUES := ["step", "hint", "miss", "discover", "win"]
const Landscape = preload("res://scripts/audio/landscape_ambience.gd")
const Foley = preload("res://scripts/audio/companion_foley.gd")
var foley: RefCounted
var landscape: RefCounted

var preferences: Dictionary = {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var voice: AudioStreamPlayer
var feedback: AudioStreamPlayer
var ensemble: AudioStreamPlayer
var _song_active := false
var notes: Array[AudioStreamPlayer] = []
var theme_id := ""
var mode := "home"
var walking := false
var fade: Tween
var music_mix := Vector2(1, 0)
var layer_gain := 0.0
var duck_gain := 1.0
var bookmarks: Dictionary = {}
var last_cue := ""
var last_cue_ms := -1000
var composition: Array = []
var composition_voice := "bell"
var tempo := 80
var cursor := 0
var remaining := 0.0
var suspended := false
var _paused := false
var _unfocused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_a = player()
	music_b = player()
	voice = player()
	feedback = player()
	ensemble = player()
	ensemble.finished.connect(_finish_seal_song)
	landscape = Landscape.new(player(), player())
	foley = Foley.new(player(),player(),player())
	for i in range(5): notes.append(player())

func player() -> AudioStreamPlayer:
	var output := AudioStreamPlayer.new()
	add_child(output)
	return output

func configure(settings: Dictionary) -> void:
	var narration_was_on := bool(preferences.get("narration", true))
	preferences = settings.duplicate()
	if not bool(preferences.get("sound", true)):
		_stop_one_shots()
	elif narration_was_on and not bool(preferences.get("narration", true)):
		stop_voice()
	if _music_slider() <= 0.0: _stop_seal_song()
	if not enabled_music():
		if fade and fade.is_valid(): fade.kill()
		_park(music_a)
		_park(music_b)
		_stop_seal_song()
	elif not theme_id.is_empty() and not music_a.playing and not suspended:
		_start_theme(theme_id)
	_apply_mix()
	_update_landscape()

func enabled_music() -> bool:
	return bool(preferences.get("sound", true)) and bool(preferences.get("music", true))

func _can_sound() -> bool:
	return not suspended and bool(preferences.get("sound", true))

func _music_slider() -> float:
	return clampf(float(preferences.get("musicVolume", .35)), 0.0, 1.0)

func _db(gain: float) -> float:
	return linear_to_db(maxf(.0001, gain))

func volume() -> float:
	return _db(_music_slider() * duck_gain * .90)

func play_music(id: String) -> void:
	if id == theme_id or (id not in STATIONS and id not in ["map", "ending"]): return
	theme_id = id
	if enabled_music() and not suspended: _start_theme(id)

func _start_theme(id: String) -> void:
	if fade and fade.is_valid(): fade.kill()
	var old := music_a
	music_a = music_b
	music_b = old
	music_mix = Vector2(music_mix.y if music_a.playing else 0.0, music_mix.x if music_b.playing else 0.0)
	if music_a.get_meta("theme", "") != id or not music_a.playing:
		_park(music_a)
		var score := AudioStreamSynchronized.new()
		score.stream_count = 2
		for part in ["lead", "motion"]:
			var stream := load(SCORE_DIR + id + "_" + part + ".ogg") as AudioStreamOggVorbis
			stream.loop = true
			score.set_sync_stream(0 if part == "lead" else 1, stream)
		score.set_sync_stream_volume(1, _db(layer_gain))
		music_a.set_meta("theme", id)
		music_a.stream = score
		music_a.volume_db = -80
		music_a.play(float(bookmarks.get(id, 0.0)))
		music_mix.x = 0
	_apply_mix()
	fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(self, "music_mix", Vector2(1, 0), .65)
	fade.tween_callback(_park.bind(music_b))

func _park(output: AudioStreamPlayer) -> void:
	if output.playing:
		bookmarks[output.get_meta("theme", "")] = output.get_playback_position()
	output.stop()
	output.stream = null

func set_context(next_mode: String) -> void:
	if mode == next_mode: return
	mode = next_mode
	foley.stop()
	walking = false
	_stop_seal_song()
	feedback.stop()
	if not composition.is_empty(): stop_composition()
	if next_mode not in ["landmark","dialog"] and landscape: landscape.profile = ""
	_update_landscape()

func set_landscape(profile: String, season: String, phase: String, site_id := "") -> void:
	landscape.select(profile, season, phase, site_id)
	_update_landscape()

func _update_landscape() -> void:
	if landscape: landscape.update(mode == "landmark" and _can_sound())

func set_walking(active: bool) -> void:
	walking = active and mode == "world"

func companion_step(terrain: String, animal: bool, side: int) -> bool:
	return mode == "world" and _can_sound() and foley.step(terrain,animal,side,voice.playing)

func companion_action(action: String) -> bool:
	return mode in ["world","companions"] and _can_sound() and foley.accent(action,voice.playing)

func _apply_mix() -> void:
	music_a.volume_db = maxf(-80, volume() + _db(music_mix.x))
	music_b.volume_db = maxf(-80, volume() + _db(music_mix.y))
	for output: AudioStreamPlayer in [music_a, music_b]:
		var score := output.stream as AudioStreamSynchronized
		if score: score.set_sync_stream_volume(1, _db(layer_gain))
	ensemble.volume_db = _db(_music_slider() * (.26 if voice.playing else .96))
	feedback.volume_db = -14 if voice.playing else -5

func speak(id: String) -> void:
	if not _can_sound(): return
	var path := "res://assets/voice/%s.mp3" % id
	if not ResourceLoader.exists(path): return
	voice.stop()
	voice.stream = load(path)
	voice.volume_db = -3
	voice.play()
	duck_gain = minf(duck_gain, .18)
	_apply_mix()

func stop_voice() -> void:
	voice.stop()

func note(index: int, timbre := "bell") -> void:
	if index < 0 or index > 4 or not _can_sound(): return
	var path := "res://assets/notes/%s-%d.mp3" % [timbre, index]
	if not ResourceLoader.exists(path): return
	var output := notes[index]
	output.stream = load(path)
	output.volume_db = -14 if voice.playing else -9
	output.play()

func cue(kind: String, stage_id := "") -> bool:
	if not _can_sound(): return false
	var clip := "cue_" + kind
	if kind == "seal":
		if stage_id not in STATIONS: return false
		clip = "seal_" + stage_id
	elif kind not in CUES:
		return false
	var now := Time.get_ticks_msec()
	if last_cue == clip and now - last_cue_ms < 160: return false
	last_cue = clip
	last_cue_ms = now
	_stop_seal_song()
	feedback.stream = load(SCORE_DIR + clip + ".ogg")
	feedback.volume_db = -14 if voice.playing else -5
	feedback.play()
	return true

func is_seal_song_playing() -> bool:
	return _song_active

func _finish_seal_song() -> void:
	if not _song_active: return
	_song_active = false
	seal_song_finished.emit()

func _stop_seal_song() -> void:
	if not _song_active: return
	ensemble.stop()
	_finish_seal_song()

func play_seal_song() -> bool:
	if not _can_sound() or not enabled_music() or _music_slider() <= 0 or _song_active: return false
	feedback.stop()
	if not composition.is_empty(): stop_composition()
	ensemble.stream = load(SCORE_DIR + "seal_song.ogg")
	_apply_mix()
	ensemble.play()
	_song_active = true
	return true

func play_composition(sequence: Array, timbre: String, speed: int) -> void:
	stop_composition()
	if not _can_sound(): return
	composition = sequence.duplicate()
	composition_voice = timbre
	tempo = clampi(speed, 60, 140)
	cursor = 0
	remaining = 0

func stop_composition() -> void:
	composition.clear()
	for sound in notes: sound.stop()
	beat.emit(-1)
	composition_finished.emit()

func _process(delta: float) -> void:
	if suspended: return
	var target_layer := 0.0
	if mode in ["trail","game","landmark_detail"]: target_layer = .88
	elif walking: target_layer = .75
	layer_gain = move_toward(layer_gain, target_layer, delta * 2.0)
	var target_duck := 1.0
	if ensemble.playing: target_duck = .035
	elif voice.playing or mode == "composer": target_duck = .18
	elif feedback.playing and last_cue.begins_with("seal_"): target_duck = .24
	elif mode == "dialog" or mode == "book": target_duck = .55
	duck_gain = move_toward(duck_gain, target_duck, delta * (3.6 if target_duck < duck_gain else 1.35))
	_apply_mix()
	if composition.is_empty(): return
	remaining -= delta
	if remaining > 0: return
	if cursor >= composition.size():
		stop_composition()
		return
	note(int(composition[cursor]), composition_voice)
	beat.emit(cursor)
	cursor += 1
	remaining += 60.0 / tempo

func _stop_one_shots() -> void:
	if foley: foley.stop()
	voice.stop()
	feedback.stop()
	_stop_seal_song()
	stop_composition()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: _paused = true
		NOTIFICATION_APPLICATION_RESUMED: _paused = false
		NOTIFICATION_APPLICATION_FOCUS_OUT: _unfocused = true
		NOTIFICATION_APPLICATION_FOCUS_IN: _unfocused = false
		_: return
	var should_suspend := _paused or _unfocused
	if should_suspend == suspended: return
	suspended = should_suspend
	if not music_a: return
	_update_landscape()
	if suspended:
		music_a.stream_paused = true
		music_b.stream_paused = true
		if fade and fade.is_valid(): fade.pause()
		_stop_one_shots()
	else:
		music_a.stream_paused = false
		music_b.stream_paused = false
		if fade and fade.is_valid(): fade.play()
		if enabled_music() and not theme_id.is_empty() and (not music_a.playing or theme_id != music_a.get_meta("theme", "")):
			_start_theme(theme_id)

func shutdown() -> void:
	theme_id = ""
	if landscape: landscape.profile = ""
	_stop_seal_song()
	if fade and fade.is_valid(): fade.kill()
	composition.clear()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _exit_tree() -> void:
	shutdown()
