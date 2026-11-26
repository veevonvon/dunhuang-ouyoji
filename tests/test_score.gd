extends SceneTree

var failures := 0
var ended := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	var audio: Node = load("res://scripts/audio/audio_director.gd").new()
	root.add_child(audio)
	var has_api := audio.has_method("set_context") and audio.has_method("set_walking") and audio.has_method("cue") and audio.has_method("play_seal_song")
	check(has_api, "score must respond to walking, puzzle states, station stamps and ensemble playback")
	if has_api:
		await exercise(audio)
	audio.shutdown()
	audio.queue_free()
	await process_frame
	await create_timer(.3).timeout
	if failures == 0: print("SCORE_CHECKS: 8 synchronized themes, adaptive mix, cues, ensemble and lifecycle passed")
	quit(1 if failures else 0)

func exercise(audio: Node) -> void:
	audio.configure({"sound": true, "music": true, "musicVolume": .7})
	audio.set_context("world")
	for station in ["map", "wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang", "ending"]:
		audio.play_music(station)
		var synchronized := audio.music_a.stream as AudioStreamSynchronized
		check(synchronized != null, "%s must use the sample-synchronous mixer" % station)
		if not synchronized: return
		var lead := synchronized.get_sync_stream(0) as AudioStreamOggVorbis
		var layer := synchronized.get_sync_stream(1) as AudioStreamOggVorbis
		check(lead.loop and layer.loop and lead.get_length() == layer.get_length() and lead.get_length() > 14, "%s stems must loop at the same sample" % station)
	var song: AudioStreamSynchronized = audio.music_a.stream
	var quiet := song.get_sync_stream_volume(1)
	audio.set_walking(true)
	await create_timer(.8).timeout
	check(song.get_sync_stream_volume(1) > quiet + 12, "walking should bring out a distinct accompaniment")
	audio.set_context("dialog")
	await create_timer(.8).timeout
	check(song.get_sync_stream_volume(1) < -45, "dialog should clear walking accompaniment")
	audio.set_context("trail")
	await create_timer(.8).timeout
	check(song.get_sync_stream_volume(1) > -12, "puzzles should bring the pattern into focus")
	audio.play_music("ending")
	check(audio.music_a.stream == song and audio.music_a.get_playback_position() > 1, "same theme should continue across screens")
	for kind in ["step", "hint", "miss", "discover", "win"]:
		check(audio.cue(kind, "wuwei"), "%s needs an audible response" % kind)
	for station in ["wuwei", "zhangye", "jiuquan", "jiayuguan", "guazhou", "dunhuang"]:
		check(audio.cue("seal", station), "missing stamp sound for %s" % station)
	check(not audio.cue("seal", "other"), "unknown stamps have no station melody")
	check(audio.play_seal_song() and not audio.play_seal_song(), "ensemble cannot stack on repeated tap")
	audio.set_context("book")
	check(not audio.ensemble.playing, "leaving the album stops its performance")
	audio.configure({"sound": false})
	check(not audio.cue("win") and not audio.play_seal_song(), "sound disabled must suppress musical responses")
	audio.configure({"sound": true, "music": false})
	check(not audio.play_seal_song(), "ensemble respects the music switch")
	audio.configure({"sound": true, "music": true})
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not audio.cue("step") and not audio.play_seal_song(), "background must stay silent")
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(audio.play_seal_song(), "ensemble should be available after foregrounding")

	audio.configure({"sound": true, "music": true, "narration": false})
	audio.speak("welcome")
	audio.configure({"sound": true, "music": true, "narration": false})
	check(audio.voice.playing, "saving other progress must preserve a child-requested reading with automatic narration off")
	audio.stop_voice()

	# Hear the real mixed accompaniment through the native AudioServer.
	audio.set_context("world")
	audio.configure({"sound": true, "music": true, "musicVolume": 1.0})
	audio.play_music("wuwei")
	var mixer := audio.music_a.stream as AudioStreamSynchronized
	mixer.set_sync_stream_volume(0, -80)
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "ScoreTestCapture")
	var tap := AudioEffectCapture.new()
	tap.buffer_length = .5
	AudioServer.add_bus_effect(bus, tap)
	audio.music_a.bus = "ScoreTestCapture"
	await create_timer(.85).timeout
	tap.clear_buffer()
	await create_timer(.40).timeout
	var rest := rms(tap)
	audio.set_walking(true)
	await create_timer(.50).timeout
	tap.clear_buffer()
	await create_timer(.40).timeout
	var moving := rms(tap)
	check(rest >= 0 and rest < .001 and moving > .002 and moving > rest * 8, "native audio output must gain actual motion energy while walking")
	audio.music_a.bus = "Master"
	AudioServer.remove_bus(bus)
	audio.seal_song_finished.connect(func():
		ended += 1
		check(not audio.is_seal_song_playing(), "album callback must see an idle player immediately")
	)
	check(audio.play_seal_song(), "complete performance can be started again")
	await create_timer(.12).timeout
	audio.ensemble.seek(audio.ensemble.stream.get_length() - .18)
	await create_timer(.55).timeout
	check(ended == 1 and not audio.ensemble.playing, "ensemble must reach its final rest and signal completion once")
	check(audio.has_method("is_seal_song_playing"), "album must be able to read current performance state")
	if not audio.has_method("is_seal_song_playing"): return
	for reason in ["stamp", "mute", "background", "navigation", "zero_volume"]:
		var before := ended
		check(audio.play_seal_song() and audio.is_seal_song_playing(), "state must show a playing performance")
		match reason:
			"stamp": audio.cue("seal", "zhangye")
			"mute": audio.configure({"sound": false})
			"background": audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			"navigation": audio.set_context("album")
			"zero_volume": audio.configure({"sound": true, "music": true, "musicVolume": 0.0})
		check(not audio.is_seal_song_playing() and ended == before + 1, "interruption must reset album button and signal exactly once: " + reason)
		audio.set_context("world")
		audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		audio.configure({"sound": true, "music": true, "musicVolume": 1.0})
		check(ended == before + 1, "later changes must not repeat the finish signal")


func rms(tap: AudioEffectCapture) -> float:
	var frames := tap.get_buffer(tap.get_frames_available())
	if frames.is_empty(): return -1.0
	var power := 0.0
	for sample in frames: power += sample.length_squared()
	return sqrt(power / (2 * frames.size()))
