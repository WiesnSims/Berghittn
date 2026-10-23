class_name LeverActionViewmodel
extends Viewmodel
## Lever-action rifle (Repetierer). After every shot, while the recoil settles, the hand throws the
## lever down and forward: the bolt slides back out of the receiver, pushes the hammer to full cock
## and the casing flies out of the top; a short stop at the bottom, then the lever is snapped shut
## and the gun gives a little jolt as the action locks. The gun dips and cants a little with the
## throw (less when aimed). The cycle fits the time to the next shot.
## The reload rolls the gun so its right side faces up and thumbs the missing rounds one by one
## through the loading gate, nose first; from empty the gun comes back up and the lever is worked to
## chamber one. The Querschläger kicks harder and the lever is worked slowly after it.

## Pause after the shot before the lever is thrown, and how long the throw takes; together the
## longest the cycle runs (it is squeezed into a faster shot, see Viewmodel.cycle_time). Seconds.
@export var lever_delay: float = 0.05
@export var lever_time: float = 0.26
## How far the lever swings down, the hammer goes back (degrees) and the bolt slides back (metres).
@export var lever_angle: float = 62.0
@export var hammer_angle: float = 40.0
@export var bolt_travel: float = 0.045
## How far the gun dips (muzzle down) and cants with the throw, and kicks up as the action locks.
@export var work_dip: float = 5.0
@export var work_cant: float = 7.0
@export var lockup_angle: float = 1.5
## Reload pose on top of reload_offset and reload_tilt: muzzle turned left so the side faces the
## camera, and raised. Degrees.
@export var reload_turn: float = 40.0
@export var reload_raise: float = 10.0
## Where each round thumbed in during a reload starts beside the gate and where it is pushed to
## inside it (model space, from the gate).
@export var round_insert_from: Vector3 = Vector3(0.035, -0.03, 0.06)
@export var round_insert_to: Vector3 = Vector3(-0.012, 0.0, -0.04)
## The Querschläger: how much harder it kicks, and the most its lever cycle may be slowed down to
## fill the long wait after it.
@export var ricochet_kick: float = 1.6
@export var ricochet_slowest: float = 3.0

# Pivots: the lever at its front end, the hammer at its base.
@onready var _lever: Node3D = $Model/Lever
@onready var _hammer: Node3D = $Model/Hammer
@onready var _bolt: Node3D = $Model/Bolt
@onready var _bolt_rest: Vector3 = _bolt.position
@onready var _round: Node3D = $Model/Round
@onready var _round_rest: Vector3 = _round.position


func _ready() -> void:
	super()
	_round.visible = false
	_hammer.rotation.x = deg_to_rad(hammer_angle)


func fire_animation_time() -> float:
	return lever_delay + lever_time


func play_fire(_rounds: int = 1) -> void:
	_shot(1.0, 1.0)


## The Querschläger: a harder kick, then the lever worked slowly through the long wait after it.
func play_secondary(_rounds: int) -> void:
	_shot(ricochet_kick, ricochet_slowest)


## The kick of a shot and the lever cycle after it, fitted to the time until the next shot (squeezed,
## or slowed down by at most `slowest`).
func _shot(strength: float, slowest: float) -> void:
	_flash_and_kick(strength)
	# The hammer has fallen on the round.
	_hammer.rotation.x = 0.0
	var scale: float = 1.0
	if cycle_time > 0.0:
		scale = clampf(cycle_time * 0.95 / fire_animation_time(), 0.3, slowest)
	var delay: float = lever_delay * scale
	var time: float = lever_time * scale
	# The recoil settles into the dip of the throw instead of back to rest.
	_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, "transform", _work_pose(), delay + time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(time * 0.24)
	_lockup(_tween, time * 0.36, time * 0.08)
	_parts_tween = create_tween()
	_parts_tween.tween_interval(delay)
	_work_lever(_parts_tween, time, true)


func play_reload(duration: float, chamber_time: float = 0.0) -> void:
	_restart_tween()
	var d: float = duration
	# Brought in front of the chest, muzzle up and to the left, rolled so the gate on the right side
	# faces the camera.
	var loading: Transform3D = _rest.translated(reload_offset).rotated_local(Vector3.UP, deg_to_rad(reload_turn)).rotated_local(Vector3.FORWARD, deg_to_rad(reload_tilt)).rotated_local(Vector3.RIGHT, deg_to_rad(reload_raise))
	# The rounds missing, each in its slot of time (the WeaponHolder counts it in at the click); the
	# rest of the time goes on bringing the gun up and back.
	var rounds: int = maxi(reload_rounds, 1)
	var each: float = reload_round_time if reload_rounds > 0 else d * 0.65 / rounds
	var own: float = maxf(d - each * rounds, 0.0)
	_tween.tween_property(_model, "transform", loading, own * Constants.RELOAD_LIFT_SHARE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var start: Vector3 = _round_rest + round_insert_from
	var mouth: Vector3 = _round_rest + Vector3(round_insert_from.x * 0.35, 0.0, round_insert_from.z * 0.3)
	# Nose up and in, towards the gate.
	var angled := Vector3(deg_to_rad(18.0), deg_to_rad(28.0), 0.0)
	for i: int in rounds:
		_tween.tween_callback(func() -> void:
			_round.position = start
			_round.rotation = angled
			_round.visible = true)
		# The hand brings the round to the gate...
		_tween.tween_property(_round, "position", mouth, each * (Constants.RELOAD_ROUND_IN_AT - 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(_round, "rotation", angled * 0.4, each * (Constants.RELOAD_ROUND_IN_AT - 0.3))
		# ...and the thumb pushes it in, the gun giving a little under the push.
		_tween.tween_property(_round, "position", _round_rest + round_insert_to, each * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_round, "rotation", Vector3.ZERO, each * 0.3)
		_tween.parallel().tween_property(_model, "transform", loading.translated_local(Vector3(0, -slap_lift, -slap_lift)), each * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func() -> void:
			_round.hide()
			Sound.play(&"load_clunk", -4.0, randf_range(1.15, 1.3)))
		_tween.tween_property(_model, "transform", loading, each * (1.0 - Constants.RELOAD_ROUND_IN_AT)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "transform", _rest, own * (1.0 - Constants.RELOAD_LIFT_SHARE)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if chamber_time > 0.0:
		# From empty: shouldered again, the lever worked to feed the first round (nothing to throw out).
		_tween.tween_property(_model, "transform", _work_pose(), chamber_time * 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_work_lever(_tween, chamber_time * 0.75, false)
		_lockup(_tween, 0.0, chamber_time * 0.1)


## The gun as the lever is thrown: muzzle down a little, canted out to the right.
func _work_pose() -> Transform3D:
	var amount: float = lerpf(1.0, 0.35, _aim)
	return _rest.rotated_local(Vector3.RIGHT, deg_to_rad(-work_dip * amount)).rotated_local(Vector3.FORWARD, deg_to_rad(-work_cant * amount))


## The action locking shut: a little jolt up, then settled at rest.
func _lockup(tween: Tween, close_time: float, settle_time: float) -> void:
	if close_time > 0.0:
		tween.tween_property(_model, "transform", _rest.rotated_local(Vector3.RIGHT, deg_to_rad(lockup_angle)), close_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_model, "transform", _rest, settle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Lever down with the bolt back and the hammer cocked, a short stop, the casing out (after a shot),
## then snapped shut. Chained on `tween`, `time` long in all.
func _work_lever(tween: Tween, time: float, eject: bool) -> void:
	var open: float = time * 0.4
	var shut: float = time * 0.36
	tween.tween_callback(func() -> void: Sound.play(&"lever_open", -6.0, 1.2))
	tween.tween_property(_lever, "rotation:x", deg_to_rad(lever_angle), open).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_bolt, "position", _bolt_rest + Vector3(0, 0, bolt_travel), open).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_hammer, "rotation:x", deg_to_rad(hammer_angle), open * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if eject:
		tween.tween_callback(_eject_casing)
	tween.tween_interval(time - open - shut)
	tween.tween_property(_lever, "rotation:x", 0.0, shut).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_bolt, "position", _bolt_rest, shut).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: Sound.play(&"lever_close", -6.0, 1.15))


func _reset_parts() -> void:
	super()
	_lever.rotation.x = 0.0
	# Ready to fire: cocked.
	_hammer.rotation.x = deg_to_rad(hammer_angle)
	_bolt.position = _bolt_rest
	_round.position = _round_rest
	_round.rotation = Vector3.ZERO
	_round.visible = false
