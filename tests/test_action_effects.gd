extends SceneTree

const EFFECTS := "res://scripts/characters/effects.gd"
const ACTIONS := ["greet", "look", "think", "listen", "surprise", "celebrate", "draw", "rest"]
const CONTACT := Vector2(88, 78)

var errors: Array[String] = []
var stage: SubViewport
var layer: Node2D
var effects: Node2D
var output_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		printerr(message)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--effects-output="):
			output_dir = arg.trim_prefix("--effects-output=")
	if not FileAccess.file_exists(EFFECTS):
		check(false, "角色动作与落脚需要可独立实例化的原生特效层")
		quit(1)
		return
	var script := load(EFFECTS) as GDScript
	if script == null or not script.can_instantiate():
		check(false, "特效脚本必须可以加载")
		quit(1)
		return
	stage = SubViewport.new()
	stage.size = Vector2i(176, 126)
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	layer = Node2D.new()
	stage.add_child(layer)
	effects = script.new()
	layer.add_child(effects)
	await process_frame
	if DisplayServer.get_name() != "headless":
		for i in 3:
			await process_frame
			await RenderingServer.frame_post_draw
	check_lifecycle()
	if DisplayServer.get_name() != "headless":
		if not output_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(output_dir)
		await check_tracks()
		await check_cues()
		await check_small_scale()
		await check_retention()
	elif not output_dir.is_empty():
		check(false, "保存实绘帧需要 Compatibility 图形窗口")
	stage.free()
	print("ACTION_EFFECTS ", "PASS" if errors.is_empty() else "FAIL", " · ", errors.size(), " 项失败")
	quit(0 if errors.is_empty() else 1)

func reset_layer() -> void:
	effects.set_active(false)
	effects.set_active(true)
	effects.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	effects.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

func check_lifecycle() -> void:
	reset_layer()
	check(not effects.is_processing(), "空层不占用每帧处理")
	effects.step(CONTACT, 0, -1.0, "sand")
	check(effects.is_processing(), "实际落脚启动限时绘制")
	effects.set_reduced_motion(true)
	effects.step(CONTACT, 1, 1.0, "grass", true)
	effects.accent("celebrate", CONTACT)
	check(not effects.is_processing(), "少动态立即清空脚印和飞散物")
	effects.set_reduced_motion(false)
	effects.accent("unknown", CONTACT)
	check(not effects.is_processing(), "未知动作不产生默认动画")
	for id: String in ACTIONS:
		effects.accent(id, CONTACT)
		check(effects.is_processing(), "动作反馈应可触发 " + id)
		effects._process(4.0)
		check(not effects.is_processing(), "动作反馈自然结束 " + id)
	effects.step(CONTACT, 1, 1.0, "stone", true)
	layer.hide()
	effects.accent("greet", CONTACT)
	check(not effects.is_processing(), "隐藏父画层应清除并停用反馈")
	layer.show()
	effects.set_active(false)
	effects.accent("think", CONTACT)
	check(not effects.is_processing(), "关闭时不接受动作")
	effects.set_active(true)
	effects.accent("draw", CONTACT)
	effects.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	effects.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	effects.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	effects.step(CONTACT, 0, 1.0, "stone")
	check(not effects.is_processing(), "应用恢复但仍失焦时不接受动作")
	effects.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not effects.is_processing(), "恢复后不重播离开前的效果")
	effects.step(CONTACT, 0, 1.0, "sand")
	check(effects.is_processing(), "恢复后的新脚步可用")
	effects._process(4.0)
	check(not effects.is_processing(), "脚印自然消退后画层休眠")

func frame_after(seconds: float) -> Image:
	effects._process(seconds)
	effects.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	return stage.get_texture().get_image()

func track(terrain: String, animal: bool, side: int, heading: float, age: float) -> Image:
	reset_layer()
	effects.step(CONTACT, side, heading, terrain, animal)
	return await frame_after(age)

func cue(id: String, heading: float, age: float) -> Image:
	reset_layer()
	effects.accent(id, CONTACT, heading)
	return await frame_after(age)

func save_frame(image: Image, id: String) -> void:
	if not output_dir.is_empty():
		check(image.save_png(output_dir.path_join(id + ".png")) == OK, "写入实绘样张 " + id)

func mask_similarity(a: Image, b: Image, flip := false) -> float:
	var common := 0
	var total := 0
	for y in a.get_height():
		for x in a.get_width():
			var first := a.get_pixel(x, y).a >= 0.22
			var second := b.get_pixel(b.get_width() - x - 1 if flip else x, y).a >= 0.22
			if first or second:
				total += 1
			if first and second:
				common += 1
	return float(common) / maxi(1, total)

func check_tracks() -> void:
	var sole := await track("sand", false, 0, 1.0, 0.64)
	var hoof := await track("sand", true, 0, 1.0, 0.64)
	for animal in [false, true]:
		var rightward := hoof if animal else sole
		var leftward := await track("sand", animal, 0, -1.0, 0.64)
		var other_foot := await track("sand", animal, 1, 1.0, 0.64)
		check(rightward.get_used_rect().has_point(Vector2i(CONTACT)), "足印附着在给定的落脚点")
		check(mask_similarity(rightward, leftward, true) > 0.84, "转身时鞋尖或蹄尖必须翻向另一边")
		check(mask_similarity(rightward, leftward) < 0.88, "前掌和后跟需要有方向")
		check(mask_similarity(rightward, other_foot) < 0.88, "左右脚印必须可辨")
	check(mask_similarity(sole, hoof) < 0.68, "分瓣的鹿蹄和分掌跟的布鞋需要不同实绘轮廓")
	var sand := await track("sand", false, 0, 1.0, 0.18)
	var stone := await track("stone", false, 0, 1.0, 0.18)
	var grass := await track("grass", false, 0, 1.0, 0.18)
	var kick := Rect2i(int(CONTACT.x) - 45, int(CONTACT.y) - 30, 32, 29)
	var sand_kick := sand.get_region(kick)
	var stone_kick := stone.get_region(kick)
	var grass_kick := grass.get_region(kick)
	check(sand_kick.get_used_rect().has_area() and stone_kick.get_used_rect().has_area() and grass_kick.get_used_rect().has_area(), "三种地表都应在后跟外产生扬起物")
	check(mask_similarity(sand_kick, stone_kick) < 0.75 and mask_similarity(stone_kick, grass_kick) < 0.75, "细沙、石屑、叶片的外轮廓应可分辨")
	save_frame(sole, "shoe")
	save_frame(hoof, "hoof")
	save_frame(sand, "sand")
	save_frame(stone, "stone")
	save_frame(grass, "grass")

func check_cues() -> void:
	var rendered: Array[Image] = []
	for id: String in ACTIONS:
		var shown := await cue(id, 1.0, 0.38)
		var bounds := shown.get_used_rect()
		check(bounds.size.x >= 12 and bounds.size.y >= 8, "动作在实际画面上应清晰可见 " + id)
		for previous in rendered:
			check(mask_similarity(shown, previous) < 0.80, "动作应有各自的实绘标记 " + id)
		rendered.append(shown)
		save_frame(shown, id)
	var ring := rendered[ACTIONS.find("listen")]
	check(ring.get_used_rect().position.x < CONTACT.x - 6 and ring.get_used_rect().end.x > CONTACT.x + 6, "铜铃声波应从铃的两侧传开")
	var early := await cue("draw", 1.0, 0.15)
	var late := await cue("draw", 1.0, 0.75)
	check(late.get_used_rect().end.x - early.get_used_rect().end.x > 15, "提笔时墨迹应从笔尖逐段写出")
	check(has_dry_brush(late), "笔画浓处应向细丝分开，露出纸底")
	save_frame(early, "draw-start")
	save_frame(late, "draw-finish")
	var reflected := await cue("look", -1.0, 0.38)
	check(mask_similarity(rendered[ACTIONS.find("look")], reflected, true) > 0.84, "望远发现细线必须随朝向翻转")
	var settling := await cue("celebrate", 1.0, 1.19)
	check(settling.get_used_rect().position.x < CONTACT.x - 30 and settling.get_used_rect().end.x > CONTACT.x + 35, "两端的金箔应留在落点渐隐")

func check_small_scale() -> void:
	effects.scale = Vector2.ONE * 0.56
	effects.position = CONTACT * (1.0 - effects.scale.x)
	var shoe := await track("sand", false, 0, 1.0, 0.63)
	var hoof := await track("sand", true, 0, 1.0, 0.63)
	check(shoe.get_used_rect().size.x >= 12 and hoof.get_used_rect().size.x >= 9 and mask_similarity(shoe, hoof) < 0.72, "远景仍能区分鞋印和蹄印")
	var draw := await cue("draw", 1.0, 0.75)
	check(draw.get_used_rect().size.x > 33, "近景下限仍能读到整笔墨迹")
	save_frame(shoe, "small-shoe")
	save_frame(hoof, "small-hoof")
	save_frame(draw, "small-ink")
	effects.scale = Vector2.ONE
	effects.position = Vector2.ZERO

func has_dry_brush(image: Image) -> bool:
	var split_columns := 0
	for x in range(int(CONTACT.x) + 7, image.get_used_rect().end.x - 4):
		var runs := 0
		var within := false
		for y in range(int(CONTACT.y) - 24, int(CONTACT.y) + 25):
			var ink := image.get_pixel(x, y).a > 0.23
			if ink and not within:
				runs += 1
			within = ink
		if runs >= 2:
			split_columns += 1
	return split_columns >= 6

func check_retention() -> void:
	reset_layer()
	effects.step(CONTACT, 0, 1.0, "sand")
	effects.accent("celebrate", CONTACT)
	for i in 96:
		effects.step(Vector2(-350, -350), i % 2, 1.0, "stone", i % 2 == 0)
		effects.accent("listen", Vector2(-350, -350))
	var displaced := await frame_after(0.16)
	check(not displaced.get_used_rect().has_area(), "连续输入应挤掉最旧的脚印和动作，绘制数量有上限")
	reset_layer()
	effects.accent("celebrate", CONTACT)
	effects.set_active(false)
	effects.set_active(true)
	var reopened := await frame_after(0.1)
	check(not reopened.get_used_rect().has_area(), "再次打开时画面不应残留金箔")
