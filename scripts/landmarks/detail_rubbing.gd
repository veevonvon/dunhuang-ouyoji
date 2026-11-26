extends RefCounted

const DUST = preload("res://scripts/landmarks/detail_rubbings.png")
static var _plate: Image
var dry: Array[ImageTexture] = []
var original: Array[Image] = []
var live: Image
var live_texture: ImageTexture
var active := -1
var last_uv := Vector2.ZERO

func _init(seed_value: int) -> void:
	if not _plate: _plate=DUST.get_image()
	var tile:=Vector2i(_plate.get_width()/3,_plate.get_height())
	for i in 3:
		var part:=_plate.get_region(Rect2i(Vector2i((i+seed_value%3)%3*tile.x,0),tile))
		original.append(part)
		dry.append(ImageTexture.create_from_image(part))

func picture(item: int) -> Texture2D:
	return live_texture if item==active else dry[item]

func begin(item: int, uv: Vector2) -> void:
	active=item
	live=original[item].duplicate()
	live_texture=ImageTexture.create_from_image(live)
	last_uv=uv
	brush(uv)

func brush(uv: Vector2) -> void:
	if active<0: return
	var dims:=Vector2(live.get_size())
	var start:=last_uv*dims
	var finish:=uv*dims
	var r:=dims.x*.105
	var steps:=maxi(1,ceili(start.distance_to(finish)/(r*.55)))
	for i in range(1,steps+1):
		var p:=start.lerp(finish,i/float(steps))
		var min_xy:=Vector2i((p-Vector2.ONE*r).floor()).clamp(Vector2i.ZERO,live.get_size())
		var max_xy:=Vector2i((p+Vector2.ONE*r).ceil()).clamp(Vector2i.ZERO,live.get_size())
		for y in range(min_xy.y,max_xy.y):
			for x in range(min_xy.x,max_xy.x):
				var distance:=p.distance_to(Vector2(x,y))/r
				if distance>=1.: continue
				var pixel:=live.get_pixel(x,y)
				pixel.a=minf(pixel.a,smoothstep(.29,1.,distance)*.94)
				live.set_pixel(x,y,pixel)
	last_uv=uv
	live_texture.update(live)

func cancel() -> void:
	active=-1
	live=null
	live_texture=null
