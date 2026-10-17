class_name RuteViewmodel
extends MeleeViewmodel
## Krampus-Rute: a bundle of birch twigs bound with red ribbon and a bit of chain at the grip, swung
## sideways like the shovel. Held as the Larve (hold V), it goes up high on the right and rattles.

## Degrees the raised rod rattles while the Larve is held.
@export var rattle: float = 4.0

var _rattling: bool = false


func _ready() -> void:
	guard_pose = Transform3D(Basis.looking_at(Vector3(-0.2, 1.0, -0.4), Vector3.BACK), Vector3(0.3, -0.25, -0.35))
	guard_time = 0.15
	super()


func play_guard() -> void:
	super()
	_rattling = true


func end_guard() -> void:
	_rattling = false
	super()


func _process(_delta: float) -> void:
	if not _rattling or (_tween and _tween.is_running()):
		return
	var shake := deg_to_rad(rattle)
	_model.transform = guard_pose.rotated_local(Vector3.FORWARD, randf_range(-shake, shake)).rotated_local(Vector3.RIGHT, randf_range(-shake, shake))
