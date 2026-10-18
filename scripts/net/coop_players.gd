class_name CoopPlayers
extends Node3D
## The other players in a co-op match (M7): each player sends where they are 20 times a second
## (each owns their own movement, NETWORKING.md section 4), and everyone else is drawn as their hiker,
## NET_INTERPOLATION_DELAY in the past so it glides between two received poses.
## Main creates it as /root/Main/CoopPlayers on every peer, so the RPC paths match.

const HIKER := preload("res://scenes/net/hiker.tscn")
## Poses older than this (ms behind the newest) are dropped.
const KEEP_MS: int = 1000
## How long one crouch flag holds the crouch pose (s); refreshed while poses keep coming.
const CROUCH_HOLD: float = 0.2

var _player: Player
var _send_left: float = 0.0
## Peer -> Remote.
var _remotes: Dictionary = {}


func setup(player: Player) -> void:
	_player = player
	Net.roster_changed.connect(_sync_roster)
	_sync_roster()


func _process(delta: float) -> void:
	if not Net.in_match():
		return
	_send_left -= delta
	if _send_left <= 0.0 and _player:
		_send_left += Constants.NET_POSE_INTERVAL
		_send_left = maxf(_send_left, 0.0)
		_pose.rpc(Time.get_ticks_msec(), _player.global_position, _player.rotation.y, _player.is_crouching())
	var now: int = Time.get_ticks_msec()
	for remote: Remote in _remotes.values():
		remote.update(now, delta)


func _sync_roster() -> void:
	for peer: int in _remotes.keys():
		if not Net.roster.has(peer):
			(_remotes[peer] as Remote).hiker.queue_free()
			_remotes.erase(peer)
	for peer: int in Net.roster:
		if peer == Net.my_id():
			continue
		if not _remotes.has(peer):
			var hiker := HIKER.instantiate() as Hiker
			add_child(hiker)
			hiker.hide()
			_remotes[peer] = Remote.new(hiker)
		(_remotes[peer] as Remote).hiker.apply(Net.roster[peer], peer)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(sent_ms: int, at: Vector3, yaw: float, crouching: bool) -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	if remote:
		remote.add(Time.get_ticks_msec(), sent_ms, at, yaw, crouching)


## One other player's hiker and the poses heard from them.
class Remote:
	var hiker: Hiker
	# [sender ms, position, yaw], oldest first.
	var _poses: Array = []
	# Local clock minus the sender's, from the fastest packet so far (so lag spikes do not count).
	var _offset: int = 0
	var _has_offset: bool = false
	var _last_position: Vector3
	var _crouch_left: float = 0.0

	func _init(body: Hiker) -> void:
		hiker = body

	func add(now: int, sent: int, at: Vector3, yaw: float, crouching: bool) -> void:
		if not _has_offset or now - sent < _offset:
			_offset = now - sent
			_has_offset = true
		if not _poses.is_empty() and sent <= int(_poses[-1][0]):
			return
		_poses.append([sent, at, yaw])
		while _poses.size() > 2 and sent - int(_poses[0][0]) > KEEP_MS:
			_poses.pop_front()
		if crouching:
			_crouch_left = CROUCH_HOLD
		if not hiker.visible:
			hiker.global_position = at
			hiker.rotation.y = yaw
			_last_position = at
			hiker.show()

	func update(now: int, delta: float) -> void:
		if _poses.is_empty():
			return
		var t: float = float(now - _offset) - Constants.NET_INTERPOLATION_DELAY * 1000.0
		var at: Vector3 = _poses[-1][1]
		var yaw: float = _poses[-1][2]
		for i: int in range(_poses.size() - 1, 0, -1):
			var a: Array = _poses[i - 1]
			var b: Array = _poses[i]
			if float(a[0]) <= t:
				var span: float = maxf(float(b[0]) - float(a[0]), 1.0)
				var w: float = clampf((t - float(a[0])) / span, 0.0, 1.0)
				at = (a[1] as Vector3).lerp(b[1], w)
				yaw = lerp_angle(a[2], b[2], w)
				break
		hiker.global_position = at
		hiker.rotation.y = yaw
		var flat: Vector3 = at - _last_position
		flat.y = 0.0
		_last_position = at
		_crouch_left -= delta
		if _crouch_left > 0.0:
			hiker.rig.play(EnemyRig.Action.CROUCH, CROUCH_HOLD)
		hiker.rig.update(delta, flat.length() / maxf(delta, 0.001))
