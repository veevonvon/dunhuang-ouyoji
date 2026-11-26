extends SceneTree

var errors: Array[String] = []
var contacts: Array[int] = []
var cues: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		printerr(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://scripts/characters/travel_actor.gd"
	if not ResourceLoader.exists(path):
		printerr("missing shared skeletal actor")
		quit(1)
		return
	var actor: Node2D = load(path).new()
	root.add_child(actor)
	actor.set_process(false)
	check(actor.get_node("Facing/Skeleton2D") is Skeleton2D, "native skeleton")
	var tip: Bone2D = actor.joint(actor.skeleton, "Tip", Vector2(18, -40), 12)
	actor.register_anchor("tip", tip)
	check(tip.rest.origin.is_equal_approx(tip.position) and actor.anchor_point("tip").is_equal_approx(Vector2(18,-40)), "rest and moving anchor")
	actor.set_locomotion(1, -1)
	actor.footfall.connect(func(side: int): contacts.append(side))
	actor.action_cue.connect(func(id: String): cues.append(id))
	for i in 90: actor.advance(1.0/60)
	check(contacts.size() >= 3 and contacts[0] != contacts[1] and contacts[1] != contacts[2], "alternating heel strikes")
	check(actor.anchor_point("tip").x < 0, "mirroring carries the anchors")
	actor.set_locomotion(0, 0)
	var count := contacts.size()
	for i in 40: actor.advance(1.0/60)
	check(contacts.size() == count and is_zero_approx(actor.move_weight), "stopping parks both feet")
	actor.perform("draw", true)
	for i in 200: actor.advance(1.0/60)
	check(actor.acting == "draw" and actor.action_weight > .9 and cues == ["draw"], "held readable key pose with one cue")
	actor.perform("surprise")
	for i in 200: actor.advance(1.0/60)
	check(actor.acting == "" and cues == ["draw", "surprise"], "one-shot returns to idle")
	actor.perform("look")
	actor.set_active(false)
	var stamp: float = actor.clock
	for i in 100: actor.advance(.03)
	check(is_equal_approx(stamp,actor.clock) and cues.size() == 2, "paused performance cannot emit")
	actor.set_active(true)
	actor.set_reduced_motion(true)
	actor.perform("greet", true)
	actor.set_locomotion(1, 1)
	check(not actor.is_processing(), "a reduced held portrait sleeps between inputs")
	var pose: float = actor.action_progress
	for i in 120: actor.advance(1.0/60)
	check(is_equal_approx(actor.action_progress,pose) and actor.blink_amount == 0 and contacts.size() == count, "reduced motion keeps a fixed expressive pose")
	actor.perform("surprise")
	check(actor.is_processing(), "reduced one-shot still has a finite duration")
	for i in 140: actor.advance(1.0 / 60)
	check(actor.acting.is_empty() and not actor.is_processing(), "reduced one-shot settles to rest")
	actor.set_reduced_motion(false)
	actor.perform("look")
	actor.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	actor.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	actor.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not actor.is_processing(), "focus-in cannot wake a background actor")
	actor.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(actor.is_processing() and actor.acting.is_empty(), "resume never replays a lost action")
	actor.hide()
	stamp = actor.clock
	actor.advance(.1)
	check(is_equal_approx(stamp,actor.clock), "hidden actors sleep")
	actor.free()
	print("表演时钟与落脚测试，失败 ", errors.size())
	quit(0 if errors.is_empty() else 1)
