class_name CoopPlayers
extends Node3D
## The players in a co-op match (M7). Each player runs their own body (NETWORKING.md section 4) and
## sends where they are and how they are (alive, downed, out, health) 20 times a second; everyone else
## is drawn as their hiker, NET_INTERPOLATION_DELAY in the past. On the host the hikers are also what
## the enemies go for (group "player"): a hit is handed to that player's own game, which takes it
## like a hit at home (the Pfanne's guard, Sturschädl, going down).
## Downed teammates get a revive spot and a marker; a player who bled out watches a teammate until
## the next wave starts. Main creates it as /root/Main/CoopPlayers on every peer.

const HIKER := preload("res://scenes/net/hiker.tscn")
const MARKER_COLOR := Color(1.0, 0.3, 0.25)

var _player: Player
var _send_left: float = 0.0
## Peer -> Remote.
var _remotes: Dictionary = {}
var _spectator: Camera3D
var _watching: int = 0


func setup(player: Player) -> void:
	_player = player
	Coop.players = self
	Net.roster_changed.connect(_sync_roster)
	Events.wave_started.connect(_on_wave_started.unbind(2))
	_player.life_changed.connect(_on_own_life_changed)
	_spectator = Camera3D.new()
	_spectator.fov = 70.0
	add_child(_spectator)
	_sync_roster()


func _exit_tree() -> void:
	if Coop.players == self:
		Coop.players = null


## 1.. for our own Player or a hiker, 0 for anything else.
func peer_of(node: Node) -> int:
	if node == null:
		return 0
	if node == _player:
		return Net.my_id()
	var hiker := node as Hiker
	return hiker.peer if hiker and _remotes.has(hiker.peer) else 0


func node_of(peer: int) -> Node3D:
	if peer == Net.my_id():
		return _player
	var remote: Remote = _remotes.get(peer)
	return remote.hiker if remote else null


## Every player's state by peer (ourselves included), for the host's game over and the HUD.
func lives() -> Dictionary:
	var out: Dictionary = {Net.my_id(): _player.life}
	for peer: int in _remotes:
		out[peer] = (_remotes[peer] as Remote).hiker.life
	return out


## Health share (0..1) of a teammate, for the HUD.
func health_share(peer: int) -> float:
	var remote: Remote = _remotes.get(peer)
	return remote.health_share if remote else 0.0


func _process(delta: float) -> void:
	if not Net.in_match():
		return
	_send_left -= delta
	if _send_left <= 0.0 and _player:
		_send_left = maxf(_send_left + Constants.NET_POSE_INTERVAL, 0.0)
		var flags: int = (1 if _player.is_crouching() else 0) | (_player.life << 1)
		var share: int = roundi(100.0 * _player.health.current() / maxf(_player.health.max_health, 1.0))
		_pose.rpc(Time.get_ticks_msec(), _player.global_position, _player.rotation.y, flags, share)
	var now: int = Time.get_ticks_msec()
	for remote: Remote in _remotes.values():
		remote.update(now, delta)
	_update_spectator()


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
			hiker.peer = peer
			add_child(hiker)
			hiker.hide()
			hiker.add_child(ReviveSpot.new(hiker))
			if Net.is_host():
				hiker.add_to_group("player")
				hiker.on_hurt = _hurt_remote
			_remotes[peer] = Remote.new(hiker)
		(_remotes[peer] as Remote).hiker.apply(Net.roster[peer], peer)


# --- damage, downed, revive ---------------------------------------------------------------------------

## Host: an enemy hit another player's hiker; their own game takes the hit.
func _hurt_remote(peer: int, amount: int, attacker: Node3D) -> void:
	var enemy := attacker as Enemy
	_hurt.rpc_id(peer, amount, enemy.net_id if enemy else 0)


@rpc("authority", "call_remote", "reliable")
func _hurt(amount: int, attacker_id: int) -> void:
	var attacker: Enemy = Coop.enemies.by_id(attacker_id) if Coop.enemies and attacker_id != 0 else null
	_player.take_damage(amount, attacker)


## Our revive of `peer` has got this far (0..1); they stop bleeding while it goes on.
func revive_tick(peer: int, share: float) -> void:
	_revive_heard.rpc_id(peer, share)


func revive(peer: int) -> void:
	_revived.rpc_id(peer)


@rpc("any_peer", "call_remote", "unreliable")
func _revive_heard(share: float) -> void:
	_player.hear_revive(share)


@rpc("any_peer", "call_remote", "reliable")
func _revived() -> void:
	var by: int = multiplayer.get_remote_sender_id()
	_player.revive()
	_announce.rpc("UI_COOP_REVIVED", Net.my_id(), by)
	_show_announcement("UI_COOP_REVIVED", Net.my_id(), by)


func _on_own_life_changed(life: Player.Life) -> void:
	if life == Player.Life.DOWNED:
		_announce.rpc("UI_COOP_DOWN", Net.my_id(), 0)
	elif life == Player.Life.OUT:
		_announce.rpc("UI_COOP_BLED_OUT", Net.my_id(), 0)


## A banner for everyone: "<who> is down", "<by> got <who> up", ...
@rpc("any_peer", "call_remote", "reliable")
func _announce(key: String, who: int, by: int) -> void:
	_show_announcement(key, who, by)


func _show_announcement(key: String, who: int, by: int) -> void:
	var who_name: String = HikerStyle.display_name(Net.roster.get(who, {}), who)
	var by_name: String = HikerStyle.display_name(Net.roster.get(by, {}), by)
	Events.event_announced.emit(tr(key) % [who_name, by_name] if by != 0 else tr(key) % who_name)


func _on_wave_started() -> void:
	# Section 10 (user decision Q3): out players come back when a new wave starts.
	_player.come_back()


## Bled out: the view follows a teammate who is still up, from behind and above.
func _update_spectator() -> void:
	if _player.life != Player.Life.OUT:
		if _spectator.current:
			_spectator.current = false
			(_player.get_node("Head/Camera3D") as Camera3D).make_current()
		return
	var target: Remote = _remotes.get(_watching)
	if target == null or target.hiker.life != Player.Life.ALIVE:
		target = null
		for peer: int in _remotes:
			if (_remotes[peer] as Remote).hiker.life == Player.Life.ALIVE:
				_watching = peer
				target = _remotes[peer]
				break
	if target == null:
		return
	var hiker: Hiker = target.hiker
	var behind: Vector3 = hiker.global_basis * Constants.COOP_SPECTATE_OFFSET
	_spectator.global_position = hiker.global_position + behind
	_spectator.look_at(hiker.global_position + Vector3.UP * 1.4)
	_spectator.make_current()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _pose(sent_ms: int, at: Vector3, yaw: float, flags: int, health_percent: int) -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	if remote:
		remote.add(Time.get_ticks_msec(), sent_ms, at, yaw, flags, health_percent)


## One other player's hiker and the poses heard from them.
class Remote:
	var hiker: Hiker
	var health_share: float = 1.0
	var _poses := PoseBuffer.new()
	var _last_position: Vector3
	var _crouching: bool = false
	var _marker: MapMarker

	func _init(body: Hiker) -> void:
		hiker = body

	func add(now: int, sent: int, at: Vector3, yaw: float, flags: int, health_percent: int) -> void:
		_poses.add(now, sent, at, yaw)
		_crouching = flags & 1 != 0
		health_share = health_percent / 100.0
		var life: Player.Life = ((flags >> 1) & 3) as Player.Life
		if life != hiker.life:
			hiker.set_life(life)
			_mark(life == Player.Life.DOWNED)
		if not hiker.visible and life != Player.Life.OUT:
			hiker.global_position = at
			hiker.rotation.y = yaw
			_last_position = at
			hiker.show()

	func update(now: int, delta: float) -> void:
		if _poses.is_empty():
			return
		var pose: Array = _poses.sample(now)
		var at: Vector3 = pose[0]
		hiker.global_position = at
		hiker.rotation.y = pose[1]
		var flat: Vector3 = at - _last_position
		flat.y = 0.0
		_last_position = at
		if _crouching and hiker.life == Player.Life.ALIVE:
			hiker.rig.play(EnemyRig.Action.CROUCH, Constants.NET_POSE_INTERVAL * 4.0)
		hiker.rig.update(delta, flat.length() / maxf(delta, 0.001))

	## A downed teammate shows across the map, like an event (MapMarker and its edge arrow).
	func _mark(on: bool) -> void:
		if on and _marker == null:
			_marker = MapMarker.new()
			_marker.text = "UI_COOP_MARKER_DOWN"
			_marker.color = MARKER_COLOR
			_marker.column_height = 8.0
			_marker.label_height = 1.2
			hiker.add_child(_marker)
		elif not on and _marker:
			_marker.queue_free()
			_marker = null
