extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_harmonika.tscn
## Headless check of the Steirische Harmonika (section 6a) on the real main scene: 3 / 9, a polka that
## makes every enemy within 8 m dance for 4 s (not past 8 m, not behind a wall): dancers stay on the
## spot, do not attack, take 20 a second and twice the damage from other hits; a boss takes the
## damage but does not dance. The Tanzboden (right click) takes two rounds and lies where the player
## aims for 10 s: whoever is on it dances (newcomers too), whoever is beside it does not, and the
## dance ends with it. The polka animation ends as the next can start, and the
## Hüttentruhe has it at weight 1.

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
	enemy.global_position = at
	enemy.health = 10000
	return enemy


func _look_flat(direction: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + direction, Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0


func _clear(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		e.set_physics_process(true)
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


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/harmonika.tres")
	await _frames(10)

	await _polka()
	await _boss()
	await _tanzboden()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _polka() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	player.global_position = _ground(Vector3.ZERO)
	player.weapons.give_weapon(gun)
	await _seconds(0.6)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.weapon == gun and holder.mag == 3 and holder.reserve == 9, "Harmonika in hand, 3 / 9")
	# Right next to the player (it would be swinging), at 4 m behind the player, 7 m ahead; out of reach
	# at 11 m; and 5 m off behind a wall.
	var close: Enemy = _spawn(knappe, Vector3(1.0, 0, 0))
	var behind: Enemy = _spawn(wanderer, Vector3(-4, 0, 0.5))
	var far_in: Enemy = _spawn(wanderer, Vector3(7, 0, 0))
	var out: Enemy = _spawn(wanderer, Vector3(0, 0, 11))
	var wall: StaticBody3D = _wall(Vector3(0, 0, -3), 0.0)
	var walled: Enemy = _spawn(wanderer, Vector3(0, 0, -5))
	await _frames(20)
	holder._fire()
	_check(holder.mag == 2, "one polka used")
	await _frames(2)
	_check(close.is_dancing() and behind.is_dancing() and far_in.is_dancing(), "everyone within 8 m dances, all around")
	_check(not out.is_dancing(), "not 11 m away")
	_check(not walled.is_dancing(), "not behind a wall")
	var spots: Array[Vector3] = [close.global_position, behind.global_position, far_in.global_position]
	var out_start: Vector3 = out.global_position
	var hp: float = player.health._health
	# Not topped up for a moment: the Knappe right next to the player must not swing while it dances.
	var hurt: bool = false
	for i: int in 120:
		await get_tree().physics_frame
		if player.health._health < hp:
			hurt = true
		player.health._health = hp
	_check(not hurt, "a dancer right next to the player does not attack")
	var still: bool = true
	for i: int in 3:
		var dancer: Enemy = [close, behind, far_in][i]
		still = still and _flat_distance(dancer.global_position, spots[i]) < 0.2
	_check(still, "dancers stay on the spot")
	_check(_flat_distance(out.global_position, out_start) > 1.0, "the one out of reach walks on (%.1f m)" % _flat_distance(out.global_position, out_start))
	# Twice the damage from another hit while dancing; the polka's own 20 a second is not doubled.
	var before: int = far_in.health
	far_in.receive_hit(100, false, false, player)
	_check(before - far_in.health == 200, "a hit on a dancer lands twice as hard (%d for 100)" % (before - far_in.health))
	await _seconds(2.2)
	_check(not close.is_dancing() and not far_in.is_dancing(), "the dance is over after 4 s")
	_check(behind.health == 10000 - 4 * gun.damage, "a dancer took %d (4 s at %d a second)" % [10000 - behind.health, gun.damage])
	before = behind.health
	behind.receive_hit(100, false, false, player)
	_check(before - behind.health == 100, "after the dance a hit lands normally (%d)" % (before - behind.health))
	wall.queue_free()
	await _clear([close, behind, far_in, out, walled])


func _boss() -> void:
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	var krampus: Enemy = _spawn(krampus_data, Vector3(6, 0, 0))
	await _frames(5)
	holder.mag = 3
	holder._cooldown = 0.0
	holder._fire()
	await _frames(2)
	_check(not krampus.is_dancing(), "the Krampus does not dance")
	await _seconds(1.1)
	_check(krampus.health == 10000 - gun.damage, "but takes the polka's damage (%d after a second)" % (10000 - krampus.health))
	await _clear([krampus])


func _tanzboden() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	# Looking a little down: the aim meets the pasture about 8 m ahead.
	(player.get_node("Head") as Node3D).rotation.x = -0.2
	await _frames(5)
	holder.mag = 3
	holder.reserve = 9
	holder._cooldown = 0.0
	holder.fire_secondary()
	await _frames(2)
	_check(holder.mag == 1, "right click lays a Tanzboden for two rounds (%d left)" % holder.mag)
	var floor: Node3D = holder._behavior._floors[0] if not holder._behavior._floors.is_empty() else null
	var ahead: float = (floor.global_position - player.global_position).dot(Vector3(1, 0, 0)) if floor else -1.0
	_check(floor != null and floor.visible and ahead > 5.0 and ahead < 11.0, "it lies where the player aims, %.1f m ahead" % ahead)
	if floor == null:
		return
	var on_it: Vector3 = floor.global_position - FIELD
	var dancer: Enemy = _spawn(wanderer, on_it + Vector3(0.8, 0, 0))
	var outsider: Enemy = _spawn(wanderer, on_it + Vector3(0, 0, gun.secondary_range + 2.5))
	outsider.set_physics_process(false)
	await _seconds(0.4)
	_check(dancer.is_dancing(), "whoever is on it dances")
	_check(not outsider.is_dancing(), "whoever is beside it does not")
	await _seconds(3.0)
	var newcomer: Enemy = _spawn(wanderer, on_it + Vector3(-0.8, 0, 0.5))
	await _seconds(0.4)
	_check(newcomer.is_dancing(), "one that steps on later starts dancing")
	_check(dancer.is_dancing(), "still dancing past the polka's 4 s")
	await _seconds(Constants.TANZBODEN_TIME - 3.8 + Constants.DANCE_LINGER + 0.6)
	_check(not dancer.is_dancing() and not floor.visible, "after %.0f s the music stops, the floor is gone and so is the dance" % Constants.TANZBODEN_TIME)
	_check(dancer.health < 10000 - 8 * gun.secondary_damage, "dancing on it hurt all along (%d)" % (10000 - dancer.health))
	await _clear([dancer, outsider, newcomer])


func _extras() -> void:
	var model := gun.viewmodel.instantiate() as Viewmodel
	_check(absf(model.fire_animation_time() - 1.0 / gun.fire_rate) < 0.01, "the polka animation ends as the next can start (%.2f s)" % model.fire_animation_time())
	model.free()
	_check(gun.secondary == WeaponData.Secondary.BEHAVIOR and gun.cycle_ring, "right click lays the Tanzboden; the ready ring shows between polkas")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Harmonika, weight 1")
	_check(gun.cost == 0 and main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "chest only: no wall-buy")
