extends Control

var picture: Texture2D
var shade := 0.3
var motion := true
var elapsed := 0.0
var shading: GradientTexture2D

func follow_motion_setting() -> void:
	motion = not Journey.progress.settings.reducedMotion
	set_process(motion)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	shading = GradientTexture2D.new()
	shading.width = 4
	shading.height = 256
	shading.fill_from = Vector2.ZERO
	shading.fill_to = Vector2(0, 1)
	shading.gradient = Gradient.new()
	shading.gradient.offsets = PackedFloat32Array([0, .4, .65, 1])
	shading.gradient.colors = PackedColorArray([Color(.04, .12, .15, shade), Color(.04, .12, .15, shade * .5), Color(.04, .12, .15, shade * .5), Color(.04, .12, .15, shade * 1.3)])

func _process(delta: float) -> void:
	if motion:
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	if picture:
		var ratio := maxf(size.x / picture.get_width(), size.y / picture.get_height())
		var source_size := size / ratio
		draw_texture_rect_region(picture, Rect2(Vector2.ZERO, size), Rect2((picture.get_size() - source_size) / 2, source_size))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("173d43"))
	if shading: draw_texture_rect(shading, Rect2(Vector2.ZERO, size), false)
	for i in range(32):
		var x := fposmod(i * 137.7 + sin(elapsed * .13 + i) * 16, size.x)
		var y := fposmod(i * 83.3 - elapsed * 7, size.y)
		draw_circle(Vector2(x, y), 1.3 + i % 3, Color(1, .84, .5, .12 + .15 * sin(i + elapsed * .5)))
