class_name Ambience
extends Node
## The storm around the hut (section 11, M6 part 2): the wind loops on its own Wind bus (into
## Ambience), loud out in the open and muffled and quieter under a roof, following the Atmosphere's
## indoor blend through that bus's low-pass filter. Indoors the old timbers creak now and then.

@export var atmosphere: Atmosphere

var _wind: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter
var _creak_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# The storm goes on behind the menus too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_creak_left = _rng.randf_range(Constants.CREAK_MIN, Constants.CREAK_MAX)
	var bus: int = AudioServer.get_bus_index(&"Wind")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		_filter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sound.stream(&"wind_loop")
	_wind.bus = &"Wind"
	# Mixed by the engine even in the browser (where sounds play as Web Audio samples by default),
	# because the samples skip bus effects and the muffling is one.
	_wind.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_wind)
	_wind.play()
	_apply(_indoors())



# Stopped before the engine shuts down, or the running playback outlives the audio server.
func _exit_tree() -> void:
	_wind.stop()


func _process(delta: float) -> void:
	var indoors: float = _indoors()
	_apply(indoors)
	if get_tree().paused or indoors < 0.5:
		return
	_creak_left -= delta
	if _creak_left <= 0.0:
		_creak_left = _rng.randf_range(Constants.CREAK_MIN, Constants.CREAK_MAX)
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var angle: float = _rng.randf() * TAU
			var offset := Vector3(cos(angle), 0.4, sin(angle)) * Constants.CREAK_DISTANCE
			Sound.play_at(&"creak", camera.global_position + offset)


func _indoors() -> float:
	return atmosphere.inside() if atmosphere else 0.0


func _apply(indoors: float) -> void:
	_wind.volume_db = Sound.level(&"wind_loop") + Constants.WIND_INDOOR_DB * indoors
	if _filter:
		# Swept in octaves, so the muffling sounds even on the way in.
		var low: float = log(Constants.WIND_INDOOR_CUTOFF)
		var high: float = log(Constants.WIND_OUTDOOR_CUTOFF)
		_filter.cutoff_hz = exp(lerpf(high, low, indoors))
