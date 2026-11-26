extends Control

const Boy = preload("res://scripts/characters/boy_actor.gd")
const Deer = preload("res://scripts/characters/deer_actor.gd")
var actor: Node2D
var action := "greet"
var animal := false
var _face := Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(158,105)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	actor = Deer.new() if animal else Boy.new()
	add_child(actor)
	_face = actor.anchor_point("face")
	actor.set_reduced_motion(Journey.progress.settings.reducedMotion)
	actor.perform(action,true)
	resized.connect(_fit)
	Journey.changed.connect(_motion)
	_fit()

func _fit() -> void:
	var zoom := minf(size.x / (121.0 if animal else 120.0),size.y / (134.0 if animal else 137.0))
	zoom = clampf(zoom,.75,1.44)
	actor.scale = Vector2.ONE * zoom
	actor.position = Vector2(size.x * (.60 if action == "greet" and not animal else .50),size.y * (.48 if animal else .46)) - _face * zoom
	queue_redraw()

func _motion() -> void:
	actor.set_reduced_motion(Journey.progress.settings.reducedMotion)

func _draw() -> void:
	var box := GameTheme.style(Color("d9ad79"),14)
	box.shadow_size = 0
	box.border_color = Color("aa784a")
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	for i in range(3):
		draw_arc(Vector2(size.x*.49,size.y*.48),size.x*(.33+i*.08),0,TAU,52,Color("fff0b269"),1.1,true)
