class_name BreakActionViewmodel
extends Viewmodel
## Double-barrel shotgun: no slide and nothing ejected on firing. The reload breaks the gun open,
## flicks out the spent shells, drops in new ones and snaps it shut.

## How far the barrels tip down when broken open. Degrees.
@export var break_angle: float = 38.0
## Where the fresh shells start above the open breech (barrel space). Metres.
@export var shell_insert_from: Vector3 = Vector3(0.0, 0.09, 0.05)

# Pivots at the hinge pin, so rotating it tips the barrels.
@onready var _barrels: Node3D = $Model/Barrels
@onready var _shells: Node3D = $Model/Barrels/Shells
@onready var _shells_rest: Vector3 = _shells.position


func _ready() -> void:
	super()
	_shells.visible = false


func play_fire(rounds: int = 1) -> void:
	# Both barrels at once kick a lot harder than one.
	_flash_and_kick(1.0 + 0.6 * (rounds - 1))


func play_reload(duration: float, _chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	var tilted: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt))
	_tween.tween_property(_model, "transform", tilted, d * 0.15).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_barrels, "rotation:x", deg_to_rad(-break_angle), d * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Both shells fly out as the barrels drop; the ejector does not care how many were fired.
	_tween.tween_callback(_eject_casing)
	_tween.tween_callback(_eject_casing)
	_tween.tween_interval(d * 0.13)
	_tween.tween_callback(func() -> void:
		_shells.position = _shells_rest + shell_insert_from
		_shells.visible = true)
	_tween.tween_property(_shells, "position", _shells_rest, d * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Snapped shut with an upward flick of the wrist.
	_tween.tween_property(_barrels, "rotation:x", 0.0, d * 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_model, "transform", tilted.translated(Vector3(0, slap_lift, 0)), d * 0.08)
	_tween.tween_callback(_shells.hide)
	_tween.tween_property(_model, "transform", _rest, d * 0.27).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _reset_parts() -> void:
	super()
	_barrels.rotation.x = 0.0
	_shells.position = _shells_rest
	_shells.visible = false
