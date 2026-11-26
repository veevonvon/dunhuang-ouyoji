extends SceneTree

const ACTOR := "res://scripts/characters/deer_actor.gd"
const HOOFS := ["NearForeHoof", "FarForeHoof", "NearHindHoof", "FarHindHoof"]
const ACTIONS := ["greet", "look", "think", "listen", "surprise", "celebrate", "draw", "rest"]
const FRAME_SIZE := Vector2i(450, 360)
const STAMP_BITS := 10

var actor: Node2D
var stage: SubViewport
var expression: Node2D
var sample_number := 0
var failures: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		printerr("DEER_FAIL ", detail)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--deer-output="):
			capture_dir = arg.trim_prefix("--deer-output=")
	if not FileAccess.file_exists(ACTOR):
		check(false, "鹿铃需要自己的原生四足骨架角色")
		quit(1)
		return
	var script := load(ACTOR) as GDScript
	if script == null or not script.can_instantiate():
		check(false, "鹿铃角色可独立实例化")
		quit(1)
		return
	stage = SubViewport.new()
	stage.size = FRAME_SIZE + Vector2i(4, 0)
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(stage)
	actor = script.new()
	stage.add_child(actor)
	actor.set_process(false)
	# The actor's own public methods may schedule _process again. Preserve
	# can_process() for manual advance() while taking control of every idle tick.
	process_frame.connect(disable_automatic_tick)
	await process_frame
	var skeleton := actor.get_node("Facing/Skeleton2D") as Skeleton2D
	check(skeleton.get_bone_count() >= 23, "耳、铃、尾、带与四肢需要独立骨骼")
	var skins := actor.find_children("*", "Polygon2D", true, false)
	check(skins.size() >= 7, "四肢、双带和连续颈肩具有原生蒙皮")
	for part: Polygon2D in skins:
		check(part.get_node_or_null(part.skeleton) == skeleton and part.get_bone_count() >= 2, "画层骨骼绑定 " + str(part.name))
	print("DEER_NATIVE bones=%d weighted_meshes=%d" % [skeleton.get_bone_count(), skins.size()])
	for id in HOOFS + ["Head", "NearEar", "FarEar", "Tail", "Bell", "RedStreamer", "JadeStreamer"]:
		check(bone(id) != null, "需要骨骼 " + id)
	if failures.is_empty():
		check_walk()
		check_actions()
		check_live_timing()
		# The project headless checks still exercise the complete hierarchy and IK.
		if DisplayServer.get_name() != "headless":
			expression = actor.find_child("Expression", true, false) as Node2D
			expression.draw.connect(stamp_face_draw)
			await check_paint()
		elif not capture_dir.is_empty():
			check(false, "实绘预览需要 Compatibility 渲染器")
	process_frame.disconnect(disable_automatic_tick)
	actor.free()
	stage.free()
	if failures.is_empty():
		print("DEER_RIG_OK")
	quit(0 if failures.is_empty() else 1)

func bone(id: String) -> Bone2D:
	return actor.find_child(id, true, false) as Bone2D

func foot(id: String) -> Vector2:
	return actor.to_local(bone(id).global_position)

func pose(action := "", progress := 0.48, phase := 0.0, walking := 0.0, blink := 0.0) -> void:
	actor.set("acting", action)
	actor.set("action_progress", progress)
	actor.set("action_weight", 0.0 if action.is_empty() else 1.0)
	actor.set("gait", phase)
	actor.set("move_weight", walking)
	actor.set("blink_amount", blink)
	actor.call("pose_character")

func check_walk() -> void:
	var counts := PackedInt32Array([0, 0, 0, 0])
	var top := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var first_swing := PackedInt32Array([-1, -1, -1, -1])
	var minimum_supports := 4
	var max_travel := 0.0
	var x_range := Vector2(INF, -INF)
	for i in 96:
		pose("", 0.48, TAU * i / 96.0, 1.0)
		var supports := 0
		for k in 4:
			var at := foot(HOOFS[k])
			check(at.y < 0.7, "第 %d 格 %s 穿过地面 %.2f" % [i, HOOFS[k], at.y])
			if at.y >= -0.7:
				supports += 1
				counts[k] += 1
			elif first_swing[k] == -1:
				first_swing[k] = i
			top[k] = minf(top[k], at.y)
			if k == 0:
				x_range = Vector2(minf(x_range.x, at.x), maxf(x_range.y, at.x))
		minimum_supports = mini(minimum_supports, supports)
	max_travel = x_range.y - x_range.x
	check(minimum_supports >= 2, "四拍步行应始终至少两蹄支撑")
	check(max_travel > 18.0, "前蹄应在支撑段向后移、空中回收")
	for k in 4:
		check(counts[k] > 43 and counts[k] < 73 and top[k] < -7, "每蹄都经历支撑和离地 " + HOOFS[k])
	check(first_swing[0] != first_swing[1] and first_swing[2] != first_swing[3], "同对蹄应错相迈出")
	pose()
	var left: Vector2 = actor.call("anchor_point", "left_foot")
	var right: Vector2 = actor.call("anchor_point", "right_foot")
	check(left.distance_to(bone("NearForeHoof").global_position) < 0.5, "脚印跟随近前蹄")
	check(right.distance_to(bone("FarForeHoof").global_position) < 0.5, "脚印跟随远前蹄")
	print("DEER_WALK contact=%s lift=%s support=%d stride=%.1f" % [counts, top, minimum_supports, max_travel])

func check_actions() -> void:
	pose()
	var neutral_face := foot("Head")
	var neutral_bell := foot("Bell")
	var neutral_tail := bone("Tail").rotation
	var neutral_ear := bone("NearEar").rotation
	var neutral_ribbon := bone("RedStreamer").rotation
	pose("greet")
	check(foot("NearForeHoof").y < -13, "招呼时抬起一只前蹄")
	pose("listen")
	check(absf(bone("NearEar").rotation - bone("FarEar").rotation) > 0.35, "倾听时一耳转向声源")
	pose("surprise")
	check(absf(bone("NearEar").rotation - neutral_ear) > 0.18, "惊喜时立起耳朵")
	pose("celebrate")
	check(absf(bone("Tail").rotation - neutral_tail) > 0.22, "欢喜时尾巴扬起")
	pose("draw")
	check(foot("Head").y - neutral_face.y > 10 and foot("Bell").distance_to(neutral_bell) > 6, "看男孩提笔时低头，颈铃随颈下垂")
	pose("rest")
	check(foot("Head").y - neutral_face.y > 24, "休息时真正收腿趴低")
	check(absf(bone("RedStreamer").rotation - neutral_ribbon) > 0.12, "趴下时丝带随之垂落")
	pose()

func check_live_timing() -> void:
	var contacts: Array[int] = []
	var on_ground := func(side: int):
		contacts.append(side)
		check(absf(foot(HOOFS[side]).y) < .8, "脚步信号到达时相应前蹄应实际着地")
	actor.connect("footfall", on_ground)
	actor.call("set_locomotion", 1.0, 1)
	for i in 120:
		actor.call("advance", 1.0 / 90.0)
	actor.disconnect("footfall", on_ground)
	check(contacts.size() >= 3 and contacts[0] != contacts[1], "完整移动入口发出交替落蹄")
	var follow_names := ["Bell", "Tassel", "JadeStreamerMiddle", "JadeStreamerTip"]
	var peaks := PackedInt32Array([0, 0, 0, 0])
	var high := PackedFloat32Array([-INF, -INF, -INF, -INF])
	for i in 48:
		pose("", .48, PI * i / 48.0, 1.0)
		for k in follow_names.size():
			var angle := bone(follow_names[k]).rotation
			if angle > high[k]:
				peaks[k] = i
				high[k] = angle
	var bell_lag := posmod(peaks[1] - peaks[0], 48)
	var tip_lag := posmod(peaks[3] - peaks[2], 48)
	check(bell_lag in range(2, 13) and tip_lag in range(2, 13), "行走时铃穗与带尖应滞后于挂点 " + str(peaks))
	print("DEER_FOLLOW bell_to_tassel=%d/48 silk_middle_to_tip=%d/48" % [bell_lag, tip_lag])
	actor.call("set_locomotion", 0.0, 1)
	actor.call("set_reduced_motion", true)
	actor.call("perform", "rest", true)
	var ears := Vector2(bone("NearEar").rotation, bone("FarEar").rotation)
	var face_position := foot("Head")
	for i in 40:
		actor.call("advance", .06)
	check(face_position.is_equal_approx(foot("Head")) and ears.is_equal_approx(Vector2(bone("NearEar").rotation, bone("FarEar").rotation)), "少动态保持可读的趴卧姿态")
	actor.call("set_reduced_motion", false)
	actor.set("clock", 0.0)
	pose()

func check_paint() -> void:
	actor.position = Vector2(196, 316)
	actor.scale = Vector2(1.65, 1.65)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var signatures: Array[PackedByteArray] = []
	var minimum_ink_difference := 10000
	var neutral_frame: Image
	for id in [""] + ACTIONS:
		pose(id)
		var frame := await painted_frame()
		var used := frame.get_used_rect()
		check(used.size.y > 125 and used.size.x > 130, "画层有完整鹿的轮廓 " + id)
		check(used.position.x > 3 and used.end.x < frame.get_width() - 3 and used.position.y > 3, "预览保留完整耳角轮廓 " + id)
		check(used.end.y <= actor.position.y + 2, "蹄与折起的膝部在实绘中应落在地面上方 " + id + " " + str(used.end.y))
		if id.is_empty():
			neutral_frame = frame
		if not capture_dir.is_empty():
			check(frame.save_png(capture_dir.path_join(("idle" if id.is_empty() else id) + ".png")) == OK, "动作截图写入")
		# Compare expression ink on the identical neutral head. A rotated head or
		# a different silhouette cannot accidentally satisfy this assertion.
		pose()
		var face := actor.find_child("Expression", true, false)
		face.call("show_pose", id, 1.0, 0.0)
		var signature := face_ink(await painted_frame())
		for old in signatures:
			var different := count_difference(old, signature)
			minimum_ink_difference = mini(minimum_ink_difference, different)
			check(different >= 13, "固定头部时两种动作的眼眉嘴应由实际像素区分 " + id)
		signatures.append(signature)
	pose("", 0.48, 0.0, 0.0, 1.0)
	var closed := face_ink(await painted_frame())
	check(count_difference(closed, signatures[0]) >= 12, "真实渲染能看到合眼")
	for tuck in [.56, .62, .68, .74, .80, .86]:
		pose("rest", .14)
		actor.set("action_weight", tuck)
		actor.call("pose_character")
		var transition := await painted_frame()
		check(transition.get_used_rect().end.y <= actor.position.y + 2, "收腿途中真实画层保持贴地 " + str(tuck))
	actor.call("set_locomotion", 0.0, -1)
	pose()
	var mirrored := await painted_frame()
	var matching := 0
	var samples := 0
	for y in range(4, 340, 2):
		for x in range(30, 360, 2):
			var original := neutral_frame.get_pixel(x, y).a
			var other := mirrored.get_pixel(roundi(2 * actor.position.x) - 1 - x, y).a
			if maxf(original, other) > .45:
				samples += 1
				if absf(original - other) < .22:
					matching += 1
	check(matching > samples * .95, "左右翻转后四蹄和皮毛网格保持相同轮廓")
	actor.call("set_locomotion", 0.0, 1)
	for i in 24:
		pose("", 0.48, TAU * i / 24.0, 1.0)
		var frame := await painted_frame()
		for id in HOOFS:
			var hoof := bone(id).global_position
			if foot(id).y >= -.68:
				check(hoof_pigment(frame, hoof), "实际落蹄附近应能采到蹄色 %s %d" % [id, i])
		if not capture_dir.is_empty():
			check(frame.save_png(capture_dir.path_join("walk-%02d.png" % i)) == OK, "步态帧写入")
	print("DEER_PAINT fixed_face_min_delta=%d mirror=%.3f" % [minimum_ink_difference, float(matching) / maxi(1, samples)])
	if not capture_dir.is_empty() and "--deer-film" in OS.get_cmdline_user_args():
		await capture_performance()

func capture_performance() -> void:
	var frame_number := 0
	var fps := 15.0
	pose()
	actor.call("set_locomotion", 1.0, 1)
	for i in 25:
		actor.call("advance", 1.0 / fps)
		var page := await painted_frame()
		check(page.save_png(capture_dir.path_join("film-%03d-walk.png" % frame_number)) == OK, "记录移动中的实机帧")
		frame_number += 1
	actor.call("set_locomotion", 0.0, 1)
	for action in ACTIONS:
		actor.call("perform", action)
		var count := ceili(float(actor.DURATIONS[action]) * fps)
		for i in count:
			actor.call("advance", 1.0 / fps)
			var page := await painted_frame()
			check(page.save_png(capture_dir.path_join("film-%03d-%s.png" % [frame_number, action])) == OK, "记录动作中的实机帧")
			frame_number += 1

func hoof_pigment(frame: Image, at: Vector2) -> bool:
	var sole := Vector2i(at.round())
	for y in range(sole.y - 6, sole.y + 1):
		for x in range(sole.x - 4, sole.x + 5):
			var pigment := frame.get_pixel(x, y)
			if pigment.a > .8 and pigment.r > .30 and pigment.g < pigment.r * .8 and pigment.b < pigment.r * .60:
				return true
	return false

func disable_automatic_tick() -> void:
	actor.set_process(false)

func stamp_face_draw() -> void:
	# Draw the sample number in the same CanvasItem command list as the eyes.
	# Four extra viewport columns keep it outside the delivered picture.
	expression.draw_set_transform_matrix(expression.global_transform.affine_inverse())
	for bit in STAMP_BITS:
		var ink := Color.WHITE if (sample_number & (1 << bit)) != 0 else Color.BLACK
		expression.draw_rect(Rect2(FRAME_SIZE.x, bit * 3, 4, 3), ink)
	expression.draw_set_transform_matrix(Transform2D.IDENTITY)

func painted_frame() -> Image:
	actor.set_process(false)
	var sampled_clock := float(actor.get("clock"))
	var mode := str(expression.get("mode"))
	var features := Vector2(expression.get("strength"), expression.get("blink"))
	sample_number += 1
	expression.queue_redraw()
	await expression.draw
	# The draw signal precedes _draw(). Wait until its commands have been
	# submitted before forcing this specific viewport update and reading it back.
	await process_frame
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false)
	var page := stage.get_texture().get_image()
	var number_on_paper := 0
	for bit in STAMP_BITS:
		var ink := page.get_pixel(FRAME_SIZE.x + 1, bit * 3 + 1)
		check(ink.a > .99, "实绘帧含有本次眼眉绘制标记")
		if ink.r > .5:
			number_on_paper |= 1 << bit
	check(number_on_paper == sample_number, "实绘读回对应本次画面 %d / %d" % [number_on_paper, sample_number])
	check(is_equal_approx(float(actor.get("clock")), sampled_clock), "实绘读回之前角色应停在取样时刻")
	check(str(expression.get("mode")) == mode and features == Vector2(expression.get("strength"), expression.get("blink")), "实绘读回保留指定的表情 " + mode)
	return page.get_region(Rect2i(Vector2i.ZERO, FRAME_SIZE))

func face_ink(frame: Image) -> PackedByteArray:
	var output := PackedByteArray()
	var face_node := actor.find_child("Expression", true, false) as Node2D
	if face_node == null:
		check(false, "脸部绘制应独立绑定头骨")
		return output
	for y in range(-15, 13):
		for x in range(-24, 24):
			var at := Vector2i(face_node.to_global(Vector2(x, y)).round())
			var pigment := frame.get_pixelv(at)
			output.append(1 if pigment.a > 0.7 and pigment.r < 0.49 and pigment.g < 0.36 else 0)
	return output

func count_difference(left: PackedByteArray, right: PackedByteArray) -> int:
	var result := 0
	for i in mini(left.size(), right.size()):
		if left[i] != right[i]:
			result += 1
	return result
