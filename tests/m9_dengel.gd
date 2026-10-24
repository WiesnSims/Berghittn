extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_dengel.tscn
## Headless check of da Dengelstock (M9 part 4a) on the real main scene: the dengelt weapons follow
## their base by the rules of tools/weapons/dengel.py; the forge is cold until wave 5, then open; the
## gun in hand goes on the anvil for 5000 and the hands hold only the melee weapon for 10 s; it waits
## 30 s, forged, with full ammo, double damage (bosses x1.5) and the forged look; a wall-buy refills
## its own reserve; doppelt dengelt for 10000, then no more; not taken in time it is gone (and with no
## gun left, the pistol comes back); the shovel at the grindstone comes back as the
## Schneefräsn-Schaufl, whose blow leaves the survivor dazed; the Dienstpistole doppelt dengelt is
## the Golden Gun, all gold, killing whatever it hits (bosses too).

const BASES: Array[String] = ["pistole", "jagdflinte", "stutzen", "repetierer", "schaufel"]
const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var weapons: WeaponHolder
var waves: WaveManager
var stock: Dengelstock
var failures: Array[String] = []
var announced: Array[String] = []


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


func _weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	weapons = player.weapons
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	Events.event_announced.connect(func(text: String) -> void: announced.append(text))
	_check_data()
	stock = get_tree().get_first_node_in_group("dengelstocks") as Dengelstock
	_check(stock != null, "the Dengelstock is in the world")
	if stock == null:
		_finish()
		return
	var forward: Vector3 = -stock.global_basis.z
	_check(stock.global_position.y > 3.4 and forward.x < -0.9, "it stands in the hay loft, facing the Schuppen (forward %s)" % forward)
	_check(Sound.has(&"anvil_clang") and Sound.has(&"dengel_quench"), "the anvil rings and the forged weapon hisses")
	await _at_the_anvil()
	await _cold_then_open()
	await _dengel_the_stutzen()
	await _shoot_with_it()
	await _doppelt()
	await _not_taken()
	await _the_schaufel()
	await _golden_gun()
	_finish()


func _finish() -> void:
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check_data() -> void:
	for id: String in BASES:
		var base: WeaponData = _weapon(id)
		var one: WeaponData = base.upgrade
		var two: WeaponData = one.upgrade if one else null
		if one == null or two == null:
			_check(false, "%s has both upgrades" % id)
			continue
		var ok: bool = one.level == 1 and two.level == 2 and two.upgrade == null and one.family_id() == base.id \
				and two.family_id() == base.id and base.family_id() == base.id
		ok = ok and one.damage == base.damage * 2 and two.damage == base.damage * 4
		ok = ok and is_equal_approx(one.damage * one.boss_multiplier, base.damage * 1.5) and is_equal_approx(two.damage * two.boss_multiplier, base.damage * 2.25)
		ok = ok and one.mag_size == ceili(base.mag_size * 1.5) and two.mag_size == base.mag_size * 2
		ok = ok and one.reserve_ammo == base.reserve_ammo * 2 and two.reserve_ammo == base.reserve_ammo * 4
		ok = ok and one.sound_pitch < 1.0 and two.sound_pitch < one.sound_pitch
		for i: int in base.ricochet_damage.size():
			ok = ok and one.ricochet_damage[i] == base.ricochet_damage[i] * 2 and two.ricochet_damage[i] == base.ricochet_damage[i] * 4
		var named: bool = tr(one.display_name) != one.display_name and tr(two.display_name) != two.display_name
		_check(ok and named, "%s: %s (%d dmg, %d mag, %d reserve), %s (%d, %d, %d)" % [id, tr(one.display_name), one.damage,
				one.mag_size, one.reserve_ammo, tr(two.display_name), two.damage, two.mag_size, two.reserve_ammo])
	var shovel: WeaponData = _weapon("schaufel")
	_check(shovel.stun_time == 0.0 and shovel.upgrade.stun_time > 0.0 and is_equal_approx(shovel.upgrade.upgrade.stun_time, shovel.upgrade.stun_time * 2.0),
			"the Schaufl's twist: dazed for %.1f s, doppelt %.1f s" % [shovel.upgrade.stun_time, shovel.upgrade.upgrade.stun_time])
	# The special weapons get theirs in part 4b.
	for id: String in ["alphorn", "knoedelwerfer", "goassl", "mistgabel"]:
		_check(_weapon(id).upgrade == null, "%s waits for part 4b" % id)


func _at_the_anvil() -> void:
	var spot: Vector3 = stock.get_interact_position()
	player.global_position = Vector3(spot.x, stock.global_position.y + 0.05, spot.z)
	player.velocity = Vector3.ZERO
	_look_at(spot)
	await _frames(10)


func _look_at(point: Vector3) -> void:
	var flat := Vector3(point.x, player.global_position.y, point.z)
	if flat.distance_to(player.global_position) > 0.05:
		player.look_at(flat, Vector3.UP)
	var head := player.get_node("Head") as Node3D
	var d: Vector3 = point - head.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _cold_then_open() -> void:
	_check(stock.state == Dengelstock.State.COLD and player.interactor._prompt == tr("UI_DENGEL_COLD") % Constants.DENGEL_WAVE,
			"cold before wave %d: \"%s\"" % [Constants.DENGEL_WAVE, player.interactor._prompt])
	Events.wave_started.emit(Constants.DENGEL_WAVE - 1, false)
	await _frames(2)
	_check(stock.state == Dengelstock.State.COLD, "still cold in wave %d" % (Constants.DENGEL_WAVE - 1))
	Events.wave_started.emit(Constants.DENGEL_WAVE, false)
	await _frames(2)
	_check(stock.state == Dengelstock.State.COLD, "lit a moment into the wave, after its banner")
	await _seconds(Constants.DENGEL_OPEN_DELAY + 0.1)
	_check(stock.state == Dengelstock.State.OPEN and announced.has(tr("EVENT_DENGEL_OPEN")) and is_instance_valid(stock._marker),
			"open from wave %d, with the banner and the light column" % Constants.DENGEL_WAVE)
	Events.wave_cleared.emit(Constants.DENGEL_WAVE)
	await _frames(2)
	_check(not is_instance_valid(stock._marker) and stock.state == Dengelstock.State.OPEN, "the light column goes with the wave, the forge stays lit")


func _dengel_the_stutzen() -> void:
	var stutzen: WeaponData = _weapon("stutzen")
	weapons.give_weapon(stutzen)
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	# Two kills with it before (for the death screen).
	for i: int in 2:
		Events.enemy_killed.emit(null, false, false, player)
	player.points.add(30000)
	var before: int = player.points.total
	await _frames(2)
	_check(player.interactor._target == stock and player.interactor._prompt == tr("UI_DENGEL") % [tr("WEAPON_STUTZEN"), Constants.DENGEL_COST[0]],
			"at the anvil: \"%s\"" % player.interactor._prompt)
	player.interactor._use()
	await _frames(2)
	_check(player.points.total == before - Constants.DENGEL_COST[0], "it cost %d" % Constants.DENGEL_COST[0])
	_check(stock.state == Dengelstock.State.FORGING and weapons.weapon == null and weapons.gun_count() == 1 and not weapons.has_weapon(stutzen),
			"the Stutzen is on the anvil; nothing in hand")
	_check(stock._on_anvil.get_child_count() == 1, "it lies on the anvil")
	_check(player.interactor._prompt == tr("UI_DENGEL_WORKING"), "\"%s\"" % player.interactor._prompt)
	# The shovel still works meanwhile.
	weapons._start_melee()
	_check(weapons._melee_left > 0.0, "the melee weapon still swings")
	await _seconds(Constants.DENGEL_TIME * 0.5)
	_check(weapons.weapon == null and stock.state == Dengelstock.State.FORGING, "after %d s still only the melee weapon in hand" % roundi(Constants.DENGEL_TIME * 0.5))
	await _seconds(Constants.DENGEL_TIME * 0.5 + 0.1)
	_check(weapons.weapon != null and weapons.weapon.id == &"pistole", "after %d s the pistol is back in hand" % roundi(Constants.DENGEL_TIME))
	_check(stock.state == Dengelstock.State.READY and stock.result.id == &"stutzen_dengelt" and stock._display.get_child_count() == 1,
			"the Kaiserjäger-Stutzen floats over the anvil")
	await _frames(2)
	_check(player.interactor._prompt == tr("UI_CHEST_TAKE") % tr("WEAPON_STUTZEN_1"), "\"%s\"" % player.interactor._prompt)
	player.interactor._use()
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	var gun: WeaponData = weapons.weapon
	_check(gun.id == &"stutzen_dengelt" and weapons.mag == gun.loaded_capacity(true) and weapons.reserve == gun.reserve_ammo and stock.state == Dengelstock.State.OPEN,
			"taken back: %s, %d + %d rounds" % [tr(gun.display_name), weapons.mag, weapons.reserve])
	var gold: bool = false
	for mesh: Node in weapons._viewmodel.find_children("*", "MeshInstance3D", true, false):
		var material := (mesh as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		gold = gold or (material and material.albedo_color.is_equal_approx(Constants.FORGED_GOLD[0]) and material.albedo_texture == ForgedLook.ENGRAVED)
	_check(gold, "it has the forged look (dark gold, engraved)")
	# One gun of its kind: the wall-buy and the chest count it for the Stutzen.
	_check(weapons.has_weapon(stutzen) and weapons.gun_count() == 2, "it counts as the Stutzen for the wall-buy and the chest")
	weapons.reserve = 3
	_check(weapons.needs_ammo(stutzen), "its wall-buy sells it ammo")
	weapons.refill_ammo(stutzen)
	_check(weapons.reserve == gun.reserve_ammo, "the wall-buy fills its own reserve (%d)" % weapons.reserve)
	Events.enemy_killed.emit(null, false, false, player)
	_check(player.stats.favourite() == gun and player.stats.kills_with(gun) == 3, "the death screen counts its kills with the Stutzen's, under its new name")


func _spawn(id: String, offset: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var at: Vector3 = FIELD + offset
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	at = hit.position if not hit.is_empty() else at
	enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.data = enemy.data.duplicate()
	enemy.data.speed = 0.0
	enemy.global_position = at
	enemy.health = 100000
	enemy.max_health = 100000
	return enemy


func _shoot_with_it() -> void:
	var gun: WeaponData = weapons.weapon
	player.global_position = FIELD
	# Down the scope, so the shot goes where it is aimed.
	weapons.force_aim = true
	await _seconds(gun.aim_time + 0.1)
	for id: String in ["wanderer", "krampus"]:
		var enemy: Enemy = _spawn(id, Vector3(0, 0, -6))
		await _frames(3)
		_look_at(enemy.global_position + Vector3.UP * 1.0)
		await _frames(1)
		var before: int = enemy.health
		weapons._cooldown = 0.0
		weapons._fire()
		await _frames(1)
		var dealt: int = before - enemy.health
		var expected: int = roundi(gun.damage * (gun.boss_multiplier if enemy.data.is_boss else 1.0))
		_check(dealt == expected, "a body shot on the %s: %d (the Stutzen does %d)" % [id, dealt, _weapon("stutzen").damage])
		enemy._take_hit(10000000, false, false, null)
		await _seconds(0.2)
	weapons.force_aim = false


func _doppelt() -> void:
	await _at_the_anvil()
	await _frames(2)
	_check(player.interactor._prompt == tr("UI_DENGEL_TWICE") % [tr("WEAPON_STUTZEN_1"), Constants.DENGEL_COST[1]], "again: \"%s\"" % player.interactor._prompt)
	player.interactor._use()
	await _seconds(Constants.DENGEL_TIME + 0.2)
	await _frames(2)
	player.interactor._use()
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	var gun: WeaponData = weapons.weapon
	_check(gun.id == &"stutzen_doppelt" and weapons.mag == gun.loaded_capacity(true), "doppelt dengelt: %s, %d rounds" % [tr(gun.display_name), weapons.mag])
	await _frames(2)
	_check(player.interactor._prompt == "" or player.interactor._target != stock, "no third time (\"%s\")" % player.interactor._prompt)


func _not_taken() -> void:
	# Two guns: the pistol goes and is not fetched; the Stutzen stays.
	weapons._select(weapons._slot_of(_weapon("pistole")))
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	player.interactor._use()
	await _seconds(Constants.DENGEL_TIME + Constants.DENGEL_WAIT + 0.3)
	_check(stock.state == Dengelstock.State.OPEN and weapons.gun_count() == 1 and not weapons.has_weapon(_weapon("pistole")),
			"not taken in %d s: the Gendarmen-Pistole is gone" % roundi(Constants.DENGEL_WAIT))
	# The only gun goes and is not fetched: the pistol a match starts with comes back.
	weapons.reset_loadout()
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	player.interactor._use()
	await _seconds(Constants.DENGEL_TIME + 0.2)
	_check(weapons.weapon == null and weapons.gun_count() == 0, "no gun left meanwhile, only the melee weapon")
	await _seconds(Constants.DENGEL_WAIT + 0.2)
	_check(weapons.gun_count() == 1 and weapons.weapon.id == &"pistole", "gone with no gun left: the plain pistol comes back")


func _the_schaufel() -> void:
	var spot: Node3D = null
	for child: Node in stock.get_children():
		if child is Dengelstock.GrindstoneSpot:
			spot = child
	_check(spot != null, "a grindstone beside the anvil")
	var at: Vector3 = spot.get_interact_position()
	player.global_position = Vector3(at.x, stock.global_position.y + 0.05, at.z) - stock.global_basis.z * 0.3
	_look_at(at)
	await _frames(5)
	_check(player.interactor._target == spot and player.interactor._prompt == tr("UI_DENGEL") % [tr("WEAPON_SCHAUFEL"), Constants.DENGEL_COST[0]],
			"at the grindstone: \"%s\"" % player.interactor._prompt)
	player.interactor._use()
	await _frames(2)
	_check(weapons.melee_weapon == null and weapons.weapon != null, "the shovel is on the anvil, the gun still in hand")
	await _seconds(Constants.DENGEL_TIME + 0.2)
	await _frames(2)
	player.interactor._use()
	await _frames(2)
	var shovel: WeaponData = weapons.melee_weapon
	_check(shovel != null and shovel.id == &"schaufel_dengelt", "the %s is back on V" % (tr(shovel.display_name) if shovel else "nothing"))
	player.global_position = FIELD
	await _frames(3)
	var enemy: Enemy = _spawn("wanderer", Vector3(0, 0, -1.2))
	await _frames(3)
	_look_at(enemy.global_position + Vector3.UP * 1.0)
	var before: int = enemy.health
	weapons._start_melee()
	await _seconds(1.0 / shovel.fire_rate)
	_check(before - enemy.health == shovel.damage and enemy.is_stunned(), "its blow: %d and the survivor dazed" % (before - enemy.health))
	enemy._take_hit(10000000, false, false, null)
	await _seconds(0.2)


func _golden_gun() -> void:
	var gun: WeaponData = _weapon("pistole").upgrade.upgrade
	_check(gun.one_hit and gun.golden and tr(gun.display_name) == "Golden Gun" and not _weapon("pistole").upgrade.one_hit,
			"the Dienstpistole doppelt dengelt is the %s" % tr(gun.display_name))
	weapons.give_weapon(gun)
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	var gold: bool = true
	# (Its model, not the muzzle flash or the brass casings it throws.)
	for mesh: Node in weapons._viewmodel.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var surface := mesh as MeshInstance3D
		if String(weapons._viewmodel.get_node("Model").get_path_to(surface)).begins_with("MuzzleFlash"):
			continue
		for i: int in surface.mesh.get_surface_count():
			var material := surface.get_active_material(i) as StandardMaterial3D
			gold = gold and material != null and material.albedo_color.is_equal_approx(Constants.FORGED_GOLD[1])
	_check(gold, "every part of it is gold, the grip too")
	player.global_position = FIELD
	weapons.force_aim = true
	await _seconds(gun.aim_time + 0.1)
	var boss: Enemy = _spawn("krampus", Vector3(0, 0, -6))
	await _frames(3)
	_look_at(boss.global_position + Vector3.UP * 1.0)
	await _frames(1)
	weapons._cooldown = 0.0
	weapons._fire()
	await _frames(1)
	_check(not boss.is_alive(), "one shot fells a Krampus with %d health" % boss.max_health)
	weapons.force_aim = false
