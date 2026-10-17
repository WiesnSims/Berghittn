class_name RodelViewmodel
extends Viewmodel
## Rodelkanone: an open wooden chute bound with iron, a powder chamber at its back, on a stock held
## at the hip. The next sled sits in the chute; after a shot the next one slides forward into place,
## and when it is there the gun is ready (fire_animation_time). The reload tips the chute up and drops
## two sleds in from above.

## Seconds from a shot until the next sled sits in the muzzle (= 1 / fire_rate).
@export var ready_time: float = 2.5
## Degrees the chute is tipped up for loading, and how far above it a dropped sled starts (metres).
@export var load_tilt: float = 25.0
@export var feed_from: float = 0.2

@onready var _loaded: Node3D = $Model/Loaded
@onready var _loaded_rest: Vector3 = _loaded.position
@onready var _feeding: Node3D = $Model/Feeding
@onready var _feeding_rest: Vector3 = _feeding.position


func _ready() -> void:
	super()
	_feeding.visible = false


func fire_animation_time() -> float:
	return ready_time


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick()
	_reload_next()


func play_secondary(_rounds: int) -> void:
	# The Kehre's double charge kicks harder.
	_flash_and_kick(1.6)
	_reload_next()


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var up: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.RIGHT, deg_to_rad(load_tilt))
	_tween.tween_property(_model, "transform", up, d * 0.15).set_trans(Tween.TRANS_QUAD)
	for i: int in 2:
		_tween.tween_callback(func() -> void:
			_feeding.position = _feeding_rest + Vector3(0, feed_from, 0)
			_feeding.visible = true)
		_tween.tween_property(_feeding, "position", _feeding_rest, d * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_feeding.hide)
	_tween.tween_callback(func() -> void:
		_loaded.position = _loaded_rest
		_loaded.visible = true)
	_tween.tween_property(_model, "transform", _rest, d * 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _reload_next() -> void:
	# The shot is gone; the next one slides forward from the chamber and sits ready when the gun is.
	_loaded.visible = false
	_parts_tween = create_tween()
	_parts_tween.tween_interval(ready_time * 0.6)
	_parts_tween.tween_callback(func() -> void:
		_loaded.position = _loaded_rest + Vector3(0, 0, 0.12)
		_loaded.visible = true)
	_parts_tween.tween_property(_loaded, "position", _loaded_rest, ready_time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_parts() -> void:
	super()
	_feeding.visible = false
	_feeding.position = _feeding_rest
	_loaded.position = _loaded_rest
	_loaded.visible = true
