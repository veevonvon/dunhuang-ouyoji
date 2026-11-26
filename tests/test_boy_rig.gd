extends SceneTree

const ACTOR_PATH := "res://scripts/characters/boy_actor.gd"
const ACTIONS := ["greet", "look", "think", "listen", "surprise", "celebrate", "draw", "rest"]

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func sample(actor: Node, action: String, progress: float, weight: float) -> void:
	actor.acting = action
	actor.action_progress = progress
	actor.action_weight = weight
	actor.pose_character()


func run() -> void:
	check(ResourceLoader.exists(ACTOR_PATH), "the boy has a native skeletal actor")
	if failures == 0:
		var source := load(ACTOR_PATH) as GDScript
		check(source != null and source.can_instantiate(), "the boy's rig can be instantiated")
		if failures == 0:
			var actor: Node = source.new()
			root.add_child(actor)
			await process_frame
			actor.set_process(false)
			verify_rig(actor)
			actor.queue_free()
			await process_frame
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--boy-capture="):
					await capture_paintings(source, argument.trim_prefix("--boy-capture="))
	print("BOY_RIG_CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)


func verify_rig(actor: Node) -> void:
	var skeleton := actor.get_node_or_null("Facing/Skeleton2D") as Skeleton2D
	check(skeleton != null and skeleton.get_bone_count() >= 18, "both arms, legs, head, scarf and bag have separate native bones")
	if skeleton == null:
		return
	var cloth_count := 0
	for child: Node in skeleton.get_children():
		if child is Polygon2D and child.texture != null and child.get_bone_count() >= 3:
			cloth_count += 1
	check(cloth_count == 4, "both sleeves and both trouser legs use continuous painted native skin weights")
	var left_trouser := skeleton.get_node_or_null("LeftHipCloth") as Polygon2D
	var right_trouser := skeleton.get_node_or_null("RightHipCloth") as Polygon2D
	if left_trouser != null and right_trouser != null:
		check(left_trouser.texture != right_trouser.texture, "the two visible trouser legs carry different embroidery and creases")
	for bone_name in ["LeftKnee","RightKnee"]:
		var knee: Bone2D = actor.find_child(bone_name, true, false)
		check(knee != null and absf(knee.rotation) < deg_to_rad(22), bone_name + " supports an upright standing child")
	var portrait := actor.find_child("Expression", true, false) as Sprite2D
	var lids := actor.find_child("PaintedEyelids", true, false) as Sprite2D
	check(portrait != null and lids != null, "the original painted face and eyelids are mounted together")
	var face: Vector2 = actor.anchor_point("face")
	var hand: Vector2 = actor.anchor_point("hand")
	check(face.y < -190 and face.y > -247, "the face anchor lies inside the six-year-old's head")
	check(hand.y > face.y + 35, "the relaxed hand hangs below the face")
	for side in ["left_foot", "right_foot"]:
		var point: Vector2 = actor.anchor_point(side)
		check(absf(point.y) < 5, side + " sole meets the ground at rest")
	check(actor.anchor_point("bell").distance_to(face) > 25, "the satchel attachment is separate from the head")

	var signatures: Array[Vector2] = []
	var visible_faces: Array[int] = []
	for action: String in ACTIONS:
		sample(actor, action, 0.52, 1.0)
		if portrait != null:
			check(not visible_faces.has(portrait.frame), action + " shows its own painted eyes, brows and mouth")
			visible_faces.append(portrait.frame)
		var hand_at_peak: Vector2 = actor.anchor_point("hand")
		for previous: Vector2 in signatures:
			check(hand_at_peak.distance_to(previous) > 1.0, action + " has a distinct hand gesture")
		signatures.append(hand_at_peak)
		if action == "greet" or action == "look":
			check(hand_at_peak.y < face.y + 23, action + " raises the near hand to the face")
		if action == "greet":
			check(actor.anchor_point("face").x - hand_at_peak.x > 77, "the open waving hand clears the hair silhouette")
		if action == "look":
			var wrist: Node2D = actor.find_child("LeftWrist", true, false)
			var wrist_in_actor: Vector2 = actor.to_local(wrist.global_position)
			var eyes: Vector2 = actor.anchor_point("face")
			check(wrist_in_actor.x < eyes.x - 20 and wrist_in_actor.y < eyes.y - 4, "the scouting cuff stays outside the temple and above both eyes")
		if action == "draw":
			check(hand_at_peak.x > hand.x + 23, "the drawing hand reaches forward")
		sample(actor, action, 0.97, 0.08)
		check(actor.anchor_point("hand").distance_to(hand) < 15, action + " releases the hand at the end")
	sample(actor, "", 0.0, 0.0)
	actor.move_weight = 1.0
	actor.gait = 0.0
	actor.pose_character()
	var left: Vector2 = actor.anchor_point("left_foot")
	var right: Vector2 = actor.anchor_point("right_foot")
	check(left.x - right.x > 44, "at left heel strike the two shoes clearly straddle the body's center")
	var left_boot: Bone2D = actor.find_child("LeftAnkle", true, false)
	check(left_boot.global_rotation < deg_to_rad(-5), "the front shoe arrives heel first with its embroidered toe lifted")
	actor.gait += PI
	actor.pose_character()
	check(left.distance_to(actor.anchor_point("left_foot")) > 12, "the left foot takes a real stride")
	check(right.distance_to(actor.anchor_point("right_foot")) > 12, "the right foot takes a real stride")
	check(actor.anchor_point("right_foot").x - actor.anchor_point("left_foot").x > 44, "the right heel strike reverses the wide silhouette")
	actor.gait = PI / 2.0
	actor.pose_character()
	check(absf(actor.anchor_point("left_foot").y) < 2.0 and actor.anchor_point("right_foot").y < -13.0, "the left stance supports a visible lifted right knee and shoe")
	actor.set_locomotion(1.0,-1.0)
	check(actor.anchor_point("left_foot").x > 0, "facing left mirrors the attached shoe")
	actor.set_locomotion(0.0,1.0)
	actor.move_weight = 0.0
	if portrait != null and lids != null:
		sample(actor, "look", .54, 1.0)
		var look_face := portrait.frame
		actor.blink_amount = .63
		actor.pose_character()
		var half_shut := lids.frame
		actor.blink_amount = 1
		actor.pose_character()
		check(lids.visible and lids.frame != half_shut and portrait.frame == look_face, "blinking closes the eyes without replacing the scouting mouth or brows")
	actor.set_reduced_motion(true)
	actor.perform("celebrate", true)
	check(actor.acting == "celebrate" and actor.action_weight == 1.0, "the public reduced-motion gesture reaches its held celebration")
	check(absf(actor.anchor_point("left_foot").y) < 2 and absf(actor.anchor_point("right_foot").y) < 2, "reduced celebration keeps both shoes on the ground")
	actor.perform("listen", true)
	actor.pose_character()
	var still: Vector2 = actor.anchor_point("face")
	actor.clock += 1.5
	actor.pose_character()
	check(still.is_equal_approx(actor.anchor_point("face")), "reduced motion freezes residual breathing and head movement")


func capture_paintings(source: GDScript, folder: String) -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "painted previews use the Compatibility renderer with a display")
		return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	var canvas := SubViewport.new()
	canvas.size = Vector2i(312,440)
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var actor: Node = source.new()
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	canvas.add_child(actor)
	actor.set_process(false)
	actor.position = Vector2(155,415)
	actor.scale = Vector2(1.55,1.55)
	var neutral := await take_frame(canvas, folder.path_join("neutral.png"), sample.bind(actor,"",0,0))
	var key_signatures: Array[int] = []
	for action: String in ACTIONS:
		actor.set_reduced_motion(true)
		sample(actor,action,.54,1.0)
		if action == "greet":
			# A newly opened desktop capture window may deliver focus after the
			# first pose was requested. Exercise that real first-frame ordering.
			actor.call_deferred("notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var contact: Vector2i = actor.to_global(actor.anchor_point("hand"))
		var key := await take_frame(canvas, folder.path_join("key-" + action + ".png"), sample.bind(actor,action,.54,1.0))
		var pixels := key.get_data()
		check(pixels != neutral.get_data(), action + " full-body key differs from neutral pixels")
		var signature := hash(pixels)
		check(not key_signatures.has(signature), action + " full-body key is distinct from previous actions")
		key_signatures.append(signature)
		var palm := key.get_region(Rect2i(contact - Vector2i(4,4), Vector2i(9,9)))
		check(palm.get_used_rect().get_area() > 4, action + " actual painted hand meets the selected pose's contact")
		actor.set_reduced_motion(false)
		for i in 15:
			var p := i / 14.0
			actor.clock = p * 1.8
			var level := smoothstep(0,.2,p) * (1.0 - smoothstep(.76,1,p))
			await take_frame(canvas, folder.path_join("frames/%s-%02d.png" % [action,i]), sample.bind(actor,action,p,level))
	sample(actor, "", 0, 0)
	actor.move_weight = 1.0
	for heading in [1,-1]:
		actor.set_locomotion(1, heading)
		for i in 12:
			var step_path := folder.path_join("frames/walk-%s-%02d.png" % ["right" if heading > 0 else "left",i])
			await take_frame(canvas, step_path, sample_step.bind(actor,i))
	actor.set_locomotion(0, 1)
	actor.move_weight = 0
	actor.gait = 0
	canvas.size = Vector2i(316,300)
	actor.position = Vector2(164,790)
	actor.scale = Vector2(3.05,3.05)
	actor.set_reduced_motion(true)
	var portraits: Array[int] = []
	for action: String in [""] + ACTIONS:
		var pose := sample.bind(actor,action,.54,0.0 if action.is_empty() else 1.0)
		var portrait := await take_frame(canvas, folder.path_join("face-" + ("neutral" if action.is_empty() else action) + ".png"), pose)
		var signature := hash(portrait.get_data())
		check(not portraits.has(signature), "camera records a distinct actually rendered portrait for " + action)
		portraits.append(signature)
	actor.set_reduced_motion(false)
	var open_eyes: Image
	for amount in [0.0, .4, .67, 1.0]:
		var painted := await take_frame(canvas, folder.path_join("blink-%03d.png" % roundi(amount * 100.0)), sample_blink.bind(actor,amount))
		if amount == 0.0:
			open_eyes = painted
		if amount == 1.0 and open_eyes != null:
			var eyes: Vector2i = actor.to_global(actor.anchor_point("face"))
			var neck := actor.find_child("Neck", true, false) as Bone2D
			var lips: Vector2i = neck.to_global(Vector2(15,-14))
			var eyes_area := Rect2i(eyes - Vector2i(38,20),Vector2i(76,40))
			var lips_area := Rect2i(lips - Vector2i(8,5),Vector2i(16,10))
			check(open_eyes.get_region(eyes_area).get_data() != painted.get_region(eyes_area).get_data(), "the rendered scout actually closes his eyes")
			check(open_eyes.get_region(lips_area).get_data() == painted.get_region(lips_area).get_data(), "the painted scouting mouth is preserved throughout the blink")
	canvas.queue_free()
	await process_frame
	print("BOY_NATIVE_PREVIEW: ", folder)


func sample_step(actor: Node, frame: int) -> void:
	actor.move_weight = 1
	actor.gait = TAU * frame / 12.0
	actor.clock = frame / 12.0
	actor.pose_character()


func sample_blink(actor: Node, amount: float) -> void:
	actor.blink_amount = amount
	sample(actor,"look",.54,1)


func take_frame(canvas: SubViewport, path: String, apply_pose: Callable) -> Image:
	# Apply after the frame has dispatched window events and read only after
	# the renderer has updated this viewport, including the skeleton's skin.
	await process_frame
	apply_pose.call()
	await RenderingServer.frame_post_draw
	var painted := canvas.get_texture().get_image()
	check(painted != null and painted.get_used_rect().size.x > 64 and painted.save_png(path) == OK, "native painted frame is written " + path.get_file())
	return painted
