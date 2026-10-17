extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_krampusrute.tscn
## Headless check of the Krampus-Rute (section 6a) on the real main scene: the Krampus leaves it where
## he falls (announced), and E takes it onto V in place of the shovel; the swat hits the front for 150
## and makes the struck ones, and those within 2.5 m of them, run from the player for 3 s, not one
## 6 m off; the Krampus is not scared. Holding V past the swat, the Larve, makes everyone in its 8 m
## cone flee for as long as it is held (not one behind the player), a moment after letting go they
## come back. Not in the chest, no wall-buy.

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
	gun = load("res://data/weapons/krampusrute.tres")
	await _frames(10)

	await _drop()
	await _swat()
	await _larve()
	_extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _drop() -> void:
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	_check(player.weapons.melee_weapon.id == &"schaufel", "the shovel on V to begin with")
	var announced: Array[String] = []
	var listen := func(text: String) -> void: announced.append(text)
	Events.event_announced.connect(listen)
	var krampus: Enemy = _spawn(krampus_data, Vector3(4, 0, 0))
	await _frames(5)
	var fell_at: Vector3 = krampus.global_position
	krampus._take_hit(1000000, false, false, player)
	await _frames(3)
	Events.event_announced.disconnect(listen)
	var pickups: Array = main.find_children("*", "WeaponPickup", true, false).filter(func(p: WeaponPickup) -> bool: return p.weapon == gun)
	_check(pickups.size() == 1, "the Krampus leaves his Rute where he falls")
	_check(announced.has(tr("EVENT_RUTE_DROPPED")), "and it is announced: %s" % [announced])
	if pickups.is_empty():
		return
	var pickup: WeaponPickup = pickups[0]
	_check(Vector2(pickup.global_position.x - fell_at.x, pickup.global_position.z - fell_at.z).length() < 0.2, "right there on the ground")
	player.global_position = pickup.global_position - Vector3(1.0, 0, 0)
	_look_flat(Vector3(1, 0, 0))
	await _frames(3)
	_check(player.interactor._find_target() == pickup and pickup.get_interact_prompt(player) == tr("UI_CHEST_TAKE") % tr(gun.display_name), "E: %s" % pickup.get_interact_prompt(player))
	pickup.interact(player)
	await _frames(2)
	_check(player.weapons.melee_weapon == gun and not is_instance_valid(pickup), "taken onto V in place of the shovel")
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _swat() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	# Struck right in front; 2 m behind it (out of the swat's reach, within the panic's); 6 m off.
	var struck: Enemy = _spawn(wanderer, Vector3(1.2, 0, 0))
	var behind: Enemy = _spawn(wanderer, Vector3(3.2, 0, 0.3))
	var away: Enemy = _spawn(wanderer, Vector3(0, 0, 6))
	for e: Enemy in [struck, behind, away]:
		e.data.speed = 2.5
	await _frames(3)
	await _swing(false)
	_check(struck.health == 10000 - gun.damage, "the swat hits for %d" % (10000 - struck.health))
	_check(behind.health == 10000, "not past its 2 m")
	_check(struck.is_fleeing() and behind.is_fleeing(), "the struck one and the one 2 m behind it run")
	_check(not away.is_fleeing(), "not one 6 m off")
	var start: Array[float] = [_from_player(struck), _from_player(behind)]
	var hp: float = player.health._health
	var hurt: bool = false
	for i: int in 90:
		await get_tree().physics_frame
		if player.health._health < hp:
			hurt = true
		player.health._health = hp
	_check(_from_player(struck) > start[0] + 1.5 and _from_player(behind) > start[1] + 1.5, "running away from the player (%.1f m, %.1f m further)" % [_from_player(struck) - start[0], _from_player(behind) - start[1]])
	_check(not hurt or away._state == Enemy.State.ATTACKING, "the fleeing ones attack nobody")
	await _seconds(1.7)
	_check(not struck.is_fleeing(), "and turn back after %.0f s" % Constants.RUTE_FLEE_TIME)
	await _clear([struck, behind, away])
	var krampus: Enemy = _spawn(krampus_data, Vector3(1.6, 0, 0))
	await _frames(3)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(false)
	_check(krampus.health == 10000 - gun.damage and not krampus.is_fleeing(), "the Krampus takes the swat but is not scared")
	await _clear([krampus])


func _larve() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var ahead: Enemy = _spawn(wanderer, Vector3(6, 0, 1))
	var behind: Enemy = _spawn(wanderer, Vector3(-5, 0, 0))
	for e: Enemy in [ahead, behind]:
		e.data.speed = 1.0
	await _frames(3)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _frames(15)
	_check(holder.is_blocking() and ahead.is_fleeing(), "the Larve: the one 6 m ahead flees")
	_check(not behind.is_fleeing(), "not one behind the player")
	await _seconds(2.0)
	_check(ahead.is_fleeing(), "for as long as it is held")
	holder.force_melee_hold = false
	await _seconds(Constants.LARVE_LINGER + 0.4)
	_check(not ahead.is_fleeing(), "and comes back a moment after letting go")
	await _clear([ahead, behind])


func _from_player(enemy: Enemy) -> float:
	return Vector2(enemy.global_position.x - player.global_position.x, enemy.global_position.z - player.global_position.z).length()


func _extras() -> void:
	_check(gun.is_melee and gun.secondary == WeaponData.Secondary.BEHAVIOR, "a melee weapon; holding V is its own mode")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	_check(chest.pool.entries.all(func(e: ChestEntry) -> bool: return e.weapon != gun), "not in the Hüttentruhe: only the Krampus has it")
	_check(main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "no wall-buy")
