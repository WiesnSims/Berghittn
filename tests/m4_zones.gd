extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m4_zones.tscn
## Headless M4 check on the real main scene: unlock all six zones through their doors (points from the
## debug key), spawn activation after every purchase, navmesh paths through opened doors, the shotgun and
## rifle wall-buys, ammo refills at half price, gun slots and switching, and one set of points per shotgun blast.

const ALL_ZONES: Array[StringName] = [&"stube", &"kueche", &"terrasse", &"skiraum", &"schuppen", &"seilbahn"]

var main: Node
var player: Player
var zones: ZoneMap
var waves: WaveManager
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


func _door(a: StringName, b: StringName) -> ZoneDoor:
	for node: Node in get_tree().get_nodes_in_group("zone_doors"):
		var door := node as ZoneDoor
		if door.other_side(a) == b:
			return door
	return null


func _stand_at(target: Node3D) -> void:
	player.global_position = target.get_interact_position()
	player.velocity = Vector3.ZERO


func _expected_active() -> Array[StringName]:
	# Section 4 by hand, from the table of doors: unlocked zones plus their neighbours.
	var adjacent := {
		&"stube": [&"kueche", &"terrasse"], &"kueche": [&"stube", &"skiraum"], &"terrasse": [&"stube", &"schuppen"],
		&"skiraum": [&"kueche", &"seilbahn"], &"seilbahn": [&"skiraum", &"schuppen"], &"schuppen": [&"seilbahn", &"terrasse"],
	}
	var active: Array[StringName] = []
	for zone: StringName in ALL_ZONES:
		if zones.is_unlocked(zone):
			active.append(zone)
			continue
		for other: StringName in adjacent[zone]:
			if zones.is_unlocked(other):
				active.append(zone)
				break
	return active


func _check_spawns(stage: String) -> void:
	var expected: Array[StringName] = _expected_active()
	var picked: Dictionary = {}
	for i: int in 400:
		var point := waves._pick_spawn_point() as SpawnPoint
		picked[point.zone] = true
	var ok: bool = picked.size() == expected.size()
	for zone: StringName in picked:
		ok = ok and expected.has(zone)
	_check(ok, "%s: spawns come from %s (expected %s)" % [stage, picked.keys(), expected])


func _reachable(from: Vector3, to: Vector3) -> bool:
	var map: RID = (main.get_node("World/Navigation") as NavigationRegion3D).get_navigation_map()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 0.6


func _buy_door(a: StringName, b: StringName, zone: StringName) -> void:
	var door: ZoneDoor = _door(a, b)
	_stand_at(door)
	var cost: int = zones.get_zone(zone).cost
	var target: Node3D = player.interactor._find_target()
	_check(target == door, "standing at the %s door, E targets it" % zone)
	var before: int = player.points.total
	door.interact(player)
	_check(zones.is_unlocked(zone) and player.points.total == before - cost, "%s bought for %d (points %d -> %d)" % [zone, cost, before, player.points.total])
	await _frames(3)
	_check(door.is_open() and not (door.get_node("Hinge/Panel") as CSGShape3D).use_collision, "%s door open and out of the way" % zone)
	_check_spawns("after %s" % zone)


func _debug_points() -> void:
	var press := InputEventAction.new()
	press.action = &"debug_points"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"debug_points"
	Input.parse_input_event(release)
	await _frames(2)


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	waves = main.get_node("WaveManager")
	# No enemies: this test is about the map; spawning is checked through the picker.
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)

	_check(zones.unlocked_count() == 1 and zones.is_unlocked(&"stube"), "only the Stube starts open")
	_check(get_tree().get_nodes_in_group("zone_doors").size() == 6, "six doors")
	_check_spawns("start")
	var stube_spot := Vector3(-1, 0, 2)
	var schuppen_spot := Vector3(14.3, 0, 13)
	_check(not _reachable(stube_spot, Vector3(1, 0, -8)), "Kueche not reachable on foot while locked")

	# Not enough points: nothing happens, and the prompt says what is missing.
	var kueche_door: ZoneDoor = _door(&"stube", &"kueche")
	_stand_at(kueche_door)
	var prompt: String = kueche_door.get_interact_prompt(player)
	kueche_door.interact(player)
	_check(not zones.is_unlocked(&"kueche") and player.points.total == 0 and prompt.contains("500"), "no buy with 0 points (prompt: %s)" % prompt)

	# Points from the debug key, as the acceptance allows; only while the F3 overlay is shown.
	var overlay := main.get_node("UI/DebugOverlay") as Label
	overlay.visible = false
	await _debug_points()
	_check(player.points.total == 0, "debug key does nothing while the overlay is hidden")
	overlay.visible = true
	for i: int in 7:
		await _debug_points()
	_check(player.points.total == 7 * Constants.DEBUG_POINTS, "debug key adds %d per press (now %d)" % [Constants.DEBUG_POINTS, player.points.total])

	await _buy_door(&"stube", &"kueche", &"kueche")
	await _frames(3)
	_check(_reachable(stube_spot, Vector3(1, 0, -8)), "Kueche reachable through its door after the rebake")
	await _buy_door(&"kueche", &"skiraum", &"skiraum")
	await _buy_door(&"skiraum", &"seilbahn", &"seilbahn")
	await _buy_door(&"seilbahn", &"schuppen", &"schuppen")
	var terrasse_schuppen: ZoneDoor = _door(&"terrasse", &"schuppen")
	_check(not terrasse_schuppen.is_open() and terrasse_schuppen.get_interact_prompt(player) != "", "Terrasse door from the Schuppen side is for sale")
	await _buy_door(&"stube", &"terrasse", &"terrasse")
	_check(terrasse_schuppen.is_open(), "door between two open zones opened by itself")
	_check(zones.unlocked_count() == 6, "all six zones unlocked")
	await _frames(3)
	_check(_reachable(stube_spot, schuppen_spot), "Schuppen reachable from the Stube")
	var spent: int = 500 + 1000 + 1500 + 1250 + 750
	_check(player.points.total == 7 * Constants.DEBUG_POINTS - spent, "spent exactly %d" % spent)
	for node: Node in get_tree().get_nodes_in_group("zone_doors"):
		_check((node as ZoneDoor).get_interact_prompt(player) == "", "%s: no prompt once open" % node.name)

	await _check_wall_buys()
	await _check_shotgun_points()

	print("RESULT: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_wall_buys() -> void:
	var weapons: WeaponHolder = player.weapons
	var shotgun_buy := main.get_node("World/Stube/WallBuyJagdflinte") as WallBuy
	var rifle_buy := main.get_node("World/Skiraum/WallBuyStutzen") as WallBuy
	player.points.total = 400
	_stand_at(shotgun_buy)
	_check(player.interactor._find_target() == shotgun_buy, "E targets the Jagdflinte wall-buy")
	shotgun_buy.interact(player)
	_check(not weapons.has_weapon(shotgun_buy.weapon) and player.points.total == 400, "Jagdflinte not sold for 400")
	player.points.total = 2000
	shotgun_buy.interact(player)
	_check(weapons.weapon.id == &"jagdflinte" and weapons.gun_count() == 2 and player.points.total == 1500, "Jagdflinte bought for 500 into the free slot")
	_check(weapons.mag == 2 and weapons.reserve == 24, "Jagdflinte 2 / 24, no chamber round (got %d / %d)" % [weapons.mag, weapons.reserve])
	_check(shotgun_buy.get_interact_prompt(player) == "", "no ammo offer while the reserve is full")
	await _frames(int(Constants.WEAPON_SWITCH_TIME * 60) + 2)
	weapons._fire()
	weapons.start_reload()
	weapons._finish_reload()
	_check(weapons.mag == 2 and weapons.reserve == 23, "break-action reload tops up to 2, never 3 (got %d / %d)" % [weapons.mag, weapons.reserve])
	var offer: String = shotgun_buy.get_interact_prompt(player)
	shotgun_buy.interact(player)
	_check(offer.contains("250") and weapons.reserve == 24 and player.points.total == 1250, "ammo refill for 250 (half price): reserve %d, points %d" % [weapons.reserve, player.points.total])

	# Switching keeps each gun's ammo.
	weapons._select(0)
	_check(weapons.weapon.id == &"pistole" and weapons.mag == 9, "slot 1 is the pistol, still 9 in it")
	weapons._fire()
	weapons._select(1)
	_check(weapons.weapon.id == &"jagdflinte" and weapons.mag == 2, "slot 2 back to the Jagdflinte with 2")
	weapons._select(0)
	_check(weapons.mag == 8, "pistol kept its 8 after switching away and back")

	# Both slots full: a new gun replaces the one in hand.
	_stand_at(rifle_buy)
	_check(player.interactor._find_target() == rifle_buy, "E targets the Stutzen wall-buy")
	rifle_buy.interact(player)
	_check(weapons.weapon.id == &"stutzen" and weapons.gun_count() == 2 and not weapons.has_weapon(load("res://data/weapons/pistole.tres")) and player.points.total == 500,
		"Stutzen for 750 replaced the pistol in hand")
	_check(weapons.mag == 6 and weapons.reserve == 40, "Stutzen starts chambered: 6 / 40 (got %d / %d)" % [weapons.mag, weapons.reserve])
	await _frames(int(Constants.WEAPON_SWITCH_TIME * 60) + 2)
	for i: int in 6:
		weapons._fire()
	weapons.start_reload()
	weapons._finish_reload()
	_check(weapons.mag == 5, "Stutzen reload from empty: 5 (got %d)" % weapons.mag)
	weapons._fire()
	weapons.start_reload()
	weapons._finish_reload()
	_check(weapons.mag == 6, "Stutzen reload with a round chambered: 6 (got %d)" % weapons.mag)
	player.points.total = 300
	_check(rifle_buy.get_interact_prompt(player).contains("375"), "Stutzen ammo costs 375: %s" % rifle_buy.get_interact_prompt(player))


func _check_shotgun_points() -> void:
	var weapons: WeaponHolder = player.weapons
	weapons._select(weapons._slot_of(load("res://data/weapons/jagdflinte.tres")))
	await _frames(int(Constants.WEAPON_SWITCH_TIME * 60) + 2)
	# Outside the (disabled) wave manager: a disabled parent would take the hurtboxes out of physics.
	var enemy := waves.enemy_scene.instantiate() as Enemy
	main.add_child(enemy)
	# Stand in the Stube facing a fresh enemy 3 m away; aim at the chest.
	player.global_position = Vector3(-1, 0, 2)
	player.rotation = Vector3.ZERO
	(player.get_node("Head") as Node3D).rotation.x = -0.1
	enemy.activate(load("res://data/enemies/wanderer.tres"), 1, Transform3D(Basis.IDENTITY, Vector3(-1, 0, -1)))
	await _frames(2)
	var kills: Array[int] = [0]
	Events.enemy_killed.connect(func(_e: Node3D, _h: bool, _m: bool, _s: Node3D) -> void: kills[0] += 1)
	var before: int = player.points.total
	weapons._fire()
	var gained: int = player.points.total - before
	_check(not enemy.is_alive() and kills[0] == 1 and (gained == Constants.POINTS_KILL_BODY or gained == Constants.POINTS_KILL_HEADSHOT),
		"one shotgun blast: %d kill(s), %d points (not one payout per pellet)" % [kills[0], gained])
