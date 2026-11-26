extends SceneTree
var app: Node
var journey: Node
var qa_dir := "user://qa-journey-%d" % OS.get_process_id()
var errors: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
		printerr("FAIL ",label)
func play(game: Control, id: String) -> void:
	match id:
		"pack":
			for item in ["water","grain","silk","scroll"]: game.perform({"type":"item","id":item})
		"water":
			for pair in [[0,3],[1,2],[4,3],[7,3],[8,3]]:
				for n in range(pair[1]): game.perform({"type":"cell","index":pair[0]})
		"trade":
			for weights in [[3],[3,1],[3,2]]:
				for weight in weights: game.perform({"type":"weight","value":weight})
				game.perform({"type":"check"})
		"route":
			for cell in [1,5,9,10,11,15]: game.perform({"type":"cell","index":cell})
		"music":
			for phrase in [[0,2],[0,2,3],[3,2,0,4]]:
				for note in phrase: game.perform({"type":"note","index":note})
				if not game.session.state.done: game.perform({"type":"next"})
		"mural":
			for i in range(6): game.perform({"type":"drop","piece":i,"target":i})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(qa_dir)
	journey = root.get_node("Journey")
	journey.save_path = qa_dir.path_join("progress.json")
	journey.progress = journey.normalize({})
	journey.set_setting("sound",false)
	root.size = Vector2i(1280,720)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var data: Dictionary = root.get_node("Library").data
	for chapter in data.chapters:
		app.show_world(chapter.id)
		await process_frame
		app.open_story()
		for page in range(chapter.dialogue.size()):
			app.modal.chosen.emit("next")
		app.modal.chosen.emit(chapter.choices[0].id)
		check(chapter.id in journey.progress.journey.conversations,chapter.id+" story callback")
		app.modal.chosen.emit("play")
		await process_frame
		check(app.view == "game" and app.screen.game_id == chapter.requiredGame,chapter.id+" linked game")
		play(app.screen,chapter.requiredGame)
		check(chapter.requiredGame in journey.progress.completed,chapter.id+" real game reward")
		app.screen._primary()
		await process_frame
		check(app.view == "world" and app.stage_id == chapter.id,chapter.id+" return")
		var visited := 0
		for point in data.encounters:
			if point.stageId == chapter.id and visited < 2:
				app.observe(point.id)
				app.modal.chosen.emit("close")
				visited += 1
		app.screen.claim_button.pressed.emit()
		check(chapter.id in journey.progress.journey.claimed,chapter.id+" bell claimed")
		print("STAGE ",chapter.id," bells=",journey.progress.journey.claimed.size())
		app.modal.chosen.emit("next")
		await process_frame
	check(app.view == "ending","sixth stage next enters ending")
	for button in app.screen.find_children("*","Button",true,false):
		if button.tooltip_text in ["准备","照顾","分享","勇气","倾听","创造"]: button.pressed.emit()
	check(journey.progress.journey.endingSeen,"all chime callbacks finish ending")
	print("JOURNEY_CHECKS: %d; FAILURES: %d" % [checks, errors.size()])
	app.queue_free()
	await create_timer(.3).timeout
	for file in DirAccess.get_files_at(qa_dir): DirAccess.remove_absolute(qa_dir.path_join(file))
	DirAccess.remove_absolute(qa_dir)
	quit(1 if errors.size() else 0)
