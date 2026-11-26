extends SceneTree

# Run with a graphical Compatibility renderer and --fixed-fps 24.
const OUT := "res://test-results/companions-4.3"
var app: Node
var frames := ""
var frame_id := 0
var failed := false
var capture_count := 0

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	RenderingServer.force_draw(false)
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(path) != OK:
		printerr("无法取画 ", path)
		failed = true
	capture_count += 1

func sequence(count: int, still := "", key_frame := 18, record := true) -> void:
	for i in count:
		await process_frame
		if i == key_frame and not still.is_empty(): capture(OUT.path_join(still + ".png"))
		if record and not frames.is_empty():
			capture(frames.path_join("frame-%04d.png" % frame_id))
			frame_id += 1

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var movie := "--performance-reel" in args
	if args.size() == 2 and args[0] == "--frames": frames = args[1]
	if not frames.is_empty(): DirAccess.make_dir_recursive_absolute(frames)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	var store: Node = root.get_node("Journey")
	var folder := "user://qa-cast-render-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	store.save_path = folder.path_join("progress.json")
	store.progress = store.normalize({})
	store.set_setting("sound", movie)
	store.set_setting("musicVolume",.26)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.show_world("dunhuang")
	app.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await sequence(14, "", 0, false)
	app.world.set_move_direction(Vector2.RIGHT)
	await sequence(34,"walking")
	app.world.set_move_direction(Vector2.LEFT)
	await sequence(25,"turning")
	app.world.cancel_input()
	app.show_camp()
	await sequence(12,"camp",10,false)
	app.screen.find_child("MeetCompanions",true,false).pressed.emit()
	await sequence(12, "", 0, false)
	for id: String in ["greet","look","listen","think","draw","surprise","celebrate","rest"]:
		app.screen.choose(id)
		await sequence(42,id,20)
	if movie:
		app.audio.shutdown()
		app.free()
		quit(1 if failed else 0)
		return
	app.show_settings()
	await sequence(12,"camp-dialog",10,false)
	app.close_dialog()
	app.screen.start_riddle()
	await sequence(26,"guess",23,false)
	for extent: Vector2i in [Vector2i(1560,720),Vector2i(1024,768)]:
		root.size = extent
		await sequence(12,"stage-%d" % extent.x,10,false)
	root.size = Vector2i(1280,720)
	app.show_home()
	app.welcome()
	await sequence(24,"welcome",20,false)
	app.show_world("wuwei")
	app.guide()
	await sequence(24,"guide",20,false)
	app.show_companions()
	store.set_setting("reducedMotion",true)
	app.screen.choose("think")
	await sequence(12,"reduced-think",10,false)
	app.audio.shutdown()
	app.free()
	await process_frame
	print("真实画面 ",capture_count," 张，连续画格 ",frame_id)
	quit(1 if failed else 0)
