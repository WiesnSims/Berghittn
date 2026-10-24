extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_dohlen.tscn
## Headless check of the Bergdohlen (M9 part 5c) on the real main scene: their data and wave; a flock
## of 3 to 5 comes at once, high up, each one of the wave and of the alive; out in the open a bird
## flies at the player, pecks for 8 and flutters off, then comes back; with the Stube's windows
## boarded it waits outside (never tearing at the boards), and once a window is broken it flies in
## and pecks; a stunned bird hangs in the air, a dead one falls.

const FIELD: Vector3 = Vector3(2.0, -0.3, 28.0)
const DOHLE: EnemyData = preload("res://data/enemies/bergdohle.tres")

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


func _heal() -> void:
	player.health._health = float(player.health.max_health)


func _bird(at: Vector3) -> Enemy:
	var bird: Enemy = waves._create_enemy()
	bird.activate(DOHLE, 6, Transform3D(Basis.IDENTITY, at))
	bird.process_mode = Node.PROCESS_MODE_PAUSABLE
	bird._groan_left = 999.0
	return bird


func _until(condition: Callable, seconds: float) -> bool:
	for i: int in roundi(seconds * 60.0):
		if condition.call():
			return true
		await _frames(1)
	return condition.call()


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
	_flock()
	await _open_air()
	await _into_the_hut()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _data() -> void:
	_check(DOHLE.flies and DOHLE.health_for_wave(6) == 108 and is_equal_approx(DOHLE.speed, 6.0) and DOHLE.damage == 8
			and DOHLE.flock_min == 3 and DOHLE.flock_max == 5,
		"Bergdohle: 60 + 8 a wave (wave 6: %d, one Stutzen hit), 6 m/s, pecks for 8, flocks of 3 to 5" % DOHLE.health_for_wave(6))
	var entry: WaveEntry = null
	for e: WaveEntry in waves.wave_table.entries:
		if e.enemy == DOHLE:
			entry = e
	_check(entry != null and entry.first_wave == 6, "in the waves from wave 6")
	_check(Sound.has(&"dohle_caw"), "its caw")


func _flock() -> void:
	waves.wave = 6
	waves._to_spawn = 40
	var alive: int = waves._alive
	var sizes: Array[int] = []
	var high: bool = true
	for i: int in 6:
		var before: int = waves._alive
		waves._queue.append(DOHLE)
		waves._spawn()
		sizes.append(waves._alive - before)
		for child: Node in waves.get_children():
			var bird := child as Enemy
			if bird and bird.is_alive() and bird.data == DOHLE and bird.global_position.y < 1.5:
				high = false
	_check(sizes.all(func(n: int) -> bool: return n >= 3 and n <= 5), "a flock of 3 to 5 at once (%s)" % [sizes])
	_check(waves._to_spawn == 40 - (waves._alive - alive), "each bird is one of the wave")
	_check(high, "they come in high")
	for child: Node in waves.get_children():
		var bird := child as Enemy
		if bird and bird.is_alive():
			bird._take_hit(100000, false, false, null)
	waves._to_spawn = 0
	_check(waves._alive == alive, "and of the alive (%d)" % waves._alive)


func _open_air() -> void:
	player.global_position = _ground(FIELD)
	player.velocity = Vector3.ZERO
	await _frames(2)
	_heal()
	var bird: Enemy = _bird(_ground(FIELD + Vector3(14.0, 0.0, 0.0)) + Vector3.UP * 3.0)
	var health: int = player.health.current()
	var pecked: bool = await _until(func() -> bool: return player.health.current() < health, 5.0)
	_check(pecked and health - player.health.current() == 8, "out in the open it flies at the player and pecks for 8 (%d)" % (health - player.health.current()))
	var near: float = bird.global_position.distance_to(player.global_position)
	await _seconds(0.6)
	_check(bird.global_position.distance_to(player.global_position) > near + 1.0, "then flutters off")
	_heal()
	health = player.health.current()
	pecked = await _until(func() -> bool: return player.health.current() < health, 5.0)
	_check(pecked, "and comes back for another")
	# Stunned it hangs in the air; dead it falls.
	await _seconds(0.5)
	var y: float = bird.global_position.y
	bird.stun(1.0)
	await _seconds(0.8)
	_check(bird.is_stunned() and absf(bird.global_position.y - y) < 0.3 and y > _ground(bird.global_position).y + 0.5, "a stunned bird hangs in the air")
	bird._take_hit(100000, false, false, null)
	await _seconds(2.0)
	var floor_y: float = _ground(bird.global_position).y
	_check(bird.global_position.y < floor_y + 0.4 or bird._rig.is_down(), "a dead one falls")
	await _seconds(Constants.ENEMY_CORPSE_TIME)


func _into_the_hut() -> void:
	# In the Stube with every window boarded; the bird outside, 12 m off.
	var inside: Vector3 = (get_tree().get_first_node_in_group("player_spawn") as Node3D).global_position
	player.global_position = inside
	player.velocity = Vector3.ZERO
	var windows: Array[Barricade] = []
	for node: Node in get_tree().get_nodes_in_group("barricades"):
		var window := node as Barricade
		window.set_boards(6)
		windows.append(window)
	await _frames(10)
	_heal()
	var nearest: Barricade = null
	for window: Barricade in windows:
		if nearest == null or window.global_position.distance_to(inside) < nearest.global_position.distance_to(inside):
			nearest = window
	# Outside the nearest window: out along its outward side (+Z is out of the room).
	var out: Vector3 = Enemy._flat(nearest.global_basis.z).normalized()
	var bird: Enemy = _bird(_ground(nearest.global_position + out * 10.0) + Vector3.UP * 2.0)
	var health: int = player.health.current()
	var worked: Array[bool] = [false]
	var got_in: bool = await _until(func() -> bool:
			worked[0] = worked[0] or bird._state in [Enemy.State.QUEUED, Enemy.State.BREAKING, Enemy.State.CLIMBING]
			return player.health.current() < health, 6.0)
	_check(not got_in, "every window boarded: it stays outside")
	_check(not worked[0] and nearest.boards == 6, "and never tears at the boards (%d boards)" % nearest.boards)
	for window: Barricade in windows:
		if window.global_position.distance_to(nearest.global_position) < 0.5:
			window.set_boards(0)
	got_in = await _until(func() -> bool: return player.health.current() < health, 12.0)
	_check(got_in, "a window broken: it flies in and pecks (%s)" % bird.global_position)
	bird._take_hit(100000, false, false, null)
	await _seconds(0.5)
