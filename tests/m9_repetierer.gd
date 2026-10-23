extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_repetierer.tscn
## Headless check of the Repetierer on the real main scene (user request 2026-10-24): the reload loads
## only the rounds missing, one at a time (a short reload for a few, a long one from empty, the rounds
## counting as they go in and kept when it is cut short); the Querschläger, for three rounds, glances
## from body to body: five in a bunch, three when they stand 6 m apart, off a wall on to one near it
## but never through the wall; not with fewer than three rounds in the gun.

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
	await _ricochet()

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


## No recoil or bloom left, so the shot flies where it is aimed.
func _steady() -> void:
	var camera := player.get_node("Head/Camera3D") as CameraRecoil
	camera.sway = Vector2.ZERO
	camera._target = Vector2.ZERO
	camera._current = Vector2.ZERO
	camera.rotation = Vector3.ZERO
	holder.bloom = 0.0


func _look_at(point: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	player.look_at(Vector3(point.x, player.global_position.y, point.z), Vector3.UP)
	var d: Vector3 = point - cam.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Fires the Querschläger at `target`'s middle; returns how many bodies it hit.
func _ricochet_at(target: Vector3) -> int:
	_steady()
	_look_at(target)
	await _frames(1)
	holder.mag = gun.mag_size
	holder._cooldown = 0.0
	return holder.fire_ricochet()


func _hurt(list: Array[Enemy]) -> int:
	var count: int = 0
	for e: Enemy in list:
		if e.health < 10000:
			count += 1
	return count


func _clear(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		if e.is_alive():
			e._take_hit(1000000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _ricochet() -> void:
	var data: EnemyData = load("res://data/enemies/wanderer.tres")
	_look_at(player.global_position + Vector3(1, 0, 0))
	# Six in a tight bunch 6 m ahead: five are hit, one with full damage each, the sixth is spared.
	var bunch: Array[Enemy] = []
	for offset: Vector3 in [Vector3(6, 0, 0), Vector3(7.2, 0, 0.8), Vector3(7.2, 0, -0.8), Vector3(8.4, 0, 0), Vector3(8.4, 0, 1.6), Vector3(8.4, 0, -1.6)]:
		bunch.append(_spawn(data, offset))
	await _frames(3)
	var hit: int = await _ricochet_at(bunch[0].global_position + Vector3.UP * 1.0)
	var most: int = gun.ricochet_damage.size()
	_check(hit == most and _hurt(bunch) == most, "close together: %d of 6 hit (%d)" % [_hurt(bunch), most])
	var dealt: Array[int] = []
	for e: Enemy in bunch:
		if e.health < 10000:
			dealt.append(10000 - e.health)
	dealt.sort()
	dealt.reverse()
	_check(dealt == Array(gun.ricochet_damage), "less with every hop: %s" % [dealt])
	_check(holder.mag == gun.mag_size - gun.secondary_rounds and is_equal_approx(holder._cooldown, gun.ricochet_cycle), "uses %d rounds, then the lever takes %.1f s" % [gun.secondary_rounds, gun.ricochet_cycle])
	await _clear(bunch)

	# Spread out, 6 m from one to the next: only three before the 12 m of hops run out.
	var line: Array[Enemy] = []
	for offset: Vector3 in [Vector3(6, 0, 0), Vector3(6, 0, 6), Vector3(6, 0, 12), Vector3(6, 0, 18)]:
		line.append(_spawn(data, offset))
	await _frames(3)
	hit = await _ricochet_at(line[0].global_position + Vector3.UP * 1.0)
	_check(hit == 3 and _hurt(line) == 3 and line[3].health == 10000, "6 m apart: three hit (%d)" % _hurt(line))
	await _clear(line)

	# Off a wall on to the one standing near it; not round the wall to the one behind it.
	_wall(Vector3(8, 0, 0))
	var near: Enemy = _spawn(data, Vector3(6, 0, 3))
	var behind: Enemy = _spawn(data, Vector3(10, 0, 0.5))
	await _frames(3)
	# (Aimed level with the one near it: the ground probe there would land on top of the wall.)
	hit = await _ricochet_at(Vector3(FIELD.x + 7.85, near.global_position.y + 1.0, FIELD.z))
	_check(hit == 1 and near.health < 10000 and behind.health == 10000, "a shot into the wall glances off on to the one near it, not the one behind")
	await _clear([near, behind] as Array[Enemy])

	# Fewer than three rounds: no Querschläger.
	holder.mag = 2
	holder._cooldown = 0.0
	_check(holder.fire_ricochet() == 0 and holder.mag == 2, "needs three rounds in the gun")
