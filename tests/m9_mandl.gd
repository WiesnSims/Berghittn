extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_mandl.tscn
## Headless check of the Venedigermandl (M9 part 5a) on the real main scene: his health and lines;
## he turns up at least 20 m from the player with a banner and a marker, outside the wave count;
## digs while nobody is near, runs off when the player comes close (never through a window) and
## never attacks; a stun holds him; hits pay 10 and the kill 1000 + 100 a wave; after 10 s he
## vanishes with "Arrivederci!"; he comes from wave 4, never on a boss wave, about one wave in four.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var gredn: Gredn
var failures: Array[String] = []
var _banners: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
		player.health._health = float(player.health.max_health)


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _ground(at: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _place_player(at: Vector3) -> void:
	player.global_position = _ground(at)
	player.velocity = Vector3.ZERO


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	gredn = main.get_node("Gredn")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	Settings.chatter = true
	Events.event_announced.connect(func(text: String) -> void: _banners.append(text))
	_data()
	await _appears()
	await _vanishes()
	_chance()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _data() -> void:
	var data := load("res://data/enemies/venedigermandl.tres") as EnemyData
	_check(data.treasure and data.health_for_wave(4) == 250 and data.health_for_wave(10) == 400 and is_equal_approx(data.speed, 5.5),
		"Venedigermandl: 150 + 25 a wave health (wave 4: %d), 5.5 m/s" % data.health_for_wave(4))
	_check(waves.wave_table.treasure == data, "the wave table knows him")
	var missing: Array[String] = []
	for line: Array in Gredn.LINES:
		if line[0] == &"venedigermandl" and not Sound.has(line[3]):
			missing.append(String(line[3]))
	for moment: Gredn.Moment in [Gredn.Moment.APPEAR, Gredn.Moment.RUN, Gredn.Moment.HIT, Gredn.Moment.VANISH, Gredn.Moment.DEATH]:
		if not Gredn.LINES.any(func(l: Array) -> bool: return l[0] == &"venedigermandl" and l[1] == moment):
			missing.append("moment %d" % moment)
	_check(missing.is_empty() and Sound.has(&"gredn_venedigermandl_giggle"), "all his lines and his giggle have voices %s" % [missing])


func _appears() -> void:
	_place_player(FIELD)
	await _frames(3)
	waves.wave = 4
	var alive_before: int = waves._alive
	var died: Array[int] = [0]
	_banners.clear()
	var mandl: Enemy = waves.send_mandl()
	_check(mandl != null and mandl.is_alive(), "he turns up")
	if mandl == null:
		return
	# The wave manager is off here; he runs on his own.
	mandl.process_mode = Node.PROCESS_MODE_PAUSABLE
	mandl.died.connect(func(_e: Enemy) -> void: died[0] += 1)
	_check(waves.send_mandl() == null, "only one at a time")
	var distance: float = mandl.global_position.distance_to(player.global_position)
	_check(distance >= Constants.MANDL_SPAWN_DISTANCE, "at least 20 m from the player (%.1f m)" % distance)
	_check(EventDirector.walkable(mandl.get_world_3d(), player.global_position, mandl.global_position), "somewhere the player can walk to")
	_check(_banners.has(tr("EVENT_MANDL")), "banner: %s" % [_banners])
	_check(mandl.find_children("*", "MapMarker", true, false).size() == 1, "a marker over him")
	_check(waves._alive == alive_before and mandl.health == 250, "not in the wave count, 250 health at wave 4")
	await _seconds(0.5)
	_check(gredn.last_heard >= 0 and Gredn.LINES[gredn.last_heard][1] == Gredn.Moment.APPEAR, "\"Do glanzt wos!\"")
	var at: Vector3 = mandl.global_position
	await _seconds(1.0)
	_check(mandl.global_position.distance_to(at) < 0.3 and mandl._rig._action == EnemyRig.Action.DIG, "nobody near: he digs")
	# The player comes up to 9 m away.
	var toward: Vector3 = Enemy._flat(player.global_position - mandl.global_position).normalized()
	var spot: Vector3 = mandl.global_position + toward * 9.0
	_place_player(spot)
	player.global_position = NavigationServer3D.map_get_closest_point(mandl.get_world_3d().navigation_map, player.global_position)
	await _frames(2)
	var start: float = Enemy._flat(mandl.global_position - player.global_position).length()
	var climbed: bool = false
	var digging: bool = false
	var health_before: int = int(player.health._health)
	# Darting: how often he swings from one side to the other of his way.
	var swings: int = 0
	var last_side: float = 0.0
	var after: float = start
	for i: int in 120:
		await _frames(1)
		climbed = climbed or mandl._state != Enemy.State.CHASING
		after = Enemy._flat(mandl.global_position - player.global_position).length()
		if after < Constants.MANDL_CALM:
			digging = digging or mandl._rig._action == EnemyRig.Action.DIG
		var away: Vector3 = Enemy._flat(mandl.global_position - player.global_position).normalized()
		var side: float = signf(away.cross(Enemy._flat(mandl.velocity)).y)
		if side != 0.0 and last_side != 0.0 and side != last_side:
			swings += 1
		if side != 0.0:
			last_side = side
	_check(after > start + 4.0, "the player near: he runs off (%.1f m to %.1f m)" % [start, after])
	_check(swings >= 2, "darting from side to side (%d swings in 2 s)" % swings)
	_check(not climbed, "never climbing through a window")
	_check(not digging, "and no digging while near")
	# Corner him: right on top of him, he still never strikes.
	player.global_position = mandl.global_position + Vector3(0.6, 0.0, 0.0)
	await _seconds(0.5)
	_check(mandl._state != Enemy.State.ATTACKING and int(player.health._health) >= health_before, "he never attacks")
	mandl.stun(1.0)
	_check(mandl.is_stunned(), "a stun holds him")
	await _seconds(1.1)
	# Pay: 10 a hit, and the sack for the kill.
	var points: int = player.points.total
	mandl.receive_hit(60, false, false, player)
	_check(player.points.total == points + Constants.POINTS_HIT, "a hit pays 10 (%d)" % (player.points.total - points))
	points = player.points.total
	gredn.last_heard = -1
	mandl.receive_hit(1000, true, false, player)
	_check(not mandl.is_alive() and player.points.total == points + 1400, "the kill pays 1000 + 100 x 4 (%d)" % (player.points.total - points))
	_check(died[0] == 1 and waves._alive == alive_before, "his death leaves the wave count alone (%d alive)" % waves._alive)
	_check(gredn.last_heard >= 0 and Gredn.LINES[gredn.last_heard][1] == Gredn.Moment.DEATH, "\"Porca miseria…\"")
	await _frames(1)
	_check(mandl.find_children("*", "MapMarker", true, false).is_empty(), "the marker is gone")
	await _seconds(Constants.ENEMY_CORPSE_TIME + Constants.ENEMY_DEATH_FALL_TIME + 0.5)


func _vanishes() -> void:
	_place_player(FIELD)
	await _frames(3)
	var mandl: Enemy = waves.send_mandl()
	_check(mandl != null, "another one turns up")
	if mandl == null:
		return
	mandl.process_mode = Node.PROCESS_MODE_PAUSABLE
	var died: Array[int] = [0]
	var vanished: Array[int] = [0]
	mandl.died.connect(func(_e: Enemy) -> void: died[0] += 1)
	mandl.vanished.connect(func(_e: Enemy) -> void: vanished[0] += 1)
	await _seconds(Constants.MANDL_LIFETIME - 1.0)
	# Near enough to hear him go.
	_place_player(mandl.global_position + Vector3(12.0, 0.0, 0.0))
	await _seconds(0.7)
	_check(mandl.is_alive(), "still there after 9.7 s")
	gredn.last_heard = -1
	await _seconds(0.5)
	_check(not mandl.is_alive() and vanished[0] == 1 and died[0] == 0, "gone after 10 s, not killed")
	_check(gredn.last_heard >= 0 and Gredn.LINES[gredn.last_heard][1] == Gredn.Moment.VANISH, "\"Arrivederci!\" (%.1f m away)" % mandl.global_position.distance_to(player.global_position))
	_check(waves.send_mandl() != null, "and he can come again")
	await _seconds(Constants.MANDL_LIFETIME + 0.5)


func _chance() -> void:
	var comes: Dictionary = {}
	for wave: int in [3, 4, 5, 6]:
		var count: int = 0
		for i: int in 400:
			waves._start_wave(wave)
			if waves._mandl_left > 0.0:
				count += 1
		comes[wave] = count
	waves._mandl_left = -1.0
	_check(comes[3] == 0 and comes[5] == 0, "never before wave 4 or on the boss wave (%s)" % [comes])
	_check(comes[4] > 60 and comes[4] < 140 and comes[6] > 60 and comes[6] < 140, "about one wave in four (%s of 400)" % [comes])
