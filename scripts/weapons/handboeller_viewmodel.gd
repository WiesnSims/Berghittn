class_name HandboellerViewmodel
extends Viewmodel
## Handböller: a short bronze mortar barrel on a wooden stock, held at the hip. Each shot kicks hard
## and belches powder smoke; the double charge kicks harder still. The long reload: muzzle up, a
## measure of powder, the iron ball dropped in, two strokes of the ramrod, back down.

## Degrees the muzzle is tipped up for loading, how far the ball and the ramrod start above the
## muzzle (metres), and how deep the rod goes in.
@export var load_tilt: float = 55.0
@export var drop_from: float = 0.12
@export var rod_from: float = 0.25
@export var rod_depth: float = 0.08

@onready var _ball: Node3D = $Model/Barrel/Ball
@onready var _ball_rest: Vector3 = _ball.position
@onready var _rod: Node3D = $Model/Barrel/Ramrod
@onready var _rod_rest: Vector3 = _rod.position


func _ready() -> void:
	super()
	_ball.visible = false
	_rod.visible = false


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick(1.0)


func play_secondary(_rounds: int) -> void:
	_flash_and_kick(1.7)


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var up: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.RIGHT, deg_to_rad(load_tilt))
	_tween.tween_property(_model, "transform", up, d * 0.12).set_trans(Tween.TRANS_QUAD)
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
