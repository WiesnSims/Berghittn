extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_rodelkanone.tscn
## Headless check of the Rodelkanone (section 6a) on the real main scene: 4 / 12, a sled that runs
## 15 m along the ground and strikes every enemy in its lane once for 300 (not beside the lane, not
## beyond 15 m), throws survivors aside, breaks on a wall without passing it, the Kehre banks off a
## wall for two rounds and reaches what is around the corner, sleds come from a pool, the next one
## shows at the muzzle as the gun is ready again, and the Hüttentruhe has it at weight 1.

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
	enemy.set_physics_process(false)
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
		e.set_physics_process(true)
		if e.is_alive():
			e.receive_hit(1000000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


## A wall of the world's kind standing on the pasture, turned `yaw` degrees.
func _wall(offset: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Constants.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 0.3)
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	body.global_position = _ground(offset) + Vector3.UP * 1.0
	body.rotation.y = deg_to_rad(yaw)
	return body


func _sleds() -> Array:
	return player.weapons._behavior._sleds


func _busy_sled() -> Node3D:
	var busy: Array = _sleds().filter(func(s: Node3D) -> bool: return s.is_busy())
	return busy[0] if busy.size() == 1 else null


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/rodelkanone.tres")
	await _frames(10)

	await _lane()
	await _wall_stop()
	await _kehre()
	await _indoors()
	await _pool()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _lane() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	player.global_position = _ground(Vector3.ZERO)
	player.weapons.give_weapon(gun)
	await _seconds(0.6)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.weapon == gun and holder.mag == 4 and holder.reserve == 12, "Rodelkanone in hand, 4 / 12")
	# In the lane at 4 m, 9 m (half a metre off its line) and 13 m; beside it at 2.5 m; past its end at 18 m.
	var in_lane: Array[Enemy] = [_spawn(knappe, Vector3(4, 0, 0)), _spawn(wanderer, Vector3(9, 0, 0.5)), _spawn(wanderer, Vector3(13, 0, -0.3))]
	var beside: Enemy = _spawn(wanderer, Vector3(7, 0, 2.5))
	var beyond: Enemy = _spawn(wanderer, Vector3(18, 0, 0))
	await _frames(3)
	holder._fire()
	_check(holder.mag == 3, "one sled used")
	var sled: Node3D = _busy_sled()
	_check(sled != null, "a sled is out")
	if sled == null:
		return
	await _frames(2)
	var start: Vector3 = sled.global_position
	_check(absf(start.y - _ground(Vector3(start.x - FIELD.x, 0, start.z - FIELD.z)).y) < 0.05, "it rides on the ground (%.2f m up)" % (start.y - _ground(Vector3(start.x - FIELD.x, 0, start.z - FIELD.z)).y))
	await _frames(20)
	# Struck once and thrown aside, out of the lane.
	_check(in_lane[0].health == 10000 - gun.damage and in_lane[0]._knock.length() > 1.0 and absf(in_lane[0]._knock.z) > 0.5, "the Knappe at 4 m takes %d and is thrown aside (%.1f, %.1f)" % [10000 - in_lane[0].health, in_lane[0]._knock.x, in_lane[0]._knock.z])
	var last: Vector3 = sled.global_position
	await _seconds(1.5)
	_check(not sled.is_busy(), "and is gone after its run")
	for e: Enemy in in_lane:
		_check(e.health == 10000 - gun.damage, "struck once in the lane for %d" % (10000 - e.health))
	_check(beside.health == 10000, "not 2.5 m beside the lane")
	_check(beyond.health == 10000, "not 18 m out, past its 15 m")
	var run: float = Vector2(sled.global_position.x - FIELD.x, sled.global_position.z - FIELD.z).length()
	_check(run > gun.range - 0.5 and run < gun.range + 1.5, "it broke apart %.1f m out" % run)
	_check(last.x > start.x, "it went the way the player looked")
	in_lane.append_array([beside, beyond])
	await _clear(in_lane)


func _wall_stop() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var wall: StaticBody3D = _wall(Vector3(6, 0, 0), 90.0)
	var behind: Enemy = _spawn(wanderer, Vector3(9, 0, 0))
	await _frames(3)
	holder._cooldown = 0.0
	holder._fire()
	var sled: Node3D = _busy_sled()
	await _seconds(1.0)
	_check(sled != null and not sled.is_busy() and sled.global_position.x - FIELD.x < 6.0, "a wall breaks it (at %.1f m)" % (sled.global_position.x - FIELD.x if sled else -1.0))
	_check(behind.health == 10000, "nothing behind the wall is hit")
	wall.queue_free()
	await _clear([behind])


func _kehre() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	# A wall across the way at 45 degrees: a sled going +x turns off it towards +z.
	var wall: StaticBody3D = _wall(Vector3(6, 0, 0), -45.0)
	var around: Enemy = _spawn(wanderer, Vector3(6, 0, 6))
	await _frames(3)
	holder.mag = 4
	holder._cooldown = 0.0
	holder._fire()
	await _seconds(1.5)
	_check(around.health == 10000, "a plain shot breaks on the slanted wall and does not reach around it")
	holder._cooldown = 0.0
	holder.fire_secondary()
	_check(holder.mag == 4 - 1 - gun.secondary_rounds, "the Kehre takes %d rounds (%d left)" % [gun.secondary_rounds, holder.mag])
	var sled: Node3D = _busy_sled()
	await _seconds(1.2)
	_check(around.health == 10000 - gun.secondary_damage, "it banks off the wall and strikes the one around it for %d" % (10000 - around.health))
	if sled:
		_check(sled.global_position.z - FIELD.z > 3.0, "and runs on the new way (z +%.1f m)" % (sled.global_position.z - FIELD.z))
		await _seconds(2.5)
		_check(not sled.is_busy(), "until its %.0f m are run" % gun.secondary_range)
	wall.queue_free()
	await _clear([around])


func _indoors() -> void:
	var holder: WeaponHolder = player.weapons
	# Across the Stube at a slant, between the tables: it banks round the hall and never through a wall.
	player.global_position = Vector3(5.5, 0.0, 4.5)
	await _frames(5)
	var floor_y: float = player.global_position.y
	_look_flat(Vector3(-14.5, 0.0, -8.5))
	holder.mag = 4
	holder._cooldown = 0.0
	holder.fire_secondary()
	var sled: Node3D = _busy_sled()
	if sled == null:
		_check(false, "a Kehre sled is out in the Stube")
		return
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var through: int = 0
	var low: float = 0.0
	var last: Vector3 = sled.global_position
	while sled.is_busy():
		await _frames(1)
		var now: Vector3 = sled.global_position
		var line := PhysicsRayQueryParameters3D.create(last + Vector3.UP * 0.3, now + Vector3.UP * 0.3, Constants.LAYER_WORLD)
		if not space.intersect_ray(line).is_empty():
			through += 1
		low = minf(low, now.y - floor_y)
		last = now
	_check(sled._banks < 3, "indoors the Kehre banked %d times" % (3 - sled._banks))
	_check(through == 0, "and never passed through a wall (%d)" % through)
	_check(low > -0.3, "and stayed on the floor (lowest %.2f m)" % low)


func _pool() -> void:
	var holder: WeaponHolder = player.weapons
	for i: int in 10:
		holder.mag = 4
		holder._cooldown = 0.0
		holder._fire()
		await _frames(2)
	_check(_sleds().size() <= Constants.RODEL_POOL, "10 shots, %d sleds built (pool of %d)" % [_sleds().size(), Constants.RODEL_POOL])
	await _seconds(2.5)
	_check(_sleds().all(func(s: Node3D) -> bool: return not s.is_busy()), "every sled has run out")


func _extras() -> void:
	var model := gun.viewmodel.instantiate() as Viewmodel
	_check(absf(model.fire_animation_time() - 1.0 / gun.fire_rate) < 0.01, "the next sled shows at the muzzle as the gun is ready (%.2f s)" % model.fire_animation_time())
	model.free()
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Rodelkanone, weight 1")
	_check(gun.cost == 0 and main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "chest only: no wall-buy")
