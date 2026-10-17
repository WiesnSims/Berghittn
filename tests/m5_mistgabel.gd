extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_mistgabel.tscn
## Headless check of the Mistgabel (section 6a) on the real main scene: on V in place of the shovel; the
## thrust goes 3 m straight along the aim through the first two bodies in the line (100 each), not a
## third behind them, not one off to the side, not one past 3 m. Holding V past the thrust lifts the
## skewered one up over the player's head; letting go hurls it where the player looks, and where it
## comes down it and everything within 2 m take 80. The Krampus takes the thrust but is too heavy to
## lift; held too long, the fork throws by itself. Plus chest weight 1 and no wall-buy.

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
		# Nothing in this test is about the player's health.
		player.health._health = float(player.health.max_health)


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


## A spot on the pasture, set down on the ground there.
func _ground(offset: Vector3) -> Vector3:
	var at: Vector3 = FIELD + offset
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _spawn(data: EnemyData, offset: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var at: Vector3 = _ground(offset)
	enemy.activate(data, 1, Transform3D(Basis.IDENTITY, at))
	# The wave manager is switched off in this test; its enemies must not inherit that.
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Standing still, so distances stay what the test set; damage over time still runs.
	enemy.data = enemy.data.duplicate()
	enemy.data.speed = 0.0
	enemy.global_position = at
	enemy.health = 10000
	return enemy


func _look_flat(direction: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + direction, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var camera := player.get_node("Head/Camera3D") as CameraRecoil
	camera._target = Vector2.ZERO
	camera._current = Vector2.ZERO
	camera.rotation = Vector3.ZERO


func _clear(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		if e.is_alive():
			e._take_hit(1000000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


## A wall of the world's kind standing on the pasture, turned `yaw` degrees.
func _wall(offset: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.3)
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	body.global_position = _ground(offset) + Vector3.UP * 1.0
	body.rotation.y = deg_to_rad(yaw)
	return body


## Swings once with V, holding it past the blow when `hold` is set.
func _swing(hold: bool) -> void:
	var holder: WeaponHolder = player.weapons
	holder.force_melee_hold = hold
	holder._start_melee()
	await _frames(roundi(60.0 / gun.fire_rate * Constants.MELEE_HIT_FRACTION) + 2)


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/mistgabel.tres")
	await _frames(10)

	await _thrust()
	await _hurl()
	await _heavy()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _thrust() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = _ground(Vector3.ZERO)
	player.weapons.give_weapon(gun)
	await _frames(5)
	_look_flat(Vector3(1, 0, 0))
	_check(player.weapons.melee_weapon == gun, "the Mistgabel takes the shovel's place on V")
	# In the line at 1.3 m, 2.1 m and 2.8 m; 1.5 m off to the side at 40°; 4 m out in the line.
	var first: Enemy = _spawn(wanderer, Vector3(1.3, 0, 0))
	var second: Enemy = _spawn(wanderer, Vector3(2.1, 0, 0.1))
	var third: Enemy = _spawn(wanderer, Vector3(2.8, 0, -0.1))
	var aside: Enemy = _spawn(wanderer, Vector3(1.5 * cos(deg_to_rad(40.0)), 0, 1.5 * sin(deg_to_rad(40.0))))
	var past: Enemy = _spawn(wanderer, Vector3(4.0, 0, 0))
	await _frames(5)
	await _swing(false)
	_check(first.health == 10000 - gun.damage and second.health == 10000 - gun.damage, "the thrust goes through the first two for %d (%d, %d)" % [gun.damage, 10000 - first.health, 10000 - second.health])
	_check(third.health == 10000, "not a third behind them")
	_check(aside.health == 10000, "not one 40° to the side")
	_check(past.health == 10000, "not 4 m out")
	await _clear([first, second, third, aside, past])


func _hurl() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(10.0)
	var skewered: Enemy = _spawn(wanderer, Vector3(1.4, 0, 0))
	# A crowd further down the line, where it comes down.
	var crowd: Array[Enemy] = []
	for x: float in [8.0, 9.5, 11.0, 12.5, 14.0]:
		crowd.append(_spawn(wanderer, Vector3(x, 0, 0.6)))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _frames(5)
	_check(holder.is_blocking() and skewered.is_lifted(), "V held past the thrust: it is lifted on the fork")
	await _seconds(0.5)
	var eye: Vector3 = holder.global_position
	_check(skewered.global_position.y > eye.y and skewered.global_position.distance_to(eye) < 2.5, "carried up over the player's head (feet %.1f m above the eye)" % (skewered.global_position.y - eye.y))
	var landed: Array[Vector3] = []
	var behavior: Object = holder._melee_behavior
	holder.force_melee_hold = false
	await _frames(2)
	_check(not holder.is_blocking() and not skewered.is_lifted(), "let go: it is hurled")
	for i: int in 180:
		await _frames(1)
		if not skewered._hurled:
			landed.append(skewered.global_position)
			break
	_check(landed.size() == 1, "and comes down")
	if landed.is_empty():
		return
	var out: float = Vector2(landed[0].x - FIELD.x, landed[0].z - FIELD.z).length()
	_check(out > 5.0, "%.1f m away" % out)
	_check(skewered.health == 10000 - gun.damage - gun.secondary_damage, "it took the thrust and the fall (%d)" % (10000 - skewered.health))
	var near_hit: bool = true
	var any_near: bool = false
	for e: Enemy in crowd:
		var d: float = Vector2(e.global_position.x - landed[0].x, e.global_position.z - landed[0].z).length()
		if d < gun.secondary_range - 0.3:
			any_near = true
			near_hit = near_hit and e.health == 10000 - gun.secondary_damage
		elif d > gun.secondary_range + 1.5:
			near_hit = near_hit and e.health == 10000
	_check(any_near and near_hit, "it bowls over the ones within %.0f m of where it lands for %d, not the others" % [gun.secondary_range, gun.secondary_damage])
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	crowd.append(skewered)
	await _clear(crowd)


func _heavy() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var krampus: Enemy = _spawn(krampus_data, Vector3(1.6, 0, 0))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _frames(5)
	_check(krampus.health == 10000 - gun.damage and not krampus.is_lifted() and not holder.is_blocking(), "the Krampus takes the thrust but is too heavy to lift")
	holder.force_melee_hold = false
	await _clear([krampus])
	var held: Enemy = _spawn(wanderer, Vector3(1.4, 0, 0))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _seconds(Constants.MISTGABEL_HOLD_MAX + 0.3)
	_check(not holder.is_blocking() and not held.is_lifted(), "held for %.0f s, the fork throws by itself" % Constants.MISTGABEL_HOLD_MAX)
	holder.force_melee_hold = false
	await _seconds(2.0)
	await _clear([held])


func _extras() -> void:
	_check(gun.is_melee and gun.secondary == WeaponData.Secondary.BEHAVIOR, "a melee weapon; holding V is its own mode")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Mistgabel, weight 1")
	_check(gun.cost == 0 and main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "chest only: no wall-buy")
