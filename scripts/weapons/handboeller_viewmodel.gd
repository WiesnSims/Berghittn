class_name HandboellerViewmodel
extends Viewmodel
## Handböller: a short bronze mortar barrel bedded in a wooden stock with a short handle, held at the
## hip, fired by a big hammer onto the nipple on its breech. Each shot drops the hammer, kicks hard and
## belches powder smoke; the double charge kicks harder still. The long reload: muzzle up, the hammer
## cocked, a measure of powder, the iron ball dropped in, two strokes of the ramrod, back down.

## Degrees the muzzle is tipped up for loading, how far the ball and the ramrod start above the
## muzzle (metres), and how deep the rod goes in.
@export var load_tilt: float = 55.0
@export var drop_from: float = 0.12
@export var rod_from: float = 0.25
@export var rod_depth: float = 0.08
## Degrees the hammer falls forward onto the nipple, and how fast (seconds).
@export var hammer_fall: float = 23.0
@export var hammer_time: float = 0.04

@onready var _ball: Node3D = $Model/Barrel/Ball
@onready var _ball_rest: Vector3 = _ball.position
@onready var _rod: Node3D = $Model/Barrel/Ramrod
@onready var _rod_rest: Vector3 = _rod.position
@onready var _hammer: Node3D = $Model/Hammer
var _hammer_tween: Tween


func _ready() -> void:
	super()
	_ball.visible = false
	_rod.visible = false


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick(1.0)
	_drop_hammer()


func play_secondary(_rounds: int) -> void:
	_flash_and_kick(1.7)
	_drop_hammer()


# The hammer is left out of _reset_parts: it stays down after a shot until the reload cocks it.
func _drop_hammer() -> void:
	_move_hammer(-deg_to_rad(hammer_fall), hammer_time)


func _move_hammer(angle: float, time: float, delay: float = 0.0) -> void:
	if _hammer_tween:
		_hammer_tween.kill()
	_hammer_tween = create_tween()
	_hammer_tween.tween_property(_hammer, "rotation:x", angle, time).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var up: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.RIGHT, deg_to_rad(load_tilt))
	_tween.tween_property(_model, "transform", up, d * 0.12).set_trans(Tween.TRANS_QUAD)
	# Cocked again with the thumb as the muzzle comes up.
	_move_hammer(0.0, d * 0.06, d * 0.1)
	# The ball goes in.
	_tween.tween_callback(func() -> void:
		_ball.position = _ball_rest + Vector3(0, drop_from, 0)
		_ball.visible = true)
	_tween.tween_property(_ball, "position", _ball_rest, d * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_ball.hide)
	# Two strokes of the ramrod.
	_tween.tween_callback(func() -> void:
		_rod.position = _rod_rest + Vector3(0, rod_from, 0)
		_rod.visible = true)
	for i: int in 2:
		_tween.tween_property(_rod, "position", _rod_rest - Vector3(0, rod_depth, 0), d * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(_rod, "position", _rod_rest + Vector3(0, rod_from * 0.4, 0), d * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_rod, "position", _rod_rest + Vector3(0, rod_from, 0), d * 0.06)
	_tween.tween_callback(_rod.hide)
	_tween.tween_property(_model, "transform", _rest, d * 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _reset_parts() -> void:
	super()
	_ball.visible = false
	_ball.position = _ball_rest
	_rod.visible = false
	_rod.position = _rod_rest
