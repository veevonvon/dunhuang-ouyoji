extends Control

var symbol := "star"
var color := Color("e4b96d")

func _ready() -> void:
	resized.connect(queue_redraw)

func line(points: Array, width := 2.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func _draw() -> void:
	var scale_factor: float = minf(size.x, size.y) / 36.0
	draw_set_transform(size / 2.0, 0, Vector2.ONE * scale_factor)
	match symbol:
		"back": line([Vector2(5, -10), Vector2(-6, 0), Vector2(5, 10)], 2.6)
		"close":
			line([Vector2(-9, -9), Vector2(9, 9)])
			line([Vector2(9, -9), Vector2(-9, 9)])
		"menu", "settings":
			for y in [-9, 0, 9]: line([Vector2(-12, y), Vector2(12, y)])
		"check": line([Vector2(-12, 0), Vector2(-3, 9), Vector2(13, -10)], 3)
		"star", "sun":
			if symbol == "sun":
				draw_circle(Vector2.ZERO, 7, color)
				for i in range(8):
					var ray := Vector2.from_angle(i * TAU / 8.0)
					line([ray * 11, ray * 16])
			else:
				var points := PackedVector2Array()
				for i in range(10): points.append(Vector2.from_angle(i * PI / 5 - PI / 2) * (15 if i % 2 == 0 else 6))
				draw_colored_polygon(points, color)
		"leaf":
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 12), Vector2(-15, -1), Vector2(-6, -12), Vector2(13, -15), Vector2(14, -2), Vector2(4, 10)]), color)
			draw_line(Vector2(-8, 8), Vector2(8, -9), Color("f6e6c3"), 1.5, true)
		"water":
			var points := PackedVector2Array([Vector2(0, -16)])
			for i in range(17): points.append(Vector2.from_angle(-.3 + i * (PI + .6) / 16) * 11 + Vector2(0, 4))
			draw_colored_polygon(points, color)
		"moon":
			draw_arc(Vector2(3, -1), 13, .7, 4.5, 30, color, 8, true)
		"lotus", "palette", "puzzle":
			for i in range(-2, 3):
				var angle := float(i) * .48
				var petal := PackedVector2Array([Vector2(0, 12), Vector2(-6, -1), Vector2(0, -15), Vector2(6, -1)])
				for j in range(petal.size()): petal[j] = petal[j].rotated(angle)
				draw_colored_polygon(petal, color)
			line([Vector2(-14, 15), Vector2(14, 15)])
		"book", "scroll":
			draw_rect(Rect2(-11, -13, 22, 26), color, false, 2)
			line([Vector2(-15, -15), Vector2(-15, 15)])
			for y in [-7, 0, 7]: line([Vector2(-6, y), Vector2(6, y)], 1.5)
		"map":
			line([Vector2(-15, -11), Vector2(-5, -15), Vector2(5, -11), Vector2(15, -15), Vector2(15, 11), Vector2(5, 15), Vector2(-5, 11), Vector2(-15, 15), Vector2(-15, -11)])
			line([Vector2(-5, -15), Vector2(-5, 11)])
			line([Vector2(5, -11), Vector2(5, 15)])
		"camp":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(-17, 15), Vector2(17, 15)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(-7, 15), Vector2(7, 15)]), Color("286063"))
		"bell":
			draw_circle(Vector2(0, -4), 9, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), Vector2(-13, 10), Vector2(13, 10), Vector2(9, -4)]), color)
			draw_circle(Vector2(0, 14), 2, color)
			line([Vector2(0, -13), Vector2(0, -17)])
		"letter":
			draw_rect(Rect2(-15, -10, 30, 21), color, false, 2)
			line([Vector2(-15, -10), Vector2(0, 3), Vector2(15, -10)])
		"camel":
			draw_circle(Vector2(-6, -3), 7, color)
			draw_circle(Vector2(6, -3), 7, color)
			draw_rect(Rect2(-13, -3, 26, 12), color)
			line([Vector2(11, 8), Vector2(16, -12), Vector2(19, -12)], 5)
			line([Vector2(-10, 8), Vector2(-12, 17)], 3)
			line([Vector2(9, 8), Vector2(8, 17)], 3)
		"gate":
			for x in [-14, 7]: draw_rect(Rect2(x, -12, 7, 28), color)
			draw_rect(Rect2(-14, -12, 28, 8), color)
			for x in [-14, -3, 8]: draw_rect(Rect2(x, -17, 6, 5), color)
		"grape":
			for point in [Vector2(-7, -4), Vector2(2, -5), Vector2(8, 2), Vector2(-8, 5), Vector2(0, 5), Vector2(-3, 13)]: draw_circle(point, 4.4, color)
			line([Vector2(0, -9), Vector2(3, -16), Vector2(12, -13)])
		"pipa", "music":
			draw_circle(Vector2(-1, 5), 10, color)
			draw_rect(Rect2(-3, -17, 5, 20), color)
			for x in [-3, 1]: draw_line(Vector2(x, -9), Vector2(x, 12), Color("f6e6c3"), 1, true)
		"sound", "play":
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -10), Vector2(11, 0), Vector2(-11, 10)]), color)
			if symbol == "sound": draw_arc(Vector2.ZERO, 16, -.8, .8, 20, color, 2, true)
		"silk":
			line([Vector2(-15, -10), Vector2(-5, -14), Vector2(4, -2), Vector2(15, -6), Vector2(15, 10), Vector2(4, 14), Vector2(-5, 2), Vector2(-15, 6), Vector2(-15, -10)], 2.5)
		"mountain": line([Vector2(-17, 13), Vector2(-4, -13), Vector2(4, 2), Vector2(10, -7), Vector2(18, 13), Vector2(-17, 13)])
		_:
			draw_arc(Vector2.ZERO, 13, 0, TAU, 40, color, 2, true)
			draw_circle(Vector2.ZERO, 3.5, color)
