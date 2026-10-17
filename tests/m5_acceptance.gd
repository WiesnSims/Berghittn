extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_acceptance.tscn
## M5 acceptance "all items purchasable" (section 12) on the real main scene. Every weapon and piece of
## equipment in data/ has a way in (the start, a wall-buy, the Hüttentruhe, a boss's drop or an event),
## and every way in works where it stands: with all doors bought through the real doors, each wall-buy
## (the Alphorn once wave 10 comes), Schnaps bottle, the Brettljause, the Munitionskiste and the
## Hüttentruhe is reachable on foot from the start, E finds it, and buying it gives what it sells;
## the chest hands out every weapon in its pool. "Wave 10 reachable" is tests/m5_waves.

var main: Node
var player: Player
var zones: ZoneMap
var nav_map: RID
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


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	nav_map = (main.get_node("World/Navigation") as NavigationRegion3D).get_navigation_map()
	await _frames(10)

	_coverage()
	await _open_all_doors()
	# The Alphorn's Seilbahn wall-buy shows from wave 10.
	Events.wave_started.emit(10, true)
	await _frames(2)
	await _wall_buys()
	await _shrine()
	await _crate()
	await _chest()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


## Every weapon and equipment resource has a way into a player's hands.
func _coverage() -> void:
	var ways: Dictionary = {}
	var holder: WeaponHolder = player.weapons
	ways[holder.starting_weapon.id] = "start"
	ways[holder.melee_weapon.id] = "start (V)"
	for buy: WallBuy in main.find_children("*", "WallBuy", true, false):
		if buy.weapon:
			ways[buy.weapon.id] = "wall-buy %s" % buy.get_parent().name
		if buy.equipment:
			ways[buy.equipment.id] = "wall-buy %s" % buy.get_parent().name
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	for entry: ChestEntry in chest.pool.entries:
		ways[entry.weapon.id] = "Hüttentruhe"
	for file: String in DirAccess.get_files_at("res://data/enemies"):
		var enemy: EnemyData = load("res://data/enemies/" + file.trim_suffix(".remap")) as EnemyData
		if enemy and enemy.drop:
			ways[enemy.drop.id] = "dropped by the %s" % enemy.id
	# The Deitscha Tourist hands out the Eisstock (section 8a).
	var tourist: GDScript = load("res://scripts/events/tourist_guest.gd")
	if tourist.source_code.contains("eisstock.tres"):
		ways[&"eisstock"] = "the Deitscha Tourist"
	for folder: String in ["weapons", "equipment"]:
		for file: String in DirAccess.get_files_at("res://data/" + folder):
			var item: Resource = load("res://data/%s/%s" % [folder, file.trim_suffix(".remap")])
			var id: StringName = item.get("id")
			_check(ways.has(id), "%s: %s" % [id, ways.get(id, "NO WAY TO GET IT")])


func _open_all_doors() -> void:
	player.points.total = 100000
	var opened: bool = true
	# Doors in the order the map allows: each one bought from a side already open.
	for round: int in 8:
		opened = false
		for node: Node in get_tree().get_nodes_in_group("zone_doors"):
			var door := node as ZoneDoor
			if door.is_open() or door.get_interact_prompt(player) == "":
				continue
			player.global_position = door.get_interact_position()
			player.velocity = Vector3.ZERO
			await _frames(2)
			door.interact(player)
			opened = true
			await _frames(3)
		if not opened:
			break
	_check(zones.unlocked_count() == 7, "all seven zones bought through their doors")
	player.global_position = _spawn()
	await _frames(5)


func _spawn() -> Vector3:
	return (get_tree().get_first_node_in_group("player_spawn") as Node3D).global_position


## Somewhere on foot next to `at`: the nearest walkable point within 1.6 m (a bottle on a shelf, a
## board on a wall), with a path to it from the start.
func _reachable(at: Vector3) -> bool:
	var near: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, at)
	if Vector2(near.x - at.x, near.z - at.z).length() > 1.6 or absf(near.y - at.y) > 2.2:
		return false
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, _spawn(), near, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(near) < 0.6


## Walks up to `item` (stands at its spot, looking at it) and checks E finds it.
func _step_up(item: Node3D, what: String) -> bool:
	var at: Vector3 = item.get_interact_position()
	_check(_reachable(at), "%s can be walked to" % what)
	var near: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, at)
	player.global_position = Vector3(near.x, near.y, near.z)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(at.x, player.global_position.y, at.z) + (Vector3.FORWARD if Vector2(at.x - near.x, at.z - near.z).length() < 0.05 else Vector3.ZERO), Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	await _frames(3)
	var found: bool = player.interactor._find_target() == item
	_check(found, "E finds the %s (%s)" % [what, item.get_interact_prompt(player)])
	return found


func _wall_buys() -> void:
	var holder: WeaponHolder = player.weapons
	for buy: WallBuy in main.find_children("*", "WallBuy", true, false):
		player.points.total = 100000
		var what: String = tr(buy.weapon.display_name) if buy.weapon else tr(buy.equipment.display_name)
		# Not already carried, so it is on sale.
		if buy.weapon and holder.has_weapon(buy.weapon):
			if buy.weapon.is_melee:
				holder.set_melee(load("res://data/weapons/schaufel.tres"))
			else:
				holder.give_weapon(load("res://data/weapons/pistole.tres"))
		if buy.equipment and player.equipment.item == buy.equipment:
			player.equipment.count = 0
		if not await _step_up(buy, "%s wall-buy" % what):
			continue
		buy.interact(player)
		var got: bool = holder.has_weapon(buy.weapon) if buy.weapon else player.equipment.item == buy.equipment and player.equipment.count > 0
		_check(got and player.points.total < 100000, "%s bought for %d" % [what, 100000 - player.points.total])
		await _frames(2)


func _shrine() -> void:
	for bottle: PerkBottle in main.find_children("*", "PerkBottle", true, false):
		player.points.total = 100000
		var what: String = tr(bottle.perk.display_name)
		if not await _step_up(bottle, "%s bottle" % what):
			continue
		bottle.interact(player)
		_check(player.perks.has(bottle.perk), "%s drunk" % what)
	for jause: JauseItem in main.find_children("*", "JauseItem", true, false):
		player.points.total = 100000
		var what: String = tr(jause.jause.display_name)
		if not await _step_up(jause, what):
			continue
		for i: int in jause.jause.max_level:
			jause.interact(player)
		_check(player.perks.jause_level(jause.jause) == jause.jause.max_level, "%s eaten to level %d" % [what, jause.jause.max_level])


func _crate() -> void:
	var holder: WeaponHolder = player.weapons
	for crate: AmmoCrate in main.find_children("*", "AmmoCrate", true, false):
		player.points.total = 100000
		for slot: WeaponHolder.GunSlot in holder._slots:
			slot.reserve = 0
		holder.reserve = 0
		if not await _step_up(crate, "Munitionskiste"):
			continue
		crate.interact(player)
		_check(holder.reserve > 0 and not holder.needs_any_ammo(), "the Munitionskiste refills every gun")


func _chest() -> void:
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var holder: WeaponHolder = player.weapons
	if not await _step_up(chest, "Hüttentruhe"):
		return
	var seen: Dictionary = {}
	for i: int in 60:
		if seen.size() == chest.pool.entries.size():
			break
		player.points.total = 100000
		# Back to the start kit, so nothing in the pool is already carried.
		while holder.gun_count() > 1:
			holder._slots.remove_at(holder._slots.size() - 1)
		holder._current = -1
		holder._select(0)
		holder.set_melee(load("res://data/weapons/schaufel.tres"))
		chest.interact(player)
		await _seconds(chest.pool.roll_time + 0.1)
		if chest.state != Huettentruhe.State.OFFERING:
			continue
		var offer: WeaponData = chest.offer
		chest.interact(player)
		if holder.has_weapon(offer):
			seen[offer.id] = true
		await _seconds(1.2)
	for entry: ChestEntry in chest.pool.entries:
		_check(seen.has(entry.weapon.id), "the Hüttentruhe hands out the %s" % tr(entry.weapon.display_name))
