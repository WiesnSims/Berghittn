class_name Zeitlupe
extends Node
## Zeitlupe (1.2 extras, GAME_DESIGN section 12): the last kill of a wave in slow motion. The game
## runs at ZEITLUPE_SCALE for ZEITLUPE_TIME (real seconds), then eases back over ZEITLUPE_EASE, the
## sound muffled meanwhile (a low pass on the Master bus). Every screen plays its own at the wave's
## end (co-op guests hear wave_cleared from CoopWorld). Settings.zeitlupe turns it off. Main makes one.

var _filter: AudioEffectLowPassFilter
var _tween: Tween


func _ready() -> void:
	# The ease back must go on under a pausing screen (going down in the slow motion).
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.wave_cleared.connect(func(_wave: int) -> void: play())


## Slow motion now (if the setting is on); also used by tests.
func play() -> void:
	if not Settings.zeitlupe or get_tree().paused:
		return
	if _tween:
		_tween.kill()
	Engine.time_scale = Constants.ZEITLUPE_SCALE
	_muffle(true)
	_tween = create_tween()
	# Real seconds: the slow motion must not slow its own clock.
	_tween.set_ignore_time_scale(true)
	_tween.tween_interval(Constants.ZEITLUPE_TIME)
	_tween.tween_property(Engine, "time_scale", 1.0, Constants.ZEITLUPE_EASE).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(stop)


## Back to full speed and sound at once.
func stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	Engine.time_scale = 1.0
	_muffle(false)


func is_slow() -> bool:
	return Engine.time_scale < 1.0


# A reload (game over, restart) must never leave the next scene slow.
func _exit_tree() -> void:
	stop()


func _muffle(on: bool) -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	if on and _filter == null:
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = Constants.ZEITLUPE_CUTOFF
		AudioServer.add_bus_effect(bus, _filter)
	elif not on and _filter:
		for i: int in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _filter:
				AudioServer.remove_bus_effect(bus, i)
				break
		_filter = null
