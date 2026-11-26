extends "res://scripts/ui/base_screen.gd"

const Stage = preload("res://scripts/ui/companion_stage.gd")
const Art = preload("res://scripts/ui/edition_art.gd")
# Captions describe what a child can look for in the actual performance.
const ACTS := {
	"greet": ["打招呼","silk","欧哟几扬起小手，鹿铃也来跟你打招呼。"],
	"look": ["望远山","mountain","一起望望，那边的山有多远？"],
	"think": ["想一想","scroll","歪歪脑袋，欧哟几有个小主意。"],
	"listen": ["听风铃","bell","嘘，竖起耳朵，听一听鹿铃的铃铛。"],
	"surprise": ["好惊喜","star","哇！他们的眼睛睁得圆圆的。"],
	"celebrate": ["庆祝啦","lotus","欧哟几欢呼起来，鹿铃也跟着雀跃。"],
	"draw": ["画一笔","leaf","看着笔尖，用手指跟着欧哟几画一笔。"],
	"rest": ["歇一歇","moon","小手放下来，和累了的旅伴歇一会儿。"]
}
var stage: Control
var caption: Label
var guess: Button
var leave_guess: Button
var tiles := {}
var riddle := ""
var last_riddle := ""

func _ready() -> void:
	setup()
	background("camp-" + str(Journey.progress.camp.sky), .08)
	Art.scrim(self,178,Color("193335b8"),Color.TRANSPARENT)
	var layout := column()
	header(layout,"旅伴小戏台","点小物看动作，也可以轮流猜一猜。",app.show_camp)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",20)
	layout.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation",4)
	body.add_child(left)
	stage = Stage.new()
	stage.name = "CompanionStage"
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(stage)
	stage.touched.connect(_touch_actor)
	stage.sounded.connect(app.audio.companion_action)
	var strip := GameTheme.panel(true)
	left.add_child(strip)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation",5)
	strip.add_child(words)
	caption = GameTheme.label("跟旅伴打声招呼吧。",24)
	caption.name = "Caption"
	caption.custom_minimum_size.y = 36
	words.add_child(caption)
	var games := HBoxContainer.new()
	words.add_child(games)
	guess = GameTheme.button("猜猜动作",start_riddle,Vector2(170,64),true)
	guess.name = "GuessAction"
	guess.size_flags_horizontal = SIZE_SHRINK_BEGIN
	games.add_child(guess)
	leave_guess = GameTheme.button("自由玩",end_riddle,Vector2(135,64))
	leave_guess.hide()
	games.add_child(leave_guess)
	var palette := GameTheme.panel(true)
	palette.custom_minimum_size.x = 398
	body.add_child(palette)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",10)
	palette.add_child(grid)
	for id: String in ACTS:
		var data: Array = ACTS[id]
		var button := GameTheme.tile(data[0],data[1],choose.bind(id),Vector2(152,91),false,_token_art(id,data[1]))
		button.name = "Act_" + id
		button.size_flags_vertical = SIZE_EXPAND_FILL
		button.toggle_mode = true
		tiles[id] = button
		grid.add_child(button)
	choose("greet")

func _token_art(id: String, symbol: String) -> Texture2D:
	if id in ["greet","draw"]:
		var hand := AtlasTexture.new()
		hand.atlas = preload("res://assets/characters/boy/hands.png")
		var cell := hand.atlas.get_size() / Vector2(4,2)
		var slot := Vector2(1,0) if id == "greet" else Vector2(2,1)
		hand.region = Rect2(slot * cell,cell)
		return hand
	if id == "listen": return preload("res://assets/characters/deer/bell.webp")
	var path := "res://assets/edition/props/%s.webp" % symbol
	return load(path) if ResourceLoader.exists(path) else null

func show_selection(id: String) -> void:
	for key: String in tiles: tiles[key].set_pressed_no_signal(key == id)

func choose(id: String) -> void:
	if not ACTS.has(id): return
	if not riddle.is_empty():
		if id != riddle:
			caption.text = "再看看小手和耳朵。还可以重看一遍。"
			show_selection("")
			stage.play(riddle,true)
			return
		var answer: String = ACTS[id][0]
		riddle = ""
		leave_guess.hide()
		caption.text = "猜中啦！刚才演的是“%s”。" % answer
		show_selection(id)
		stage.play("celebrate")
		guess.text = "再猜一个"
		return
	show_selection(id)
	caption.text = ACTS[id][2]
	stage.play(id)

func start_riddle() -> void:
	if riddle.is_empty():
		var pool := ACTS.keys()
		pool.erase(last_riddle)
		riddle = str(pool.pick_random())
		last_riddle = riddle
	caption.text = "看我们演一遍。猜到了，就点右边的小物。"
	show_selection("")
	guess.text = "再看一遍"
	leave_guess.show()
	stage.play(riddle,true)

func end_riddle() -> void:
	riddle = ""
	guess.text = "猜猜动作"
	leave_guess.hide()
	choose("greet")

func _touch_actor(which: String) -> void:
	if not riddle.is_empty(): start_riddle()
	else: choose("greet" if which == "boy" else "listen")

func set_covered(covered: bool) -> void:
	stage.set_covered(covered)
	if not covered and not riddle.is_empty(): stage.play(riddle,true)
