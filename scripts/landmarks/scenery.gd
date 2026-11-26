extends Control

signal detail_requested(local_id: String)

const Marker = preload("res://scripts/landmarks/scenic_marker.gd")
const Light = preload("res://scripts/landmarks/scenic_light.gdshader")
const SEASONS := ["spring","summer","autumn","winter"]
const PHASES := ["dawn","day","dusk","night"]
const PROFILES := ["desert","rock","water","garden","forest","architecture","cliff","ruin"]
const ART_DIR := "res://assets/landmarks/paintings/"
const MASK_DIR := "res://scripts/landmarks/scenic_masks/"
var site: Dictionary
var season := "spring"
var phase := "day"
var reduced_motion := false:
	set(value):
		if reduced_motion == value: return
		reduced_motion = value
		if is_node_ready(): _visibility()
var painting: TextureRect
var lighting := ShaderMaterial.new()
var plate: Image
var surfaces: Dictionary = {}
var current_surface := ""
var registered_season := ""
var pins: Control
var observed: Array = []
var show_pins := true
var held: Button
var pointer := -99
var breeze := 0.0
var since_draw := 0.0
var in_background := false
var out_of_focus := false

func configure(place: Dictionary, selected_season: String, selected_phase: String, reduced: bool) -> void:
	site = place
	reduced_motion = reduced
	set_sky(selected_season,selected_phase)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	painting = TextureRect.new()
	painting.name = "Painting"
	painting.mouse_filter = MOUSE_FILTER_IGNORE
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lighting.shader = Light
	painting.material = lighting
	add_child(painting)
	var ecology := maxi(0,PROFILES.find(site.get("profile","rock")))
	lighting.set_shader_parameter("ecology",ecology)
	lighting.set_shader_parameter("landmark_seed",float(hash(str(site.id))%997)/997.)
	pins = Control.new()
	pins.name = "Hotspots"
	pins.mouse_filter = MOUSE_FILTER_IGNORE
	pins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(pins)
	pins.visible = show_pins
	for i in site.details.size():
		var mark := Marker.new()
		var detail: Dictionary = site.details[i]
		mark.configure(self,detail,i)
		mark.set_found(detail.id in observed)
		mark.pressed.connect(func(): detail_requested.emit(str(detail.id)))
		pins.add_child(mark)
	resized.connect(_place_picture)
	visibility_changed.connect(_visibility)
	_place_picture()
	set_sky(season,phase)
	_visibility()

func _place_picture() -> void:
	if not painting or not painting.texture or not pins: return
	var natural := painting.texture.get_size()
	var cover := maxf(size.x/natural.x,size.y/natural.y)
	painting.size = natural*cover
	painting.position = (size-painting.size)*.5
	for mark in pins.get_children():
		var at := painting.position+Vector2(float(mark.detail.x),float(mark.detail.y))*painting.size
		var desired := at-Vector2(mark.size.x*.5,77)
		mark.position = desired.clamp(Vector2(2,2),(size-mark.size-Vector2(2,2)).max(Vector2(2,2)))

func _load_surface() -> void:
	if registered_season==season: return
	registered_season=season
	var prefix := "" if season=="summer" else season+"/"
	var file := str(site.id)+".webp"
	var path := ART_DIR+prefix+file
	var original := ResourceLoader.exists(path)
	if not original:
		prefix=""
		path=ART_DIR+file
	if not ResourceLoader.exists(path): path="res://assets/images/%s.jpg" % site.get("station","dunhuang")
	lighting.set_shader_parameter("painted_season",original)
	if path==current_surface: return
	current_surface=path
	if not surfaces.has(path):
		var mask_path:=MASK_DIR+prefix+str(site.id)+".png"
		var mask: Texture2D = load(mask_path) if ResourceLoader.exists(mask_path) else null
		var texture:=load(path) as Texture2D
		surfaces[path]={"painting":texture,"mask":mask,"pixels":mask.get_image() if mask else null}
	var surface: Dictionary=surfaces[path]
	painting.texture=surface.painting
	plate=surface.pixels
	lighting.set_shader_parameter("landscape_plate",surface.mask)
	lighting.set_shader_parameter("has_plate",plate!=null)
	lighting.set_shader_parameter("art_aspect",painting.texture.get_size().aspect())
	_place_picture()

func set_sky(value: String, hour: String) -> void:
	if value!=season or hour!=phase: cancel_input()
	season = value if value in SEASONS else "spring"
	phase = hour if hour in PHASES else "day"
	if not painting: return
	_load_surface()
	var phase_index := PHASES.find(phase)
	var season_index := SEASONS.find(season)
	lighting.set_shader_parameter("phase_id",phase_index)
	lighting.set_shader_parameter("season_id",season_index)
	var origin: Vector2 = [Vector2(.21,.21),Vector2(.46,.065),Vector2(.78,.22),Vector2(.68,.11)][phase_index]
	origin.x += (float(hash(str(site.id))%17)/100.-.08)
	origin.y += [.003,-.015,.012,.027][season_index]
	if plate:
		# A nearby patch of open sky keeps celestial bodies behind roofs, cliffs and branches.
		var origin_x := origin.x
		var cost := 1000.0
		var best:=origin
		var dims := plate.get_size()
		for dx in range(-5,6):
			for dy in range(-5,4):
				var probe := Vector2(clampf(origin_x+dx*.031,.04,.96),clampf(origin.y+dy*.024,.035,.39))
				var coverage := 1.0
				for d: Vector2 in [Vector2.ZERO,Vector2(-.012,0),Vector2(.012,0),Vector2(0,-.024),Vector2(0,.024)]:
					var pixel := Vector2i((probe+d)*Vector2(dims)).clamp(Vector2i.ZERO,dims-Vector2i.ONE)
					coverage = minf(coverage,plate.get_pixelv(pixel).r)
				var weight := probe.distance_squared_to(origin)+(1.-coverage)*.22
				if weight<cost:
					cost=weight
					best=probe
		lighting.set_shader_parameter("light_pos",best)
	else: lighting.set_shader_parameter("light_pos",origin)

func set_found(ids: Array) -> void:
	observed = ids.duplicate()
	if pins:
		for mark in pins.get_children(): mark.set_found(mark.detail.id in observed)

func set_hotspots_visible(value: bool) -> void:
	show_pins = value
	if pins: pins.visible = value
	if not value: cancel_input()

func _visibility() -> void:
	if not is_visible_in_tree(): cancel_input()
	set_process(not reduced_motion and is_visible_in_tree() and not in_background and not out_of_focus)

func _process(delta: float) -> void:
	since_draw += delta
	if since_draw < .067: return
	breeze = fmod(breeze+since_draw,600.)
	since_draw=0.0
	lighting.set_shader_parameter("breeze",breeze)

func begin_point(mark: Button, finger: int) -> void:
	if held: return
	held=mark
	pointer=finger
	mark.grab_focus()

func cancel_input() -> void:
	held=null
	pointer=-99

func _input(event: InputEvent) -> void:
	if not held or event.device==InputEvent.DEVICE_ID_EMULATION: return
	var release := false
	if event is InputEventScreenTouch and event.index==pointer:
		if event.canceled:
			cancel_input()
			return
		release=not event.pressed
	elif event is InputEventMouseButton and pointer==-1 and event.button_index==MOUSE_BUTTON_LEFT:
		release=not event.pressed
	if release:
		var mark:=held
		cancel_input()
		var point: Vector2 = mark.get_global_transform_with_canvas().affine_inverse()*event.position
		get_viewport().set_input_as_handled()
		if Rect2(Vector2.ZERO,mark.size).has_point(point): mark.pressed.emit()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT: out_of_focus=true
		NOTIFICATION_APPLICATION_FOCUS_IN: out_of_focus=false
		NOTIFICATION_APPLICATION_PAUSED: in_background=true
		NOTIFICATION_APPLICATION_RESUMED: in_background=false
		NOTIFICATION_EXIT_TREE:
			cancel_input()
			return
		_: return
	if in_background or out_of_focus: cancel_input()
	if is_inside_tree(): _visibility()
