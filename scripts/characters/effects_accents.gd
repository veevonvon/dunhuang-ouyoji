extends RefCounted

const INK := Color("203b40")
const DRY_INK := Color("617f78")
const JADE := Color("4e8c7d")
const PALE_JADE := Color("bfe0bb")
const VERMILION := Color("ad5542")
const COPPER := Color("9a603e")
const GOLD := Color("ebba68")
const LIGHT := Color("ffefb6")

const GLINT := [Vector2(0.02,-1), Vector2(0.18,-0.24), Vector2(0.85,-0.05), Vector2(0.17,0.16), Vector2(-0.03,1), Vector2(-0.20,0.20), Vector2(-0.78,0.06), Vector2(-0.17,-0.17)]
const GLINT_FACE := [Vector2(0.02,-0.88), Vector2(0.13,-0.14), Vector2(0.70,-0.04), Vector2(0,0.03), Vector2(-0.58,0.04), Vector2(-0.11,-0.11)]
const PETAL_GILT := [Vector2(0,-0.13),Vector2(0,-0.51),Vector2(0.12,-0.07),Vector2(0.45,-0.26),Vector2(0.12,0.07),Vector2(0.45,0.26),Vector2(0,0.13),Vector2(0,0.51),Vector2(-0.12,0.07),Vector2(-0.45,0.26),Vector2(-0.12,-0.07),Vector2(-0.45,-0.26)]
const SPRAY := [Vector2(-48,-40), Vector2(-19,-64), Vector2(12,-72), Vector2(50,-52), Vector2(65,-24)]

static var wave_outer := _stroke([Vector2(3,-5),Vector2(15,-6),Vector2(30,-17),Vector2(27,-35)], 4.0)
static var wave_rim := _stroke([Vector2(8,-7),Vector2(19,-11),Vector2(28,-20),Vector2(26.8,-29)], 1.25)
static var wave_inner := _stroke([Vector2(8,-1),Vector2(24,-2),Vector2(37,-14),Vector2(34,-26)], 2.6)
static var wave_glint := _stroke([Vector2(31,-9),Vector2(35,-11),Vector2(38,-17),Vector2(38,-20)], 1.2)
static var gaze_high := _stroke([Vector2(10,-8),Vector2(17,-8.5),Vector2(24,-10.2),Vector2(31,-10.7)], 2.1)
static var gaze_low := _stroke([Vector2(14,-0.5),Vector2(20,-2.7),Vector2(27,-5.6),Vector2(32,-7.5)], 1.55)
static var thought := _stroke([Vector2(7,-5),Vector2(12,-6),Vector2(13,-15),Vector2(18,-20),Vector2(23,-27),Vector2(38,-27),Vector2(38,-19),Vector2(38.5,-13),Vector2(30,-12),Vector2(28.5,-16.5),Vector2(27,-20),Vector2(31,-21),Vector2(33,-19.3)], 3.2)
static var thought_rim := _stroke([Vector2(15,-16.5),Vector2(20,-25),Vector2(33,-27.4),Vector2(36.7,-23.4)], 1.15)
static var rest_low := _stroke([Vector2(6,1.5),Vector2(13,1),Vector2(18,5),Vector2(25,4),Vector2(34,3.2),Vector2(37,-3),Vector2(34,-6.1)], 2.5)
static var rest_high := _stroke([Vector2(12,-2.5),Vector2(18,-3),Vector2(21,0),Vector2(25.5,-0.7),Vector2(30,-1),Vector2(32,-5),Vector2(29,-7.3)], 1.6)
static var flower := _rosette()
static var cloud := _cubic([Vector2(-7.6,2.5),Vector2(-4,1.8),Vector2(-5.5,-2.8),Vector2(-2,-3.5),Vector2(-0.6,-3.8),Vector2(0,-3.3),Vector2(0.6,-2.9),Vector2(0.8,-6.6),Vector2(7.2,-7.0),Vector2(7.4,-3.0),Vector2(10.1,-3.7),Vector2(12,-0.5),Vector2(9.5,1.3),Vector2(6.3,3.9),Vector2(3.0,1.5),Vector2(0.1,2.7),Vector2(-2.3,3.9),Vector2(-5.5,4.3),Vector2(-7.5,2.6)], 5)
static var cloud_fold := _stroke([Vector2(-4.4,1.4),Vector2(-1.7,1.0),Vector2(-1.3,-1.8),Vector2(1.5,-1.8),Vector2(3,-1.8),Vector2(4.9,-0.8),Vector2(6.6,-1.6)], 1.1)
static var ink_path := _cubic([Vector2.ZERO, Vector2(4,14), Vector2(14,18), Vector2(29,6), Vector2(42,-4.4),Vector2(57,-18),Vector2(70,-10)], 16)

static func paint(canvas: CanvasItem, at: Vector2, heading: float, action: String, t: float) -> void:
	var base := Transform2D(0, Vector2(heading, 1), 0, at)
	var alpha := 1.0 - smoothstep(0.59, 1.0, t)
	canvas.draw_set_transform_matrix(base)
	match action:
		"greet":
			var sweep := smoothstep(0.0, 0.62, t)
			canvas.draw_set_transform_matrix(base * Transform2D(lerpf(0.13, -0.06, sweep), Vector2(2.0 * sweep, -1.8 * sweep)))
			canvas.draw_colored_polygon(wave_outer, Color(VERMILION, alpha))
			canvas.draw_colored_polygon(wave_rim, Color(LIGHT, alpha))
			canvas.draw_colored_polygon(wave_inner, Color(GOLD, alpha))
			canvas.draw_colored_polygon(wave_glint, Color(GOLD, alpha * 0.75))
		"look":
			canvas.draw_colored_polygon(gaze_high, Color(COPPER, alpha * 0.92))
			canvas.draw_colored_polygon(gaze_low, Color(GOLD, alpha))
			var focus := Vector2(41 + 3.0 * smoothstep(0.0, 0.45, t), -12)
			_glint(canvas, base, focus, 5.8, -0.1, alpha)
			_glint(canvas, base, focus + Vector2(8, -6), 2.6, 0.2, alpha * 0.84)
		"think":
			canvas.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0, -3.0 * smoothstep(0.0, 0.58, t))))
			canvas.draw_colored_polygon(thought, Color(JADE, alpha))
			canvas.draw_colored_polygon(thought_rim, Color(LIGHT, alpha))
			canvas.draw_circle(Vector2(9, -6.2), 1.55, Color(GOLD, alpha), true, -1.0, true)
			canvas.draw_circle(Vector2(4.0, -1.6), 1.15, Color(COPPER, alpha), true, -1.0, true)
		"listen":
			_bronze_rings(canvas, base, t, alpha)
		"surprise":
			var rise := smoothstep(0.0, 0.5, t)
			var center := Vector2(19 + 2.5 * rise, -18 - 4 * rise)
			_glint(canvas, base, center, 8.0 + 2.2 * rise, 0.18, alpha)
			_glint(canvas, base, center + Vector2(15,-7), 3.5, -0.16, alpha)
			canvas.draw_set_transform_matrix(base)
			canvas.draw_line(center + Vector2(-5,-10), center + Vector2(-7,-14), Color(COPPER, alpha), 1.5, true)
			canvas.draw_line(center + Vector2(8,4), center + Vector2(12,7), Color(GOLD, alpha), 1.6, true)
			canvas.draw_circle(center + Vector2(-10,5), 1.3, Color(LIGHT, alpha), true, -1.0, true)
		"celebrate":
			_gilded_spray(canvas, base, t, alpha)
		"draw":
			_ink_stroke(canvas, t, alpha)
		"rest":
			var drift := smoothstep(0.0, 0.72, t)
			canvas.draw_set_transform_matrix(base * Transform2D(0, Vector2(4.0 * drift, -2.0 * drift)))
			canvas.draw_colored_polygon(rest_low, Color(JADE, alpha * 0.96))
			canvas.draw_colored_polygon(rest_high, Color(PALE_JADE, alpha))
			canvas.draw_circle(Vector2(37.5, -7.5), 1.15, Color(GOLD, alpha * 0.8), true, -1, true)

static func _bronze_rings(canvas: CanvasItem, base: Transform2D, t: float, alpha: float) -> void:
	canvas.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(1, 0.82), 0.0, Vector2(0, 1.0)))
	for i in 3:
		var spread := clampf((t - 0.09 * i) / 0.82, 0.0, 1.0)
		if spread == 0.0 and i > 0:
			continue
		var radius := 8.0 + 6.2 * i + 13.0 * sin(spread * PI * 0.5)
		var shade := alpha * (1.0 - 0.14 * i)
		# 断开的弧把铃和挂绳留在中央，外圈在右肩逐渐变细。
		for side in 2:
			if side == 1 and i == 2:
				continue
			var angle := 0.01 if side == 0 else PI + 0.12
			var arc := 0.87 - 0.12 * i
			canvas.draw_arc(Vector2.ZERO, radius, angle - arc, angle + arc, 14, Color(COPPER, shade * 0.94), 2.75 - 0.3 * i, true)
			canvas.draw_arc(Vector2.ZERO, radius - 0.6, angle - arc + 0.08, angle + arc - 0.12, 14, Color(GOLD if i % 2 else LIGHT, shade), 1.35, true)

static func _gilded_spray(canvas: CanvasItem, base: Transform2D, t: float, alpha: float) -> void:
	for i in SPRAY.size():
		var elapsed := clampf((t - 0.023 * (i % 3)) / 0.96, 0.0, 1.0)
		var reach := 0.16 + 0.84 * (1.0 - pow(1.0 - elapsed, 2.4))
		var travel: Vector2 = SPRAY[i] * reach + Vector2(sin(elapsed * PI * 1.5 + i) * 2.4, 40.0 * elapsed * elapsed)
		var angle := (i - 2) * 0.26 + elapsed * (0.8 if i % 2 == 0 else -0.9)
		var particle := base * Transform2D(angle, travel)
		match i:
			0, 3:
				var size := 6.7 if i == 0 else 8.1
				canvas.draw_set_transform_matrix(particle.scaled_local(Vector2.ONE * size))
				canvas.draw_colored_polygon(flower, Color(COPPER, alpha))
				canvas.draw_set_transform_matrix(particle.scaled_local(Vector2.ONE * size * 0.82))
				canvas.draw_colored_polygon(flower, Color(GOLD, alpha))
				canvas.draw_multiline(PETAL_GILT, Color(LIGHT, alpha), 0.16, true)
				canvas.draw_circle(Vector2.ZERO, 0.20, Color(VERMILION, alpha), true, -1.0, true)
			1, 4:
				var size := 0.90 if i == 1 else 0.65
				canvas.draw_set_transform_matrix(particle.scaled_local(Vector2.ONE * size))
				canvas.draw_colored_polygon(cloud, Color(COPPER, alpha))
				canvas.draw_set_transform_matrix(particle.scaled_local(Vector2.ONE * size * 0.88))
				canvas.draw_colored_polygon(cloud, Color(GOLD, alpha))
				canvas.draw_colored_polygon(cloud_fold, Color(LIGHT, alpha))
			2:
				_glint(canvas, particle, Vector2.ZERO, 4.8, 0.35, alpha)

static func _glint(canvas: CanvasItem, base: Transform2D, at: Vector2, radius: float, angle: float, alpha: float) -> void:
	var transform := base * Transform2D(angle, Vector2.ONE * radius, 0, at)
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_colored_polygon(GLINT, Color(COPPER, alpha))
	canvas.draw_set_transform_matrix(transform.scaled_local(Vector2.ONE * 0.79))
	canvas.draw_colored_polygon(GLINT, Color(GOLD, alpha))
	canvas.draw_colored_polygon(GLINT_FACE, Color(LIGHT, alpha))

static func _ink_stroke(canvas: CanvasItem, t: float, alpha: float) -> void:
	var written := lerpf(0.035, 1.0, smoothstep(0.0, 0.61, t))
	_ink_band(canvas, 0.0, written, 0, alpha)
	_ink_band(canvas, 0.0, written, 1, alpha)
	if written > 0.34:
		_ink_band(canvas, 0.32, minf(0.85, written), 2, alpha * 0.78)

static func _ink_band(canvas: CanvasItem, start: float, finish: float, band: int, fade: float) -> void:
	var edge := PackedVector2Array()
	var opposite := PackedVector2Array()
	var pigment := PackedColorArray()
	var reverse_pigment := PackedColorArray()
	var last := ink_path.size() - 1
	var pieces := maxi(1, ceili((finish - start) * last))
	for i in range(pieces + 1):
		var u := lerpf(start, finish, float(i) / pieces)
		var index := mini(last - 1, floori(u * last))
		var point := ink_path[index].lerp(ink_path[index + 1], u * last - index)
		var tangent := ink_path[mini(index + 2, last)] - ink_path[maxi(index - 1, 0)]
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var pressure := 0.42 + 5.5 * (0.18 + 0.82 * smoothstep(0.0, 0.13, u)) * (1.0 - smoothstep(0.41, 1.0, u))
		# 笔毫分叉后留下透明的飞白，能透出当下的画卷和地色。
		var opening := smoothstep(0.10, 0.39, u)
		var inner := -1.0
		var outer := lerpf(0.72, -0.09, opening)
		var color := INK.lerp(DRY_INK, 0.68 * smoothstep(0.3, 1.0, u))
		if band == 1:
			inner = lerpf(0.70, 0.36, opening)
			outer = 1.04
			color = INK.lerp(DRY_INK, 0.24 + 0.55 * u)
		elif band == 2:
			inner = 1.33
			outer = 1.37 + 0.19 * sin(PI * (u - 0.32) / 0.53)
			color = DRY_INK
		edge.append(point + normal * pressure * inner)
		opposite.append(point + normal * pressure * outer)
		pigment.append(Color(color, fade))
		reverse_pigment.append(Color(color.lightened(0.08), fade * 0.94))
	opposite.reverse()
	reverse_pigment.reverse()
	edge.append_array(opposite)
	pigment.append_array(reverse_pigment)
	canvas.draw_polygon(edge, pigment)

static func _cubic(controls: Array, samples := 10) -> PackedVector2Array:
	var points := PackedVector2Array([controls[0]])
	for segment in range(0, controls.size() - 1, 3):
		var origin: Vector2 = controls[segment]
		for i in range(1, samples + 1):
			points.append(origin.bezier_interpolate(controls[segment + 1], controls[segment + 2], controls[segment + 3], float(i) / samples))
	return points

static func _stroke(controls: Array, width: float) -> PackedVector2Array:
	var points := _cubic(controls)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var last := points.size() - 1
	for i in points.size():
		var direction := points[mini(i + 1, last)] - points[maxi(0, i - 1)]
		var normal := Vector2(-direction.y, direction.x).normalized()
		var radius := width * (0.04 + 0.46 * pow(maxf(0.0, sin(PI * i / last)), 0.58))
		left.append(points[i] + normal * radius)
		right.append(points[i] - normal * radius)
	right.reverse()
	left.append_array(right)
	return left

static func _rosette() -> PackedVector2Array:
	var border := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		var radius := 0.82 + 0.18 * cos(6.0 * (angle + PI / 2.0))
		border.append(Vector2.from_angle(angle) * radius)
	return border
