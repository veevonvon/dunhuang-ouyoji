extends SceneTree

const Places = preload("res://scripts/landmarks/catalog.gd")
const Landscape = preload("res://scripts/landmarks/scenery.gd")
const DESTINATION := "res://assets/landmarks/prints"
const TILE := Vector2i(256,144)

func tile_error(expected: Image, stored: Image) -> float:
	expected.resize(48,27,Image.INTERPOLATE_LANCZOS)
	stored.resize(48,27,Image.INTERPOLATE_LANCZOS)
	var fresh := expected.get_data()
	var cached := stored.get_data()
	var difference := 0
	for i in fresh.size(): difference += absi(int(fresh[i])-int(cached[i]))
	return float(difference)/fresh.size()

func _initialize() -> void:
	call_deferred("render_prints")

func render_prints() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("请用 Compatibility 图形渲染器制作四时小像。")
		quit(1)
		return
	root.size = TILE * 2
	var field := SubViewport.new()
	field.size = TILE * 2
	field.disable_3d = true
	field.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(field)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINATION))
	var verify := "--verify-prints" in OS.get_cmdline_user_args()
	var mismatches := 0
	var peak_difference := 0.0
	for site: Dictionary in Places.sites():
		var canvas := Landscape.new()
		canvas.configure(site,"summer","day",true)
		field.add_child(canvas)
		canvas.set_hotspots_visible(false)
		var sheet := Image.create_empty(TILE.x*4,TILE.y*4,false,Image.FORMAT_RGB8)
		var path := DESTINATION.path_join(str(site.id)+".webp")
		var stored: Image
		if verify:
			var texture := load(path) as Texture2D
			if not texture:
				quit(1)
				return
			stored = texture.get_image()
			stored.convert(Image.FORMAT_RGB8)
		for row in 4:
			for column in 4:
				canvas.set_sky(Places.SEASONS[row],Places.PHASES[column])
				await process_frame
				RenderingServer.force_draw(false)
				var frame := field.get_texture().get_image()
				frame.convert(Image.FORMAT_RGB8)
				frame.resize(TILE.x,TILE.y,Image.INTERPOLATE_LANCZOS)
				var origin := Vector2i(column*TILE.x,row*TILE.y)
				if verify:
					var distance := tile_error(frame,stored.get_region(Rect2i(origin,TILE)))
					peak_difference = maxf(peak_difference,distance)
					if distance > 2.5:
						mismatches += 1
						printerr("时景小画需要重绘 ",site.id," ",Places.SEASONS[row]," ",Places.PHASES[column]," ",snappedf(distance,.01))
				else: sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,TILE),origin)
		if not verify and sheet.save_webp(path,true,.84) != OK:
			printerr("时景小像写入失败：",site.id)
			quit(1)
			return
		if not verify: print("写生页已绘制 ",site.name)
		canvas.queue_free()
		await process_frame
	if verify: print("FIELD_PRINTS: 304 格实绘比对，超差 ",mismatches," 格，最大平均色差 ",snappedf(peak_difference,.01),"/255")
	quit(1 if mismatches else 0)
