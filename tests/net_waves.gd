extends Node
## M7 acceptance, headless: two players play waves 1 to 10 together over the real relay, one role per
## process (about ten minutes, the breaks shortened):
##     NET_TEST_TIMEOUT_MS=1500000 node tools/net_test.mjs res://tests/net_waves.tscn
## Like tests/m5_waves, but networked: both stand in the Stube and kill whatever comes near, the
## guest through the host. Both must see every wave up to 10 cleared, in order; after each clear the
## guest must have no enemy left alive; the guest's kills must pay the guest.
##
## With browsers (the M7 acceptance in real browsers): --players=4 --browsers=1 --build=<deployed id>.
## The two bots wait for two browsers to join the room by its link and clear the waves with them;
## the game sits at /root/Main as in a browser, so the RPC paths match, and the bots do not wait
## for each other at the end (the browsers have no test node).

const STANDS: Dictionary = {1: Vector3(-2.0, 0.0, 3.5), 2: Vector3(-0.8, 0.0, 3.5), 3: Vector3(-2.0, 0.0, 2.3),
		4: Vector3(-0.8, 0.0, 2.3)}
const REACH: float = 7.0
# An enemy alive this long has not found the way in (the host kills it and counts it).
const STUCK_AFTER: float = 75.0
const BREAK: float = 3.0
const TIME_LIMIT: float = 1200.0
const TIMEOUT: float = 30.0
const LAST_WAVE: int = 10

var _main: Node
var _player: Player
var _waves: WaveManager
var _role: String
var _players: int = 2
var _browsers: bool = false
var _failures: Array[String] = []
var _cleared: Array[int] = []
var _born: Dictionary = {}
var _stuck: Array[String] = []
var _kills: int = 0
# Guest: puppets already hit, waiting for the host's word; not hit again meanwhile.
var _hit: Dictionary = {}
var _types: Dictionary = {}
var _done: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	if Engine.has_meta("net_waves_done"):
		get_tree().quit(int(Engine.get_meta("net_waves_done")))
		return
	_role = _arg("role", "host")
	_players = int(_arg("players", "2"))
	_browsers = _arg("browsers", "0") != "0"
	Settings.profile = {"name": "Wirt" if _role == "host" else "Gast", "head": 0, "hat": 0, "jacket": 0, "trousers": 0}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	if _browsers:
		get_tree().root.add_child.call_deferred(_main)
		await _main.ready
	else:
		add_child(_main)
	_player = _main.get_node("Player") as Player
	_waves = _main.get_node("WaveManager") as WaveManager
	Events.wave_cleared.connect(_on_cleared)
	await _run()
	var ok: bool = _failures.is_empty()
	Engine.set_meta("net_waves_done", 0 if ok else 1)
	print("RESULT %s: %s" % [_role, "PASS" if ok else "%d FAILED" % _failures.size()])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var host: bool = _role == "host"
	await get_tree().process_frame
	if host:
		Net.create_room()
		if not await _until(func() -> bool: return Net.in_lobby()):
			return _check(false, "room")
		print("ROOM %s" % Net.code)
		if not await _until(func() -> bool: return Net.roster.size() == _players, 180.0 if _browsers else TIMEOUT):
			return _check(false, "%d of %d players came" % [Net.roster.size(), _players])
		Net.start_match()
		print("STARTED")
	if not await _until(func() -> bool: return Net.in_match() and Coop.world != null, 240.0 if _browsers else TIMEOUT):
		return _check(false, "match started")
	var points_before: int = _player.points.total
	if host:
		_waves.wave_table.break_time = BREAK
		_waves.begin_break(BREAK)
	var stand: Vector3 = STANDS[Net.my_id()]
	while _t < TIME_LIMIT and not _cleared.has(LAST_WAVE):
		await get_tree().physics_frame
		_t += get_physics_process_delta_time()
		_player.global_position = stand
		_player.velocity = Vector3.ZERO
		_player.health._health = float(_player.health.max_health)
		_bot(stand, host)
	print("--- %s t=%.0f, cleared %s" % [_role, _t, _cleared])
	var expected: Array[int] = []
	for w: int in range(1, LAST_WAVE + 1):
		expected.append(w)
	_check(_cleared == expected, "waves 1 to %d cleared in order (%s)" % [LAST_WAVE, _cleared])
	_check(_kills > 0, "%d kills of our own" % _kills)
	if host:
		_check(_stuck.size() <= 1, "%d stuck: %s" % [_stuck.size(), _stuck])
		for id: StringName in [&"wanderer", &"tourist", &"knappe", &"perchte", &"krampus"]:
			_check(_types.get(id, 0) > 0, "%s came in (%d)" % [id, _types.get(id, 0)])
	else:
		_check(_player.points.total > points_before, "the guest's kills paid the guest (%d points)" % (_player.points.total - points_before))
	if _browsers:
		# The browsers see the last clear and the next countdown before the room closes.
		if host:
			await get_tree().create_timer(5.0).timeout
	else:
		_mark.rpc("done")
		if not await _until(func() -> bool: return _done.has("done"), 60.0):
			_check(false, "the other side finished")
	if host:
		await get_tree().create_timer(1.0).timeout
		Net.leave()


func _bot(stand: Vector3, host: bool) -> void:
	for enemy: Enemy in _hit.keys():
		if not enemy.is_alive():
			_hit.erase(enemy)
	# Killed by the other player (or by us): forgotten, so a pooled body sent in again starts afresh.
	for id: int in _born.keys():
		var body := instance_from_id(id) as Enemy
		if body == null or not body.is_alive():
			_born.erase(id)
	for enemy: Enemy in _alive_enemies():
		if _hit.has(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if not _born.has(id):
			_born[id] = _t
		if enemy.global_position.distance_to(stand) <= REACH:
			_types[enemy.data.id] = _types.get(enemy.data.id, 0) + 1
			enemy.receive_hit(100000, true, false, _player)
			_kills += 1
			if not host:
				_hit[enemy] = true
			_born.erase(id)
		elif host and _t - float(_born[id]) > STUCK_AFTER:
			var target: Node = enemy._target
			_stuck.append("%s at %s (%s, after %s)" % [enemy.data.id, enemy.global_position.snapped(Vector3.ONE * 0.1),
					Enemy.State.keys()[enemy._state], target.name if target else "nobody"])
			enemy.receive_hit(100000, false, false, null)
			_born.erase(id)


func _on_cleared(wave: int) -> void:
	_cleared.append(wave)
	print("%s t=%.0f wave %d cleared" % [_role, _t, wave])
	if _role == "host":
		return
	# The host's last kill and the clear come in the same frame; give the puppets a moment.
	await get_tree().create_timer(0.5).timeout
	var left: Array[Enemy] = _alive_enemies()
	if not left.is_empty():
		_check(false, "%d enemies still alive here after wave %d was cleared" % [left.size(), wave])


func _alive_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	var parent: Node = _waves if _role == "host" else _main.get_node("CoopEnemies")
	for child: Node in parent.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive():
			out.append(enemy)
	return out


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures.append(what)


@rpc("any_peer", "call_remote", "reliable")
func _mark(label: String) -> void:
	_done[label] = true


func _until(condition: Callable, timeout: float = TIMEOUT) -> bool:
	var left: float = timeout
	while not condition.call():
		if left <= 0.0:
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback
