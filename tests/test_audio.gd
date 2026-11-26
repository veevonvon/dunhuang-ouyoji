extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio: Node = load("res://scripts/audio/audio_director.gd").new()
	root.add_child(audio)
	audio.configure({"sound": true, "music": true, "musicVolume": .35})
	audio.play_music("wuwei")
	audio.speak("welcome")
	await create_timer(.8).timeout
	if audio.music_a.volume_db > -20:
		printerr("FAIL: music crossfade must keep narration audible")
		audio.queue_free()
		await create_timer(.3).timeout
		quit(1)
		return
	audio.play_composition([0, 1, 2, 3], "bell", 80)
	assert(audio.music_a.playing)
	audio._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert(audio.music_a.stream_paused)
	assert(audio.composition.is_empty())
	audio._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert(not audio.music_a.stream_paused)
	if not audio.has_method("shutdown"):
		printerr("FAIL: shutdown must release native audio streams")
		audio.queue_free()
		await process_frame
		quit(1)
		return
	audio.shutdown()
	for player: AudioStreamPlayer in audio.get_children():
		assert(not player.playing and player.stream == null)
	audio.queue_free()
	await process_frame
	# AudioServer releases playback references on its mixer thread.
	await create_timer(.3).timeout
	print("AUDIO_CHECKS: lifecycle, voice ducking and native stream cleanup passed")
	quit()
