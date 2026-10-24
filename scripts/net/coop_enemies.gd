class_name CoopEnemies
extends Node3D
## Enemies in a co-op match (M7, NETWORKING.md section 3). The host's WaveManager runs them as in
## solo; every guest keeps a puppet of each (Enemy.puppet) under this node, moved by the host's
## snapshots, posed by its actions, hurt and killed by its word. A guest's hit on a puppet comes here
## and goes to the host, which applies it as that player's hit (source: their hiker), so points,
## kills and herbs land where they belong once the host passes the damage back.
## Main creates it as /root/Main/CoopEnemies on every peer, so the RPC paths match.

## Bytes per enemy in a snapshot: id u16, position 3 x s16 (cm), yaw u16, lean 3 x s8, flags u8.
## An enemy whose entry is the same as in the last snapshot (standing, striking) is left out: the
## relay loses nothing, so the guest's puppet just stays (M7 part 4, a third less with a crowd).
const ENTRY_BYTES: int = 14
## Snapshot flags: it is burning.
const FLAG_BURNING: int = 1
const CM: float = 100.0
const LEAN_SCALE: float = 40.0
## Enemy methods a guest may ask the host to call, with their argument counts (the host adds the
## hitting player as `source` to those that take one).
const RELAYED: Dictionary = {&"receive_hit": 3, &"scorch": 1, &"ignite": 2, &"dance": 2,
		&"apply_slow": 2, &"stun": 1, &"flee": 2, &"apply_knockback": 1,
		&"lift": 0, &"carry_to": 2, &"hurl": 1, &"knock_hat": 1}
const WITH_SOURCE: Array[StringName] = [&"receive_hit", &"scorch", &"ignite", &"dance", &"knock_hat"]

var _waves: WaveManager
## Net id -> Enemy: the host's live enemies, or a guest's puppets.
var _by_id: Dictionary = {}
var _next_id: int = 1
var _send_left: float = 0.0
# Host: net id -> the entry (without the id) last sent for it.
var _sent: Dictionary = {}
# Guests: puppets waiting to be reused, by EnemyData id, and each puppet's received poses.
var _pools: Dictionary = {}
var _buffers: Dictionary = {}
var _data: Dictionary = {}


func setup(waves: WaveManager) -> void:
	_waves = waves
	Coop.enemies = self
	if Net.is_host():
		Events.enemy_damaged.connect(_on_damaged)
		Events.enemy_killed.connect(_on_killed)
	else:
		Enemy.hit_relay = _relay_hit


func _exit_tree() -> void:
	if Coop.enemies == self:
		Coop.enemies = null
		Enemy.hit_relay = Callable()


## The live enemy (host) or puppet (guest) with this id, or null.
func by_id(id: int) -> Enemy:
	return _by_id.get(id)


func _physics_process(delta: float) -> void:
	if not Net.in_match():
		return
	if Net.is_host():
		_host_step(delta)
	else:
		_guest_step(delta)


# --- host -------------------------------------------------------------------------------------------

func _host_step(delta: float) -> void:
	for child: Node in _waves.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive() and enemy.net_id == 0:
			_announce(enemy)
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = maxf(_send_left + Constants.NET_POSE_INTERVAL, 0.0)
		_send_snapshot()


func _announce(enemy: Enemy) -> void:
	enemy.net_id = _next_id
	# Ids go round within u16 and skip 0; a wave never has that many alive.
	_next_id = _next_id % 65535 + 1
	_by_id[enemy.net_id] = enemy
	if not enemy.posed.is_connected(_on_posed):
		enemy.posed.connect(_on_posed)
		enemy.said.connect(_on_said)
		enemy.vanished.connect(_on_vanished)
		enemy.fired.connect(_on_fired)
		enemy.hat_lost.connect(_on_hat_lost)
		enemy.cued.connect(_on_cued)
	_spawned.rpc(enemy.net_id, String(enemy.data.id), _waves.wave, enemy.global_transform, enemy.health)


func _send_snapshot() -> void:
	var alive: Array[Enemy] = []
	for enemy: Enemy in _by_id.values():
		if enemy.is_alive():
			alive.append(enemy)
	var bytes := PackedByteArray()
	bytes.resize(alive.size() * ENTRY_BYTES)
	var at: int = 0
	var sent: Dictionary = {}
	for enemy: Enemy in alive:
		var p: Vector3 = enemy.global_position * CM
		var lean: Vector3 = enemy.puppet_lean()
		bytes.encode_u16(at, enemy.net_id)
		bytes.encode_s16(at + 2, clampi(roundi(p.x), -32768, 32767))
		bytes.encode_s16(at + 4, clampi(roundi(p.y), -32768, 32767))
		bytes.encode_s16(at + 6, clampi(roundi(p.z), -32768, 32767))
		bytes.encode_u16(at + 8, roundi(fposmod(enemy.rotation.y, TAU) / TAU * 65535.0))
		bytes.encode_s8(at + 10, clampi(roundi(lean.x * LEAN_SCALE), -127, 127))
		bytes.encode_s8(at + 11, clampi(roundi(lean.y * LEAN_SCALE), -127, 127))
		bytes.encode_s8(at + 12, clampi(roundi(lean.z * CM), -127, 127))
		bytes.encode_u8(at + 13, FLAG_BURNING if enemy.is_burning() else 0)
		var entry: PackedByteArray = bytes.slice(at + 2, at + ENTRY_BYTES)
		sent[enemy.net_id] = entry
		if _sent.get(enemy.net_id) != entry:
			at += ENTRY_BYTES
	_sent = sent
	if at == 0:
		return
	bytes.resize(at)
	_snapshot.rpc(Time.get_ticks_msec(), bytes)


func _on_posed(enemy: Enemy, action: EnemyRig.Action, length: float) -> void:
	if enemy.net_id != 0 and enemy.is_alive():
		_posed.rpc(enemy.net_id, action, length)


## A line (Gredn) picked here: its index goes out to the guests, before a dying enemy's death.
func _on_said(enemy: Enemy, line: int) -> void:
	if enemy.net_id != 0:
		_said.rpc(enemy.net_id, line)


func _on_damaged(node: Node3D, amount: int, is_headshot: bool, source: Node3D) -> void:
	var enemy := node as Enemy
	if enemy and enemy.net_id != 0:
		_damaged.rpc(enemy.net_id, amount, is_headshot, Coop.peer_of(source), enemy.health)


func _on_killed(node: Node3D, is_headshot: bool, is_melee: bool, source: Node3D) -> void:
	var enemy := node as Enemy
	if enemy == null or enemy.net_id == 0:
		return
	_killed.rpc(enemy.net_id, is_headshot, is_melee, Coop.peer_of(source), enemy.last_damage)
	_by_id.erase(enemy.net_id)
	enemy.net_id = 0


## The Wilderer fired: the bang and the streak on every guest (the damage goes as usual).
func _on_fired(enemy: Enemy, at: Vector3) -> void:
	if enemy.net_id != 0:
		_fired.rpc(enemy.net_id, at)


## Huat obschiaßn: the hat flies on every guest, and the shooter's own game pays for it.
func _on_hat_lost(enemy: Enemy, direction: Vector3, source: Node3D) -> void:
	if enemy.net_id != 0:
		_hat_lost.rpc(enemy.net_id, direction, Coop.peer_of(source))


## A variant's trick has something to show (Die Bsundan): out to every guest. Enemies in it (the
## Bergführer's rope) go as their net ids.
func _on_cued(enemy: Enemy, cue: StringName, arg: Variant) -> void:
	if enemy.net_id == 0:
		return
	if arg is Array:
		arg = (arg as Array).map(func(item: Variant) -> Variant: return (item as Enemy).net_id if item is Enemy else item)
	_cued.rpc(enemy.net_id, String(cue), arg)


## The Venedigermandl vanished (after his last line went out).
func _on_vanished(enemy: Enemy) -> void:
	if enemy.net_id == 0:
		return
	_vanished.rpc(enemy.net_id)
	_by_id.erase(enemy.net_id)
	enemy.net_id = 0


## A guest hit one of our enemies: applied as that player's hit.
@rpc("any_peer", "call_remote", "reliable")
func _hit(id: int, method: StringName, args: Array) -> void:
	if not Net.is_host() or not RELAYED.has(method) or args.size() != RELAYED[method]:
		return
	var enemy: Enemy = _by_id.get(id)
	if enemy == null or not enemy.is_alive():
		return
	var call_args: Array = args.duplicate()
	if method in WITH_SOURCE:
		call_args.append(Coop.node_of(multiplayer.get_remote_sender_id()))
	enemy.callv(method, call_args)


# --- guest ------------------------------------------------------------------------------------------

func _relay_hit(enemy: Enemy, method: StringName, args: Array) -> void:
	if enemy.net_id != 0:
		_hit.rpc_id(1, enemy.net_id, method, args)


func _guest_step(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for id: int in _by_id:
		var buffer: PoseBuffer = _buffers.get(id)
		var puppet: Enemy = _by_id[id]
		if buffer == null or buffer.is_empty() or not puppet.is_alive() or puppet.puppet_driven():
			continue
		var pose: Array = buffer.sample(now)
		puppet.puppet_move(pose[0], pose[1], pose[2], delta)


func _take_puppet(data: EnemyData) -> Enemy:
	var pool: Array = _pools.get(data.id, [])
	if not pool.is_empty():
		return pool.pop_back()
	var puppet := _waves.enemy_scene.instantiate() as Enemy
	puppet.puppet = true
	add_child(puppet)
	puppet.despawned.connect(_on_puppet_despawned)
	return puppet


func _on_puppet_despawned(puppet: Enemy) -> void:
	if not _pools.has(puppet.data.id):
		_pools[puppet.data.id] = []
	_pools[puppet.data.id].append(puppet)


func _enemy_data(id: String) -> EnemyData:
	if not _data.has(id):
		_data[id] = load("res://data/enemies/%s.tres" % id) as EnemyData
	return _data[id]


@rpc("authority", "call_remote", "reliable")
func _spawned(id: int, data_id: String, wave: int, at: Transform3D, health: int) -> void:
	var data: EnemyData = _enemy_data(data_id)
	if data == null:
		return
	var puppet: Enemy = _take_puppet(data)
	puppet.activate(data, wave, at)
	puppet.net_id = id
	puppet.health = health
	puppet.max_health = maxi(puppet.max_health, health)
	_by_id[id] = puppet
	var buffer := PoseBuffer.new()
	_buffers[id] = buffer


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(sent: int, bytes: PackedByteArray) -> void:
	var now: int = Time.get_ticks_msec()
	for at: int in range(0, bytes.size() - ENTRY_BYTES + 1, ENTRY_BYTES):
		var id: int = bytes.decode_u16(at)
		var buffer: PoseBuffer = _buffers.get(id)
		if buffer == null:
			continue
		(_by_id[id] as Enemy).puppet_burn(bytes.decode_u8(at + 13) & FLAG_BURNING != 0)
		var p := Vector3(bytes.decode_s16(at + 2), bytes.decode_s16(at + 4), bytes.decode_s16(at + 6)) / CM
		var yaw: float = bytes.decode_u16(at + 8) / 65535.0 * TAU
		var lean := Vector3(bytes.decode_s8(at + 10) / LEAN_SCALE, bytes.decode_s8(at + 11) / LEAN_SCALE, bytes.decode_s8(at + 12) / CM)
		buffer.add(now, sent, p, yaw, lean)


@rpc("authority", "call_remote", "reliable")
func _posed(id: int, action: int, length: float) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet and puppet.is_alive():
		puppet.puppet_pose(action as EnemyRig.Action, length)


@rpc("authority", "call_remote", "reliable")
func _said(id: int, line: int) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet and puppet.is_alive() and Gredn.current:
		Gredn.current.say(puppet, line)


@rpc("authority", "call_remote", "reliable")
func _damaged(id: int, amount: int, is_headshot: bool, peer: int, health_left: int) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet:
		puppet.puppet_damaged(amount, is_headshot, Coop.node_of(peer), health_left, peer == Net.my_id())


@rpc("authority", "call_remote", "reliable")
func _fired(id: int, at: Vector3) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet:
		puppet.puppet_fire(at)


@rpc("authority", "call_remote", "reliable")
func _hat_lost(id: int, direction: Vector3, peer: int) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet:
		puppet.puppet_hat(direction, Coop.node_of(peer))


@rpc("authority", "call_remote", "reliable")
func _cued(id: int, cue: String, arg: Variant) -> void:
	var puppet: Enemy = _by_id.get(id)
	if puppet:
		puppet.puppet_cue(StringName(cue), arg)


@rpc("authority", "call_remote", "reliable")
func _vanished(id: int) -> void:
	var puppet: Enemy = _by_id.get(id)
	_by_id.erase(id)
	_buffers.erase(id)
	if puppet:
		puppet.puppet_vanish()


@rpc("authority", "call_remote", "reliable")
func _killed(id: int, is_headshot: bool, is_melee: bool, peer: int, amount: int) -> void:
	var puppet: Enemy = _by_id.get(id)
	_by_id.erase(id)
	_buffers.erase(id)
	if puppet:
		puppet.puppet_killed(is_headshot, is_melee, Coop.node_of(peer), amount)
