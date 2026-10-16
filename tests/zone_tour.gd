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

const VIEWS: Array = [
	["stube_hall", Vector3(5.5, 1.7, 4.5), Vector3(-9.0, 3.5, -4.0)],
	["stube_gallery", Vector3(-9.8, 5.2, 4.8), Vector3(4.0, 1.0, -3.0)],
	["stube_stairs", Vector3(3.5, 1.7, 0.5), Vector3(4.0, 1.4, -5.3)],
	["stube_wallbuy", Vector3(-0.8, 1.6, -3.4), Vector3(-0.8, 1.5, -6.0)],
	["erker", Vector3(3.0, 1.7, 3.5), Vector3(3.5, 1.2, 8.0)],
	["balcony", Vector3(-8.0, 5.2, 6.8), Vector3(0.0, -1.0, 16.0)],
	["kueche", Vector3(5.5, 1.8, -7.0), Vector3(-8.0, 0.8, -15.0)],
	["lager", Vector3(5.5, 5.2, -7.0), Vector3(-9.0, 3.8, -14.0)],
	["skiraum", Vector3(8.5, 1.8, -2.5), Vector3(14.0, 0.8, -15.0)],
	["skiraum_wallbuy", Vector3(9.5, 1.6, -8.0), Vector3(7.3, 1.5, -8.0)],
	["bootroom", Vector3(19.4, 1.7, -2.3), Vector3(19.4, 1.0, -15.0)],
	["seilbahn", Vector3(8.5, 3.0, -0.3), Vector3(20.0, 1.5, 7.0)],
	["schuppen", Vector3(8.0, 1.8, 10.3), Vector3(20.0, 2.0, 17.0)],
	["schuppen_loft", Vector3(16.0, 5.2, 10.0), Vector3(9.0, 1.0, 18.0)],
	["terrasse", Vector3(-10.0, 1.7, 7.0), Vector3(6.0, -1.0, 17.0)],
	["terrasse_garden", Vector3(5.5, 0.2, 17.5), Vector3(-6.0, 0.5, 8.0)],
	["outside", Vector3(-16.0, 9.0, 30.0), Vector3(6.0, 2.0, 2.0)],
	["alm_valley", Vector3(0.0, 1.7, 10.0), Vector3(0.0, -6.0, 70.0)],
	["alm_summit", Vector3(2.0, 1.7, -20.0), Vector3(2.0, 14.0, -80.0)],
	["alm_cable", Vector3(23.0, 1.7, 8.0), Vector3(60.0, 14.0, 4.0)],
	["alm_signpost", Vector3(-6.8, 1.7, 16.4), Vector3(-10.0, 1.7, 19.5)],
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
