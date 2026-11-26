extends RefCounted

# 底色、右下沿的翻土、压痕里的暗纹随地面换色。
const EARTH := {
	"sand": [Color("965d43"), Color("f6cc82"), Color("704a3d")],
	"stone": [Color("52676a"), Color("d8cbb3"), Color("384e54")],
	"grass": [Color("426350"), Color("bec789"), Color("304e46")],
}

const HEEL := [
	Vector2(-13, -1.8), Vector2(-12.1, -3.9), Vector2(-9.7, -5), Vector2(-7.2, -4.8),
	Vector2(-5.6, -3), Vector2(-5.4, 1.7), Vector2(-6.5, 3.8), Vector2(-9.6, 4.3),
	Vector2(-12.1, 3.3), Vector2(-13.2, 1.5),
]
const SOLE := [
	Vector2(-3.1, -1.6), Vector2(-1.4, -2.9), Vector2(1.2, -5.2), Vector2(5.1, -6.6),
	Vector2(9.0, -6.8), Vector2(12.8, -5.4), Vector2(15.0, -2.7), Vector2(15.5, 0.4),
	Vector2(13.5, 3.5), Vector2(10.1, 5.1), Vector2(6.1, 5.6), Vector2(2.5, 5.0),
	Vector2(0.1, 3.3), Vector2(-2.8, 2.6),
]
const SOLE_RIM := [Vector2(-2.4, 2.8), Vector2(2.5, 5.0), Vector2(6.1, 5.6), Vector2(10.1, 5.1), Vector2(13.3, 3.6)]
const HEEL_RIM := [Vector2(-12.6, 2.6), Vector2(-9.5, 4.2), Vector2(-6.7, 3.8)]
const SOLE_STITCH := [
	Vector2(-10.8, -1.8), Vector2(-8.7, -0.7), Vector2(-10.4, 1.0), Vector2(-8.5, 1.9),
	Vector2(1.0, -1.1), Vector2(3.8, -2.9), Vector2(2.2, 1.0), Vector2(4.8, 2.4),
	Vector2(6.2, -2), Vector2(9.2, -3.9), Vector2(7.0, 0.5), Vector2(9.8, 1.8),
]
const FAR_CLAW := [
	Vector2(-6.8, -2.3), Vector2(-7.2, -4.2), Vector2(-5.9, -6.4), Vector2(-2.8, -7.4),
	Vector2(0.1, -7.2), Vector2(3.9, -5.9), Vector2(8.9, -2.4), Vector2(10.5, -1.1),
	Vector2(5.2, -1.6), Vector2(1.1, -2.7), Vector2(-3.4, -1.8),
]
const NEAR_CLAW := [
	Vector2(-6.9, 1.8), Vector2(-4.4, 0.6), Vector2(-1.4, 0.8), Vector2(2.6, 1.3),
	Vector2(7.8, 0.9), Vector2(11.4, 0.4), Vector2(8.0, 3.5), Vector2(3.6, 6.3),
	Vector2(-0.1, 7.1), Vector2(-3.7, 6.8), Vector2(-6.5, 5.2), Vector2(-7.6, 3.4),
]
const CLAW_RIM := [Vector2(-5.8, 5.4), Vector2(-3.4, 6.5), Vector2(0, 6.9), Vector2(3.5, 6.0), Vector2(6.8, 4.0)]
const SHALE := [Vector2(-3.5, -0.2), Vector2(-1.1, -2.6), Vector2(2.9, -1.6), Vector2(3.8, 0.4), Vector2(0.0, 2.5)]
const SHALE_FACE := [Vector2(-3.1, -0.2), Vector2(-1.0, -2.4), Vector2(2.6, -1.5), Vector2(0.4, -0.2)]
const SHALE_SIZES := [0.78, 1.0, 0.62]
const BLADE := [Vector2(3.8, 0.8), Vector2(0.5, 1.0), Vector2(-2.4, 1.8), Vector2(-5.9, 1.7), Vector2(-9.8, -0.4), Vector2(-12.8, -3.5), Vector2(-8.6, -2.5), Vector2(-4.6, -3.0), Vector2(-2.2, -2.2)]
const VEINS := [Vector2(1.6, 0.5), Vector2(-8.7, -1.2), Vector2(-4.0, -0.4), Vector2(-6.0, -2.2)]

static func paint(canvas: CanvasItem, at: Vector2, side: int, heading: float, terrain: String, animal: bool, age: float, duration: float) -> void:
	var facing := Transform2D(0.0, Vector2(heading, 1), 0.0, at)
	# 脚掌的内弓和蹄瓣朝内；远侧那只略收，鞋尖仍跟着人物朝向。
	var near := side <= 0
	var size := 1.0 if near else 0.92
	var sole_transform := Transform2D(0.10 if near else -0.16, Vector2(size, size if near else -size), 0, Vector2.ZERO)
	canvas.draw_set_transform_matrix(facing * sole_transform)
	var alpha := 0.86 * (1.0 - smoothstep(duration * 0.55, duration, age))
	var colors: Array = EARTH[terrain]
	var soil := Color(colors[0], alpha)
	var rim := Color(colors[1], alpha * 0.82)
	var furrow := Color(colors[2], alpha * 0.84)
	if animal:
		canvas.draw_colored_polygon(FAR_CLAW, soil)
		canvas.draw_colored_polygon(NEAR_CLAW, soil)
		canvas.draw_polyline(CLAW_RIM, rim, 1.25, true)
		canvas.draw_line(Vector2(-4.6, -5.3), Vector2(-1.1, -5.8), furrow, 1.0, true)
		canvas.draw_circle(Vector2(-9.5, -3.7), 1.3, furrow, true, -1.0, true)
		canvas.draw_circle(Vector2(-10, 3.5), 1.5, furrow, true, -1.0, true)
	else:
		canvas.draw_colored_polygon(HEEL, soil)
		canvas.draw_colored_polygon(SOLE, soil)
		canvas.draw_polyline(HEEL_RIM, rim, 1.1, true)
		canvas.draw_polyline(SOLE_RIM, rim, 1.25, true)
		canvas.draw_multiline(SOLE_STITCH, furrow, 1.15, true)
	var lift := age / 0.50
	if lift < 1.0:
		_ground_kick(canvas, facing, terrain, lift, 1.0 if near else -1.0)

static func _ground_kick(canvas: CanvasItem, facing: Transform2D, terrain: String, t: float, side: float) -> void:
	var fade := 1.0 - smoothstep(0.47, 1.0, t)
	var arc := sin(PI * t)
	var travel := 1.0 - (1.0 - t) * (1.0 - t)
	match terrain:
		"sand":
			canvas.draw_set_transform_matrix(facing)
			for i in 5:
				var point := Vector2(-8.0 - (9.0 + i * 3.2) * travel - i, side + 1.8 - (3.0 + (i * 5) % 11) * arc)
				var radius := 1.65 if i % 2 == 0 else 1.1
				canvas.draw_circle(point, radius, Color(Color("ae754e"), fade * 0.9), true, -1, true)
				if i % 2 == 0:
					canvas.draw_circle(point + Vector2(-0.4, -0.65), radius * 0.65, Color(Color("ffdb92"), fade), true, -1, true)
		"stone":
			for i in 3:
				var point := Vector2(-10.0 - (11.0 + 6.0 * i) * travel, side + 1.0 - (6.0 + (i * 4) % 9) * arc)
				canvas.draw_set_transform_matrix(facing * Transform2D(-0.8 + 0.9 * i + t * (1.4 - i), Vector2.ONE * float(SHALE_SIZES[i]), 0, point))
				canvas.draw_colored_polygon(SHALE, Color(Color("52636a"), fade))
				canvas.draw_colored_polygon(SHALE_FACE, Color(Color("d6c9a7"), fade))
		"grass":
			for i in 2:
				var point := Vector2(-10.0 - (10.0 + i * 9.0) * travel, side + 1.0 - (7.0 + i * 5.0) * arc)
				canvas.draw_set_transform_matrix(facing * Transform2D(-0.65 + i * 1.0 + t * 0.45, Vector2.ONE * (0.9 - i * 0.14), 0, point))
				canvas.draw_colored_polygon(BLADE, Color(Color("527a58") if i == 0 else Color("70915f"), fade))
				canvas.draw_multiline(VEINS, Color(Color("e7d69b"), fade), 0.95, true)
