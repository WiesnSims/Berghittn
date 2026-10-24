extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_wilderer.tscn
## Headless check of the Wilderer (M9 part 5b) on the real main scene: his data, wave and lines; a
## player in sight 16 m off: he stops, aims 1.2 s with the glint showing, and the shot takes 25 with a
## streak; then he moves on; stepping aside once the aim has locked dodges it; a wall stops him aiming;
## too far, he walks on; close up he clubs with the stock; a stun breaks his aim.

## An open strip of snow south of the hut, x from -20 to 29.
const FIELD: Vector3 = Vector3(2.0, -0.3, 28.0)

var main: Node
var player: Player
var waves: WaveManager
var failures: Array[String] = []


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


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _ground(at: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 10.0, at + Vector3.DOWN * 10.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _place(at: Vector3) -> void:
	player.global_position = _ground(at)
	player.velocity = Vector3.ZERO


func _heal() -> void:
	player.health._health = float(player.health.max_health)


func _spawn(at: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(load("res://data/enemies/wilderer.tres"), 7, Transform3D(Basis.IDENTITY, _ground(at)))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy._groan_left = 999.0
	return enemy


func _until(condition: Callable, seconds: float) -> bool:
	for i: int in roundi(seconds * 60.0):
		if condition.call():
			return true
		await _frames(1)
	return condition.call()


func _trails() -> int:
	var count: int = 0
	for child: Node in waves.get_children():
		var script := child.get_script() as Script
		if script and script.resource_path.ends_with("ricochet_trail.gd"):
			count += 1
	return count


func _kill(enemy: Enemy) -> void:
	enemy._take_hit(100000, false, false, null)
	await _seconds(0.5)


func _run() -> void:
	# The navigation map is ready after a few dozen frames.
	for i: int in 60:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.health.invincible_left = 0.0
	_data()
	await _shoots()
	await _wall()
	await _far_and_near()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _data() -> void:
	var data := load("res://data/enemies/wilderer.tres") as EnemyData
	_check(data.health_for_wave(7) == 460 and is_equal_approx(data.speed, 3.0) and data.shot_damage == 25 and is_equal_approx(data.aim_time, 1.2),
		"Wilderer: 250 + 30 a wave (wave 7: %d), 3 m/s, 25 a shot after 1.2 s" % data.health_for_wave(7))
	var entry: WaveEntry = null
	for e: WaveEntry in waves.wave_table.entries:
		if e.enemy == data:
			entry = e
	_check(entry != null and entry.first_wave == 7 and is_equal_approx(entry.weight, 1.0), "in the waves from wave 7, weight 1")
	var missing: Array[String] = []
	for line: Array in Gredn.LINES:
		if line[0] == &"wilderer" and not Sound.has(line[3]):
			missing.append(String(line[3]))
	var texts: Array = Gredn.LINES.filter(func(l: Array) -> bool: return l[0] == &"wilderer").map(func(l: Array) -> String: return l[2])
	_check(missing.is_empty() and texts.has("Des is mei Revier!") and texts.has("Hob di!"), "his lines have voices %s" % [missing])


func _shoots() -> void:
	_place(FIELD + Vector3(16.0, 0.0, 0.0))
	var wilderer: Enemy = _spawn(FIELD)
	await _frames(2)
	_heal()
	var aiming: bool = await _until(func() -> bool: return wilderer._state == Enemy.State.AIMING, 1.0)
	_check(aiming, "a player in sight 16 m off: he stops and aims")
	await _seconds(0.5)
	_check(wilderer._glint != null and wilderer._glint.visible, "the glint off his scope while he aims")
	var health: int = player.health.current()
	var trails: int = _trails()
	await _until(func() -> bool: return player.health.current() < health, 1.0)
	_check(health - player.health.current() == 25, "the shot takes 25 (%d)" % (health - player.health.current()))
	_check(_trails() > trails, "with a streak")
	_check(not wilderer._glint.visible, "the glint is gone")
	var at: Vector3 = wilderer.global_position
	await _seconds(1.5)
	_check(wilderer._move_left > 0.0 or wilderer.global_position.distance_to(at) > 2.0, "then he moves on (%.1f m)" % wilderer.global_position.distance_to(at))
	# The next aim: step aside 3 m once it has locked, just before the shot.
	await _until(func() -> bool: return wilderer._state == Enemy.State.AIMING, 5.0)
	_heal()
	health = player.health.current()
	await _until(func() -> bool: return wilderer._aim_locked, 1.5)
	var side: Vector3 = Enemy._flat(player.global_position - wilderer.global_position).normalized().cross(Vector3.UP)
	_place(player.global_position + side * 3.0)
	await _until(func() -> bool: return wilderer._state != Enemy.State.AIMING, 1.5)
	await _frames(2)
	_check(player.health.current() == health, "stepping aside once the aim has locked dodges it")
	# A stun breaks his aim.
	await _until(func() -> bool: return wilderer._state == Enemy.State.AIMING, 5.0)
	_heal()
	health = player.health.current()
	wilderer.stun(1.0)
	await _frames(2)
	_check(wilderer._state != Enemy.State.AIMING and not wilderer._glint.visible, "a stun breaks his aim")
	await _seconds(0.9)
	_check(player.health.current() == health, "and no shot comes")
	await _kill(wilderer)


func _wall() -> void:
	# The player in the Stube; the Wilderer outside, 15 m off, with a wall between them.
	var inside: Vector3 = (get_tree().get_first_node_in_group("player_spawn") as Node3D).global_position
	# Right where the player starts (from above, the ground would be the roof).
	player.global_position = inside
	await _frames(10)
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var map: RID = main.get_viewport().world_3d.navigation_map
	var outside: Vector3 = Vector3.INF
	for i: int in 32:
		var spot: Vector3 = NavigationServer3D.map_get_closest_point(map, inside + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 32.0) * 15.0)
		if absf(Enemy._flat(spot - inside).length() - 15.0) > 1.5:
			continue
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * Constants.WILDERER_EYE_HEIGHT, player.global_position + Vector3.UP * Constants.WILDERER_AIM_HEIGHT, Constants.LAYER_WORLD)
		if not space.intersect_ray(query).is_empty():
			outside = spot
			break
	_check(outside != Vector3.INF, "a spot behind a wall")
	if outside == Vector3.INF:
		return
	var wilderer: Enemy = _spawn(outside)
	# Held where he is, so he cannot walk into sight.
	wilderer.data = wilderer.data.duplicate()
	wilderer.data.speed = 0.0
	var aimed: bool = await _until(func() -> bool: return wilderer._state == Enemy.State.AIMING, 1.5)
	_check(not aimed, "a wall between: he does not aim")
	await _kill(wilderer)


func _far_and_near() -> void:
	_place(FIELD + Vector3(15.0, 0.0, 0.0))
	var wilderer: Enemy = _spawn(FIELD + Vector3(-20.0, 0.0, 0.0))
	await _frames(2)
	var start: float = Enemy._flat(player.global_position - wilderer.global_position).length()
	var aimed: bool = await _until(func() -> bool: return wilderer._state == Enemy.State.AIMING, 1.0)
	var now: float = Enemy._flat(player.global_position - wilderer.global_position).length()
	_check(not aimed and now < start - 1.5, "35 m off: he walks on (%.1f to %.1f m)" % [start, now])
	_place(wilderer.global_position + Enemy._flat(player.global_position - wilderer.global_position).normalized() * 1.2)
	_heal()
	var health: int = player.health.current()
	var struck: bool = await _until(func() -> bool: return wilderer._state == Enemy.State.ATTACKING, 1.0)
	await _seconds(0.7)
	_check(struck and health - player.health.current() == 30, "close up he clubs with the stock (%d)" % (health - player.health.current()))
	await _kill(wilderer)
