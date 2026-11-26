extends SceneTree

var bad: Array[String] = []

func check(ok: bool, why: String) -> void:
	if not ok:
		bad.append(why)
		printerr(why)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director: Node = load("res://scripts/audio/audio_director.gd").new()
	root.add_child(director)
	if not director.has_method("companion_step"):
		printerr("terrain has no contact-synchronized foley")
		quit(1)
		return
	director.configure({"sound":true,"music":false})
	director.set_context("world")
	for terrain: String in ["sand","grass","stone"]:
		for animal: bool in [false,true]:
			check(director.companion_step(terrain,animal,0), "a touch of " + terrain)
			var output: AudioStreamPlayer = director.foley.hooves if animal else director.foley.shoes
			check(output.stream is AudioStreamWAV and output.stream.get_length() > .07 and terrain in output.stream.resource_path, "real contact recording")
	director.set_context("companions")
	check(not director.foley.shoes.playing and not director.foley.hooves.playing, "old tracks fade with the page")
	for id in ["draw","listen","celebrate","greet"]:
		check(director.companion_action(id),"a sound accompanies " + id)
	director.configure({"sound":false,"music":false})
	check(not director.foley.gesture.playing and not director.companion_action("listen"), "muting also silences the bell")
	director.configure({"sound":true,"music":false})
	director.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not director.companion_action("draw"), "unfocused brush is quiet")
	director.shutdown()
	director.free()
	await create_timer(.35).timeout
	print("旅伴动作声音，失败 ", bad.size())
	quit(0 if bad.is_empty() else 1)
