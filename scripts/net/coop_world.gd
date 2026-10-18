class_name CoopWorld
extends Node
## The shared world of a co-op match (M7, NETWORKING.md section 3): the host's word on waves, doors,
## barricades and the Hüttentruhe, and the end of the match.
##
## The host runs these as in solo and tells the guests what happened; guests play it back through the
## same Events, with our own Player as the source when it was us, so points land with whoever earned
## them. What a guest wants from the shared world (a door, a board, the chest) goes to the host as a
## request; a guest pays first, and gets the points back if the host says no (someone was quicker).
## Main creates it as /root/Main/CoopWorld on every peer.

## Every player is down or out: the match is over for all.
signal game_over(wave: int)

var _main: Node
var _waves: WaveManager
var _zones: ZoneMap
var _over: bool = false
## Weapons left on the floor (the Krampus-Rute) by net id, on every peer.
var _drops: Dictionary = {}
var _next_drop: int = 1


func setup(main: Node, waves: WaveManager, zones: ZoneMap) -> void:
	_main = main
	_waves = waves
	_zones = zones
	Coop.world = self
	if Net.is_host():
		Events.wave_break_started.connect(func(next: int, duration: float) -> void: _wave_break.rpc(next, duration))
		Events.wave_started.connect(func(wave: int, boss: bool) -> void: _wave_started.rpc(wave, boss))
		Events.wave_cleared.connect(func(wave: int) -> void: _wave_cleared.rpc(wave))
		Events.zone_unlocked.connect(func(zone: StringName, source: Node3D) -> void: _unlocked.rpc(zone, Coop.peer_of(source)))
		Events.board_repaired.connect(func(barricade: Node3D, source: Node3D) -> void: _repaired.rpc(_path(barricade), Coop.peer_of(source)))
		for node: Node in get_tree().get_nodes_in_group("barricades"):
			var barricade := node as Barricade
			barricade.boards_changed.connect(func(count: int) -> void: _boards.rpc(_path(barricade), count))
		for node: Node in get_tree().get_nodes_in_group("chests"):
			var chest := node as Huettentruhe
			chest.rolled.connect(func(buyer: Node3D, weapon: WeaponData) -> void: _chest_rolled.rpc(_path(chest), Coop.peer_of(buyer), String(weapon.id)))
		# Everyone gets a moment to click into the match before the first wave.
		_waves.begin_break(Constants.COOP_FIRST_WAVE_DELAY)


func _exit_tree() -> void:
	if Coop.world == self:
		Coop.world = null


func _physics_process(_delta: float) -> void:
	if _over or not Net.in_match() or not Net.is_host() or Coop.players == null:
		return
	if Coop.players.lives().values().all(func(life: Player.Life) -> bool: return life != Player.Life.ALIVE):
		_end.rpc(_waves.wave)
		_end(_waves.wave)


func _path(node: Node) -> NodePath:
	return _main.get_path_to(node)


func _node(path: NodePath) -> Node:
	return _main.get_node_or_null(path)


# --- requests from guests ---------------------------------------------------------------------------

## Host: a weapon was dropped (WeaponPickup.spawn); the guests get it too, under one id.
func share_drop(pickup: WeaponPickup) -> void:
	pickup.net_id = _next_drop
	_next_drop += 1
	_drops[pickup.net_id] = pickup
	_dropped.rpc(pickup.net_id, String(pickup.weapon.id), pickup.global_position)


## Host: we took a drop; it goes for everyone.
func drop_taken(pickup: WeaponPickup) -> void:
	_drops.erase(pickup.net_id)
	_drop_gone.rpc(pickup.net_id)


## A guest wants a drop: the host gives it to whoever asked first.
func request_drop(pickup: WeaponPickup) -> void:
	_ask_drop.rpc_id(1, pickup.net_id)


## A guest paid for the door to `zone`.
func request_unlock(zone: StringName, cost: int) -> void:
	_ask_unlock.rpc_id(1, zone, cost)


## A guest nails a board onto `barricade` (the host pays the points out).
func request_board(barricade: Barricade) -> void:
	_ask_board.rpc_id(1, _path(barricade))


## A guest paid for the chest, which is to offer them `weapon`.
func request_chest(chest: Huettentruhe, weapon: WeaponData, cost: int) -> void:
	_ask_chest.rpc_id(1, _path(chest), String(weapon.id), cost)


## We took the chest's offer: it closes everywhere.
func chest_taken(chest: Huettentruhe) -> void:
	_chest_taken.rpc(_path(chest))


@rpc("any_peer", "call_remote", "reliable")
func _ask_unlock(zone: StringName, cost: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _zones.is_unlocked(zone):
		_refund.rpc_id(sender, cost)
		return
	_zones.unlock(zone, Coop.node_of(sender))


@rpc("any_peer", "call_remote", "reliable")
func _ask_board(path: NodePath) -> void:
	var barricade := _node(path) as Barricade
	if barricade and barricade.add_board():
		Events.board_repaired.emit(barricade, Coop.node_of(multiplayer.get_remote_sender_id()))


@rpc("any_peer", "call_remote", "reliable")
func _ask_chest(path: NodePath, weapon_id: String, cost: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var chest := _node(path) as Huettentruhe
	if chest == null or not chest.roll_for(Coop.node_of(sender), StringName(weapon_id)):
		_refund.rpc_id(sender, cost)


@rpc("any_peer", "call_remote", "reliable")
func _ask_drop(id: int) -> void:
	var pickup: WeaponPickup = _drops.get(id)
	if pickup == null or not is_instance_valid(pickup):
		return
	_drops.erase(id)
	_drop_gone.rpc(id)
	_drop_granted.rpc_id(multiplayer.get_remote_sender_id(), String(pickup.weapon.id))
	pickup.queue_free()


@rpc("authority", "call_remote", "reliable")
func _dropped(id: int, weapon_id: String, at: Vector3) -> void:
	var data := load("res://data/weapons/%s.tres" % weapon_id) as WeaponData if weapon_id.is_valid_identifier() else null
	if data == null:
		return
	var pickup: WeaponPickup = WeaponPickup.spawn(data, at, _main)
	pickup.net_id = id
	_drops[id] = pickup


@rpc("authority", "call_remote", "reliable")
func _drop_gone(id: int) -> void:
	var pickup: WeaponPickup = _drops.get(id)
	_drops.erase(id)
	if pickup and is_instance_valid(pickup):
		pickup.queue_free()


## We were first to the drop we asked for.
@rpc("authority", "call_remote", "reliable")
func _drop_granted(weapon_id: String) -> void:
	var player := Coop.node_of(Net.my_id()) as Player
	var data := load("res://data/weapons/%s.tres" % weapon_id) as WeaponData if weapon_id.is_valid_identifier() else null
	if player and data:
		player.weapons.give_weapon(data)


@rpc("authority", "call_remote", "reliable")
func _refund(cost: int) -> void:
	var player := Coop.node_of(Net.my_id()) as Player
	if player:
		player.points.add(cost)


# --- the host's word ---------------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _wave_break(next: int, duration: float) -> void:
	Events.wave_break_started.emit(next, duration)


@rpc("authority", "call_remote", "reliable")
func _wave_started(wave: int, is_boss_wave: bool) -> void:
	_waves.wave = wave
	Events.wave_started.emit(wave, is_boss_wave)


@rpc("authority", "call_remote", "reliable")
func _wave_cleared(wave: int) -> void:
	Events.wave_cleared.emit(wave)


@rpc("authority", "call_remote", "reliable")
func _unlocked(zone: StringName, peer: int) -> void:
	_zones.unlock(zone, Coop.node_of(peer))


@rpc("authority", "call_remote", "reliable")
func _boards(path: NodePath, count: int) -> void:
	var barricade := _node(path) as Barricade
	if barricade:
		barricade.set_boards(count)


@rpc("authority", "call_remote", "reliable")
func _repaired(path: NodePath, peer: int) -> void:
	var barricade := _node(path) as Barricade
	if barricade:
		Events.board_repaired.emit(barricade, Coop.node_of(peer))


@rpc("authority", "call_remote", "reliable")
func _chest_rolled(path: NodePath, peer: int, weapon_id: String) -> void:
	var chest := _node(path) as Huettentruhe
	if chest:
		chest.roll_for(Coop.node_of(peer), StringName(weapon_id))


@rpc("any_peer", "call_remote", "reliable")
func _chest_taken(path: NodePath) -> void:
	var chest := _node(path) as Huettentruhe
	if chest:
		chest.taken()


@rpc("authority", "call_remote", "reliable")
func _end(wave: int) -> void:
	if _over:
		return
	_over = true
	_waves.wave = wave
	game_over.emit(wave)
