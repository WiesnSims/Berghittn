class_name Viewmodel
extends Node3D
## First-person gun model: recoil kick, reload dip and muzzle flash. Purely visual.

## Kick per shot: metres back and degrees of muzzle climb.
@export var kick_distance: float = 0.05
@export var kick_angle: float = 9.0
@export var kick_time: float = 0.12
## Reload pose: where the gun is held up for the mag swap (so the drop is on screen) and its roll, how far the old mag falls and the new one
## starts below the grip, and how high the gun jumps when the mag is slapped in. Metres/degrees.
@export var reload_offset: Vector3 = Vector3(-0.06, 0.07, 0.0)
@export var reload_tilt: float = 40.0
@export var mag_drop: float = 0.35
@export var mag_insert_from: float = 0.12
@export var slap_lift: float = 0.03

@onready var _model: Node3D = $Model
@onready var _flash: Node3D = $Model/MuzzleFlash
@onready var _mag: Node3D = $Model/Grip/Magazine
@onready var _mag_rest: Vector3 = _mag.position

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
	# Show-off reload: tilt, old mag drops out, new one slapped in, then a full flip of the gun.
	_restart_tween()
	var d: float = duration
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_mag, "position", _mag_rest + Vector3(0, -mag_drop, 0), d * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _mag.position = _mag_rest + Vector3(0, -mag_insert_from, 0))
	_tween.tween_property(_mag, "position", _mag_rest, d * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The slap: the gun jumps up as the mag seats.
	_tween.tween_property(_model, "transform", _rest.translated(Vector3(0, slap_lift, 0)), d * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_flip, 0.0, 1.0, d * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _flip(t: float) -> void:
	# Backflip around the slide's own axis, settling from the slap height back to rest.
	_model.transform = _rest.translated(Vector3(0, slap_lift * (1.0 - t), 0)).rotated_local(Vector3.RIGHT, TAU * t)


func _restart_tween() -> void:
	if _tween:
		_tween.kill()
	_mag.position = _mag_rest
	_tween = create_tween()
