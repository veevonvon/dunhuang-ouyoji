extends SceneTree

const SCENERY := "res://scripts/landmarks/scenery.gd"
const DETAIL := "res://scripts/landmarks/detail_view.gd"
const DATA := "res://data/landmarks.json"
const OUTPUT := "res://test-results/scenic-play"
const KINDS := ["trace", "pair", "turn", "echo", "uncover", "order"]
const SEASONS := ["spring", "summer", "autumn", "winter"]
const PHASES := ["dawn", "day", "dusk", "night"]
const HARE_PLATE := "res://scripts/landmarks/detail_shared_ears.svg"
const DETAIL_ART := ["chariot","reservoir","lake_pavilion","lotus_rabbits"]
var checks := 0
var failures := 0
var awards: Array[String] = []
var cues: Array[String] = []
var pitches: Array[int] = []
var captured := {}
var replayed := {}
var signatures := {}
var render_checks := false
var require_seasons := false
var original_pairs := {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func fixtures() -> Array:
	if FileAccess.file_exists(DATA):
		return JSON.parse_string(FileAccess.get_file_as_string(DATA)).sites
	var sites := []
	for page in 2:
		var details := []
		for i in 3:
			var kind: String = KINDS[page*3+i]
			details.append({"id":kind, "title":"山的彩带", "x":.2+.3*i, "y":.43, "kind":kind, "motif":["ribbon","roof","bell"][i], "pieces":["山脚","坡腰","山脊"], "instruction":"看看三处纹样。", "result":"三处细节留在册页里。"})
		sites.append({"id":["danxia","crescent"][page], "station":"zhangye", "profile":["rock","desert"][page], "name":"丹霞", "details":details})
	return sites

func touch(point: Vector2, pressed: bool, finger := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func move(point: Vector2, finger := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = point
	root.push_input(event, true)

func tap(point: Vector2) -> void:
	touch(point,true)
	touch(point,false)

func touch_button(button: BaseButton) -> void:
	await settle()
	var p:=button.get_global_transform_with_canvas()*(button.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=p
		event.index=0
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
	await process_frame

func target(board: Control, i: int) -> Vector2:
	return board.get_global_transform_with_canvas() * board.region_rect(i).get_center()

func slot(board: Control, word: String, start := 0, end := 3) -> int:
	for i in range(start,end):
		if board.target_name(i) == word: return i
	return -1

func settle() -> void:
	await process_frame
	await process_frame

func screen() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func image_sample(image: Image) -> Image:
	var sample := image.duplicate() as Image
	sample.resize(80,45,Image.INTERPOLATE_BILINEAR)
	return sample

func mean_light(image: Image) -> float:
	var total := 0.0
	for y in image.get_height():
		for x in image.get_width(): total += image.get_pixel(x,y).get_luminance()
	return total / (image.get_width()*image.get_height())

func flat_sky_seam(day: Image, dusk: Image) -> int:
	# A discontinuity extending through otherwise uniform blue sky is an unregistered light mask.
	var span:=0
	for y in range(2,day.get_height()-1):
		var run:=0
		for x in range(1,day.get_width()-1):
			var a:=day.get_pixel(x,y-1)
			var b:=day.get_pixel(x,y+1)
			var p:=dusk.get_pixel(x,y-1)
			var q:=dusk.get_pixel(x,y+1)
			var original:=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
			var relit:=Vector3(p.r-q.r,p.g-q.g,p.b-q.b).length()
			if a.b>a.r+.045 and a.g>a.r+.012 and original<.045 and relit>original+.115:
				run+=1
				span=maxi(span,run)
			else: run=0
	return span

func check_season_assets(scene: Control, site: Dictionary, season: String) -> void:
	var part: String=("" if season=="summer" else season+"/")+str(site.id)
	var art_path:="res://assets/landmarks/paintings/"+part+".webp"
	var mask_path:="res://scripts/landmarks/scenic_masks/"+part+".png"
	var ready_art:=ResourceLoader.exists(art_path)
	if not require_seasons and not ready_art: return
	var ready_mask:=ResourceLoader.exists(mask_path)
	check(ready_art,site.id+" owns a physical seasonal painting at "+art_path)
	check(ready_mask,site.id+" owns a matching seasonal registration plate at "+mask_path)
	check(scene.painting.texture.resource_path==art_path,site.id+" displays the selected original "+season)
	var installed:=scene.lighting.get_shader_parameter("landscape_plate") as Texture2D
	check(installed!=null and installed.resource_path==mask_path and scene.plate!=null,site.id+" uses the selected seasonal registration plate "+season)
	if ready_art and ready_mask and installed and installed.resource_path==mask_path and scene.painting.texture.resource_path==art_path:
		check(scene.plate.get_width()>=320 and scene.plate.get_height()>=180,site.id+" uses a registered full landscape mask")
		original_pairs[part]=true

func scene_checks(site: Dictionary, scenery_script: Script) -> void:
	var scene: Control = scenery_script.new()
	scene.configure(site,"spring","day",true)
	scene.set_found([site.details[1].id])
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var opened := []
	scene.detail_requested.connect(func(id: String): opened.append(id))
	var marks: Array[Node] = scene.find_children("*","BaseButton",true,false)
	check(marks.size()==3, site.id+" has three native landmark targets")
	for i in marks.size():
		var b := marks[i] as BaseButton
		check(b.size.x>=64 and b.size.y>=64 and scene.get_global_rect().encloses(b.get_global_rect()), site.id+" owns a reachable finger target")
		check(b.accessibility_name.contains(str(site.details[i].title)), site.id+" target identifies the local object")
		tap(b.get_global_rect().get_center())
		check(opened.size()==i+1 and opened.back()==site.details[i].id, site.id+" dispatches the selected local id")
	if marks.size()==3:
		check(marks[1].accessibility_name.contains("已") and not marks[0].accessibility_name.contains("已"), site.id+" completion before ready reaches the markers")
		scene.set_found([site.details[0].id])
		check(marks[0].accessibility_name.contains("已") and not marks[1].accessibility_name.contains("已"), site.id+" refreshed completion is visible")
	if marks.size()==3:
		var before_open:=opened.size()
		var center: Vector2=marks[0].get_global_rect().get_center()
		touch(center,true)
		scene.set_sky("autumn","dusk")
		touch(center,false)
		check(opened.size()==before_open,site.id+" changing the sky cancels the previous press")
	if require_seasons and not render_checks:
		for seasonal: String in SEASONS:
			scene.set_sky(seasonal,"day")
			check_season_assets(scene,site,seasonal)
	if render_checks:
		scene.set_hotspots_visible(false)
		var sheet := Image.create_empty(4*304,4*171,false,Image.FORMAT_RGB8)
		var hashes := []
		for s in 4:
			var daylight := 0.0
			var day_image: Image
			for t in 4:
				scene.set_sky(SEASONS[s],PHASES[t])
				if t==0: check_season_assets(scene,site,SEASONS[s])
				var frame: Image = await screen()
				if (site.id=="mogao" and t==2) or (site.id=="poplar" and s==3 and t==1):
					check(frame.save_png(OUTPUT.path_join("%s-%s-%s.png" % [site.id,SEASONS[s],PHASES[t]]))==OK,"full seasonal registration reference")
				var sample := image_sample(frame)
				var lum := mean_light(sample)
				if t==1:
					daylight=lum
					day_image=frame.duplicate()
					day_image.resize(256,144,Image.INTERPOLATE_BILINEAR)
				if t==2:
					var dusk_image:=frame.duplicate() as Image
					dusk_image.resize(256,144,Image.INTERPOLATE_BILINEAR)
					check(flat_sky_seam(day_image,dusk_image)<25,site.id+" has a continuous painted sky at dusk in "+SEASONS[s])
				if t==3: check(daylight-lum>.10,site.id+" night has perceptibly lower luminance than daylight")
				hashes.append(hash(sample.get_data()))
				frame.resize(304,171,Image.INTERPOLATE_BILINEAR)
				frame.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(frame,Rect2i(0,0,304,171),Vector2i(t*304,s*171))
		var distinct := {}
		for h in hashes: distinct[h]=true
		check(distinct.size()==16,site.id+" renders sixteen different still paintings")
		check(hash(image_sample(await screen()).get_data())==hashes.back(),site.id+" reduced motion holds the exact last frame")
		check(sheet.save_png(OUTPUT.path_join(site.id+"-skies.png"))==OK,site.id+" rendered season and sky contact sheet")
	scene.queue_free()
	await process_frame

func living_weather(site: Dictionary, scenery_script: Script) -> void:
	var scene: Control=scenery_script.new()
	scene.configure(site,"summer","day",false)
	root.add_child(scene)
	scene.set_hotspots_visible(false)
	await settle()
	check(scene.is_processing(),site.id+" live water and wind have a clock")
	if render_checks:
		var first: Image=await screen()
		await create_timer(.36).timeout
		var next: Image=await screen()
		check(hash(first.get_data())!=hash(next.get_data()),site.id+" natural motion changes real rendered pixels")
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not scene.is_processing(),site.id+" backgrounds without ticking the scenery")
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(scene.is_processing(),site.id+" foreground scenery resumes without a stuck pointer")
	scene.queue_free()
	await process_frame

func pair_shape_scores(frame: Image, board: Control, word: String) -> Vector2:
	# Compare ink silhouettes at corresponding top/bottom locations in the actual render.
	var top:=target(board,slot(board,word))
	var bottom:=target(board,slot(board,word,3,6))
	var matches:=Vector2.ZERO
	var union:=Vector2.ZERO
	var u: float=board.unit()
	var bottom_threshold:=.76 if board.state.done else .68
	for y in range(-29,30):
		for x in range(-43,44):
			var a:=frame.get_pixelv(Vector2i(top+Vector2(x,y)*u)).get_luminance()<.76
			var b:=frame.get_pixelv(Vector2i(bottom+Vector2(x,y)*u)).get_luminance()<bottom_threshold
			var mirror:=frame.get_pixelv(Vector2i(bottom+Vector2(x,-y)*u)).get_luminance()<bottom_threshold
			if a or b: union.x+=1
			if a or mirror: union.y+=1
			if a and b: matches.x+=1
			if a and mirror: matches.y+=1
	return matches/union.max(Vector2.ONE)

func inspect_water_pairs(view: Control, detail: Dictionary, done := false) -> void:
	if not render_checks: return
	var words: Dictionary={"chariot":"伞盖","reservoir":"山尖","lake_pavilion":"屋尖"}
	if not words.has(detail.id): return
	var frame: Image=await screen()
	var scores:=pair_shape_scores(frame,view.board,words[detail.id])
	if detail.id=="chariot":
		check(scores.x>scores.y+.12,"ordinary umbrella rubbing stays upright; upright/reflected="+str(scores))
	else:
		check(scores.y>scores.x+.12,str(detail.title)+" vertically reflects its pointed silhouette; upright/reflected="+str(scores))
		if not done: check(frame.save_png(OUTPUT.path_join("detail-"+str(detail.id)+"-reflection.png"))==OK,"save actual reflection "+str(detail.id))
	print("PAIR_PIXELS ",detail.id," solved=",done," upright/reflected=",scores)

func inner_ear_ink(pixel: Color) -> bool:
	var exemplar:=Color("c3836d")
	return absf(pixel.r-exemplar.r)+absf(pixel.g-exemplar.g)+absf(pixel.b-exemplar.b)<.108

func plate_pixel(picture: Image, bounds: Rect2, offset: Vector2) -> Color:
	return picture.get_pixelv(Vector2i((bounds.get_center()+offset*bounds.size.x/600.).round()))

func ear_components(picture: Image, bounds: Rect2) -> int:
	# The copper lining of each ear is separated at its ends by rabbit fur. Count
	# connected, sizeable marks in the central disk, independently of the SVG paths.
	const WIDTH:=135
	var copper:=PackedByteArray()
	copper.resize(WIDTH*WIDTH)
	for y in WIDTH:
		for x in WIDTH:
			var at:=Vector2(x-67,y-67)
			if at.length_squared()<67*67 and inner_ear_ink(plate_pixel(picture,bounds,at)): copper[y*WIDTH+x]=1
	var count:=0
	for i in copper.size():
		if not copper[i]: continue
		var queue: Array[int]=[i]
		copper[i]=0
		var area:=0
		while not queue.is_empty():
			var pos: int=queue.pop_back()
			area+=1
			for step: int in [-WIDTH,-1,1,WIDTH]:
				var neighbor:=pos+step
				if neighbor>=0 and neighbor<copper.size() and copper[neighbor]:
					copper[neighbor]=0
					queue.append(neighbor)
		if area>110: count+=1
	return count

func verify_shared_structure(picture: Image, bounds: Rect2, label: String) -> void:
	check(ear_components(picture,bounds)==3,label+" contains exactly three separate long ear linings in the central disk")
	var aperture:=plate_pixel(picture,bounds,Vector2.ZERO)
	check(aperture.g>aperture.r+.07,label+" leaves the center of the ear triangle open")
	for n in 3:
		var angle:=n*TAU/3.
		var crown:=Vector2(0,-58).rotated(angle)
		var neighbor:=Vector2(0,-58).rotated(angle+TAU/3.)
		var painted:=0
		for t: float in [.16,.26,.36,.5,.62,.72,.82]:
			if inner_ear_ink(plate_pixel(picture,bounds,crown.lerp(neighbor,t))): painted+=1
		check(painted>=5,label+" has a continuous ear between adjacent heads "+str(n))
		for point: Vector2 in [Vector2(1,-66),Vector2(-56,-100)]:
			var fur:=plate_pixel(picture,bounds,point.rotated(angle))
			check(fur.r>.67 and fur.r-fur.b>.12,label+" shows both a head and a running body in sector "+str(n))

func inspect_hare_plate(view: Control, done: bool) -> void:
	var small:=view.find_child("HareReference",true,false) as BaseButton
	var large:=view.find_child("LargeHareReference",true,false) as BaseButton
	check(ResourceLoader.exists(HARE_PLATE),"the 407 ceiling has an original full three-hare illustration")
	check(small!=null and small.is_visible_in_tree(),"the complete three-hare pattern remains available, solved="+str(done))
	if not small or not large: return
	if not done:
		var original: Image=(load(HARE_PLATE) as Texture2D).get_image()
		verify_shared_structure(original,Rect2(Vector2.ZERO,original.get_size()),"original ceiling")
	check(view.has_method("close_reference"),"the platform Back handler can ask the reference to close")
	if view.has_method("close_reference"): check(not view.close_reference(),"Back passes through on the ordinary puzzle")
	check(small.size.y>=145 and small.size.x>=145,"the left folio gives the ceiling its own legible plate")
	if render_checks and not done:
		var spread: Image=await screen()
		check(spread.save_png(OUTPUT.path_join("detail-lotus-rabbits.png"))==OK,"save the puzzle alongside its complete reference")
	var progress: int=view.board.progress_count()
	await touch_button(small)
	check(large.is_visible_in_tree() and not view.board.is_visible_in_tree(),"a native tap enlarges the uncut three-hare motif")
	if render_checks:
		var closeup: Image=await screen()
		var displayed: Rect2=large.get_global_transform_with_canvas()*large.figure_rect()
		verify_shared_structure(closeup,displayed,"enlarged ceiling, solved="+str(done))
		check(closeup.save_png(OUTPUT.path_join("detail-lotus-rabbits-"+("solved" if done else "large")+".png"))==OK,"save the visible enlarged ceiling motif")
	if done and view.has_method("close_reference"):
		check(view.close_reference() and not view.close_reference(),"Back consumes exactly one open reference")
	else: await touch_button(large)
	check(not large.is_visible_in_tree() and view.board.is_visible_in_tree() and view.board.progress_count()==progress,"returning from the big plate preserves the three dials")

func play_checks(site: Dictionary, detail: Dictionary, view_script: Script) -> void:
	var view: Control = view_script.new()
	view.configure(site,detail,true)
	view.solved.connect(func(id: String): awards.append(id))
	view.sound_requested.connect(func(cue: String): cues.append(cue))
	view.note_requested.connect(func(note: int): pitches.append(note))
	pitches.clear()
	root.add_child(view)
	await settle()
	var board: Control = view.board
	var hdr: Button = view.find_children("*","Button",true,false)[0]
	check(hdr.size.y <= 84 and hdr.get_parent().get_global_rect().end.x <= view.size.x,site.id+" full header labels fit in one row")
	var key := "%s/%s" % [site.id,detail.id]
	var before := awards.size()
	if detail.id=="lotus_rabbits": await inspect_hare_plate(view,false)
	await inspect_water_pairs(view,detail)
	var cells: Array=board.state.cells
	check(cells[0]!=cells[1] and cells[1]!=cells[2] and cells[0]!=cells[2],key+" shows three distinct illustrated local parts")
	var visual:=str(detail.kind)+"/"+str(cells)
	check(not signatures.has(visual),key+" uses its own local picture set within this activity")
	signatures[visual]=true
	var count := 6 if detail.kind=="pair" else 3
	for i in count:
		var rect: Rect2 = board.region_rect(i)
		check(rect.size.x>=64 and rect.size.y>=64 and Rect2(Vector2.ZERO,board.size).encloses(rect),key+" fits touch target "+str(i))
	if render_checks and not captured.has(detail.kind):
		var image: Image=await screen()
		check(image.save_png(OUTPUT.path_join("play-"+detail.kind+".png"))==OK,key+" gameplay screenshot")
		captured[detail.kind]=true
	var piece: Array = detail.pieces
	var first := slot(board,piece[0])
	check(first>=0,key+" reference word is printed on a touchable object")
	if first<0: return
	touch(target(board,first),true)
	touch(target(board,(first+1)%3),true,1)
	touch(target(board,(first+1)%3),false,1)
	view.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	touch(target(board,first),false)
	check(board.progress_count()==0,key+" paused and secondary fingers do not complete a move")
	view.show_hint()
	check(not cues.is_empty() and cues.back()=="hint" and board.progress_count()==0,key+" free hint preserves the puzzle")
	match detail.kind:
		"trace":
			tap(target(board,slot(board,piece[2])))
			check(cues.back()=="miss",key+" trace rejects an out-of-order mark")
			touch(target(board,first),true)
			for word in piece.slice(1): move(target(board,slot(board,word)))
			touch(target(board,slot(board,piece[2])),false)
		"pair":
			tap(target(board,first))
			tap(target(board,slot(board,piece[1],3,6)))
			check(cues.back()=="miss" and board.progress_count()==0,key+" mismatched outline remains playable")
			for w in piece:
				var a:=target(board,slot(board,w))
				var b:=target(board,slot(board,w,3,6))
				touch(a,true)
				move(b)
				touch(b,false)
		"turn":
			for i in 3:
				for spin in 3: tap(target(board,i))
		"echo":
			pitches.clear()
			view.play_demo()
			for wait in 45:
				await create_timer(.05).timeout
				if pitches.size()==3 and not board.is_listening(): break
			var melody:=pitches.duplicate()
			check(melody.size()==3 and melody.all(func(n): return n>=0 and n<5),key+" complete audible three-note demonstration")
			for note in melody:
				var pad := -1
				for i in 3:
					if board.note_for_pad(i)==note: pad=i
				check(pad>=0,key+" audible demonstration has a matching visible pad")
				if pad>=0: tap(target(board,pad))
		"uncover":
			for i in 3:
				var p:=target(board,i)
				if i==2: tap(p)
				else:
					touch(p-Vector2(22,0),true)
					move(p+Vector2(27,4))
					touch(p+Vector2(27,4),false)
		"order":
			tap(target(board,slot(board,piece[2])))
			check(cues.back()=="miss",key+" sequence rejects a misplaced piece")
			for w in piece: tap(target(board,slot(board,w)))
	check(awards.size()==before+1 and awards.back()==detail.id and cues.back()=="win",key+" completes through native input exactly once")
	tap(target(board,0))
	view.show_hint()
	check(awards.size()==before+1,key+" completed visit cannot emit a second reward")
	if detail.id=="lotus_rabbits": await inspect_hare_plate(view,true)
	if detail.id in ["reservoir","lake_pavilion"]: await inspect_water_pairs(view,detail,true)
	if not replayed.has(detail.kind):
		replayed[detail.kind]=true
		await touch_button(view.again)
		check(board.progress_count()==0 and not view.again.visible,key+" replay button reopens the puzzle")
		if detail.kind=="trace":
			for word in piece: tap(target(board,slot(board,word)))
			check(board.progress_count()==3 and awards.size()==before+1,key+" replay by tapping all three marks cannot claim twice")
		elif detail.kind=="pair":
			for word in piece:
				tap(target(board,slot(board,word,3,6)))
				tap(target(board,slot(board,word)))
			check(board.progress_count()==3 and awards.size()==before+1,key+" reverse two-tap pairing also completes")
		elif detail.kind=="echo":
			view.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			check(not board.is_listening(),key+" demonstration ceases on backgrounding")
		var exits:=[]
		view.back_requested.connect(func(): exits.append(true))
		await touch_button(hdr)
		check(exits.size()==1,key+" native back touch dispatches once")
	view.queue_free()
	await settle()

func run() -> void:
	root.size=Vector2i(1280,720)
	render_checks="--capture-scenic" in OS.get_cmdline_user_args()
	require_seasons="--require-seasonal-art" in OS.get_cmdline_user_args()
	for path: String in [SCENERY,DETAIL]: check(ResourceLoader.exists(path),"native scene module exists: "+path)
	if failures:
		quit(1)
		return
	if render_checks: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scenery: Script=load(SCENERY)
	var view: Script=load(DETAIL)
	var sites:=fixtures()
	if "--detail-art" in OS.get_cmdline_user_args():
		for place: Dictionary in sites:
			for item: Dictionary in place.details:
				if item.id in DETAIL_ART: await play_checks(place,item,view)
		print("DETAIL_ART_CHECKS: %d; DETAILS: %d; REAL_RENDER: %s; FAILURES: %d" % [checks,awards.size(),render_checks,failures])
		quit(1 if failures else 0)
		return
	for i in sites.size():
		root.size=[Vector2i(1280,720),Vector2i(1560,720),Vector2i(1024,768)][i%3] if not render_checks else Vector2i(1280,720)
		await scene_checks(sites[i],scenery)
		if sites[i].id in ["shuangta","yardang"]: await living_weather(sites[i],scenery)
		for d: Dictionary in sites[i].details: await play_checks(sites[i],d,view)
	if require_seasons: check(original_pairs.size()==76,"all nineteen sites register four distinct physical originals and masks; available="+str(original_pairs.size()))
	print("SCENIC_PLAY_CHECKS: %d; SITES: %d; DETAILS: %d; REAL_RENDER: %s; FAILURES: %d" % [checks,sites.size(),awards.size(),render_checks,failures])
	quit(1 if failures else 0)
