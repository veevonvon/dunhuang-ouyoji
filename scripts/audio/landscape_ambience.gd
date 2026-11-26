extends RefCounted

const DIRECTORY := "res://assets/landmarks/sounds/"
const BEDS := {"desert":"sand", "ruin":"sand", "rock":"wind", "cliff":"wind", "water":"water",
	"garden":"water", "forest":"leaves", "architecture":"court"}
# The viewpoint determines what can be heard, including water inside a desert or canyon.
const VIEWPOINTS := {
	"crescent":{"bed":"sand","near":"water","greenery":true},
	"yulin":{"bed":"water","near":"wind","greenery":true},
	"tiantishan":{"bed":"water","near":"wind","greenery":true},
	"poplar":{"bed":"leaves","near":"water","greenery":true},
	"wenmiao":{"bed":"court","near":"leaves","greenery":true},
	"first_beacon":{"bed":"wind","near":"water","greenery":false}
}
var bed: AudioStreamPlayer
var color: AudioStreamPlayer
var profile := ""
var season := ""
var phase := ""
var location := ""

func _init(background: AudioStreamPlayer, wildlife: AudioStreamPlayer) -> void:
	bed = background
	color = wildlife

func select(habitat: String, season_id: String, time_id: String, site_id: String) -> void:
	profile = habitat
	season = season_id
	phase = time_id
	location = site_id

func update(active: bool) -> void:
	if not active or not BEDS.has(profile):
		bed.stop()
		color.stop()
		return
	bed.volume_db = -16 if phase == "night" else -13
	bed.pitch_scale = .82 if season == "winter" else (1.08 if season == "summer" else 1.0)
	var viewpoint: Dictionary = VIEWPOINTS.get(location, {})
	play_loop(bed, viewpoint.get("bed",BEDS[profile]))
	var greenery: bool = viewpoint.get("greenery",profile in ["garden","forest","water"])
	var call: String = viewpoint.get("near","")
	if greenery and season != "winter":
		if phase == "dawn": call = "birds"
		elif phase == "night" and season == "summer": call = "insects"
	color.volume_db = -18 if call in ["birds","insects"] else -22
	play_loop(color, call)

func play_loop(output: AudioStreamPlayer, clip: String) -> void:
	if clip.is_empty():
		output.stop()
		return
	var path := DIRECTORY + clip + ".ogg"
	if not output.stream or output.stream.resource_path != path:
		var stream := load(path) as AudioStreamOggVorbis
		stream.loop = true
		output.stream = stream
	if not output.playing: output.play()
