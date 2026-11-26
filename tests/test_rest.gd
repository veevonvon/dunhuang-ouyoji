extends SceneTree

func _initialize() -> void:
	call_deferred("rest_from_home")

func rest_from_home() -> void:
	create_timer(4).timeout.connect(func():
		printerr("FAIL: the farewell did not close the game")
		quit(1)
	)
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-rest-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("travel.json")
	store.progress = store.normalize({})
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await create_timer(.45).timeout
	assert(app.audio.music_a.playing)
	app.go_back()
	var leave: Button = app.modal.find_child("Choice_quit", true, false)
	assert(leave != null)
	root.tree_exiting.connect(func():
		for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
		print("REST_CHECK: returned through the native farewell")
	)
	leave.pressed.emit()
