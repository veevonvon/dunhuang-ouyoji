extends SceneTree

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		printerr("FAIL: ",message)
		failed = true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director: Node = load("res://scripts/audio/audio_director.gd").new()
	root.add_child(director)
	check(director.has_method("set_landscape"), "field scenery drives local sounds")
	if not failed:
		director.set_context("landmark")
		director.set_landscape("forest","summer","dawn")
		check(director.landscape.bed.playing and director.landscape.color.playing,"the grove and its dawn birds can be heard")
		director.set_landscape("forest","winter","night")
		check(director.landscape.bed.playing and not director.landscape.color.playing,"a winter grove has no summer insects or morning birds")
		director.set_landscape("desert","summer","dawn")
		check(director.landscape.bed.stream.resource_path.ends_with("sand.ogg") and not director.landscape.color.playing,"bare desert uses its own sand movement")
		check(director.get_method_argument_count("set_landscape") == 4, "the director can identify an oasis or stream inside a dry landscape")
		if director.get_method_argument_count("set_landscape") == 4:
			director.set_landscape("desert","autumn","day","crescent")
			check(director.landscape.bed.stream.resource_path.ends_with("sand.ogg") and director.landscape.color.playing and director.landscape.color.stream.resource_path.ends_with("water.ogg"),"Crescent Lake keeps its reeds and water audible inside the dunes")
			director.set_landscape("cliff","spring","dawn","yulin")
			check(director.landscape.bed.stream.resource_path.ends_with("water.ogg") and director.landscape.color.stream.resource_path.ends_with("birds.ogg"),"the stream and morning birds share Yulin's canyon")
			director.set_landscape("rock","winter","night","yardang")
			check(director.landscape.bed.stream.resource_path.ends_with("wind.ogg") and not director.landscape.color.playing,"Yardang's winter night returns to open-gobi wind")
		director.set_context("dialog")
		check(not director.landscape.bed.playing,"reading an observation quiets the field")
		director.set_context("landmark")
		check(director.landscape.bed.playing,"closing the notebook restores the scene")
		director._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		check(not director.landscape.bed.playing,"Android background stops field audio")
		director._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		director.configure({"sound":false})
		check(not director.landscape.bed.playing,"mute suppresses environmental audio")
		director.configure({"sound":true})
		director.set_context("map")
		check(not director.landscape.bed.playing and not director.landscape.color.playing,"leaving the site clears both sounds")
	director.shutdown()
	director.queue_free()
	await create_timer(.35).timeout
	print("FIELD_AUDIO: ", "FAILED" if failed else "seasonal nature sounds, switching, mute and lifecycle passed")
	quit(1 if failed else 0)
