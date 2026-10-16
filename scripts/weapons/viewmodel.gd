class_name Viewmodel
extends Node3D
## First-person gun model: recoil kick, reload dip and muzzle flash. Purely visual.

## Kick per shot: metres back and degrees of muzzle climb.
@export var kick_distance: float = 0.05
@export var kick_angle: float = 9.0
@export var kick_time: float = 0.12
## How far the gun drops out of view while reloading.
@export var reload_drop: float = 0.25
@export var reload_tilt: float = 35.0

@onready var _model: Node3D = $Model
@onready var _flash: Node3D = $Model/MuzzleFlash

var _rest: Transform3D
var _tween: Tween
var _flash_left: float = 0.0


func _ready() -> void:
	_rest = _model.transform
	_flash.visible = false


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0


func play_fire() -> void:
	_flash_left = Constants.MUZZLE_FLASH_TIME
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_restart_tween()
	var kicked: Transform3D = _rest.translated_local(Vector3(0, 0, kick_distance)).rotated_local(Vector3.RIGHT, deg_to_rad(kick_angle))
	_model.transform = kicked
	_tween.tween_property(_model, "transform", _rest, kick_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_reload(duration: float) -> void:
	_restart_tween()
	var lowered: Transform3D = _rest.translated(Vector3(0, -reload_drop, 0)).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", lowered, duration * 0.3).set_trans(Tween.TRANS_QUAD)
	_tween.tween_interval(duration * 0.4)
	_tween.tween_property(_model, "transform", _rest, duration * 0.3).set_trans(Tween.TRANS_QUAD)


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
