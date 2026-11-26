extends "res://scripts/ui/base_screen.gd"

const Medallion = preload("res://scripts/ui/seal_medallion.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
var route: Control
var points := PackedVector2Array()

func _ready() -> void:
	setup()
	background("map", .16)
	Art.scrim(self, 185, Color("133438cf"), Color("15363400"))
	Art.scrim(self, 160, Color("15363400"), Color("153634b0"), true)
	var layout := column()
	var stops: int = Journey.progress.journey.claimed.size()
	var destination: String = Library.by_id("stages", app.next_story_stop()).name
	var guide := "六枚风铃齐了 · 点一站再出发" if stops == 6 else "下一站去%s · 已收 %d / 6 枚风铃" % [destination, stops]
	header(layout, "河西画卷", guide, app.show_home)
	route = Control.new()
	route.mouse_filter = MOUSE_FILTER_IGNORE
	route.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(route)
	for station: Dictionary in Library.all("stages"):
		var token := Medallion.new()
		token.name = station.id
		token.configure(station.id, station.name, station.id in Journey.progress.journey.trailSeals)
		token.pressed.connect(func(): app.show_world(station.id))
		route.add_child(token)
	route.resized.connect(_place)
	route.draw.connect(_draw_silk_road)
	call_deferred("_place")
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(foot)
	for item: Array in [["四时山河",func(): app.show_atlas("map")],["小营地", app.show_camp],["山河图鉴", func(): app.show_book("facts")],["小游戏",func(): app.show_book("games")],["纹印谱",func(): app.show_album("map")]]:
		var action := GameTheme.button(item[0], item[1], Vector2(155, 66), item[0] == "四时山河")
		action.size_flags_horizontal = SIZE_SHRINK_CENTER
		if item[0] == "纹印谱": action.name = "OpenAlbum"
		if item[0] == "四时山河": action.name = "OpenAtlas"
		foot.add_child(action)
	if Journey.has_ending(): foot.add_child(GameTheme.button("风铃合唱", app.show_ending, Vector2(155,66)))

func _place() -> void:
	if not is_instance_valid(route) or route.size.x < 1: return
	points.clear()
	var stations: Array = Library.all("stages")
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		var button: Control = route.get_child(index)
		button.size = Vector2(146, 160)
		var x := lerpf(72, route.size.x - 72, (float(station.x) - 10) / 81.0)
		var y := 80 + (route.size.y - 160) * float([.65,.27,.62,.35,.58,.29][index])
		button.position = Vector2(x, y) - button.size / 2
		points.append(Vector2(x, y - 15))
	route.queue_redraw()

func _draw_silk_road() -> void:
	for i in range(points.size() - 1):
		var start := points[i]
		var finish := points[i + 1]
		var curve := PackedVector2Array()
		for j in range(25):
			var offset := (finish.x - start.x) * .5
			curve.append(start.bezier_interpolate(start+Vector2(offset,0), finish-Vector2(offset,0), finish, j / 24.0))
		route.draw_polyline(curve, Color("553a2bab"), 7, true)
		route.draw_polyline(curve, Color("f3d292"), 3, true)
		for j in range(0, 25, 4): route.draw_circle(curve[j], 3, Color("9c5f3c"), true, -1, true)
