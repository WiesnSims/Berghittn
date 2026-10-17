extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_alphorn.tscn
## Headless check of the Alphorn (section 6/6a) on the real main scene: the cone blast (reach, angle,
## damage, knockback, heavy enemies shoved less, walls block it), the Echo all around for two notes,
## the ammo and reload, and the Hüttentruhe offering it (weight 1, shown shrunk to fit the chest).

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var horn: WeaponData
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


## Puts enemies exactly where given and lets the physics space catch up with their hurt boxes.
func _settle(list: Array[Enemy], spots: Array[Vector3]) -> void:
	for i: int in list.size():
		list[i].set_physics_process(false)
		list[i].global_position = spots[i]
	await _frames(3)


func _clear(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		e.set_physics_process(true)
		if e.is_alive():
			e.receive_hit(100000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _look_flat(direction: Vector3) -> void:
	player.look_at(player.global_position + direction, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var camera := player.get_node("Head/Camera3D") as CameraRecoil
	camera.sway = Vector2.ZERO
	camera._target = Vector2.ZERO
	camera._current = Vector2.ZERO
	camera.rotation = Vector3.ZERO


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	horn = load("res://data/weapons/alphorn.tres")
	await _frames(10)

	await _cone()
	await _walls()
	await _echo()
	await _ammo()
	_chest()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _cone() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	player.global_position = FIELD
	player.weapons.give_weapon(horn)
	await _seconds(0.6)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.weapon == horn and holder.mag == 6 and holder.reserve == 18, "Alphorn in hand, 6 / 18")
	# In the cone: a Knappe (survives 200), a wanderer close and one near the far end, one at the edge
	# of the cone. Outside: one just past the reach, one off to the side, one behind.
	var spots: Array[Vector3] = [
		FIELD + Vector3(5.0, 0, 0),
		FIELD + Vector3(3.0, 0, 1.0),
		FIELD + Vector3(11.0, 0, 0),
		FIELD + Vector3(7.0, 0, 3.6),
		FIELD + Vector3(14.0, 0, 0),
		FIELD + Vector3(4.0, 0, 5.0),
		FIELD + Vector3(-4.0, 0, 0),
	]
	var list: Array[Enemy] = [_spawn(knappe, spots[0])]
	for i: int in range(1, spots.size()):
		list.append(_spawn(wanderer, spots[i]))
	await _settle(list, spots)
	var before: Array[int] = []
	for e: Enemy in list:
		before.append(e.health)
	holder._fire()
	_check(list[0].health == before[0] - horn.damage, "Knappe in the cone takes %d (%d -> %d)" % [horn.damage, before[0], list[0].health])
	_check(not list[1].is_alive() and not list[2].is_alive() and not list[3].is_alive(), "wanderers in the cone, near, far and at its edge, are blown away")
	_check(list[4].health == before[4] and list[5].health == before[5] and list[6].health == before[6], "past 12 m, off to the side and behind: untouched")
	_check(holder.mag == 5, "one note used (%d left)" % holder.mag)
	# The Knappe survives and is thrown back, but less than a wanderer would be.
	list[0].set_physics_process(true)
	await _seconds(0.4)
	var pushed: float = list[0].global_position.x - spots[0].x
	_check(pushed > 0.4, "the Knappe is shoved back %.2f m" % pushed)
	var wanderer_push: Enemy = _spawn(wanderer, FIELD + Vector3(5.0, 0, -2.0))
	wanderer_push.health = 100000
	await _settle([wanderer_push], [FIELD + Vector3(5.0, 0, -2.0)])
	holder._cooldown = 0.0
	holder._fire()
	wanderer_push.set_physics_process(true)
	await _seconds(0.4)
	var light_push: float = (wanderer_push.global_position - (FIELD + Vector3(5.0, 0, -2.0))).length()
	_check(light_push > pushed * 2.0, "a wanderer flies further (%.2f m) than the Knappe (%.2f m)" % [light_push, pushed])
	list.append(wanderer_push)
	await _clear(list)


func _walls() -> void:
	# Find the hut wall in front of the pasture, put an enemy right behind it, blow at it.
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	# Inside the Stube, facing its wall: the enemy stands outside on the other side.
	var spawn: Vector3 = player._spawn_transform.origin
	player.global_position = spawn
	await _frames(2)
	var eye: Vector3 = player.weapons.global_position
	var wall: Dictionary = {}
	var direction := Vector3.ZERO
	for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var query := PhysicsRayQueryParameters3D.create(eye, eye + d * 12.0, Constants.LAYER_WORLD)
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and eye.distance_to(hit.position) > 3.0 and eye.distance_to(hit.position) < 9.0:
			wall = hit
			direction = d
			break
	if wall.is_empty():
		_check(false, "found a wall 3 to 9 m away to test against")
		return
	_look_flat(direction)
	await _frames(2)
	var behind: Vector3 = Vector3(wall.position.x, spawn.y, wall.position.z) + direction * 1.2
	var hidden: Enemy = _spawn(wanderer, behind)
	await _settle([hidden], [behind])
	var health: int = hidden.health
	player.weapons._cooldown = 0.0
	player.weapons._fire()
	_check(hidden.health == health, "a wall %.1f m ahead shields the enemy behind it" % eye.distance_to(wall.position))
	await _clear([hidden])


func _echo() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = FIELD
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	holder.mag = 6
	holder._cooldown = 0.0
	var spots: Array[Vector3] = [
		FIELD + Vector3(-3.0, 0, 0),
		FIELD + Vector3(0.0, 0, 4.0),
		FIELD + Vector3(2.0, 0, -2.0),
		FIELD + Vector3(-9.0, 0, 0),
	]
	var list: Array[Enemy] = []
	for spot: Vector3 in spots:
		list.append(_spawn(wanderer, spot))
	await _settle(list, spots)
	var far_health: int = list[3].health
	holder.fire_secondary()
	_check(not list[0].is_alive() and not list[1].is_alive() and not list[2].is_alive(), "the Echo hits all around: behind, beside and in front")
	_check(list[3].health == far_health, "the Echo does not reach 9 m")
	_check(holder.mag == 6 - horn.secondary_rounds, "the Echo uses %d notes (%d left)" % [horn.secondary_rounds, holder.mag])
	await _clear(list)


func _ammo() -> void:
	var holder: WeaponHolder = player.weapons
	holder.mag = 1
	holder._cooldown = 0.0
	holder.fire_secondary()
	_check(holder.mag == 1, "no Echo with one note left")
	holder.start_reload()
	await _seconds(horn.reload_time + 0.2)
	_check(holder.mag == horn.mag_size and holder.reserve == horn.reserve_ammo - (horn.mag_size - 1), "caught breath: %d / %d" % [holder.mag, holder.reserve])


func _chest() -> void:
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == horn)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Alphorn, weight 1")
	var display: Node3D = chest._displays[chest._weapons.find(horn)]
	var bounds: AABB = chest._mesh_bounds(display, display.transform)
	_check(bounds.get_longest_axis_size() <= Constants.CHEST_DISPLAY_MAX_LENGTH + 0.01 and bounds.get_center().length() < 0.05, "shown in the chest %.2f m long, centred" % bounds.get_longest_axis_size())
