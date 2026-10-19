extends Node
## Four players in one match (M7 part 4) over the real relay, one role per process:
##     node tools/net_test.mjs res://tests/net_four.tscn
## None of them dressed their hiker, so each must wear their peer's own default jacket. Each walks a
## small circle at a spot of their own, firing, and must see the other three there. Then the host
## keeps 24 enemies alive while everyone kills one now and then, and each player measures what the
## relay brings them (NETWORKING.md section 9: under 10 KiB/s down) and the host its frame time.
##
## Bench mode for the browser measurement: --bench=<seconds> --players=<room size>, with --build=<id>
## of the deployed build. The room's other players are real browsers, so the game sits at /root/Main
## as in a browser (RPC paths must match) and nothing is checked: the host starts once everyone is
## in, the bots walk and fire, the host keeps 24 enemies alive for that long and then leaves.

const TIMEOUT: float = 40.0
## Where each slot (peers in order) stands, from the spawn (m).
const SPOTS: Array[Vector3] = [Vector3(2.0, 0.0, 1.5), Vector3(-2.0, 0.0, -1.0), Vector3(2.0, 0.0, -1.5), Vector3(-2.0, 0.0, 1.5)]
const CIRCLE: float = 0.3
const NEAR: float = 0.8
const FIRE_INTERVAL: float = 0.2
const KILL_INTERVAL: float = 2.0
const CROWD_WAVE: int = 6
const WARM_UP: float = 3.0
const MEASURE: float = 10.0
## NETWORKING.md section 9.
const DOWN_BUDGET_KIB: float = 10.0
## The host's game logic per frame, leaving the rest of a 60 FPS frame to drawing.
const HOST_FRAME_BUDGET_MS: float = 8.0
const MIN_PUPPETS: int = 20

var _main: Node
var _player: Player
var _waves: WaveManager
var _role: String
var _players: int
var _bench: float
var _failed: String = ""
# Label -> {peer: true} of everyone else who reached it.
var _marks: Dictionary = {}
var _spot: Vector3
var _playing: bool = false
var _time: float = 0.0
var _fire_left: float = 0.0
var _kill_left: float = KILL_INTERVAL


func _ready() -> void:
	# main reloads the current scene when a match ends, which would start this test again.
	if Engine.has_meta("net_four_done"):
		get_tree().quit(int(Engine.get_meta("net_four_done")))
		return
	_role = _arg("role", "host")
	_players = int(_arg("players", "4"))
	_bench = float(_arg("bench", "0"))
	# Never dressed: each must get their peer's default.
	Settings.profile = {}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	if _bench > 0.0:
		get_tree().root.add_child.call_deferred(_main)
		await _main.ready
	else:
		add_child(_main)
	_player = _main.get_node("Player") as Player
	_waves = _main.get_node("WaveManager") as WaveManager
	var ok: bool = false
	if _bench > 0.0:
		ok = await _run_bench()
	else:
		ok = await _run()
	Engine.set_meta("net_four_done", 0 if ok else 1)
	# Our last mark is still in the relay peer's next frame.
	await get_tree().create_timer(0.5).timeout
	print("PASS" if ok else "FAIL %s: %s" % [_role, _failed])
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	var host: bool = _role == "host"
	await get_tree().process_frame
	if host:
		Net.create_room()
		if not await _until(func() -> bool: return Net.in_lobby()):
			return _fail("no room")
		print("ROOM %s" % Net.code)
		if not await _until(func() -> bool: return Net.roster.size() == _players, 120.0 if _bench > 0.0 else TIMEOUT):
			return _fail("only %d of %d players came" % [Net.roster.size(), _players])
		Net.start_match()
	if not await _until(func() -> bool: return Net.in_match() and Coop.world != null):
		return _fail("no match (%s)" % Net.state)
	if Net.roster.size() != _players:
		return _fail("%d players in the match, not %d" % [Net.roster.size(), _players])
	if not await _sync("started"):
		return false
	var bots: Array = (_marks["started"] as Dictionary).keys() + [Net.my_id()]
	if not _check_jackets(bots):
		return false
	_player.health.invincible_left = 1.0e9
	_spot = _spot_of(Net.my_id())
	_playing = true
	if not await _see_the_others(bots):
		return false
	if not await _sync("met"):
		return false
	if host:
		_waves._start_wave(CROWD_WAVE)
	if host and not await _until(func() -> bool: return _fill()):
		return _fail("never 24 alive (%d)" % _waves._alive)
	if not await _sync("full"):
		return false
	if _bench > 0.0:
		await get_tree().create_timer(_bench).timeout
		print("BENCH done")
	elif not await _measure(host):
		return false
	if not await _sync("measured"):
		return false
	_playing = false
	if host:
		await get_tree().create_timer(1.0).timeout
		Net.leave()
	return true


func _run_bench() -> bool:
	var host: bool = _role == "host"
	await get_tree().process_frame
	if host:
		Net.create_room()
		if not await _until(func() -> bool: return Net.in_lobby()):
			return _fail("no room")
		print("ROOM %s" % Net.code)
		if not await _until(func() -> bool: return Net.roster.size() == _players, 120.0):
			return _fail("only %d of %d players came" % [Net.roster.size(), _players])
		Net.start_match()
	if not await _until(func() -> bool: return Net.in_match() and Coop.world != null):
		return _fail("no match (%s)" % Net.state)
	_player.health.invincible_left = 1.0e9
	_spot = _spot_of(Net.my_id())
	_playing = true
	print("BENCH playing")
	if not host:
		await _until(func() -> bool: return not Net.in_match(), _bench + 60.0)
		return true
	await get_tree().create_timer(8.0).timeout
	_waves._start_wave(CROWD_WAVE)
	_fill()
	print("BENCH full")
	await get_tree().create_timer(_bench).timeout
	_playing = false
	print("BENCH done")
	Net.leave()
	return true


## The host keeps the crowd at the cap; true once it is there.
func _fill() -> bool:
	_waves._to_spawn = 100000
	while _waves._alive < Constants.MAX_ALIVE_ENEMIES:
		_waves._spawn()
	return true


func _check_jackets(bots: Array) -> bool:
	var jackets: Dictionary = {}
	for peer: int in bots:
		var profile: Dictionary = Net.roster[peer]
		if profile != HikerStyle.default_profile(peer):
			return _fail("peer %d wears %s, not its default" % [peer, profile])
		jackets[profile["jacket"]] = true
	if jackets.size() != bots.size():
		return _fail("%d players share %d jackets" % [bots.size(), jackets.size()])
	print("jackets: %d players, %d different defaults" % [bots.size(), jackets.size()])
	return true


func _see_the_others(bots: Array) -> bool:
	var coop := _main.get_node("CoopPlayers") as CoopPlayers
	var seen := func() -> bool:
		var count: int = 0
		for peer: int in Net.roster:
			if peer == Net.my_id():
				continue
			var hiker := coop.node_of(peer) as Hiker
			if hiker == null or not hiker.visible:
				return false
			if peer in bots:
				var theirs: Vector3 = _spot_of(peer)
				if Vector2(hiker.global_position.x - theirs.x, hiker.global_position.z - theirs.z).length() > NEAR:
					return false
			count += 1
		return count == _players - 1
	if not await _until(seen):
		var where: Dictionary = {}
		for peer: int in Net.roster:
			var node: Node3D = coop.node_of(peer)
			where[peer] = node.global_position if node else null
		return _fail("not everyone at their spot: %s" % where)
	print("SEEN %d others" % (_players - 1))
	return true


func _measure(host: bool) -> bool:
	await get_tree().create_timer(WARM_UP).timeout
	if not host and _alive_enemies().size() < MIN_PUPPETS:
		return _fail("only %d enemies here, the host has %d" % [_alive_enemies().size(), MIN_PUPPETS])
	var start: Vector2i = Net.traffic()
	var physics: Array[float] = []
	var process: Array[float] = []
	var crowd: Array[int] = []
	var left: float = MEASURE
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		crowd.append(_alive_enemies().size())
	var rate: Vector2 = Vector2(Net.traffic() - start) / 1024.0 / MEASURE
	print("NET %s down %.2f up %.2f KiB/s (enemies %.1f avg)" % [_role, rate.x, rate.y, _average(crowd)])
	var frame: float = _average(physics) + _average(process)
	print("FRAME %s logic %.2f ms avg (physics %.2f, process %.2f), worst physics %.2f ms" % [_role,
			frame, _average(physics), _average(process), physics.max()])
	if rate.x > DOWN_BUDGET_KIB:
		return _fail("%.2f KiB/s down, over %.0f" % [rate.x, DOWN_BUDGET_KIB])
	if host and frame > HOST_FRAME_BUDGET_MS:
		return _fail("host logic %.2f ms a frame, over %.0f" % [frame, HOST_FRAME_BUDGET_MS])
	return true


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	# Around our spot, facing along the circle, so the pose always changes.
	var angle: float = _time * 1.5
	_player.global_position = _spot + Vector3(cos(angle), 0.0, sin(angle)) * CIRCLE
	_player.rotation.y = -angle
	_fire_left -= delta
	if _fire_left <= 0.0:
		_fire_left = FIRE_INTERVAL
		_player.weapons.acted.emit(WeaponHolder.Act.SHOT, 1)
	_kill_left -= delta
	if _kill_left <= 0.0:
		_kill_left = KILL_INTERVAL
		var nearest: Enemy = null
		for enemy: Enemy in _alive_enemies():
			if nearest == null or enemy.global_position.distance_squared_to(_spot) < nearest.global_position.distance_squared_to(_spot):
				nearest = enemy
		if nearest:
			nearest.receive_hit(99999, true, false, _player)
	if Net.is_host() and _waves._to_spawn > 0:
		_fill()


func _alive_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	var parent: Node = _waves if Net.is_host() else _main.get_node("CoopEnemies")
	for child: Node in parent.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive():
			out.append(enemy)
	return out


func _spot_of(peer: int) -> Vector3:
	var peers: Array = Net.roster.keys()
	peers.sort()
	var spawn := get_tree().get_first_node_in_group("player_spawn") as Node3D
	return spawn.global_position + SPOTS[peers.find(peer) % SPOTS.size()]


func _average(values: Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1.0)


## Every bot reaches `label` before any goes on.
func _sync(label: String) -> bool:
	_mark.rpc(label)
	if await _until(func() -> bool: return (_marks.get(label, {}) as Dictionary).size() >= _players - 1):
		return true
	return _fail("only %s reached '%s'" % [_marks.get(label, {}).keys(), label])


@rpc("any_peer", "call_remote", "reliable")
func _mark(label: String) -> void:
	if not _marks.has(label):
		_marks[label] = {}
	(_marks[label] as Dictionary)[multiplayer.get_remote_sender_id()] = true


func _until(condition: Callable, timeout: float = TIMEOUT) -> bool:
	var left: float = timeout
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
