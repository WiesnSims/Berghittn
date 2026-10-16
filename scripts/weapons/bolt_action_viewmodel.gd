class_name BoltActionViewmodel
extends Viewmodel
## Bolt-action rifle: after every shot the hand works the bolt (up, back, the casing flies out,
## forward, down). The reload opens the bolt, pushes a stripper clip of rounds in and closes it.

## Pause after the shot before the bolt is worked, and how long the cycle takes. Must fit inside
## the time between shots (1 / fire_rate). Seconds.
@export var bolt_delay: float = 0.15
@export var bolt_time: float = 0.6
## How far the handle is lifted (degrees) and the bolt pulled back (metres).
@export var bolt_lift: float = 70.0
@export var bolt_travel: float = 0.09
## Where the clip starts above the open action (model space). Metres.
@export var clip_insert_from: Vector3 = Vector3(0.0, 0.12, 0.0)

# Pivots on the bore axis, so rotating it about Z lifts the handle.
@onready var _bolt: Node3D = $Model/Bolt
@onready var _bolt_rest: Vector3 = _bolt.position
@onready var _clip: Node3D = $Model/Clip
@onready var _clip_rest: Vector3 = _clip.position


func _ready() -> void:
	super()
	_clip.visible = false


func play_fire() -> void:
	_flash_and_kick()
	_parts_tween = create_tween()
	_parts_tween.tween_interval(bolt_delay)
	_open_bolt(_parts_tween, bolt_time * 0.5)
	_parts_tween.tween_callback(_eject_casing)
	_close_bolt(_parts_tween, bolt_time * 0.5)


func play_reload(duration: float, chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_open_bolt(_tween, d * 0.15)
	_tween.tween_callback(func() -> void:
		_clip.position = _clip_rest + clip_insert_from
		_clip.visible = true)
	# Thumb the rounds down out of the clip, then the empty clip is pulled away.
	_tween.tween_property(_clip, "position", _clip_rest, d * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_clip.hide)
	# From empty the bolt has to strip a round into the chamber, and it is shoved home harder.
	_close_bolt(_tween, d * 0.1 + chamber_time)
	_tween.parallel().tween_property(_model, "transform", tilted.translated(Vector3(0, slap_lift, 0)), d * 0.1 + chamber_time)
	_tween.tween_property(_model, "transform", _rest, d * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _open_bolt(tween: Tween, time: float) -> void:
	tween.tween_property(_bolt, "rotation:z", deg_to_rad(bolt_lift), time * 0.4).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_bolt, "position", _bolt_rest + Vector3(0, 0, bolt_travel), time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_bolt(tween: Tween, time: float) -> void:
	tween.tween_property(_bolt, "position", _bolt_rest, time * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_bolt, "rotation:z", 0.0, time * 0.4).set_trans(Tween.TRANS_QUAD)


func _reset_parts() -> void:
	super()
	_bolt.position = _bolt_rest
	_bolt.rotation.z = 0.0
	_clip.position = _clip_rest
	_clip.visible = false
