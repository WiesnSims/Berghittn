class_name CoopPlayers
extends Node3D
## The players in a co-op match (M7). Each player runs their own body (NETWORKING.md section 4) and
## sends where they are and how they are (alive, downed, out, health) 20 times a second; everyone else
## is drawn as their hiker, NET_INTERPOLATION_DELAY in the past. On the host the hikers are also what
## the enemies go for (group "player"): a hit is handed to that player's own game, which takes it
## like a hit at home (the Pfanne's guard, Sturschädl, going down).
## Downed teammates get a revive spot and a marker; a player who bled out watches a teammate until
## the next wave starts. Main creates it as /root/Main/CoopPlayers on every peer.
## What each player's guns and equipment do is passed on too (M7 part 3): every hiker carries a copy
## of the gun in hand, and a ghost of their guns replays their shots, swings and specials for the
## look and the sound; thrown things fly as harmless copies. Their own game deals the damage.

const HIKER := preload("res://scenes/net/hiker.tscn")
const BOELLER_BLAST: Script = preload("res://scripts/perks/boeller_blast.gd")
const WEAPONS: String = "res://data/weapons/%s.tres"
const EQUIPMENT: String = "res://data/equipment/%s.tres"
const MARKER_COLOR := Color(1.0, 0.3, 0.25)
## Packed like the enemy snapshot (M7 part 4: a quarter of the download with 4 players).
## Pose: sent ms u32, position 3 x s16 (cm), yaw u16, pitch s16, flags u8, health % u8.
const POSE_BYTES: int = 16
## A shot or swing: action u8, rounds u8, aim origin 3 x s16 (cm), aim rotation 4 x s16.
const ACTED_BYTES: int = 16
const CM: float = 100.0
const ANGLE_SCALE: float = 10000.0
const UNIT_SCALE: float = 32767.0

var _player: Player
var _send_left: float = 0.0
## Peer -> Remote.
var _remotes: Dictionary = {}
var _spectator: Camera3D
var _watching: int = 0
# Weapon and equipment data by id, loaded the first time someone uses them.
var _data: Dictionary = {}


func setup(player: Player) -> void:
	_player = player
	Coop.players = self
	Net.roster_changed.connect(_sync_roster)
	Events.wave_started.connect(_on_wave_started.unbind(2))
	_player.life_changed.connect(_on_own_life_changed)
	_player.weapons.weapon_changed.connect(_send_held.unbind(1))
	_player.weapons.slots_changed.connect(_send_held.unbind(1))
	_player.weapons.acted.connect(_on_acted)
	_player.equipment.threw.connect(_on_threw)
	_player.perks.triggered.connect(_on_perk)
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
		var pitch: float = asin(clampf(-_player.weapons.global_basis.z.y, -1.0, 1.0))
		var bytes := PackedByteArray()
		bytes.resize(POSE_BYTES)
		bytes.encode_u32(0, Time.get_ticks_msec())
		_encode_position(bytes, 4, _player.global_position)
		bytes.encode_u16(10, roundi(fposmod(_player.rotation.y, TAU) / TAU * 65535.0))
		bytes.encode_s16(12, roundi(pitch * ANGLE_SCALE))
		bytes.encode_u8(14, flags)
		bytes.encode_u8(15, clampi(share, 0, 100))
		_pose.rpc(bytes)
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
			hiker.arm()
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
func _pose(bytes: PackedByteArray) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var remote: Remote = _remotes.get(sender)
	if remote == null or bytes.size() != POSE_BYTES:
		return
	var yaw: float = bytes.decode_u16(10) / 65535.0 * TAU
	remote.add(Time.get_ticks_msec(), bytes.decode_u32(0), _decode_position(bytes, 4), yaw,
			bytes.decode_u8(14), bytes.decode_u8(15))
	remote.hiker.aim(bytes.decode_s16(12) / ANGLE_SCALE)
	# Heard from them for the first time: which gun they hold (a change before both sides were in the
	# match would have been missed).
	if not remote.asked:
		remote.asked = true
		_ask_held.rpc_id(sender)


# --- what the others' guns do -------------------------------------------------------------------------

func _on_acted(action: WeaponHolder.Act, rounds: int) -> void:
	var weapons: WeaponHolder = _player.weapons
	var data: WeaponData = weapons.melee_weapon if action >= WeaponHolder.Act.SWING else weapons.weapon
	if data == null:
		return
	var aim: Transform3D = weapons.global_transform
	var turn: Quaternion = aim.basis.get_rotation_quaternion()
	var bytes := PackedByteArray()
	bytes.resize(ACTED_BYTES)
	bytes.encode_u8(0, action)
	bytes.encode_u8(1, clampi(rounds, 1, 255))
	_encode_position(bytes, 2, aim.origin)
	bytes.encode_s16(8, roundi(turn.x * UNIT_SCALE))
	bytes.encode_s16(10, roundi(turn.y * UNIT_SCALE))
	bytes.encode_s16(12, roundi(turn.z * UNIT_SCALE))
	bytes.encode_s16(14, roundi(turn.w * UNIT_SCALE))
	_acted.rpc(String(data.id), bytes)


static func _encode_position(bytes: PackedByteArray, at: int, position: Vector3) -> void:
	var p: Vector3 = position * CM
	bytes.encode_s16(at, clampi(roundi(p.x), -32768, 32767))
	bytes.encode_s16(at + 2, clampi(roundi(p.y), -32768, 32767))
	bytes.encode_s16(at + 4, clampi(roundi(p.z), -32768, 32767))


static func _decode_position(bytes: PackedByteArray, at: int) -> Vector3:
	return Vector3(bytes.decode_s16(at), bytes.decode_s16(at + 2), bytes.decode_s16(at + 4)) / CM


func _on_threw(item: EquipmentData, thrown: Node3D) -> void:
	var velocity: Vector3 = thrown.get("velocity") if "velocity" in thrown else Vector3.ZERO
	_thrown.rpc(String(item.id), thrown.global_position, velocity)


func _on_perk(id: StringName, _text: String) -> void:
	if id == PlayerPerks.BOELLERSCHUSS:
		_boeller.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _ask_held() -> void:
	_send_held(multiplayer.get_remote_sender_id())


## What our hiker carries, to everyone (or to `peer`): the gun in hand, and with the Kraxn (#95) the
## Kraxn and the guns strapped to it (the others carried).
func _send_held(peer: int = 0) -> void:
	var weapons: WeaponHolder = _player.weapons
	var stowed := PackedStringArray()
	for data: WeaponData in weapons.stowed():
		stowed.append(String(data.id))
	var held: String = String(weapons.weapon.id) if weapons.weapon else ""
	if peer == 0:
		_held.rpc(held, weapons.has_kraxn(), ",".join(stowed))
	else:
		_held.rpc_id(peer, held, weapons.has_kraxn(), ",".join(stowed))


@rpc("any_peer", "call_remote", "reliable")
func _held(weapon_id: String, kraxn: bool, stowed_ids: String) -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	if remote == null:
		return
	# Empty hands ("" or anything that is not a gun): their gun is at the Dengelstock.
	remote.hiker.hold(_load(WEAPONS, weapon_id) as WeaponData)
	var stowed: Array[WeaponData] = []
	for id: String in stowed_ids.split(",", false).slice(0, Constants.GUN_SLOTS + 1):
		var data := _load(WEAPONS, id) as WeaponData
		if data:
			stowed.append(data)
	remote.hiker.carry(kraxn, stowed)


## Their gun went off (or their melee weapon swung, struck, or went into its held mode), from `aim`.
@rpc("any_peer", "call_remote", "reliable")
func _acted(weapon_id: String, bytes: PackedByteArray) -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	var data := _load(WEAPONS, weapon_id) as WeaponData
	if remote == null or data == null or bytes.size() != ACTED_BYTES:
		return
	var action: int = bytes.decode_u8(0)
	if action > WeaponHolder.Act.RELEASE:
		return
	var turn := Quaternion(bytes.decode_s16(8), bytes.decode_s16(10), bytes.decode_s16(12), bytes.decode_s16(14))
	var aim := Transform3D(Basis((turn / UNIT_SCALE).normalized()), _decode_position(bytes, 2))
	remote.hiker.weapons.replay(action as WeaponHolder.Act, data, clampi(bytes.decode_u8(1), 1, 16), aim)
	if action == WeaponHolder.Act.SWING:
		remote.hiker.swing(1.0 / data.fire_rate)


## They threw or placed equipment: a copy where theirs is, with its speed, that hurts nobody (a
## Kuhglocke still lures: on the host it pulls the real enemies).
@rpc("any_peer", "call_remote", "reliable")
func _thrown(item_id: String, at: Vector3, velocity: Vector3) -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	var item := _load(EQUIPMENT, item_id) as EquipmentData
	if remote == null or item == null or item.projectile == null:
		return
	var copy := item.projectile.instantiate() as Node3D
	if "harmless" in copy:
		copy.set("harmless", true)
	get_parent().add_child(copy)
	copy.call("launch", at, Vector3.ZERO, remote.hiker)
	if "velocity" in copy:
		copy.set("velocity", velocity)


## Their Böllerschuss went off around them.
@rpc("any_peer", "call_remote", "reliable")
func _boeller() -> void:
	var remote: Remote = _remotes.get(multiplayer.get_remote_sender_id())
	if remote == null:
		return
	var blast := Node3D.new()
	blast.set_script(BOELLER_BLAST)
	get_parent().add_child(blast)
	blast.global_position = remote.hiker.global_position


## A weapon or equipment resource by id, or null for anything that is not one (ids come off the net).
func _load(path: String, id: String) -> Resource:
	var key: String = path % id
	if not _data.has(key):
		_data[key] = load(key) if id.is_valid_identifier() and ResourceLoader.exists(key) else null
	return _data[key]


## One other player's hiker and the poses heard from them.
class Remote:
	var hiker: Hiker
	var health_share: float = 1.0
	## We asked them which gun they hold.
	var asked: bool = false
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
