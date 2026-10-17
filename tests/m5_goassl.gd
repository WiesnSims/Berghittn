extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_goassl.tscn
## Headless check of the Goaßl (section 6a) on the real main scene: it goes on V in place of the shovel;
## the crack hits everything in its short cone (3.5 m, 30° each side) for 40 and stuns it for 1.5 s
## (standing still, no attacks), not outside the cone or past 3.5 m; the Krampus takes the blow but is
## not stunned. Holding V past the crack lashes the first body along the aim within 7 m and drags it
## to the player, dazed, at a slow walk; let go, it stays stunned. Nothing to lash past 7 m. Plus the
## chest (weight 1, taken into the melee slot) and no wall-buy.

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
	gun = load("res://data/weapons/goassl.tres")
	await _frames(10)

	await _crack()
	await _lash()
	await _extras()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _crack() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	var krampus_data: EnemyData = load("res://data/enemies/krampus.tres")
	player.global_position = _ground(Vector3.ZERO)
	player.weapons.give_weapon(gun)
	await _frames(5)
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	_check(holder.melee_weapon == gun and holder.gun_count() == 1, "the Goaßl takes the shovel's place on V")
	# In the cone: right in front (close enough to swing at the player), 3 m out at 20°; out of it:
	# 3 m out at 60°, and 5 m straight ahead (past its 3.5 m).
	var close: Enemy = _spawn(knappe, Vector3(1.2, 0, 0))
	var slant: Enemy = _spawn(wanderer, Vector3(3.0 * cos(deg_to_rad(20.0)), 0, 3.0 * sin(deg_to_rad(20.0))))
	var wide: Enemy = _spawn(wanderer, Vector3(3.0 * cos(deg_to_rad(60.0)), 0, -3.0 * sin(deg_to_rad(60.0))))
	var far: Enemy = _spawn(wanderer, Vector3(5, 0, -0.3))
	# Only the two in the cone may move (the others stand, so they cannot walk up and swing).
	for e: Enemy in [close, slant]:
		e.data.speed = 2.5
	await _frames(5)
	await _swing(false)
	_check(close.health == 10000 - gun.damage and slant.health == 10000 - gun.damage, "the crack hits the cone for %d (%d, %d)" % [gun.damage, 10000 - close.health, 10000 - slant.health])
	_check(close.is_stunned() and slant.is_stunned(), "and stuns them")
	_check(wide.health == 10000 and not wide.is_stunned(), "not 60° to the side")
	_check(far.health == 10000 and not far.is_stunned(), "not 5 m out")
	var spot: Vector3 = slant.global_position
	var hp: float = player.health._health
	var hurt: bool = false
	for i: int in 75:
		await get_tree().physics_frame
		if player.health._health < hp:
			hurt = true
		player.health._health = hp
	_check(not hurt, "the stunned Knappe right in front does not swing")
	_check(Vector2(slant.global_position.x - spot.x, slant.global_position.z - spot.z).length() < 0.1, "a stunned one stands still")
	await _frames(25)
	_check(not slant.is_stunned(), "and is free again after %.1f s" % Constants.GOASSL_STUN_TIME)
	await _clear([close, slant, wide, far])
	var krampus: Enemy = _spawn(krampus_data, Vector3(2.0, 0, 0))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(false)
	_check(krampus.health == 10000 - gun.damage and not krampus.is_stunned(), "the Krampus takes the crack but is not stunned")
	await _clear([krampus])


func _lash() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var holder: WeaponHolder = player.weapons
	player.global_position = _ground(Vector3.ZERO)
	_look_flat(Vector3(1, 0, 0))
	var caught: Enemy = _spawn(wanderer, Vector3(6, 0, 0))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _frames(3)
	_check(holder.is_blocking(), "V held past the crack: the lash catches the one 6 m out")
	_check(player._base_speed(Vector2(0, -1)) < Constants.PLAYER_WALK_SPEED * 0.7, "walking slowly while it holds")
	await _seconds(1.5)
	var pulled: float = Vector2(caught.global_position.x - player.global_position.x, caught.global_position.z - player.global_position.z).length()
	_check(pulled < 3.0, "and drags it in (%.1f m away now)" % pulled)
	_check(caught.is_stunned(), "dazed while dragged")
	holder.force_melee_hold = false
	await _frames(3)
	_check(not holder.is_blocking() and caught.is_stunned(), "let go, it stays stunned")
	await _clear([caught])
	var out_of_reach: Enemy = _spawn(wanderer, Vector3(9, 0, 0))
	await _frames(5)
	await _seconds(1.0 / gun.fire_rate)
	await _swing(true)
	await _frames(3)
	_check(not holder.is_blocking(), "nothing to lash 9 m out")
	holder.force_melee_hold = false
	await _clear([out_of_reach])


func _extras() -> void:
	_check(gun.is_melee and gun.secondary == WeaponData.Secondary.BEHAVIOR, "a melee weapon; holding V is its own mode")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var entry: Array = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == gun)
	_check(entry.size() == 1 and is_equal_approx(entry[0].weight, 1.0), "the Hüttentruhe has the Goaßl, weight 1")
	_check(gun.cost == 0 and main.find_children("*", "WallBuy", true, false).all(func(w: WallBuy) -> bool: return w.weapon != gun), "chest only: no wall-buy")
	# Offered by the chest, it is taken into the melee slot, not swapped for a gun.
	var holder: WeaponHolder = player.weapons
	holder.set_melee(load("res://data/weapons/schaufel.tres"))
	player.weapons.give_weapon(load("res://data/weapons/jagdflinte.tres"))
	chest.state = Huettentruhe.State.OFFERING
	chest.offer = gun
	chest._buyer = player
	_check(chest.get_interact_prompt(player) == tr("UI_CHEST_TAKE") % tr(gun.display_name), "the chest offers it to take: %s" % chest.get_interact_prompt(player))
	chest.interact(player)
	_check(holder.melee_weapon == gun and holder.gun_count() == 2, "taken into the melee slot, both guns kept")
	await _frames(2)
