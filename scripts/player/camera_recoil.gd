class_name CameraRecoil
extends Camera3D
## View kick per shot, on top of mouse look (which turns the body and head). The kick snaps in fast
## and settles back by itself, so the player feels each shot without having to pull the mouse down.

# Offset the view is heading for, and where it is now (radians, x = pitch, y = yaw).
var _target: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func kick(pitch_degrees: float, yaw_degrees: float) -> void:
	_target += Vector2(deg_to_rad(pitch_degrees), deg_to_rad(randf_range(-yaw_degrees, yaw_degrees)))


func _process(delta: float) -> void:
	_target = _target.lerp(Vector2.ZERO, minf(Constants.RECOIL_RECOVER_SPEED * delta, 1.0))
	_current = _current.lerp(_target, minf(Constants.RECOIL_SNAP_SPEED * delta, 1.0))
	rotation = Vector3(_current.x, _current.y, 0.0)
