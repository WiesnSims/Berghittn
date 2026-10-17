extends Node
## Visual check of the map and the new guns. Needs a real window (not --headless):
##   godot res://tests/zone_tour.tscn -- <out_dir> [zones|guns|motion|aim]
## zones: opens every door and saves one view per zone, plus the wall-buys and a door mid-swing.
## guns: buys the Jagdflinte and the Stutzen and saves frames of firing and reloading each.
## motion: frames of the pistol standing, walking, sprinting, turning, jumping and landing.
## aim: the crosshair opening up under rapid fire, then the right-click modes: pistol down the sights,
## both barrels of the Jagdflinte, the Stutzen scope.
## m5: the enemy line-up, the Schnaps shrine, the Hüttentruhe closed and offering, the ammo crate,
## the boss bar, and the Repetierer firing, fanning and reloading.
## boeller: the Seilbahn wall-buys (Handböller, Alphorn from wave 10), the Handböller in hand, a shell
## into a crowd, the Doppelladung, the reload.
## fladen: the Kuhfladen wall-buy in the Schuppen, one placed in the doorway, a wanderer stepping in.
## glocke: the Kuhglocke wall-buy in the Stube, then one thrown onto the pasture, ringing, with
## wanderers gathering round it.
## knoedel: the Knödelwerfer in hand, a dumpling lobbed into a crowd (flight, burst, pile), the
## Knödeltris, the reload.
## pfanne: the Küche wall-buy, the pan swung into a wanderer (BONK!), and held up as a guard.
## rodel: the Rodelkanone in hand, a sled run through a line of wanderers on the pasture, the
## reload, then the Kehre banking round the Stube.
## harmonika: the Harmonika in hand, a polka making a ring of wanderers dance on the pasture (notes,
## JUCHHE!), the held Landler, the reload.
## brennkessel: the lance in hand, the flame poured into a crowd on the pasture (burning bodies),
## the stream stopping at the hut wall, the Brennlacke, the reload with the gauge climbing.
## goassl / mistgabel / rute: the melee weapon on V: a blow into wanderers on the pasture, then V held
## past the blow (the Goaßl's lash, the Mistgabel lifting and hurling, the Rute's Larve); for the
## Rute also the Krampus dropping it.
## alphorn: the horn in hand, a blast into a crowd on the pasture, the Echo, the reload, and the horn
## shown over the Hüttentruhe.

const VIEWS: Array = [
	["stube_hall", Vector3(5.5, 1.7, 4.5), Vector3(-9.0, 3.5, -4.0)],
	["stube_gallery", Vector3(-9.8, 5.2, 4.8), Vector3(4.0, 1.0, -3.0)],
	["stube_stairs", Vector3(3.5, 1.7, 0.5), Vector3(4.0, 1.4, -5.3)],
	["stube_wallbuy", Vector3(-0.8, 1.6, -3.4), Vector3(-0.8, 1.5, -6.0)],
	["erker", Vector3(3.0, 1.7, 3.5), Vector3(3.5, 1.2, 8.0)],
	["balcony", Vector3(-8.0, 5.2, 6.8), Vector3(0.0, -1.0, 16.0)],
	["kueche", Vector3(5.5, 1.8, -10.5), Vector3(-8.0, 0.8, -15.0)],
	["kuechenstiege", Vector3(-4.0, 1.7, -11.0), Vector3(4.0, 2.0, -7.3)],
	["lager_stairwell", Vector3(-4.0, 5.2, -10.0), Vector3(4.0, 3.0, -7.3)],
	["stairwell_up", Vector3(0.6, 1.9, -7.3), Vector3(6.0, 4.6, -8.0)],
	["stairwell_landing", Vector3(5.6, 5.2, -6.6), Vector3(6.0, 4.6, -9.5)],
	["lager_stair_door", Vector3(2.5, 5.2, -11.5), Vector3(6.0, 4.6, -8.5)],
	["stube_seilbahn", Vector3(-3.0, 1.7, 1.0), Vector3(7.2, 1.2, 3.6)],
	["aussenstiege", Vector3(-3.0, 1.4, 20.0), Vector3(-9.6, 2.0, 10.0)],
	["tor_ost", Vector3(-2.0, 1.4, 17.0), Vector3(7.1, 0.5, 21.8)],
	["lager", Vector3(5.5, 5.2, -7.0), Vector3(-9.0, 3.8, -14.0)],
	["skiraum", Vector3(8.5, 1.8, -2.5), Vector3(14.0, 0.8, -15.0)],
	["skiraum_wallbuy", Vector3(9.5, 1.6, -8.0), Vector3(7.3, 1.5, -8.0)],
	["bootroom", Vector3(19.4, 1.7, -2.3), Vector3(19.4, 1.0, -15.0)],
	["seilbahn", Vector3(8.5, 3.0, -0.3), Vector3(20.0, 1.5, 7.0)],
	["seilbahn_portal", Vector3(16.0, 2.4, 3.0), Vector3(21.45, 2.2, 6.1)],
	["seilbahn_portal_out", Vector3(28.0, 3.0, 2.0), Vector3(21.45, 3.0, 6.1)],
	["schuppen", Vector3(8.0, 1.8, 10.3), Vector3(20.0, 2.0, 17.0)],
	["schuppen_loft", Vector3(16.0, 5.2, 10.0), Vector3(9.0, 1.0, 18.0)],
	["terrasse", Vector3(-10.0, 1.7, 7.0), Vector3(6.0, -1.0, 17.0)],
	["terrasse_wallbuy", Vector3(-4.6, 1.6, 8.0), Vector3(-5.6, 1.5, 6.3)],
	["terrasse_garden", Vector3(5.5, 1.4, 23.0), Vector3(-8.0, 0.5, 12.0)],
	["outside", Vector3(-16.0, 9.0, 30.0), Vector3(6.0, 2.0, 2.0)],
	["alm_valley", Vector3(0.0, 1.7, 10.0), Vector3(0.0, -6.0, 70.0)],
	["alm_summit", Vector3(2.0, 1.7, -20.0), Vector3(2.0, 14.0, -80.0)],
	["alm_cable", Vector3(23.0, 1.7, 8.0), Vector3(60.0, 14.0, 4.0)],
	["alm_signpost", Vector3(-6.8, 1.7, 23.4), Vector3(-10.0, 1.7, 26.5)],
	["alm_aerial", Vector3(-45.0, 28.0, 55.0), Vector3(7.0, 0.0, 0.0)],
]

var _out_dir: String


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://tour"
	var mode: String = args[1] if args.size() > 1 else "zones"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(960, 540)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	get_tree().paused = false
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	if mode == "guns":
		await _guns(main)
	elif mode == "motion":
		await _motion(main)
	elif mode == "aim":
		await _aim(main)
	elif mode == "m5":
		await _m5(main)
	elif mode == "perks":
		await _perks_tour(main)
	elif mode == "resi":
		await _resi_tour(main)
	elif mode == "fassl":
		await _fassl_tour(main)
	elif mode == "murmel":
		await _murmel_tour(main)
	elif mode == "guest":
		await _guest_tour(main)
	elif mode == "alphorn":
		await _alphorn_tour(main)
	elif mode == "pfanne":
		await _pfanne_tour(main)
	elif mode == "knoedel":
		await _knoedel_tour(main)
	elif mode == "glocke":
		await _glocke_tour(main)
	elif mode == "fladen":
		await _fladen_tour(main)
	elif mode == "boeller":
		await _boeller_tour(main)
	elif mode == "rodel":
		await _rodel_tour(main)
	elif mode == "harmonika":
		await _harmonika_tour(main)
	elif mode == "brennkessel":
		await _brennkessel_tour(main)
	elif mode in ["goassl", "mistgabel", "rute"]:
		await _melee_tour(main, mode)
	else:
		await _zones(main)
	get_tree().quit()


func _zones(main: Node) -> void:
	(main.get_node("UI") as CanvasLayer).hide()
	var camera := Camera3D.new()
	camera.fov = 80.0
	add_child(camera)
	camera.current = true
	var zones := main.get_node("Zones") as ZoneMap
	var player := main.get_node("Player") as Player
	# A door mid-swing first, then everything open.
	camera.look_at_from_position(Vector3(-2.0, 1.7, -2.5), Vector3(-4.0, 1.1, -6.15))
	zones.unlock(&"kueche", player)
	for i: int in 12:
		await get_tree().process_frame
	await _save("door_swing")
	for id: StringName in [&"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	await get_tree().create_timer(1.0).timeout
	for view: Array in VIEWS:
		camera.look_at_from_position(view[1], view[2])
		for i: int in 3:
			await get_tree().process_frame
		await _save(view[0])


func _guns(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var weapons: WeaponHolder = player.weapons
	player.global_position = Vector3(-1.0, 0.0, 1.0)
	# Facing the lit fireplace wall, so the dark gun metal stands out.
	player.rotation.y = -PI * 0.5
	for path: String in ["res://data/weapons/jagdflinte.tres", "res://data/weapons/stutzen.tres"]:
		var data: WeaponData = load(path)
		if weapons.gun_count() == 2:
			weapons._select(0)
		weapons.give_weapon(data)
		await _save_series(data.id + "_draw", 3, 0.12)
		weapons._fire()
		await _save_series(data.id + "_fire", 8, 0.1)
		weapons.mag = 0
		weapons.start_reload()
		await _save_series(data.id + "_reload", 12, (data.reload_time + data.chamber_time) / 12.0)


func _motion(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	# Down the long axis of the Stube, towards the fireplace.
	player.global_position = Vector3(-5.5, 0.0, 0.0)
	player.rotation.y = -PI * 0.5
	await _save_series("idle", 2, 0.2)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.4).timeout
	await _save_series("walk", 6, 0.09)
	Input.action_press("sprint")
	await get_tree().create_timer(0.4).timeout
	await _save_series("sprint", 6, 0.07)
	_check_print("sprinting: %s" % player.is_sprinting())
	Input.action_release("sprint")
	Input.action_release("move_forward")
	player.global_position = Vector3(-5.5, 0.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	# A fast turn to the right, as if from the mouse.
	var motion := player.get_node("Head/Camera3D/WeaponHolder/Motion") as WeaponMotion
	motion._look_lag = Vector2(motion.look_lag_max, 0.0)
	await _save_series("turn", 3, 0.05)
	player.velocity.y = Constants.PLAYER_JUMP_VELOCITY
	await _save_series("jump", 10, 0.08)


func _aim(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var weapons: WeaponHolder = player.weapons
	# At the far end of the Stube, looking at the west windows.
	player.global_position = Vector3(5.0, 0.0, 1.0)
	player.rotation.y = PI * 0.5
	await get_tree().create_timer(0.3).timeout
	await _save("crosshair_00")
	for i: int in 4:
		weapons._fire()
		await get_tree().create_timer(0.12).timeout
	await _save_series("crosshair_bloom", 2, 0.15)
	await get_tree().create_timer(0.8).timeout
	weapons.force_aim = true
	await _save_series("pistol_aim", 4, 0.06)
	weapons._fire()
	await _save_series("pistol_aim_fire", 2, 0.05)
	weapons.force_aim = false
	await get_tree().create_timer(0.4).timeout
	weapons.give_weapon(load("res://data/weapons/jagdflinte.tres"))
	await get_tree().create_timer(0.6).timeout
	weapons.fire_all()
	await _save_series("shotgun_both", 4, 0.06)
	weapons._select(0)
	weapons.give_weapon(load("res://data/weapons/stutzen.tres"))
	await get_tree().create_timer(0.6).timeout
	weapons.force_aim = true
	await _save_series("stutzen_scope", 6, 0.06)
	await get_tree().create_timer(0.8).timeout
	await _save_series("stutzen_sway", 3, 0.6)


func _check_print(text: String) -> void:
	print(text)


func _save_series(prefix: String, count: int, interval: float) -> void:
	for i: int in count:
		await _save("%s_%02d" % [prefix, i])
		await get_tree().create_timer(interval).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))


## perks: the six-bottle shrine, the Brettljause, a Böllerschuss going off (from outside), and the
## HUD with every Schnaps while Sturschädl holds.
func _perks_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.0).timeout
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	camera.look_at_from_position(Vector3(-8.6, 1.6, -10.75), Vector3(-11.0, 1.3, -10.75))
	await _save("perks_shrine")
	var jause := main.find_child("Brettljause", true, false) as Node3D
	camera.look_at_from_position(jause.to_global(Vector3(0.3, 1.5, -1.9)), jause.to_global(Vector3(0, 0.8, -0.3)))
	await _save("perks_jause")
	player.points.add(50000)
	for node: Node in main.find_children("*", "", true, false):
		if node is PerkBottle:
			(node as PerkBottle).interact(player)
	player.global_position = Vector3(-12.0, -0.3, 22.0)
	await get_tree().create_timer(0.3).timeout
	camera.look_at_from_position(Vector3(-17.0, 2.5, 27.0), Vector3(-12.0, 0.3, 22.0))
	player.weapons.mag = 0
	player.weapons.start_reload()
	await _save_series("perks_boeller", 4, 0.15)
	camera.current = false
	(main.get_node("UI") as CanvasLayer).show()
	await get_tree().create_timer(2.0).timeout
	player.health._health = 5.0
	player.take_damage(100)
	await get_tree().create_timer(0.3).timeout
	await _save("perks_hud_sturschaedl")


## resi: die Resi close up in the beer garden (walking, grazing), her marker from inside the Stube, and
## the HUD edge arrow when she is behind the player.
func _resi_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.0).timeout
	var resi: Resi = (main.get_node("EventDirector") as EventDirector).send_resi()
	var camera := Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	await get_tree().create_timer(4.0).timeout
	camera.look_at_from_position(resi.to_global(Vector3(2.4, 1.6, -1.6)), resi.to_global(Vector3(0, 1.0, -0.2)))
	await _save("resi_walk")
	await get_tree().create_timer(12.0).timeout
	camera.look_at_from_position(resi.to_global(Vector3(-2.2, 1.3, -1.8)), resi.to_global(Vector3(0, 0.9, -0.3)))
	await _save("resi_graze")
	camera.look_at_from_position(Vector3(-2.0, 1.7, -2.0), Vector3(-1.0, 1.0, 12.0))
	await _save("resi_marker_inside")
	camera.current = false
	(main.get_node("UI") as CanvasLayer).show()
	player.global_position = Vector3(-2.0, 0.0, -1.0)
	player.rotation.y = 0.0
	await get_tree().create_timer(0.3).timeout
	await _save("resi_arrow")


## fassl: the Bierfassl rolling down the alm, coming in at the garden gate, resting, and being tapped.
func _fassl_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.0).timeout
	var fassl: Bierfassl = (main.get_node("EventDirector") as EventDirector).send_fassl()
	var camera := Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	await get_tree().create_timer(2.5).timeout
	camera.look_at_from_position(fassl.global_position + Vector3(4.0, 1.5, 4.0), fassl.global_position)
	await _save("fassl_slope")
	camera.look_at_from_position(Vector3(-12.0, 1.6, 14.0), Vector3(-17.0, 0.3, 17.0))
	while fassl.global_position.x < -18.5:
		await get_tree().physics_frame
	await _save("fassl_gate")
	while not fassl.is_resting():
		await get_tree().physics_frame
	camera.look_at_from_position(fassl.global_position + Vector3(-2.2, 1.3, 1.4), fassl.global_position)
	await _save("fassl_rest")
	player.global_position = fassl.global_position + Vector3(-1.2, -0.12, 0.0)
	while fassl.is_resting():
		fassl.interact(player)
		await get_tree().create_timer(fassl.interact_repeat).timeout
	await get_tree().create_timer(0.4).timeout
	await _save("fassl_foam")


## murmel: the Murmeltier rising out of its hole in the Stube and screaming, close up and from afar.
func _murmel_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.0).timeout
	var murmel := (load("res://scenes/events/murmeltier.tscn") as PackedScene).instantiate() as Murmeltier
	main.get_node("World").add_child(murmel)
	murmel.start(Vector3(-4.0, 0.0, 2.5), Vector3(-4.0, 0.0, 0.0))
	murmel._pops_left = 99
	var camera := Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	camera.look_at_from_position(Vector3(-3.2, 0.6, 1.0), Vector3(-4.0, 0.35, 2.5))
	await get_tree().create_timer(0.12).timeout
	await _save("murmel_rise")
	await get_tree().create_timer(0.5).timeout
	await _save("murmel_scream")
	camera.fov = 70.0
	camera.look_at_from_position(Vector3(2.0, 1.7, -3.0), Vector3(-4.0, 0.4, 2.5))
	await _save("murmel_far")


## guest: the Deitscha Tourist at the gondola, close up and from behind with his marker, then an
## Eisstock sliding across the beer garden with the HUD showing the slot.
func _guest_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(1.0).timeout
	var guest: TouristGuest = (main.get_node("EventDirector") as EventDirector).send_guest()
	var camera := Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	await get_tree().create_timer(1.0).timeout
	camera.look_at_from_position(guest.to_global(Vector3(0.9, 1.7, -2.4)), guest.to_global(Vector3(0, 1.3, 0)))
	await _save("guest_close")
	camera.look_at_from_position(Vector3(6.0, 2.2, -4.0), guest.global_position + Vector3.UP)
	await _save("guest_station")
	# The Eisstock.
	camera.current = false
	(main.get_node("UI") as CanvasLayer).show()
	player.equipment.give(load("res://data/equipment/eisstock.tres"), 2)
	player.global_position = Vector3(-12.0, -0.3, 14.0)
	player.rotation.y = -PI * 0.5
	await get_tree().create_timer(0.4).timeout
	player.equipment.throw()
	await get_tree().create_timer(0.35).timeout
	await _save("eisstock_slide")


func _m5(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	var waves := main.get_node("WaveManager") as WaveManager
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	await get_tree().create_timer(1.0).timeout
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	# Line-up on the pasture, frozen in place.
	var x: float = -16.0
	for id: String in ["wanderer", "tourist", "knappe", "perchte", "krampus"]:
		var enemy: Enemy = waves._create_enemy()
		enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis.IDENTITY, Vector3(x, -0.3, 24.0)).looking_at(Vector3(x, -0.3, 30.0), Vector3.UP))
		enemy.set_physics_process(false)
		x += 1.8
	camera.look_at_from_position(Vector3(-12.4, 1.4, 28.6), Vector3(-12.4, 1.0, 24.0))
	await get_tree().create_timer(0.3).timeout
	await _save("m5_enemies")
	camera.look_at_from_position(Vector3(-13.4, 1.8, 26.0), Vector3(-9.2, 1.4, 24.0))
	await _save("m5_krampus")
	camera.look_at_from_position(Vector3(-8.3, 1.6, -10.75), Vector3(-11.0, 1.3, -10.75))
	await _save("m5_shrine")
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	camera.look_at_from_position(chest.to_global(Vector3(0.6, 1.6, -2.6)), chest.to_global(Vector3(0, 0.5, -0.4)))
	await _save("m5_chest")
	player.points.add(5000)
	chest.interact(player)
	await get_tree().create_timer(0.8).timeout
	await _save("m5_chest_roll")
	await get_tree().create_timer(chest.pool.roll_time).timeout
	await _save("m5_chest_offer")
	var crate := main.find_children("*", "AmmoCrate", true, false)[0] as AmmoCrate
	camera.look_at_from_position(crate.to_global(Vector3(0.5, 1.6, -2.2)), crate.to_global(Vector3(0, 0.4, -0.4)))
	await _save("m5_crate")
	# In-hand Repetierer.
	camera.current = false
	(main.get_node("UI") as CanvasLayer).show()
	player.global_position = Vector3(-1.0, 0.0, 1.0)
	player.rotation.y = -PI * 0.5
	var weapons: WeaponHolder = player.weapons
	weapons.give_weapon(load("res://data/weapons/repetierer.tres"))
	await get_tree().create_timer(0.6).timeout
	await _save("m5_rep_idle")
	weapons._fire()
	await _save_series("m5_rep_fire", 4, 0.05)
	await get_tree().create_timer(0.4).timeout
	weapons.force_aim = true
	await get_tree().create_timer(0.1).timeout
	await _save("m5_rep_fan")
	weapons.force_aim = false
	await get_tree().create_timer(0.4).timeout
	weapons.mag = 0
	weapons.start_reload()
	await _save_series("m5_rep_reload", 8, (weapons.weapon.reload_time + weapons.weapon.chamber_time) / 8.0)


func _alphorn_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	var waves := main.get_node("WaveManager") as WaveManager
	for id: StringName in [&"kueche", &"lager", &"terrasse", &"skiraum", &"seilbahn", &"schuppen"]:
		zones.unlock(id, player)
	var horn: WeaponData = load("res://data/weapons/alphorn.tres")
	var weapons: WeaponHolder = player.weapons
	player.global_position = Vector3(-1.0, 0.0, 1.0)
	player.rotation.y = -PI * 0.5
	weapons.give_weapon(horn)
	await get_tree().create_timer(0.6).timeout
	await _save("alphorn_idle")
	weapons.mag = 0
	weapons.start_reload()
	await _save_series("alphorn_reload", 8, horn.reload_time / 8.0)
	# Out on the pasture with a crowd in front.
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var crowd: Array[Enemy] = []
	for i: int in 9:
		var enemy: Enemy = waves._create_enemy()
		var spot := Vector3(14.0 + (i % 3) * 2.5, -0.3, 29.5 + (i / 3) * 1.5)
		enemy.activate(load("res://data/enemies/knappe.tres" if i == 4 else "res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(Vector3(10.0, -0.3, 31.0), Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		crowd.append(enemy)
	await get_tree().create_timer(0.8).timeout
	await _save("alphorn_crowd")
	weapons.mag = 6
	weapons._cooldown = 0.0
	weapons._fire()
	await _save_series("alphorn_blast", 10, 0.06)
	await get_tree().create_timer(2.5).timeout
	# Surrounded: the Echo.
	for i: int in crowd.size():
		var angle: float = TAU * i / crowd.size()
		if crowd[i].is_alive():
			crowd[i].global_position = Vector3(10.0 + cos(angle) * 3.5, -0.3, 31.0 + sin(angle) * 3.5)
	await get_tree().create_timer(0.1).timeout
	await _save("alphorn_surrounded")
	weapons._cooldown = 0.0
	weapons.fire_secondary()
	await _save_series("alphorn_echo", 10, 0.06)
	for enemy: Enemy in crowd:
		if enemy.is_alive():
			enemy.receive_hit(100000, false, false, null)
	# Over the chest, offered.
	var chest := main.find_children("*", "Huettentruhe", true, false)[0] as Huettentruhe
	var camera := Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	(main.get_node("UI") as CanvasLayer).hide()
	camera.look_at_from_position(chest.to_global(Vector3(0.6, 1.6, -2.6)), chest.to_global(Vector3(0, 0.5, -0.4)))
	chest.pool.entries = chest.pool.entries.filter(func(e: ChestEntry) -> bool: return e.weapon == horn)
	player.points.add(5000)
	weapons._slots.clear()
	weapons._current = -1
	weapons.weapon = null
	chest.interact(player)
	await get_tree().create_timer(chest.pool.roll_time + 0.5).timeout
	await _save("alphorn_chest")


func _pfanne_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var zones := main.get_node("Zones") as ZoneMap
	var waves := main.get_node("WaveManager") as WaveManager
	zones.unlock(&"kueche", player)
	var pan: WeaponData = load("res://data/weapons/schmarrnpfanne.tres")
	var buy: WallBuy = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.weapon == pan)[0]
	player.global_position = buy.to_global(Vector3(0.6, -1.5, -2.2))
	player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	await _save("pfanne_wallbuy")
	player.weapons.give_weapon(pan)
	# A wanderer on the pasture to bonk.
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(load("res://data/enemies/wanderer.tres"), 10, Transform3D(Basis.IDENTITY, Vector3(11.5, -0.3, 31.0)).looking_at(Vector3(10.0, -0.3, 31.0), Vector3.UP))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.set_physics_process(false)
	await get_tree().create_timer(0.3).timeout
	player.weapons._start_melee()
	await _save_series("pfanne_swing", 8, 0.06)
	await get_tree().create_timer(1.0).timeout
	enemy.set_physics_process(true)
	player.weapons.force_melee_hold = true
	player.weapons._start_melee()
	await get_tree().create_timer(0.5).timeout
	await _save("pfanne_guard")
	await get_tree().create_timer(1.2).timeout
	await _save_series("pfanne_guard_hit", 6, 0.15)
	player.weapons.force_melee_hold = false


func _knoedel_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var gun: WeaponData = load("res://data/weapons/knoedelwerfer.tres")
	var weapons: WeaponHolder = player.weapons
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(1.0)
	weapons.give_weapon(gun)
	for i: int in 7:
		var enemy: Enemy = waves._create_enemy()
		var spot := Vector3(17.0 + (i % 3) * 1.4, -0.3, 29.8 + (i / 3) * 1.3)
		enemy.activate(load("res://data/enemies/knappe.tres" if i == 3 else "res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(Vector3(10.0, -0.3, 31.0), Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().create_timer(0.3).timeout
	await _save("knoedel_idle")
	weapons._cooldown = 0.0
	weapons._fire()
	await _save_series("knoedel_shot", 12, 0.07)
	await get_tree().create_timer(1.0).timeout
	await _save("knoedel_pile")
	weapons._cooldown = 0.0
	weapons.fire_secondary()
	await _save_series("knoedel_trio", 8, 0.08)
	await get_tree().create_timer(1.0).timeout
	weapons.mag = 0
	weapons.start_reload()
	await _save_series("knoedel_reload", 8, gun.reload_time / 8.0)


func _glocke_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var glocke: EquipmentData = load("res://data/equipment/kuhglocke.tres")
	var buy: WallBuy = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.equipment == glocke)[0]
	player.global_position = buy.to_global(Vector3(-0.5, -1.5, -2.4))
	player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
	player.points.add(1000)
	await get_tree().create_timer(1.0).timeout
	await _save("glocke_wallbuy")
	buy.interact(player)
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-8.0)
	for i: int in 6:
		var enemy: Enemy = waves._create_enemy()
		var spot := Vector3(12.0 + (i % 3) * 3.0, -0.3, 25.0 + (i / 3) * 12.0)
		enemy.activate(load("res://data/enemies/wanderer.tres"), 3, Transform3D(Basis.IDENTITY, spot))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().create_timer(0.3).timeout
	await _save("glocke_hud")
	player.equipment.throw()
	await _save_series("glocke_throw", 6, 0.12)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-12.0)
	await get_tree().create_timer(2.5).timeout
	await _save_series("glocke_ring", 4, 0.5)


func _fladen_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var zones := main.get_node("Zones") as ZoneMap
	zones.unlock(&"terrasse", player)
	zones.unlock(&"schuppen", player)
	var fladen: EquipmentData = load("res://data/equipment/kuhfladen.tres")
	var buy: WallBuy = main.find_children("*", "WallBuy", true, false).filter(func(w: WallBuy) -> bool: return w.equipment == fladen)[0]
	player.global_position = buy.to_global(Vector3(0.5, -1.5, -2.4))
	player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
	player.points.add(1000)
	await get_tree().create_timer(1.0).timeout
	await _save("fladen_wallbuy")
	buy.interact(player)
	player.global_position = Vector3(8.6, 0.0, 10.3)
	player.look_at(Vector3(7.0, 0.0, 10.3), Vector3.UP)
	await get_tree().create_timer(0.2).timeout
	player.equipment.throw()
	player.global_position = Vector3(11.5, 0.0, 11.0)
	player.look_at(Vector3(7.0, 0.0, 10.3), Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-15.0)
	await get_tree().create_timer(0.5).timeout
	await _save("fladen_placed")
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(load("res://data/enemies/wanderer.tres"), 3, Transform3D(Basis.IDENTITY, Vector3(4.5, 0.0, 10.3)))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	await get_tree().create_timer(0.9).timeout
	await _save_series("fladen_step", 6, 0.12)


func _boeller_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var zones := main.get_node("Zones") as ZoneMap
	for id: StringName in [&"skiraum", &"seilbahn"]:
		zones.unlock(id, player)
	var gun: WeaponData = load("res://data/weapons/handboeller.tres")
	var horn: WeaponData = load("res://data/weapons/alphorn.tres")
	var buys: Array = main.find_children("*", "WallBuy", true, false)
	var boeller_buy: WallBuy = buys.filter(func(w: WallBuy) -> bool: return w.weapon == gun)[0]
	var horn_buy: WallBuy = buys.filter(func(w: WallBuy) -> bool: return w.weapon == horn)[0]
	Events.wave_started.emit(10, false)
	for buy: WallBuy in [boeller_buy, horn_buy]:
		player.global_position = buy.to_global(Vector3(0.4, -1.5, -2.6))
		player.look_at(Vector3(buy.global_position.x, player.global_position.y, buy.global_position.z), Vector3.UP)
		await get_tree().create_timer(0.8).timeout
		await _save("boeller_wallbuy_" + buy.weapon.id)
	var weapons: WeaponHolder = player.weapons
	weapons.give_weapon(gun)
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(2.0)
	for i: int in 6:
		var enemy: Enemy = waves._create_enemy()
		var spot := Vector3(18.0 + (i % 3) * 1.4, -0.3, 30.0 + (i / 3) * 1.4)
		enemy.activate(load("res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(Vector3(10.0, -0.3, 31.0), Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout
	await _save("boeller_idle")
	weapons._fire()
	await _save_series("boeller_shot", 12, 0.07)
	weapons.start_reload()
	await _save_series("boeller_reload", 10, gun.reload_time / 10.0)
	await get_tree().create_timer(0.5).timeout
	weapons._cooldown = 0.0
	weapons.fire_secondary()
	await _save_series("boeller_double", 10, 0.08)


func _rodel_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var gun: WeaponData = load("res://data/weapons/rodelkanone.tres")
	var weapons: WeaponHolder = player.weapons
	var stube: Vector3 = player.global_position
	weapons.give_weapon(gun)
	player.global_position = Vector3(10.0, -0.3, 31.0)
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-6.0)
	for i: int in 5:
		var enemy: Enemy = waves._create_enemy()
		var spot := Vector3(14.0 + i * 2.2, -0.3, 31.0 + (0.4 if i % 2 == 0 else -0.4))
		enemy.activate(load("res://data/enemies/knappe.tres" if i == 2 else "res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(Vector3(10.0, -0.3, 31.0), Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout
	await _save("rodel_idle")
	weapons._fire()
	await _save_series("rodel_shot", 14, 0.07)
	await get_tree().create_timer(1.5).timeout
	# Aimed high: it flies in an arc and rides on from where it comes down.
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(20.0)
	weapons._cooldown = 0.0
	weapons._fire()
	await _save_series("rodel_arc", 12, 0.08)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-6.0)
	await get_tree().create_timer(1.0).timeout
	weapons.mag = 0
	weapons.start_reload()
	await _save_series("rodel_reload", 8, gun.reload_time / 8.0)
	await get_tree().create_timer(0.5).timeout
	# Indoors: the Kehre sent at a slant across the Stube, to bank round the hall.
	player.global_position = Vector3(5.5, stube.y, 4.5)
	player.look_at(Vector3(-9.0, stube.y, -4.0), Vector3.UP)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-10.0)
	await get_tree().create_timer(0.5).timeout
	weapons._cooldown = 0.0
	weapons.fire_secondary()
	await _save_series("rodel_kehre", 16, 0.1)


func _harmonika_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var gun: WeaponData = load("res://data/weapons/harmonika.tres")
	var weapons: WeaponHolder = player.weapons
	weapons.give_weapon(gun)
	var center := Vector3(10.0, -0.3, 31.0)
	player.global_position = center
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-8.0)
	# A ring of wanderers in front and to the sides, walking in.
	for i: int in 7:
		var enemy: Enemy = waves._create_enemy()
		var angle: float = deg_to_rad(-60.0 + i * 20.0)
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * (4.0 + (i % 3) * 1.3)
		enemy.activate(load("res://data/enemies/knappe.tres" if i == 3 else "res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(center, Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.health = 100000
	await get_tree().create_timer(0.6).timeout
	await _save("harmonika_idle")
	weapons._fire()
	await _save_series("harmonika_polka", 16, 0.15)
	await get_tree().create_timer(2.0).timeout
	weapons.force_aim = true
	await _save_series("harmonika_landler", 10, 0.2)
	weapons.force_aim = false
	await get_tree().create_timer(1.6).timeout
	weapons.mag = 0
	weapons.start_reload()
	await _save_series("harmonika_reload", 8, gun.reload_time / 8.0)


func _brennkessel_tour(main: Node) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var gun: WeaponData = load("res://data/weapons/brennkessel.tres")
	var weapons: WeaponHolder = player.weapons
	weapons.give_weapon(gun)
	var center := Vector3(10.0, -0.3, 31.0)
	player.global_position = center
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-4.0)
	for i: int in 5:
		var enemy: Enemy = waves._create_enemy()
		var spot := center + Vector3(3.5 + i * 1.1, 0.0, -0.8 + (i % 3) * 0.8)
		enemy.activate(load("res://data/enemies/knappe.tres" if i == 2 else "res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(center, Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.set_physics_process(true)
		enemy.health = 100000
		enemy.data = enemy.data.duplicate()
		enemy.data.speed = 0.3
	await get_tree().create_timer(0.6).timeout
	await _save("brennkessel_idle")
	# Held down for two seconds, a frame every quarter second.
	for i: int in 8:
		for t: int in 2:
			weapons._cooldown = 0.0
			weapons._fire()
			await get_tree().create_timer(0.125).timeout
		await _save("brennkessel_flame_%02d" % i)
	await _save_series("brennkessel_burning", 4, 0.4)
	# The stream against the hut wall, from the deck.
	player.global_position = Vector3(-3.8, 0.0, 9.0)
	player.rotation.y = 0.0
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-5.0)
	await get_tree().create_timer(0.4).timeout
	for i: int in 6:
		weapons._cooldown = 0.0
		weapons._fire()
		await get_tree().create_timer(0.125).timeout
	await _save("brennkessel_wall")
	await get_tree().create_timer(0.5).timeout
	# The Brennlacke onto the pasture.
	player.global_position = center
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-12.0)
	await get_tree().create_timer(0.4).timeout
	weapons._cooldown = 0.0
	weapons.fire_secondary()
	await _save_series("brennkessel_lacke", 10, 0.15)
	weapons.mag = 30
	weapons.start_reload()
	await _save_series("brennkessel_reload", 8, gun.reload_time / 8.0)


func _melee_tour(main: Node, mode: String) -> void:
	(main.get_node("UI/StartScreen") as Control).hide()
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	var player := main.get_node("Player") as Player
	var waves := main.get_node("WaveManager") as WaveManager
	var id: String = "krampusrute" if mode == "rute" else mode
	var weapon: WeaponData = load("res://data/weapons/%s.tres" % id)
	var weapons: WeaponHolder = player.weapons
	var center := Vector3(10.0, -0.3, 31.0)
	player.global_position = center
	player.rotation.y = -PI * 0.5
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-12.0)
	if mode == "rute":
		# The Krampus falls and leaves his Rute on the pasture.
		var krampus: Enemy = waves._create_enemy()
		krampus.activate(load("res://data/enemies/krampus.tres"), 5, Transform3D(Basis.IDENTITY, center + Vector3(3.0, 0.0, 0.0)).looking_at(center, Vector3.UP))
		krampus.process_mode = Node.PROCESS_MODE_PAUSABLE
		await get_tree().create_timer(0.4).timeout
		krampus.receive_hit(1000000, false, false, player)
		await get_tree().create_timer(1.5).timeout
		await _save("rute_dropped")
		for pickup: WeaponPickup in main.find_children("*", "WeaponPickup", true, false):
			pickup.interact(player)
		await get_tree().create_timer(Constants.ENEMY_CORPSE_TIME).timeout
	else:
		weapons.give_weapon(weapon)
	(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(-6.0)
	var crowd: Array[Enemy] = []
	for i: int in 5:
		var enemy: Enemy = waves._create_enemy()
		var spot := center + Vector3(1.6 + (i % 2) * 0.9, 0.0, -1.0 + i * 0.5)
		if i == 4:
			spot = center + Vector3(5.5, 0.0, 0.0)
		enemy.activate(load("res://data/enemies/wanderer.tres"), 12, Transform3D(Basis.IDENTITY, spot).looking_at(center, Vector3.UP))
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		enemy.health = 100000
		enemy.data = enemy.data.duplicate()
		enemy.data.speed = 0.6
		crowd.append(enemy)
	await get_tree().create_timer(0.5).timeout
	weapons._start_melee()
	await _save_series("%s_blow" % mode, 10, 0.07)
	await get_tree().create_timer(1.2).timeout
	if mode == "mistgabel":
		# One straight in front to lift, and the view tipped up to see it on the fork.
		crowd[0].global_position = center + Vector3(1.4, 0.0, 0.0)
		(player.get_node("Head") as Node3D).rotation.x = deg_to_rad(18.0)
		await get_tree().create_timer(0.1).timeout
	weapons.force_melee_hold = true
	weapons._start_melee()
	await _save_series("%s_hold" % mode, 12, 0.15)
	weapons.force_melee_hold = false
	await _save_series("%s_release" % mode, 8, 0.12)
