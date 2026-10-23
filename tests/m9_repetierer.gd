extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_repetierer.tscn
## Headless check of the Repetierer on the real main scene (user request 2026-10-24): the reload loads
## only the rounds missing, one at a time (a short reload for a few, a long one from empty, the rounds
## counting as they go in and kept when it is cut short); the Ehrensalve fires every loaded round into
## the sky, hurting nobody, and everyone within 10 m (not behind a wall, not farther, not a boss)
## covers their ears for 0.25 s a round, then is deaf to the next salve for a while.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var holder: WeaponHolder
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
		player.health._health = float(player.health.max_health)


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _ground(offset: Vector3) -> Vector3:
	var at: Vector3 = FIELD + offset
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _spawn(data: EnemyData, offset: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var at: Vector3 = _ground(offset)
	enemy.activate(data, 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.data = enemy.data.duplicate()
	enemy.data.speed = 0.0
	enemy.global_position = at
	enemy.health = 10000
	return enemy


func _wall(offset: Vector3) -> void:
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
	body.rotation.y = deg_to_rad(90.0)


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	holder = player.weapons
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	gun = load("res://data/weapons/repetierer.tres")
	player.global_position = _ground(Vector3.ZERO)
	holder.give_weapon(gun)
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.2)

	await _reload()
	await _salve()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _reload() -> void:
	var own: float = gun.reload_time
	var per: float = gun.reload_round_time
	# Two shots fired: three go in (two, and the one the chamber holds on top of a full tube).
	holder.mag = gun.mag_size - 2
	holder.reserve = 50
	holder.start_reload()
	_check(is_equal_approx(holder._reload_total, own + per * 3), "three rounds missing: %.2f s" % holder._reload_total)
	var first_in: float = own * Constants.RELOAD_LIFT_SHARE + per * Constants.RELOAD_ROUND_IN_AT
	await _seconds(first_in - 0.05)
	_check(holder.mag == gun.mag_size - 2, "nothing in before the first round is pushed in")
	await _seconds(0.1)
	_check(holder.mag == gun.mag_size - 1 and holder.reserve == 49, "the first round counts the moment it is in (%d / %d)" % [holder.mag, holder.reserve])
	await _seconds(holder._reload_left + 0.1)
	_check(holder.mag == gun.mag_size + 1 and holder.reserve == 47, "loaded up to %d + 1 (%d)" % [gun.mag_size, holder.mag])

	# From empty: every round, then the lever worked to chamber one.
	holder.mag = 0
	holder.start_reload()
	var full: float = holder._reload_total
	_check(is_equal_approx(full, own + per * gun.mag_size + gun.chamber_time), "from empty: %.2f s" % full)
	# Cut short by a swing after three rounds: those three stay in.
	await _seconds(own * Constants.RELOAD_LIFT_SHARE + per * 3 - 0.02)
	holder._cancel_reload()
	_check(holder.mag == 3 and not holder.is_reloading(), "cut short after three rounds, the three are kept (%d)" % holder.mag)
	holder.mag = gun.mag_size + 1
	await _frames(2)


func _salve() -> void:
	var data: EnemyData = load("res://data/enemies/wanderer.tres")
	var near: Enemy = _spawn(data, Vector3(5.0, 0.0, 0.0))
	var behind: Enemy = _spawn(data, Vector3(-8.0, 0.0, 0.0))
	var far: Enemy = _spawn(data, Vector3(0.0, 0.0, 14.0))
	var walled: Enemy = _spawn(data, Vector3(0.0, 0.0, -6.0))
	_wall(Vector3(0.0, 0.0, -3.0))
	var boss: Enemy = _spawn(load("res://data/enemies/krampus.tres"), Vector3(0.0, 0.0, 4.0))
	boss.health = 10000
	await _frames(3)
	var rounds: int = 6
	holder.mag = rounds
	holder.reserve = 40
	holder.start_salve()
	_check(holder.is_saluting(), "right click: the salve starts")
	await _seconds(Constants.SALVE_RAISE_TIME + gun.secondary_round_time * (rounds - 1) + 0.03)
	_check(holder.mag == 0 and not holder.is_saluting(), "all %d rounds went off, one every %.2f s" % [rounds, gun.secondary_round_time])
	_check(near.is_deafened() and behind.is_deafened(), "within %.0f m, in front and behind: ears covered" % gun.secondary_range)
	_check(not far.is_deafened() and not walled.is_deafened(), "farther off, or behind a wall: not")
	_check(not boss.is_deafened(), "the Krampus does not care")
	_check(near.health == 10000 and boss.health == 10000, "shot into the sky: nobody hurt")
	var cowers: float = gun.secondary_stun * rounds
	await _seconds(cowers - 0.2)
	_check(near.is_deafened(), "still cowering after %.1f s" % (cowers - 0.2))
	await _seconds(0.4)
	_check(not near.is_deafened(), "back up after %.2f s (%.2f a round)" % [cowers, gun.secondary_stun])
	_check(holder.is_reloading(), "and the empty gun reloads")
	holder.deafen_around(gun.secondary_range, 2.0)
	_check(not near.is_deafened(), "deaf to the next salve for a while")
	await _seconds(Constants.DEAF_TIME + 0.1)
	holder.deafen_around(gun.secondary_range, 2.0)
	_check(near.is_deafened(), "and after %.0f s it works again" % Constants.DEAF_TIME)
