class_name HarmonikaViewmodel
extends Viewmodel
## Steirische Harmonika: a button accordion held low in front, the bass end in the left hand and the
## treble end with its rows of buttons in the right, red and black bellows between. The polka pumps
## the bellows hard and fast, the box bouncing with it, and ends as the next tune can start
## (fire_animation_time); laying a Tanzboden (right click) plays the same.
## The reload is the air button: the bellows pulled wide open and pressed shut.

## Seconds from a polka until the next can start (= 1 / fire_rate), and how often the bellows go in
## and out during it.
@export var polka_time: float = 3.333
@export var polka_squeezes: int = 6
## How far the bellows open (times their rest width) at a squeeze and at the reload's full pull.
@export var squeeze_open: float = 1.7
@export var full_open: float = 2.3
## How high the box bounces with each squeeze of the polka (metres) and how far it rolls (degrees).
@export var bounce: float = 0.02
@export var roll: float = 6.0

@onready var _bellows: Node3D = $Model/Bellows
@onready var _bass: Node3D = $Model/Bass
@onready var _treble: Node3D = $Model/Treble
@onready var _bass_rest: Vector3 = _bass.position
@onready var _treble_rest: Vector3 = _treble.position

var _open: float = 1.0


func fire_animation_time() -> float:
	return polka_time


func play_fire(_rounds: int = 1) -> void:
	_restart_tween()
	var squeeze: float = polka_time * 0.8 / polka_squeezes
	for i: int in polka_squeezes:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var up: Transform3D = _rest.translated(Vector3(0, bounce, 0)).rotated_local(Vector3.FORWARD, deg_to_rad(roll * side))
		_tween.tween_method(_set_open, 1.0, squeeze_open, squeeze * 0.5).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(_model, "transform", up, squeeze * 0.5).set_trans(Tween.TRANS_SINE)
		_tween.tween_method(_set_open, squeeze_open, 1.0, squeeze * 0.5).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(_model, "transform", _rest, squeeze * 0.5).set_trans(Tween.TRANS_SINE)
	# A last flourish held open, then shut as the next polka can start.
	_tween.tween_method(_set_open, 1.0, squeeze_open, polka_time * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_open, squeeze_open, 1.0, polka_time * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	# Thumb on the air button: the bellows pulled wide open with the box raised, then pressed shut.
	_restart_tween()
	var d: float = duration
	var raised: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.RIGHT, deg_to_rad(12.0))
	_tween.tween_property(_model, "transform", raised, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_set_open, 1.0, full_open, d * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(d * 0.1)
	_tween.tween_method(_set_open, full_open, 1.0, d * 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_model, "transform", raised.translated(Vector3(0, -0.02, 0)), d * 0.15)
	_tween.tween_property(_model, "transform", _rest, d * 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Bellows at `amount` times their rest width, the two ends riding on them.
func _set_open(amount: float) -> void:
	_open = amount
	_bellows.scale.x = amount
	var spread: float = (amount - 1.0) * _bellows_half()
	_bass.position = _bass_rest + Vector3(-spread, 0, 0)
	_treble.position = _treble_rest + Vector3(spread, 0, 0)


func _bellows_half() -> float:
	return (_treble_rest.x - _bass_rest.x) * 0.5 - 0.035


func _reset_parts() -> void:
	super()
	if _bellows:
		_set_open(1.0)
