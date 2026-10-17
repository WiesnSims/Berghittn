class_name KnoedelViewmodel
extends Viewmodel
## Knödelwerfer: a stubby copper barrel with an enamel Knödeltopf on top as the hopper. The next
## dumpling peeks out of the muzzle; after a shot the next one slides up into it, and when it is
## there the gun is ready (fire_animation_time). The reload opens the pot's lid and drops three
## dumplings in.

## Seconds from a shot until the next dumpling sits in the muzzle (= 1 / fire_rate).
@export var ready_time: float = 1.0
## Degrees the lid swings open, and how far above the pot a dropped dumpling starts (metres).
@export var lid_open: float = 100.0
@export var drop_from: float = 0.09

@onready var _lid: Node3D = $Model/Lid
@onready var _loaded: Node3D = $Model/Loaded
@onready var _loaded_rest: Vector3 = _loaded.position
@onready var _falling: Node3D = $Model/Falling
@onready var _falling_rest: Vector3 = _falling.position


func _ready() -> void:
	super()
	_falling.visible = false


func fire_animation_time() -> float:
	return ready_time


func play_fire(_rounds: int = 1) -> void:
	_flash_and_kick()
	_reload_next()


func play_secondary(_rounds: int) -> void:
	# Three at once kick harder.
	_flash_and_kick(1.6)
	_reload_next()


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.12).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_lid, "rotation:x", deg_to_rad(-lid_open), d * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in 3:
		_tween.tween_callback(func() -> void:
			_falling.position = _falling_rest + Vector3.UP * drop_from
			_falling.visible = true)
		_tween.tween_property(_falling, "position", _falling_rest, d * 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_falling.hide)
	_tween.tween_property(_lid, "rotation:x", 0.0, d * 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_model, "transform", tilted.translated(Vector3(0, slap_lift, 0)), d * 0.08)
	_tween.tween_callback(func() -> void:
		_loaded.position = _loaded_rest
		_loaded.visible = true)
	_tween.tween_property(_model, "transform", _rest, d * 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _reload_next() -> void:
	# The shot is gone; the next one slides up the barrel and shows at the muzzle when the gun is ready.
	_loaded.visible = false
	_parts_tween = create_tween()
	_parts_tween.tween_interval(ready_time * 0.5)
	_parts_tween.tween_callback(func() -> void:
		_loaded.position = _loaded_rest + Vector3(0, 0, 0.2)
		_loaded.visible = true)
	_parts_tween.tween_property(_loaded, "position", _loaded_rest, ready_time * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reset_parts() -> void:
	super()
	_lid.rotation.x = 0.0
	_falling.visible = false
	_falling.position = _falling_rest
	_loaded.position = _loaded_rest
	_loaded.visible = true
