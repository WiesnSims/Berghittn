extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_brennkessel.tscn
## Headless check of the Brennkessel-Werfer (section 6a) on the real main scene: 100 / 200 fuel, one
## unit a tick at 8 ticks a second; the flame hits every body in its narrow 8 m cone for 15 a tick
## (not beside the cone, not past 8 m, not behind a wall) and sets it on fire: 10 a second until 3 s
## after it left the flame; hit points come once a second, not once a tick; the Krampus burns too.
## The Brennlacke (right click) takes 20 fuel, comes down as a burning puddle that sets alight
## whoever stands in it (not someone 4 m off) and dies down after 6 s. Plus the animation length and
## the chest weight.

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


## Holds the trigger for `ticks` flame ticks, 8 a second.
func _pour(ticks: int) -> void:
	var holder: WeaponHolder = player.weapons
	for i: int in ticks:
		holder._cooldown = 0.0
		holder._fire()
		await _frames(roundi(60.0 / gun.fire_rate))


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/brennkessel.tres")
	await _frames(10)

	await _flame()
	await _walled()
	await _boss()
	await _lacke()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _flame() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = _ground(Vector3.ZERO)
	player.weapons.give_weapon(gun)
	await _seconds(0.6)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.weapon == gun and holder.mag == 100 and holder.reserve == 200, "Brennkessel in hand, 100 / 200 fuel")
	# In the cone at 3 m and 7 m; beside it (3 m out, 3 m to the side); past its reach at 10 m.
	var near: Enemy = _spawn(wanderer, Vector3(3, 0, 0))
	var far: Enemy = _spawn(wanderer, Vector3(7, 0, 0.3))
	var beside: Enemy = _spawn(wanderer, Vector3(3, 0, 3))
	var beyond: Enemy = _spawn(wanderer, Vector3(10, 0, 0))
	await _frames(5)
	var paid: Array[int] = [0]
	var count := func(enemy: Node3D, _amount: int, _head: bool, source: Node3D) -> void:
		if enemy == near and source == player:
			paid[0] += 1
	Events.enemy_damaged.connect(count)
	await _pour(16)
	_check(holder.mag == 100 - 16, "two seconds of flame burn 16 fuel (%d left)" % holder.mag)
	_check(near.health <= 10000 - 16 * gun.damage and far.health <= 10000 - 16 * gun.damage, "everyone in the cone takes %d a tick (%d, %d)" % [gun.damage, 10000 - near.health, 10000 - far.health])
	_check(near.is_burning() and far.is_burning(), "and is on fire")
	_check(beside.health == 10000 and not beside.is_burning(), "not beside the cone")
	_check(beyond.health == 10000 and not beyond.is_burning(), "not past 8 m")
	_check(paid[0] <= 5, "hit points come about once a second, not per tick (%d payouts for 16 ticks)" % paid[0])
	Events.enemy_damaged.disconnect(count)
	# Out of the flame it burns on for 3 s, 10 a second.
	var left_flame: int = near.health
	await _seconds(2.1)
	_check(near.is_burning() and left_flame - near.health == 2 * Constants.BURN_DPS, "burning on after the flame: %d in 2 s" % (left_flame - near.health))
	await _seconds(1.2)
	_check(not near.is_burning(), "and goes out 3 s after it left the flame")
	var out: int = near.health
	await _seconds(1.2)
	_check(near.health == out, "no more burning after that")
	await _clear([near, far, beside, beyond])


func _walled() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var wall: StaticBody3D = _wall(Vector3(2.5, 0, 0), 90.0)
	var behind: Enemy = _spawn(wanderer, Vector3(5, 0, 0))
	await _frames(5)
	await _pour(8)
	_check(behind.health == 10000 and not behind.is_burning(), "a wall stops the flame")
	wall.queue_free()
	await _clear([behind])


func _boss() -> void:
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var krampus: Enemy = _spawn(krampus_data, Vector3(4, 0, 0))
	await _frames(5)
	await _pour(2)
	_check(krampus.is_burning(), "the Krampus catches fire too")
	var after: int = krampus.health
	await _seconds(1.1)
	_check(after - krampus.health == Constants.BURN_DPS, "and burns for %d a second" % (after - krampus.health))
	await _clear([krampus])


func _lacke() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-20.0)
	await _frames(3)
	holder.mag = 100
	holder._cooldown = 0.0
	holder.fire_secondary()
	_check(holder.mag == 100 - gun.secondary_rounds, "the Brennlacke takes %d fuel" % gun.secondary_rounds)
	var behavior: Object = holder._behavior
	await _seconds(1.0)
	var lacken: Array = behavior.get("_lacken").filter(func(l: Node3D) -> bool: return l.is_busy())
	_check(lacken.size() == 1, "it comes down as a burning puddle")
	if lacken.is_empty():
		return
	var lacke: Node3D = lacken[0]
	var spot: Vector3 = lacke.global_position
	_check(Vector2(spot.x - FIELD.x, spot.z - FIELD.z).length() > 2.0, "%.1f m in front of the player" % Vector2(spot.x - FIELD.x, spot.z - FIELD.z).length())
	var standing: Enemy = _spawn(wanderer, Vector3(spot.x - FIELD.x, 0, spot.z - FIELD.z + 0.5))
	var off: Enemy = _spawn(wanderer, Vector3(spot.x - FIELD.x, 0, spot.z - FIELD.z + 4.0))
	await _seconds(0.5)
	_check(standing.is_burning(), "whoever stands in it catches fire")
	_check(not off.is_burning(), "not someone 4 m off")
	await _seconds(Constants.LACKE_TIME)
	_check(not lacke.is_busy(), "the puddle dies down after %.0f s" % Constants.LACKE_TIME)
	await _clear([standing, off])


func _extras() -> void:
	var model := gun.viewmodel.instantiate() as Viewmodel
	_check(absf(model.fire_animation_time() - 1.0 / gun.fire_rate) < 0.01, "a flame tick's animation is one tick long (%.3f s)" % model.fire_animation_time())
	model.free()
	_check(gun.secondary == WeaponData.Secondary.BEHAVIOR and gun.is_auto, "held fire pours the flame; right click is the Brennlacke")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Brennkessel, weight 1")
	_check(gun.cost == 0 and main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "chest only: no wall-buy")
