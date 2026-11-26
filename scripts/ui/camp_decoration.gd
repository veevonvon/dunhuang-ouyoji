extends Control

var item_id := ""

func _draw() -> void:
	var extent := minf(size.x, size.y) / 100.0
	draw_set_transform(size / 2, 0, Vector2.ONE * extent)
	draw_set_transform(size / 2 + Vector2(0, 24) * extent, 0, Vector2(extent, extent * .28))
	draw_circle(Vector2.ZERO, 38, Color(.02, .1, .12, .3))
	draw_set_transform(size / 2, 0, Vector2.ONE * extent)
	match item_id:
		"cushion":
			draw_set_transform(size / 2 + Vector2(0, 14) * extent, -.1, Vector2(extent, extent * .52))
			draw_circle(Vector2.ZERO, 40, Color("ae6357"))
			draw_arc(Vector2.ZERO, 34, 0, TAU, 48, GameTheme.GOLD, 2, true)
			draw_circle(Vector2.ZERO, 10, GameTheme.GOLD)
		"tea":
			draw_set_transform(size / 2 + Vector2(0, 17) * extent, 0, Vector2(extent, extent * .4))
			draw_circle(Vector2.ZERO, 40, Color("aa7b4b"))
			draw_set_transform(size / 2, 0, Vector2.ONE * extent)
			draw_circle(Vector2(0, -1), 19, GameTheme.LIGHT)
			draw_arc(Vector2(20, -5), 10, -.9, 1.4, 24, GameTheme.GOLD, 5, true)
			draw_circle(Vector2(0, -18), 6, GameTheme.GOLD)
			for x in [-29, 29]: draw_rect(Rect2(x - 6, 7, 13, 14), GameTheme.TEAL)
		"plant", "flowers":
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(14, 34), Vector2(-14, 34)]), GameTheme.RUST)
			draw_line(Vector2.ZERO, Vector2(0, -39), Color("72996b"), 4, true)
			for i in range(4):
				var point := Vector2(-12 if i % 2 else 12, -6 - i * 9)
				draw_arc(point, 9, 0, TAU, 24, Color("8ca178"), 10, true)
			if item_id == "flowers":
				for i in range(6): draw_circle(Vector2.from_angle(i * TAU / 6) * 10 + Vector2(0, -42), 7, Color("e1a48e"))
				draw_circle(Vector2(0, -42), 5, GameTheme.GOLD)
		"flag":
			draw_line(Vector2(-20, 35), Vector2(-20, -47), GameTheme.GOLD, 5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-17, -45), Vector2(39, -37), Vector2(25, -8), Vector2(-17, -17)]), GameTheme.RUST)
			draw_circle(Vector2(4, -29), 7, GameTheme.GOLD)
		"books":
			for i in range(3):
				draw_style_box(GameTheme.style([GameTheme.RUST, GameTheme.TEAL, Color("c8a565")][i], 5), Rect2(-31 + i * 5, 17 - i * 16, 58, 15))
		"stone": draw_arc(Vector2(4, -2), 32, .8, 4.4, 42, GameTheme.GOLD, 17, true)
		"chimes":
			draw_line(Vector2(-37, -44), Vector2(37, -44), GameTheme.GOLD, 3, true)
			for i in range(3):
				var x := -27 + i * 27
				var y := 4 if i == 1 else -12
				draw_line(Vector2(x, -44), Vector2(x, y), GameTheme.GOLD, 2, true)
				draw_circle(Vector2(x, y + 6), 9, GameTheme.GOLD)
		"lantern":
			draw_circle(Vector2(0, -5), 36, Color(1, .75, .35, .18))
			draw_circle(Vector2(0, -5), 25, Color("e4aa5c"))
			for x in [-11, 0, 11]: draw_line(Vector2(x, -28), Vector2(x, 18), GameTheme.RUST, 2, true)
			draw_line(Vector2(0, 20), Vector2(0, 42), GameTheme.GOLD, 3, true)
