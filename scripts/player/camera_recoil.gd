class_name CameraRecoil
extends Camera3D
## View kick per shot, on top of mouse look (which turns the body and head). The kick snaps in fast
## and settles back by itself, so the player feels each shot without having to pull the mouse down.

# Offset the view is heading for, and where it is now (radians, x = pitch, y = yaw).
var _target: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
## Extra drift on top (radians, x = pitch, y = yaw), set every frame by the player (scope sway).
var sway: Vector2 = Vector2.ZERO
# Screen shake (blasts): its strength in radians, seconds left, and a running phase for the tremble.
var _shake: float = 0.0
var _shake_left: float = 0.0
var _shake_phase: float = 0.0


func kick(pitch_degrees: float, yaw_degrees: float) -> void:
	_target += Vector2(deg_to_rad(pitch_degrees), deg_to_rad(randf_range(-yaw_degrees, yaw_degrees)))


## A tremble of the whole view that dies out over SHAKE_TIME; the stronger shake wins.
func shake(degrees: float) -> void:
	var strength: float = deg_to_rad(degrees)
	if strength >= _shake * _shake_left / Constants.SHAKE_TIME:
		_shake = strength
		_shake_left = Constants.SHAKE_TIME


func _process(delta: float) -> void:
	_target = _target.lerp(Vector2.ZERO, minf(Constants.RECOIL_RECOVER_SPEED * delta, 1.0))
	_current = _current.lerp(_target, minf(Constants.RECOIL_SNAP_SPEED * delta, 1.0))
	var tremble := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		_shake_phase += Constants.SHAKE_FREQUENCY * TAU * delta
		# Two out-of-step waves, so it rattles instead of swinging in a clean circle; rolls a little too.
		var amount: float = _shake * _shake_left / Constants.SHAKE_TIME
		tremble = Vector3(sin(_shake_phase), sin(_shake_phase * 1.37 + 1.0), sin(_shake_phase * 0.71 + 2.0) * 0.6) * amount
	rotation = Vector3(_current.x + sway.x + tremble.x, _current.y + sway.y + tremble.y, tremble.z)
