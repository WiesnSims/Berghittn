extends Node
## M7 part 2 over the real relay: host and guest in the real main scene, one role per process:
##     node tools/net_test.mjs res://tests/net_core.tscn
## The two sides walk through the same steps, waiting for each other at every _sync():
## enemies show up on the guest and the guest's kill pays the guest; the guest buys a door, nails a
## board the host's enemy pulled, rolls the chest and takes the gun; an enemy's hit on the guest
## downs them and the host revives them; bled out, they come back with the next wave; everyone down
## is game over and both are back in the room's lobby.

const TIMEOUT: float = 25.0

var _main: Node
var _player: Player
var _marks: Dictionary = {}
var _role: String
var _failed: String = ""


func _ready() -> void:
	if Engine.has_meta("net_core_done"):
		get_tree().quit(int(Engine.get_meta("net_core_done")))
		return
	_role = _arg("role", "host")
	Settings.profile = {"name": "Wirt" if _role == "host" else "Gast", "head": 0, "hat": 0, "jacket": 0, "trousers": 0}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	var ok: bool = await _run()
	Engine.set_meta("net_core_done", 0 if ok else 1)
	print("PASS" if ok else "FAIL %s: %s" % [_role, _failed])
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	var host: bool = _role == "host"
	await get_tree().process_frame
	# --- lobby and start ---
	if host:
		Net.create_room()
		if not await _until(func() -> bool: return Net.in_lobby()):
			return _fail("no room")
		print("ROOM %s" % Net.code)
		if not await _until(func() -> bool: return Net.roster.size() == 2):
			return _fail("guest never came")
		Net.start_match()
	if not await _until(func() -> bool: return Net.in_match() and Coop.world != null):
		return _fail("no match")
	if not await _sync("started"):
		return false
	var waves := _main.get_node("WaveManager") as WaveManager
	# Picked on both sides before anyone buys anything.
	var door: ZoneDoor = _closed_door()
	if door == null:
		return _fail("no door to buy")
	var zone: ZoneData = door._zone_behind()
	if host:
		waves.begin_break(0.5)
	# --- enemies ---
	if not host:
		if not await _until(func() -> bool: return _alive_puppets().size() > 0):
			return _fail("no puppet arrived")
		var puppet: Enemy = _alive_puppets()[0]
		var start: Vector3 = puppet.global_position
		await get_tree().create_timer(1.5).timeout
		if not puppet.is_alive() or puppet.global_position.distance_to(start) < 0.2:
			return _fail("puppet does not follow its enemy (moved %.2f m)" % puppet.global_position.distance_to(start))
		var before: int = _player.points.total
		var result: Hurtbox.Result = puppet.receive_hit(5000, true, false, _player)
		if result != Hurtbox.Result.KILLED:
			return _fail("predicted %s, not KILLED" % result)
		if not await _until(func() -> bool: return not puppet.is_alive()):
			return _fail("the host never killed it")
		if not await _until(func() -> bool: return _player.points.total == before + Constants.POINTS_KILL_HEADSHOT):
			return _fail("kill paid %d" % (_player.points.total - before))
		print("enemy: puppet followed, kill paid the guest")
	if not await _sync("enemies"):
		return false
	# Keep the hut quiet for the rest: no more spawns, the ones alive go.
	if host:
		waves.process_mode = Node.PROCESS_MODE_DISABLED
		for child: Node in waves.get_children():
			var enemy := child as Enemy
			if enemy and enemy.is_alive():
				enemy.receive_hit(99999, false, false, null)
	await get_tree().create_timer(0.5).timeout
	# --- a door ---
	if not host:
		_player.points.add(20000)
		var before: int = _player.points.total
		door.interact(_player)
		if not await _until(func() -> bool: return (_main.get_node("Zones") as ZoneMap).is_unlocked(zone.id)):
			return _fail("door never opened")
		if _player.points.total != before - zone.cost:
			return _fail("door cost %d" % (before - _player.points.total))
	elif not await _until(func() -> bool: return (_main.get_node("Zones") as ZoneMap).is_unlocked(zone.id)):
		return _fail("host never opened the guest's door")
	print("door: %s open on both" % zone.id)
	if not await _sync("door"):
		return false
	# --- a barricade ---
	var barricade := get_tree().get_nodes_in_group("barricades")[0] as Barricade
	if host:
		barricade.remove_board()
		barricade.remove_board()
	if not await _until(func() -> bool: return barricade.boards == Constants.BARRICADE_MAX_BOARDS - 2):
		return _fail("boards %d after two pulls" % barricade.boards)
	if not host:
		var before: int = _player.points.total
		barricade.interact(_player)
		if not await _until(func() -> bool: return barricade.boards == Constants.BARRICADE_MAX_BOARDS - 1):
			return _fail("board never nailed on")
		if not await _until(func() -> bool: return _player.points.total == before + Constants.POINTS_REPAIR_BOARD):
			return _fail("board paid %d" % (_player.points.total - before))
	elif not await _until(func() -> bool: return barricade.boards == Constants.BARRICADE_MAX_BOARDS - 1):
		return _fail("host never got the guest's board")
	print("barricade: pulled on the host, nailed by the guest")
	if not await _sync("barricade"):
		return false
	# --- the chest ---
	var chest := get_tree().get_nodes_in_group("chests")[0] as Huettentruhe
	if not host:
		chest.interact(_player)
	if not await _until(func() -> bool: return chest.state == Huettentruhe.State.OFFERING):
		return _fail("chest never offered (%s)" % chest.state)
	if not host:
		var offer: WeaponData = chest.offer
		chest.interact(_player)
		if not _player.weapons.has_weapon(offer):
			return _fail("took nothing")
	if not await _until(func() -> bool: return chest.state != Huettentruhe.State.OFFERING):
		return _fail("chest stayed open after the guest took it")
	print("chest: rolled for the guest, taken, closed on both")
	if not await _sync("chest"):
		return false
	# --- downed and revived ---
	var hiker: Hiker = Coop.node_of(2 if host else 1) as Hiker
	if host:
		hiker.take_damage(99999, null)
	if not host:
		if not await _until(func() -> bool: return _player.life == Player.Life.DOWNED):
			return _fail("the host's hit did not down the guest")
		if _player.weapons.weapon != _player.weapons.starting_weapon:
			return _fail("downed with %s, not the pistol" % _player.weapons.weapon.id)
	else:
		if not await _until(func() -> bool: return hiker.life == Player.Life.DOWNED):
			return _fail("host never saw the guest down")
		if hiker.is_targetable():
			return _fail("a downed hiker is still a target")
		Coop.players.revive(2)
	if not host:
		if not await _until(func() -> bool: return _player.life == Player.Life.ALIVE):
			return _fail("never revived")
		if _player.health.current() != roundi(_player.health.max_health * Constants.COOP_REVIVE_HEALTH):
			return _fail("revived with %d health" % _player.health.current())
	elif not await _until(func() -> bool: return hiker.life == Player.Life.ALIVE):
		return _fail("host never saw the guest get up")
	print("downed: guest went down, got the pistol, was revived")
	if not await _sync("revive"):
		return false
	# --- bled out, back next wave ---
	if not host:
		_player.take_damage(99999, null)
		await get_tree().process_frame
		_player._bleed_out()
	if not await _until(func() -> bool: return (_player.life if not host else hiker.life) == Player.Life.OUT):
		return _fail("never out")
	if not await _sync("out"):
		return false
	if host:
		waves.process_mode = Node.PROCESS_MODE_INHERIT
		waves.begin_break(0.3)
	if not await _until(func() -> bool: return (_player.life if not host else hiker.life) == Player.Life.ALIVE):
		return _fail("never came back with the next wave")
	print("out: bled out, back with the next wave")
	if not await _sync("back"):
		return false
	# --- game over ---
	_player.take_damage(99999, null)
	if not await _until(func() -> bool: return Net.in_lobby()):
		return _fail("no game over / lobby (%s)" % Net.state)
	if not (_main.get_node("UI/DeathScreen") as Control).visible:
		await get_tree().create_timer(Constants.DEATH_SCREEN_DELAY + 0.5).timeout
	if not (_main.get_node("UI/DeathScreen") as Control).visible:
		return _fail("no death screen")
	print("game over: both down, death screen, back in the lobby")
	await _sync("over")
	if host:
		await get_tree().create_timer(1.0).timeout
	return true


func _alive_puppets() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for child: Node in _main.get_node("CoopEnemies").get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive():
			out.append(enemy)
	return out


func _closed_door() -> ZoneDoor:
	for node: Node in get_tree().get_nodes_in_group("zone_doors"):
		var door := node as ZoneDoor
		if door._zone_behind() != null:
			return door
	return null


## Both sides reach `label` before either goes on.
func _sync(label: String) -> bool:
	_mark.rpc(label)
	if await _until(func() -> bool: return _marks.has(label)):
		return true
	return _fail("the other side never reached '%s'" % label)


@rpc("any_peer", "call_remote", "reliable")
func _mark(label: String) -> void:
	_marks[label] = true


func _until(condition: Callable) -> bool:
	var left: float = TIMEOUT
	while not condition.call():
		if left <= 0.0:
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true


func _fail(why: String) -> bool:
	if _failed == "":
		_failed = why
	return false


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback
