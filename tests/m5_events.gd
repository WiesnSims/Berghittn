extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_events.tscn
## Section 8a events on the real main scene. Die Resi: only with the Terrasse open, walks into the
## beer garden, is marked map-wide, once a player comes near her bell pulls outside enemies to her (they
## make her bolt; before that they leave her alone), and
## milking her heals fully and gives a free Brettljause helping. The Bierfassl rolls down off the alm
## into the garden, flattens what is in its way, stops at a wall or a player, and tapping it gives a Schnaps.
## The Murmeltier pops up near the player where players can walk, screams, hops, and pays out when hit.
## The Deitscha Tourist waits without an escort, is hunted by enemies, walks the long way round through the
## Schuppen and over the Terrasse (the direct way while one is shut), and once escorted to the Stube
## leaves two Eisstöcke, which slide through enemies and bounce off walls.

var main: Node
var player: Player
var zones: ZoneMap
var waves: WaveManager
var director: EventDirector
var hud: Hud
var failures: Array[String] = []
var _banners: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Events.event_announced.connect(func(text: String) -> void: _banners.append(text))
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
	await _frames(5)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	waves = main.get_node("WaveManager")
	director = main.get_node("EventDirector")
	hud = main.get_node("UI/Hud")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	# Events are started by hand here; none must turn up on their own in between.
	director.random_events = false
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	await _schedule()
	await _guest_way_shut()
	for zone: ZoneData in zones.table.zones:
		zones.unlock(zone.id, null)
	await _frames(30)
	_tables_off_navmesh()
	await _resi_walks_in()
	await _resi_lures()
	await _resi_milked()
	await _resi_leaves()
	_random_events()
	await _fassl()
	await _fassl_stopped()
	await _murmeltier_caught()
	await _murmeltier_escapes()
	await _guest_hunted()
	await _guest_escorted()
	await _eisstock()
	print("RESULT: ", "PASS" if failures.is_empty() else "%d FAILED" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _random_events() -> void:
	_check(director.available_random_events() == [&"fassl", &"murmeltier", &"guest"], "random events with every zone open: %s" % [director.available_random_events()])
	director._last_random = &"fassl"
	_check(director.available_random_events() == [&"murmeltier", &"guest"], "not the same one twice in a row: %s" % [director.available_random_events()])
	director._last_random = &""
	# Never on a boss wave: not even Resi, who is due.
	var due: int = director._next_resi
	director._next_resi = 5
	director._on_wave_started(5, true)
	_check(director._next_resi == 5, "nothing on a boss wave")
	director._next_resi = due


func _fassl() -> void:
	# An enemy standing in the garden on the barrel's way; the player safe in the Stube.
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	var victim := waves._create_enemy()
	victim.activate(load("res://data/enemies/wanderer.tres"), 1, Transform3D(Basis.IDENTITY, Vector3(-8.0, -0.3, 17.0)))
	victim.process_mode = Node.PROCESS_MODE_PAUSABLE
	victim.set_physics_process(false)
	var fassl: Bierfassl = director.start_event(&"fassl") as Bierfassl
	_check(fassl != null and _banners.back() == "Bierfassl kert onzapft!", "announced: %s" % _banners.back())
	var start: Vector3 = fassl.global_position
	_check(start.y > 3.0, "it breaks loose up on the alm (%s)" % start.snapped(Vector3.ONE * 0.1))
	for i: int in 60 * 25:
		await get_tree().physics_frame
		if fassl.is_resting():
			break
	var p: Vector3 = fassl.global_position
	_check(not victim.is_alive(), "it flattens the enemy in its way")
	_check(fassl.is_resting() and p.x > 4.0 and p.x < 7.1 and absf(p.z - 17.0) < 1.0 and p.y < 0.5, "and rolls across the garden into the Schuppen wall (%s)" % p.snapped(Vector3.ONE * 0.1))
	# Tap it.
	player.global_position = p + Vector3(-1.2, -0.12, 0.0)
	player.velocity = Vector3.ZERO
	await _frames(3)
	_check(fassl.get_interact_prompt(player) == tr("UI_TAP"), "prompt: %s" % fassl.get_interact_prompt(player))
	var owned: int = player.perks.owned.size()
	var pulls: int = 0
	while fassl.is_resting() and pulls < 40:
		fassl.interact(player)
		pulls += 1
		await _seconds(fassl.interact_repeat)
	_check(player.perks.owned.size() == owned + 1 and _banners.back().begins_with("Freibier!"), "Freibier after %.1f s: %s" % [pulls * fassl.interact_repeat, _banners.back()])
	await _seconds(5.0)
	_check(not is_instance_valid(fassl), "then the empty barrel is gone")


func _fassl_stopped() -> void:
	# A player in its way stops it.
	var spot := Vector3(-6.0, -0.3, 17.0)
	var fassl: Bierfassl = director.start_event(&"fassl") as Bierfassl
	for i: int in 60 * 25:
		player.global_position = spot
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if fassl.is_resting():
			break
	var p: Vector3 = fassl.global_position
	_check(fassl.is_resting() and p.x < spot.x and p.x > spot.x - 2.0, "a player in its way stops it (%s)" % p.snapped(Vector3.ONE * 0.1))
	fassl.queue_free()
	await _frames(2)


func _murmeltier_caught() -> void:
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	player.velocity = Vector3.ZERO
	await _frames(2)
	var murmel: Murmeltier = director.start_event(&"murmeltier") as Murmeltier
	var d: float = murmel.global_position.distance_to(player.global_position) if murmel else -1.0
	_check(murmel != null and d >= Constants.MURMEL_FIRST_MIN and d <= Constants.MURMEL_FIRST_MAX, "a Murmeltier pops up %.1f m away at %s" % [d, murmel.global_position.snapped(Vector3.ONE * 0.1) if murmel else Vector3.ZERO])
	_check(_banners.back() == "Da schreit a Murmeltier!", "announced: %s" % _banners.back())
	while not murmel.is_up() or murmel._state != Murmeltier.State.SCREAMING:
		await get_tree().physics_frame
	await _frames(2)
	_check(is_instance_valid(murmel._scream) and murmel._scream.stream != null and murmel._scream.playing, "it screams (our own synthesised scream)")
	# Shoot it with an almost empty pistol from 3 m.
	var spot: Vector3 = murmel.global_position
	murmel._pops_left = 99
	murmel._state = Murmeltier.State.SCREAMING
	murmel._time = -100.0
	player.weapons.give_weapon(load("res://data/weapons/pistole.tres"))
	await _seconds(0.6)
	# A spot close by with a clear view of it.
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var stand: Vector3 = Vector3.INF
	for i: int in 30:
		var near: Vector3 = EventDirector.reachable_spot(player.get_world_3d(), spot, 2.0, 3.5)
		if near == Vector3.INF:
			continue
		var view := PhysicsRayQueryParameters3D.create(near + Vector3.UP * 1.5, spot + Vector3.UP * 0.45, Constants.LAYER_WORLD)
		if space.intersect_ray(view).is_empty():
			stand = near
			break
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await _frames(3)
	_look_at(spot + Vector3.UP * 0.45)
	_steady()
	player.weapons.mag = 2
	player.weapons.reserve = 5
	player.weapons.aim_amount = 1.0
	player.weapons.bloom = 0.0
	var points: int = player.points.total
	player.weapons._fire()
	_check(player.points.total == points + Constants.MURMEL_POINTS, "caught with a shot: +%d points" % (player.points.total - points))
	_check(player.weapons.mag == player.weapons.weapon.mag_size and player.weapons.reserve == player.weapons.weapon.reserve_ammo, "and the gun in hand is full (%d / %d)" % [player.weapons.mag, player.weapons.reserve])
	_check(_banners.back().begins_with("Murmeltier erwischt!"), "announced: %s" % _banners.back())
	await _seconds(1.0)
	_check(not is_instance_valid(murmel), "bonk, gone")


func _murmeltier_escapes() -> void:
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	await _frames(2)
	var murmel: Murmeltier = director.start_event(&"murmeltier") as Murmeltier
	var spots: Array[Vector3] = [murmel.global_position]
	for i: int in 60 * 30:
		await get_tree().physics_frame
		if not is_instance_valid(murmel):
			break
		if murmel.global_position.distance_to(spots.back()) > 0.1:
			spots.append(murmel.global_position)
	var hops_ok: bool = true
	for i: int in range(1, spots.size()):
		var hop: float = spots[i].distance_to(spots[i - 1])
		hops_ok = hops_ok and hop >= Constants.MURMEL_HOP_MIN - 0.01 and hop <= Constants.MURMEL_HOP_MAX + 0.01
	var inside: bool = spots.all(func(v: Vector3) -> bool: return not (v.x < -16.0 or v.z > 24.0 or (v.x < -11.2 and v.z < 11.3)))
	_check(inside, "never beyond the garden fence or outside the hut")
	_check(spots.size() == Constants.MURMEL_POPS and hops_ok, "not caught, it pops up %d times close by: %s" % [spots.size(), spots.map(func(v: Vector3) -> Vector3: return v.snapped(Vector3.ONE * 0.1))])
	_check(not is_instance_valid(murmel) and _banners.back() == tr("EVENT_MURMEL_GONE"), "then it is gone: %s" % _banners.back())


func _look_at(point: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	player.look_at(Vector3(point.x, player.global_position.y, point.z), Vector3.UP)
	var d: Vector3 = point - cam.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _steady() -> void:
	var camera := player.get_node("Head/Camera3D") as CameraRecoil
	camera.sway = Vector2.ZERO
	camera._target = Vector2.ZERO
	camera._current = Vector2.ZERO
	camera.rotation = Vector3.ZERO


func _guest_hunted() -> void:
	_check(director.available_random_events().has(&"guest"), "with the Seilbahn and the way to the Stube open he can come: %s" % [director.available_random_events()])
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	var guest: TouristGuest = director.start_event(&"guest") as TouristGuest
	_check(guest != null and _banners.back() == "A Deitscha Tourist hat si verlaufen!", "announced: %s" % _banners.back())
	var start: Vector3 = guest.global_position
	await _seconds(2.0)
	_check(guest._state == TouristGuest.State.WAITING and guest.global_position.distance_to(start) < 0.3, "alone, he stands at the gondola with his map")
	# An enemy in the station goes for him.
	var enemy := waves._create_enemy()
	enemy.activate(load("res://data/enemies/wanderer.tres"), 1, Transform3D(Basis.IDENTITY, start + Vector3(-2.5, 0.0, -1.0)))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _seconds(5.0)
	_check(guest.health < Constants.GUEST_HEALTH, "enemies go for him too (health %d)" % guest.health)
	enemy.receive_hit(100000, false, false, null)
	guest.take_damage(10000)
	_check(not guest.is_alive() and _banners.back() == tr("EVENT_GUEST_DIED"), "he can die: %s" % _banners.back())
	await _seconds(5.5)
	_check(not is_instance_valid(guest), "and is gone")


func _guest_way_shut() -> void:
	# Only the Seilbahn (and the Terrasse) open: the Schuppen on the long way is shut.
	zones.unlock(&"seilbahn", null)
	await _frames(30)
	var arrival := get_tree().get_first_node_in_group("guest_arrival") as Node3D
	var goal := get_tree().get_first_node_in_group("guest_goal") as Node3D
	_check(director._guest_route_open() and director.guest_way(arrival.global_position, goal.global_position).is_empty(),
		"with the Schuppen shut, the Tourist takes the direct way from the Seilbahn")


func _guest_escorted() -> void:
	var guest: TouristGuest = director.start_event(&"guest") as TouristGuest
	_check(guest._way.size() == 2, "with every zone open, he walks the long way round (%d waypoints)" % guest._way.size())
	var schuppen: bool = false
	var terrasse: bool = false
	var arrived: bool = false
	var frames: int = 0
	for i: int in 60 * 120:
		frames = i
		var p: Vector3 = guest.global_position
		schuppen = schuppen or (p.x > 7.5 and p.x < 21.0 and p.z > 9.5 and p.z < 19.0)
		terrasse = terrasse or (p.x < 6.5 and p.z > 6.5)
		# Walk with him, a little behind.
		var back: Vector3 = guest.global_basis.z * 1.6
		player.global_position = guest.global_position + Vector3(back.x, 0.0, back.z)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if guest.has_arrived():
			arrived = true
			break
	_check(arrived, "escorted, he finds the Stube (%s)" % guest.global_position.snapped(Vector3.ONE * 0.1))
	_check(schuppen and terrasse, "through the Schuppen (%s) and over the Terrasse (%s), %.0f s" % [schuppen, terrasse, frames / 60.0])
	_check(_banners.back() == "Das ist ja total urig hier!", "and says: %s" % _banners.back())
	await _seconds(2.2)
	_check(player.equipment.item != null and player.equipment.item.id == &"eisstock" and player.equipment.count == 2, "and leaves two Eisstöcke: %s" % _banners.back())
	_check(hud._equipment_label.text.begins_with("Eisstock"), "HUD: %s" % hud._equipment_label.text)


func _eisstock() -> void:
	# Three in a row in the beer garden; one stone through all of them.
	player.global_position = Vector3(-12.0, -0.3, 16.5)
	player.velocity = Vector3.ZERO
	var row: Array[Enemy] = []
	for x: float in [-8.0, -6.0, -4.0]:
		var enemy := waves._create_enemy()
		enemy.activate(load("res://data/enemies/knappe.tres"), 10, Transform3D(Basis.IDENTITY, Vector3(x, -0.3, 16.5)))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.set_physics_process(false)
		row.append(enemy)
	await _frames(3)
	_look_at(Vector3(0.0, 0.5, 16.5))
	var points: int = player.points.total
	_check(player.equipment.throw(), "thrown")
	await _seconds(2.0)
	_check(row.all(func(e: Enemy) -> bool: return not e.is_alive()), "it slides through three Bergknappen at wave 10 and flattens them all")
	_check(player.points.total > points, "the kills pay (+%d)" % (player.points.total - points))
	# Into the south fence: it bounces.
	await _seconds(0.7)
	player.global_position = Vector3(-2.0, -0.3, 19.0)
	_look_at(Vector3(-0.5, 0.0, 24.0))
	player.equipment.throw()
	var stone: Eisstock = null
	for node: Node in main.get_children():
		if node is Eisstock and (node as Eisstock).is_sliding():
			stone = node
	await _seconds(1.0)
	_check(stone != null and is_instance_valid(stone) and stone.bounces_left() < Constants.EISSTOCK_BOUNCES, "off the fence it bounces (%d bounces left)" % [stone.bounces_left() if is_instance_valid(stone) else -1])
	_check(player.equipment.count == 0 and hud._equipment_label.text == "", "both thrown, the slot is empty; no refill anywhere")
	_check(not player.equipment.throw(), "nothing more to throw")
	for e: Enemy in row:
		if e.is_alive():
			e.receive_hit(100000, false, false, null)
	await _seconds(4.0)


func _schedule() -> void:
	director._on_wave_started(3, false)
	_check(director._next_resi == 3, "no Resi while the Terrasse is shut (she waits)")
	zones.unlock(&"terrasse", null)
	director._on_wave_started(3, false)
	_check(director._next_resi >= 6 and director._next_resi <= 8, "with the Terrasse open she comes at wave 3, next at %d" % director._next_resi)
	# The timer would send her in RESI_DELAY s; the tests send her themselves.
	await _frames(1)


func _tables_off_navmesh() -> void:
	# Play-test: table tops were navmesh islands, and an enemy shoved onto one pathed in circles.
	var map: RID = player.get_world_3d().navigation_map
	var top: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(-7.5, 0.8, 9.0))
	_check(top.y < 0.3, "no navmesh on the Terrasse table (closest point %s)" % top.snapped(Vector3.ONE * 0.1))


func _resi_walks_in() -> void:
	var resi: Resi = director.send_resi()
	_check(resi != null and _banners.back() == "Die Resi hat si verlaufen!", "announced: %s" % [_banners.back() if not _banners.is_empty() else "-"])
	_check(get_tree().get_nodes_in_group("map_markers").size() == 1, "marked on the map (light column, label, edge arrow)")
	var grazed: bool = false
	for i: int in 60 * 30:
		await get_tree().physics_frame
		if resi._state == Resi.State.GRAZING:
			grazed = true
			break
	var p: Vector3 = resi.global_position
	_check(grazed and p.y < 0.0 and p.x > -16.0 and p.x < 7.0 and p.z > 11.3 and p.z < 24.0, "she walks into the beer garden (%s)" % p.snapped(Vector3.ONE * 0.1))
	resi.queue_free()
	await _frames(2)


func _resi_lures() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(12.0)
	# An enemy outside, by the hut's west side: without the bell it would go for a window.
	var enemy := waves._create_enemy()
	var at := Vector3(-14.0, -0.3, 8.0)
	enemy.activate(load("res://data/enemies/tourist.tres"), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	var start: float = enemy.global_position.distance_to(resi.global_position)
	# Nobody near her yet (the player is in the Stube): the enemies leave her alone. The enemy holds
	# still meanwhile, or it is in through a window (and past her pull) before the player gets out.
	enemy.set_physics_process(false)
	var left_alone: bool = true
	for i: int in 60 * 5:
		await get_tree().physics_frame
		left_alone = left_alone and enemy._find_lure() == null and resi._state != Resi.State.BOLTING
	_check(left_alone and not resi._noticed, "with no player near, her bell lures nobody and she stays")
	enemy.set_physics_process(true)
	# A player walks out to her: from now on the bell pulls.
	player.global_position = resi.global_position + Vector3(0.0, 0.3, -Constants.RESI_NOTICE_RADIUS + 2.0)
	player.velocity = Vector3.ZERO
	var bolted: bool = false
	for i: int in 60 * 20:
		await get_tree().physics_frame
		if not is_instance_valid(resi) or resi._state == Resi.State.BOLTING:
			bolted = true
			break
	_check(start <= Constants.RESI_LURE_RADIUS and bolted, "her bell pulls an outside enemy (%.0f m off) to her, and she bolts" % start)
	_check(_banners.back() == "Die Resi is davon!", "announced: %s" % _banners.back())
	_check(get_tree().get_nodes_in_group("map_markers").is_empty(), "the marker goes with her")
	await _frames(2)
	_check(enemy._find_lure() == null, "the enemy is back after the players")
	enemy.receive_hit(100000, false, false, null)
	if is_instance_valid(resi):
		resi.queue_free()
	player.global_position = Vector3(-2.0, 0.0, 1.0)
	player.velocity = Vector3.ZERO
	await _seconds(0.5)


func _resi_milked() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(14.0)
	var speck: JauseData = load("res://data/jause/speck.tres")
	var germ: JauseData = load("res://data/jause/germknedl.tres")
	var kas: JauseData = load("res://data/jause/kasnockn.tres")
	var before: int = player.perks.jause_level(speck) + player.perks.jause_level(germ) + player.perks.jause_level(kas)
	player.health._health = 20.0
	var side: Vector3 = resi.global_basis.x
	player.global_position = resi.global_position + side * 1.1 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _frames(3)
	_check(resi.get_interact_prompt(player) == tr("UI_MILK"), "prompt: %s" % resi.get_interact_prompt(player))
	var pulls: int = 0
	while resi.is_milkable() and pulls < 40:
		player.global_position = resi.global_position + side * 1.1
		resi.interact(player)
		pulls += 1
		await _seconds(resi.interact_repeat)
	var after: int = player.perks.jause_level(speck) + player.perks.jause_level(germ) + player.perks.jause_level(kas)
	_check(resi._state == Resi.State.MILKED and pulls == roundi(Constants.RESI_MILK_TIME / resi.interact_repeat), "milked in %d pulls (%.1f s)" % [pulls, pulls * resi.interact_repeat])
	_check(player.health.current() == player.health.max_health and after == before + 1, "fully healed (%d) and a free helping (%d -> %d): %s" % [player.health.current(), before, after, _banners.back()])
	_check(resi.get_interact_prompt(player) == "", "only once")
	await _seconds(20.0)
	_check(not is_instance_valid(resi), "then she goes home")


func _resi_leaves() -> void:
	var resi: Resi = director.send_resi()
	await _seconds(2.0)
	resi._stay_left = 0.1
	var halfway: float = 0.0
	await _seconds(30.0)
	_check(not is_instance_valid(resi), "after %.0f s she leaves on her own" % Constants.RESI_STAY_TIME)
	# A milk pull that stops counts for nothing.
	resi = director.send_resi()
	await _seconds(14.0)
	resi.interact(player)
	halfway = resi._milk
	await _seconds(0.5)
	_check(halfway > 0.0 and resi._milk == 0.0, "letting go of E spills the milk")
	resi.queue_free()
