class_name MistgabelViewmodel
extends MeleeViewmodel
## Mistgabel: a long ash shaft with four iron tines. Not swung but thrust: drawn back low on the right,
## driven out along the aim, pulled back. Held as Aufgabeln (hold V), the fork goes up high in front,
## where the skewered body hangs; let go, it is flung forward and drops away.


func _ready() -> void:
	# The thrust: drawn back, driven out to the crosshair, back again.
	start_pose = Transform3D(Basis.looking_at(Vector3(-0.12, 0.1, -1.0), Vector3.UP), Vector3(0.3, -0.36, 0.15))
	hit_pose = Transform3D(Basis.looking_at(Vector3(-0.2, 0.18, -1.0), Vector3.UP), Vector3(0.24, -0.3, -0.25))
	end_pose = Transform3D(Basis.looking_at(Vector3(-0.1, 0.05, -1.0), Vector3.UP), Vector3(0.3, -0.4, 0.05))
	# Up high in front, tines to the sky, a body on them.
	guard_pose = Transform3D(Basis.looking_at(Vector3(-0.15, 1.0, -0.55), Vector3.BACK), Vector3(0.22, -0.45, -0.25))
	guard_time = 0.2
	super()


func end_guard() -> void:
	# The fling: forward and down, then gone.
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, "transform", hit_pose, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "transform", end_pose.translated(Vector3(0, -0.3, 0)), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_model.hide)
