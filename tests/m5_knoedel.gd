extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_knoedel.tscn
## Headless check of the Knödelwerfer (section 6a) on the real main scene: a dumpling lobbed into a
## crowd bursts for 180 within 3 m (not beyond), leaves a sticky pile that halves the speed of whoever
## wades in and keeps them slow for 4 s after, the Knödeltris fans out three smaller ones for three
## rounds, the dumplings come from a pool, the next one shows at the muzzle as the gun is ready again,
## and the Hüttentruhe has it at weight 1.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var gun: WeaponData
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


func _spawn(data: EnemyData, at: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(data, 1, Transform3D(Basis.IDENTITY, at))
	# The wave manager is switched off in this test; its enemies must not inherit that.
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	return enemy


func _look_flat(direction: Vector3) -> void:
	player.look_at(player.global_position + direction, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var camera := player.get_node("Head/Camera3D") as CameraRecoil
	camera._target = Vector2.ZERO
	camera._current = Vector2.ZERO
	camera.rotation = Vector3.ZERO


func _clear(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		e.set_physics_process(true)
		if e.is_alive():
			e.receive_hit(100000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _knoedel_nodes() -> Array:
	return player.weapons._slots.filter(func(s: WeaponHolder.GunSlot) -> bool: return s.data == gun)[0].behavior._knoedel


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/knoedelwerfer.tres")
	await _frames(10)

	await _burst()
	await _pile()
	await _trio()
	await _pool()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _burst() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	player.global_position = FIELD
	player.weapons.give_weapon(gun)
	await _seconds(0.6)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.weapon == gun and holder.mag == 12 and holder.reserve == 36, "Knödelwerfer in hand, 12 / 36")
	# A Knappe in the line of fire, a wanderer 2 m beside it, one 5 m beside it.
	var spots: Array[Vector3] = [FIELD + Vector3(8, 0, 0), FIELD + Vector3(8, 0, 2), FIELD + Vector3(8, 0, 5)]
	var list: Array[Enemy] = [_spawn(knappe, spots[0]), _spawn(wanderer, spots[1]), _spawn(wanderer, spots[2])]
	for i: int in list.size():
		list[i].set_physics_process(false)
		list[i].global_position = spots[i]
	await _frames(3)
	var before: Array[int] = [list[0].health, list[1].health, list[2].health]
	holder._fire()
	_check(holder.mag == 11, "one dumpling used")
	await _seconds(0.8)
	_check(list[0].health == before[0] - gun.damage, "the Knappe it hits takes %d (%d -> %d)" % [gun.damage, before[0], list[0].health])
	_check(not list[1].is_alive(), "a wanderer 2 m away is caught in the burst")
	_check(list[2].health == before[2], "one 5 m away is not")
	await _clear(list)


func _pile() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var behavior: Object = player.weapons._behavior
	var piles: Array = behavior._piles.filter(func(p: Node3D) -> bool: return p.is_busy())
	# The first burst's pile has sunk by now; lay a fresh one with a shot at the ground ahead.
	player.global_position = FIELD
	_look_flat(Vector3(1, 0, 0))
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-25.0)
	# A wanderer standing just past where the dumpling comes down: a ground burst must reach it too.
	var bystander: Enemy = _spawn(wanderer, FIELD + Vector3(5.0, 0.0, 0.0))
	bystander.health = 1000
	bystander.set_physics_process(false)
	await _frames(3)
	player.weapons._cooldown = 0.0
	player.weapons._fire()
	await _seconds(0.6)
	piles = behavior._piles.filter(func(p: Node3D) -> bool: return p.is_busy())
	_check(piles.size() == 1, "a sticky pile lies where it burst")
	if piles.size() == 1:
		var gap: float = Vector2(bystander.global_position.x - piles[0].global_position.x, bystander.global_position.z - piles[0].global_position.z).length()
		_check(bystander.health == 1000 - gun.damage, "a ground burst %.1f m away hurts (%d)" % [gap, 1000 - bystander.health])
	await _clear([bystander])
	if piles.is_empty():
		return
	var pile: Node3D = piles[0]
	# A wanderer walks into it from beyond and keeps walking towards the player.
	var walker: Enemy = _spawn(wanderer, pile.global_position + Vector3(0.5, 0.0, 0.0))
	walker.health = 100000
	await _seconds(0.3)
	_check(is_equal_approx(walker._slow_factor, gun.slow_factor), "wading in it halves the speed (x%.2f)" % walker._slow_factor)
	# Carry it out of the pile: the slow lasts slow_time more.
	walker.set_physics_process(false)
	walker.global_position = pile.global_position + Vector3(6, 0, 0)
	# The player stands further out the same way, so its chase does not lead back through the pile.
	player.global_position = pile.global_position + Vector3(11, 0.3, 0)
	walker.set_physics_process(true)
	await _seconds(gun.slow_time - 0.5)
	_check(is_equal_approx(walker._slow_factor, gun.slow_factor), "still slow %.1f s after stepping out" % (gun.slow_time - 0.5))
	await _seconds(1.0)
	_check(is_equal_approx(walker._slow_factor, 1.0), "full speed again after %.0f s" % gun.slow_time)
	await _seconds(gun.pile_time)
	_check(not pile.is_busy() and not pile.visible, "the pile is gone after %.0f s" % gun.pile_time)
	await _clear([walker])


func _trio() -> void:
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var holder: WeaponHolder = player.weapons
	holder.mag = 12
	holder._cooldown = 0.0
	holder.fire_secondary()
	var flying: Array = _knoedel_nodes().filter(func(k: Node3D) -> bool: return k.is_busy())
	_check(flying.size() == 3 and holder.mag == 12 - gun.secondary_rounds, "the Knödeltris: three in the air for three rounds (%d flying, %d left)" % [flying.size(), holder.mag])
	if flying.size() == 3:
		await _frames(10)
		var spread: float = flying[0].global_position.distance_to(flying[2].global_position)
		_check(spread > 0.5, "fanned out (%.1f m apart after 1/6 s)" % spread)
	await _seconds(3.0)


func _pool() -> void:
	var holder: WeaponHolder = player.weapons
	for i: int in 20:
		holder.mag = 12
		holder._cooldown = 0.0
		holder._fire()
		await _frames(2)
	_check(_knoedel_nodes().size() <= Constants.KNOEDEL_POOL, "20 shots, %d dumplings built (pool of %d)" % [_knoedel_nodes().size(), Constants.KNOEDEL_POOL])
	await _seconds(Constants.LOBBED_MAX_FLIGHT + 0.5)
	_check(_knoedel_nodes().all(func(k: Node3D) -> bool: return not k.is_busy()), "every dumpling has landed or burst")


func _extras() -> void:
	var model := gun.viewmodel.instantiate() as Viewmodel
	_check(absf(model.fire_animation_time() - 1.0 / gun.fire_rate) < 0.01, "the next dumpling shows at the muzzle as the gun is ready (%.2f s)" % model.fire_animation_time())
	model.free()
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Knödelwerfer, weight 1")
