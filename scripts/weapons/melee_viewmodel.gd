class_name MeleeViewmodel
extends Node3D
## First-person melee weapon for quick melee: hidden until swung, then sweeps across the view; a
## weapon with a guard can be held up after the blow. Purely visual.

## Swing path in camera space for a sideways bash: the grip stays low on the right while the handle sweeps
## from pointing out to the right, through the crosshair, to the left. The blade face leads (local Y = left).
@export var start_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(1.0, 0.45, -0.5), Vector3.LEFT), Vector3(0.42, -0.3, -0.15))
@export var hit_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(-0.3, 0.32, -0.75), Vector3.LEFT), Vector3(0.28, -0.36, -0.22))
@export var end_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(-1.0, -0.2, -0.35), Vector3.LEFT), Vector3(0.08, -0.42, -0.28))

## Guard (hold V, BLOCK secondary): held up in front of the lower half of the view, handle down in the
## fist, face to the enemy. Seconds to get there, and how far a caught hit knocks it back (metres).
@export var guard_pose: Transform3D = Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN).rotated(Vector3.FORWARD, 0.25), Vector3(0.17, -0.72, -0.5))
@export var guard_time: float = 0.12
@export var bonk_kick: float = 0.06

@onready var _model: Node3D = $Model

var _tween: Tween


func _ready() -> void:
	_model.visible = false


func play_swing(duration: float, hit_time: float) -> void:
	if _tween:
		_tween.kill()
	_model.transform = start_pose
	_model.visible = true
	_tween = create_tween()
	_tween.tween_property(_model, "transform", hit_pose, hit_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_model, "transform", end_pose, (duration - hit_time) * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_model.hide)


func play_guard() -> void:
	if _tween:
		_tween.kill()
	_model.visible = true
	_tween = create_tween()
	_tween.tween_property(_model, "transform", guard_pose, guard_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func end_guard() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, "transform", guard_pose.translated(Vector3(0, -0.4, 0)), guard_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_model.hide)


## A hit caught on the guard: it jolts back towards the player and settles.
func play_bonk() -> void:
	if _tween:
		_tween.kill()
	_model.transform = guard_pose.translated(Vector3(0, 0, bonk_kick))
	_tween = create_tween()
	_tween.tween_property(_model, "transform", guard_pose, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
