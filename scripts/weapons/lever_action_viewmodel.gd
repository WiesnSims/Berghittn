class_name LeverActionViewmodel
extends Viewmodel
## Lever-action rifle (Repetierer): after every shot the lever swings down and back up, cocking the
## hammer and throwing the casing out of the top. The reload thumbs rounds one by one through the
## loading gate on the right side.

## Pause after the shot before the lever is worked, and how long the down-and-up takes. Must fit
## inside the time between shots, also when fanning (1 / rapid_fire_rate). Seconds.
@export var lever_delay: float = 0.02
@export var lever_time: float = 0.16
## How far the lever swings down and the hammer goes back (degrees).
@export var lever_angle: float = 55.0
@export var hammer_angle: float = 40.0
## Rounds shown going in during a reload, and where each one starts beside the gate (model space).
@export var reload_rounds: int = 5
@export var round_insert_from: Vector3 = Vector3(0.05, -0.02, 0.0)

# Pivots: the lever at its front end, the hammer at its base.
@onready var _lever: Node3D = $Model/Lever
@onready var _hammer: Node3D = $Model/Hammer
@onready var _round: Node3D = $Model/Round
@onready var _round_rest: Vector3 = _round.position


func _ready() -> void:
	super()
	_round.visible = false


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick()
	_parts_tween = create_tween()
	_parts_tween.tween_interval(lever_delay)
	_work_lever(_parts_tween, lever_time)


func play_reload(duration: float, chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	# Rolled onto its left side so the gate faces the camera.
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.15).set_trans(Tween.TRANS_QUAD)
	var each: float = d * 0.6 / reload_rounds
	for i: int in reload_rounds:
		_tween.tween_callback(func() -> void:
			_round.position = _round_rest + round_insert_from
			_round.visible = true)
		_tween.tween_property(_round, "position", _round_rest, each * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Each push nudges the whole gun a little.
		_tween.parallel().tween_property(_model, "transform", tilted.translated(Vector3(0, slap_lift, 0)), each * 0.7)
		_tween.tween_callback(_round.hide)
		_tween.tween_property(_model, "transform", tilted, each * 0.3)
	if chamber_time > 0.0:
		# From empty: work the lever to feed the first round.
		_work_lever(_tween, chamber_time)
	_tween.tween_property(_model, "transform", _rest, d * 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _work_lever(tween: Tween, time: float) -> void:
	tween.tween_property(_lever, "rotation:x", deg_to_rad(lever_angle), time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_hammer, "rotation:x", deg_to_rad(hammer_angle), time * 0.45)
	tween.tween_callback(_eject_casing)
	tween.tween_property(_lever, "rotation:x", 0.0, time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _reset_parts() -> void:
	super()
	_lever.rotation.x = 0.0
	_hammer.rotation.x = 0.0
	_round.position = _round_rest
	_round.visible = false
