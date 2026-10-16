class_name MeleeViewmodel
extends Node3D
## First-person melee weapon for quick melee: hidden until swung, then sweeps across the view. Purely visual.

## Swing path in camera space for a sideways bash: the grip stays low on the right while the handle sweeps
## from pointing out to the right, through the crosshair, to the left. The blade face leads (local Y = left).
@export var start_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(1.0, 0.45, -0.5), Vector3.LEFT), Vector3(0.42, -0.3, -0.15))
@export var hit_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(-0.3, 0.32, -0.75), Vector3.LEFT), Vector3(0.28, -0.36, -0.22))
@export var end_pose: Transform3D = Transform3D(Basis.looking_at(Vector3(-1.0, -0.2, -0.35), Vector3.LEFT), Vector3(0.08, -0.42, -0.28))

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
