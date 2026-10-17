extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_handboeller.tscn
## Headless check of the Seilbahn's wall-buys: the Handböller (section 6a: 1500, ammo at half price,
## a lobbed shell bursting for 150 within 3 m, the long reload, the Doppelladung taking its second
## measure from the reserve, bursting for 260 within 4.5 m and shoving the shooter back) and the
## Alphorn, hidden until wave 10, then announced and on sale for 4000.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var gun: WeaponData
var horn: WeaponData
var failures: Array[String] = []
var _announced: Array[String] = []


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
	enemy.set_physics_process(false)
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
			e.receive_hit(1000000, false, false, null)
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _wall_buy(data: WeaponData) -> WallBuy:
	var buys: Array = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.weapon == data)
	return buys[0] if buys.size() == 1 else null


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	for zone: StringName in [&"skiraum", &"seilbahn"]:
		(main.get_node("Zones") as ZoneMap).unlock(zone, player)
	Events.event_announced.connect(func(text: String) -> void: _announced.append(text))
	gun = load("res://data/weapons/handboeller.tres")
	horn = load("res://data/weapons/alphorn.tres")
	await _frames(10)

	await _buy()
	await _shot()
	await _double()
	await _alphorn()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _buy() -> void:
	var buy: WallBuy = _wall_buy(gun)
	_check(buy != null and (main.get_node("World/Seilbahn") as Node3D).is_ancestor_of(buy), "one Handböller wall-buy, in the Seilbahn")
	if buy == null:
		return
	player.global_position = buy.get_interact_position()
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
	await _frames(3)
	player.points.add(5000)
	_check(player.interactor._find_target() == buy and buy.get_interact_prompt(player).contains("1500"), "in reach: %s" % buy.get_interact_prompt(player))
	var before: int = player.points.total
	buy.interact(player)
	_check(player.weapons.weapon == gun and player.points.total == before - 1500 and player.weapons.mag == 1 and player.weapons.reserve == 10, "bought for 1500, 1 / 10")
	player.weapons.reserve = 3
	_check(buy.get_interact_prompt(player).contains("750"), "ammo at half price: %s" % buy.get_interact_prompt(player))
	player.weapons.reserve = 10
	await _seconds(0.6)


func _shot() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var knappe: EnemyData = load("res://data/enemies/knappe.tres")
	player.global_position = FIELD
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	var spots: Array[Vector3] = [FIELD + Vector3(9, 0, 0), FIELD + Vector3(9, 0, 2.5), FIELD + Vector3(9, 0, 4.5)]
	var list: Array[Enemy] = [_spawn(knappe, spots[0]), _spawn(wanderer, spots[1]), _spawn(wanderer, spots[2])]
	for e: Enemy in list:
		e.health = 10000
	await _frames(3)
	holder._fire()
	_check(holder.mag == 0, "one shot and it is empty")
	await _seconds(1.0)
	_check(list[0].health == 10000 - gun.damage and list[1].health == 10000 - gun.damage, "the shell bursts for %d on the Knappe and a wanderer 2.5 m off" % gun.damage)
	_check(list[2].health == 10000, "not on one 4.5 m off")
	holder.start_reload()
	await _seconds(gun.reload_time - 0.3)
	_check(holder.mag == 0, "still loading after %.1f s" % (gun.reload_time - 0.3))
	await _seconds(0.5)
	_check(holder.mag == 1 and holder.reserve == 9, "loaded after %.1f s (1 / %d)" % [gun.reload_time, holder.reserve])
	await _clear(list)


func _double() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	player.global_position = FIELD
	player.velocity = Vector3.ZERO
	_look_flat(Vector3(1, 0, 0))
	var holder: WeaponHolder = player.weapons
	holder._cooldown = 0.0
	var reserve: int = holder.reserve
	# Flatter and faster: where does it come down? Put enemies 4 m either side of that line further out.
	var near := _spawn(wanderer, FIELD + Vector3(14, 0, 0))
	var side := _spawn(wanderer, FIELD + Vector3(14, 0, 4))
	near.health = 10000
	side.health = 10000
	await _frames(3)
	holder.fire_secondary()
	_check(holder.mag == 0 and holder.reserve == reserve - 1, "the Doppelladung takes the loaded round and one from the reserve (%d left)" % holder.reserve)
	await _frames(2)
	_check(player.velocity.x < -2.0, "and kicks the shooter back (%.1f m/s)" % player.velocity.x)
	await _seconds(1.2)
	_check(near.health == 10000 - gun.secondary_damage and side.health == 10000 - gun.secondary_damage, "it flies further and bursts for %d within %.1f m" % [gun.secondary_damage, gun.secondary_range])
	# With nothing in the reserve there is no second measure to pour in.
	holder.mag = 1
	holder.reserve = 0
	holder._cooldown = 0.0
	holder.fire_secondary()
	_check(holder.mag == 1, "no Doppelladung with an empty reserve")
	await _clear([near, side])


func _alphorn() -> void:
	var buy: WallBuy = _wall_buy(horn)
	_check(buy != null and (main.get_node("World/Seilbahn") as Node3D).is_ancestor_of(buy), "an Alphorn wall-buy in the Seilbahn")
	if buy == null:
		return
	_check(not buy.visible and not buy.is_in_group("interactables"), "hidden before wave %d" % buy.from_wave)
	Events.wave_started.emit(buy.from_wave - 1, false)
	_check(not buy.visible, "still hidden in wave %d" % (buy.from_wave - 1))
	Events.wave_started.emit(buy.from_wave, false)
	_check(buy.visible and buy.is_in_group("interactables") and _announced.has(tr("EVENT_ALPHORN_READY")), "wave %d: it hangs there and is announced" % buy.from_wave)
	player.global_position = buy.get_interact_position()
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
	await _frames(3)
	player.points.add(5000)
	_check(player.interactor._find_target() == buy and buy.get_interact_prompt(player).contains("4000"), "on sale: %s" % buy.get_interact_prompt(player))
	var before: int = player.points.total
	buy.interact(player)
	_check(player.weapons.weapon == horn and player.points.total == before - 4000, "bought for 4000")
