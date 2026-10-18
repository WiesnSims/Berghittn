class_name PoseBuffer
extends RefCounted
## Poses of one thing heard over the network (M7), drawn NET_INTERPOLATION_DELAY in the past so it
## glides between two received ones: a position, a facing and one spare Vector3 (an enemy's lean).
## Times are the sender's clock; the offset to ours comes from the fastest packet so far, so a lag
## spike does not shift the timeline.

## Poses older than this behind the newest are dropped (ms).
const KEEP_MS: int = 1000

# [sender ms, position, yaw, extra], oldest first.
var _poses: Array = []
var _offset: int = 0
var _has_offset: bool = false


func add(now: int, sent: int, at: Vector3, yaw: float, extra: Vector3 = Vector3.ZERO) -> void:
	if not _has_offset or now - sent < _offset:
		_offset = now - sent
		_has_offset = true
	if not _poses.is_empty() and sent <= int(_poses[-1][0]):
		return
	_poses.append([sent, at, yaw, extra])
	while _poses.size() > 2 and sent - int(_poses[0][0]) > KEEP_MS:
		_poses.pop_front()


func is_empty() -> bool:
	return _poses.is_empty()


func clear() -> void:
	_poses.clear()


## [position, yaw, extra] as of NET_INTERPOLATION_DELAY ago; the newest pose if nothing older.
func sample(now: int) -> Array:
	var t: float = float(now - _offset) - Constants.NET_INTERPOLATION_DELAY * 1000.0
	for i: int in range(_poses.size() - 1, 0, -1):
		var a: Array = _poses[i - 1]
		var b: Array = _poses[i]
		if float(a[0]) <= t:
			var w: float = clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0), 0.0, 1.0)
			return [(a[1] as Vector3).lerp(b[1], w), lerp_angle(a[2], b[2], w), (a[3] as Vector3).lerp(b[3], w)]
	var last: Array = _poses[-1] if t >= float(_poses[-1][0]) or _poses.size() == 1 else _poses[0]
	return [last[1], last[2], last[3]]
