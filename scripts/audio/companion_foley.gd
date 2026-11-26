extends RefCounted

var shoes: AudioStreamPlayer
var hooves: AudioStreamPlayer
var gesture: AudioStreamPlayer
var _clips := {}

func _init(steps: AudioStreamPlayer, deer: AudioStreamPlayer, accents: AudioStreamPlayer) -> void:
	shoes = steps
	hooves = deer
	gesture = accents

func step(terrain: String, animal: bool, side: int, narrating: bool) -> bool:
	if terrain not in ["sand","stone","grass"]: return false
	var output := hooves if animal else shoes
	var clip := ("hoof_" if animal else "shoe_") + terrain
	output.pitch_scale = .96 if side == 0 else 1.035
	return _play(output,"res://assets/foley/" + clip + ".wav",(-23.0 if animal else -18.0) - (7.0 if narrating else 0.0))

func accent(action: String, narrating: bool) -> bool:
	var path: String
	match action:
		"draw": path = "res://assets/foley/brush.wav"
		"listen": path = "res://assets/foley/collar.wav"
		"greet": path = "res://assets/notes/wood-1.mp3"
		"surprise": path = "res://assets/notes/bell-3.mp3"
		"celebrate": path = "res://assets/notes/bell-4.mp3"
		_: return false
	return _play(gesture,path,-18.0 if narrating else -12.0)

func _play(output: AudioStreamPlayer, path: String, gain: float) -> bool:
	if not _clips.has(path):
		_clips[path] = load(path)
	var clip: AudioStream = _clips[path]
	if not clip: return false
	output.stream = clip
	output.volume_db = gain
	output.play()
	return true

func stop() -> void:
	for output in [shoes,hooves,gesture]: output.stop()
