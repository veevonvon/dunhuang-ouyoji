extends CharacterBody2D

@export var speed := 250.0
var walk_area := Rect2(110, 420, 1700, 215)
var direction := Vector2.ZERO
var target := Vector2.ZERO
var following_target := false
var facing := 1.0
var walk_amount := 0.0
var reduced_motion := false:
	set(value):
		reduced_motion = value
		if is_instance_valid(rig): rig.set_reduced_motion(value)
@onready var rig := $Rig

func _ready() -> void:
	target = position
	rig.set_reduced_motion(reduced_motion)
	update_depth()

func _physics_process(delta: float) -> void:
	var move := direction
	if move.is_zero_approx() and following_target:
		if position.distance_to(target) > 8: move = position.direction_to(target)
		else: following_target = false
	if not move.is_zero_approx():
		velocity = move.limit_length() * speed
		if absf(move.x) > .03: facing = signf(move.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 7 * delta)
	var start := position
	move_and_slide()
	position = position.clamp(walk_area.position, walk_area.end)
	var distance := position.distance_to(start)
	walk_amount = clampf(distance / maxf(.001,speed * delta),0,1)
	rig.set_locomotion(walk_amount, facing)
	update_depth()

func update_depth() -> void:
	rig.scale = Vector2.ONE * remap(position.y, walk_area.position.y, walk_area.end.y, .78, 1.12)

func walk_to(point: Vector2) -> void:
	target = point.clamp(walk_area.position, walk_area.end)
	following_target = true

func cancel_movement() -> void:
	direction = Vector2.ZERO
	velocity = Vector2.ZERO
	following_target = false
	walk_amount = 0
	rig.set_locomotion(0, facing)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, .23))
	draw_circle(Vector2.ZERO, 36, Color(.12, .15, .13, .13), true, -1, true)
	draw_circle(Vector2(0,1), 23, Color(.12, .15, .13, .16), true, -1, true)
