extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_core.tscn
## Headless M5 check on the real main scene: the enemy mix per wave, boss waves, the Perchte lunge,
## bullet penetration, the four Schnaps and their effects, the Hüttentruhe (take, let sink, swap),
## the Repetierer's fanning, the Lager's ammo crate and the Terrasse's snow cannon.

# Open pasture in front of the hut, clear of furniture.
const FIELD: Vector3 = Vector3(-12.0, -0.3, 22.0)
const ALL_ZONES: Array[StringName] = [&"kueche", &"lager", &"terrasse", &"skiraum", &"schuppen", &"seilbahn"]

var main: Node
var player: Player
var zones: ZoneMap
var waves: WaveManager
var failures: Array[String] = []
var _boss_seen: Node3D = null


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


func _find(type: Variant) -> Array[Node]:
	return main.find_children("*", "", true, false).filter(func(n: Node) -> bool: return is_instance_of(n, type))


func _spawn(data: EnemyData, at: Vector3, facing: Vector3 = Vector3.ZERO) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var xf := Transform3D(Basis.IDENTITY, at)
	if facing != Vector3.ZERO:
		xf = xf.looking_at(facing, Vector3.UP)
	enemy.activate(data, 1, xf)
	# The wave manager is switched off in this test; its enemies must not inherit that.
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	return enemy


func _look_at(point: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var cam := player.get_node("Head/Camera3D") as Camera3D
	player.look_at(Vector3(point.x, player.global_position.y, point.z), Vector3.UP)
	var d: Vector3 = point - cam.global_position
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _place(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	zones = main.get_node("Zones")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	Events.boss_spawned.connect(func(e: Node3D) -> void: _boss_seen = e)
	for zone: StringName in ALL_ZONES:
		zones.unlock(zone, player)
	await _frames(10)

	_wave_mix()
	await _penetration()
	await _lunge()
	await _perks()
	await _chest()
	await _fanning()
	await _ammo_crate()
	await _snow_cannon()
	await _boss_wave()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _wave_mix() -> void:
	var table: WaveTable = waves.wave_table
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for wave: int in [1, 3, 6, 8]:
		var seen: Dictionary = {}
		for i: int in 3000:
			var data: EnemyData = table.pick_enemy(wave, rng)
			seen[data.id] = seen.get(data.id, 0) + 1
		var expected: Array = [&"wanderer"]
		if wave >= 3:
			expected.append(&"tourist")
		if wave >= 6:
			expected.append(&"knappe")
		if wave >= 8:
			expected.append(&"perchte")
		expected.sort()
		var got: Array = seen.keys()
		got.sort()
		_check(got == expected and not seen.has(&"krampus"), "wave %d mix %s" % [wave, seen])
	var boss_waves: Array[int] = []
	for wave: int in range(1, 21):
		if table.is_boss_wave(wave):
			boss_waves.append(wave)
	_check(boss_waves == [5, 10, 15, 20], "boss waves %s" % [boss_waves])
	var krampus: EnemyData = table.boss
	_check(krampus.health_for_wave(5) == 3500 and krampus.health_for_wave(10) == 4000, "Krampus HP 3000 + 500·(wave/5): %d at 5, %d at 10" % [krampus.health_for_wave(5), krampus.health_for_wave(10)])


func _penetration() -> void:
	# Five wanderers in a row in front of the player, out on the open pasture; one Stutzen shot through the line.
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var stutzen: WeaponData = load("res://data/weapons/stutzen.tres")
	var pistol: WeaponData = load("res://data/weapons/pistole.tres")
	_place(FIELD + Vector3(-3.0, 0.0, 0.0))
	var line: Array[Enemy] = []
	for i: int in 5:
		line.append(_spawn(wanderer, FIELD + Vector3(i * 1.2, 0.0, 0.0), FIELD + Vector3(-3.0, 0.0, 0.0)))
	player.weapons.give_weapon(stutzen)
	await _seconds(0.6)
	for i: int in line.size():
		line[i].global_position = FIELD + Vector3(i * 1.2, 0.0, 0.0)
	await _frames(1)
	_look_at(FIELD + Vector3(8.0, 1.0, 0.0))
	player.weapons.aim_amount = 1.0
	player.weapons.bloom = 0.0
	await _frames(1)
	var before: Array[int] = []
	for e: Enemy in line:
		before.append(e.health)
	player.weapons._fire()
	var dealt: Array[int] = []
	for i: int in line.size():
		dealt.append(before[i] - maxi(line[i].health, 0) if line[i].is_alive() else before[i])
	# 120, then half of it, a quarter, an eighth; the fifth body stops nothing more.
	_check(not line[0].is_alive() and line[1].health == before[1] - 60 and line[2].health == before[2] - 30 and line[3].health == before[3] - 15 and line[4].health == before[4],
		"Stutzen goes through 3 more: health %s -> %s" % [before, line.map(func(e: Enemy) -> int: return e.health)])
	# The pistol does not go through.
	player.weapons.give_weapon(pistol)
	await _seconds(0.6)
	var h1: int = line[1].health
	var h2: int = line[2].health
	_look_at(line[1].global_position + Vector3(0, 1.0, 0))
	player.weapons.aim_amount = 1.0
	player.weapons.bloom = 0.0
	await _frames(1)
	player.weapons._fire()
	_check(line[1].health < h1 and line[2].health == h2, "pistol stops in the first body (%d -> %d, behind %d -> %d)" % [h1, line[1].health, h2, line[2].health])
	_check(pistol.fire_rate >= 8.0 and not pistol.is_auto, "pistol fires as fast as clicked: up to %.0f/s, one shot per click" % pistol.fire_rate)
	for e: Enemy in line:
		if e.is_alive():
			e.receive_hit(10000, false, false, null)
	await _seconds(0.2)


func _lunge() -> void:
	var perchte: EnemyData = load("res://data/enemies/perchte.tres")
	_place(FIELD)
	player.health._health = 100.0
	var enemy: Enemy = _spawn(perchte, FIELD + Vector3(5.0, 0.0, 0.0), FIELD)
	var lunged: bool = false
	var hit_at: float = -1.0
	var start_distance: float = 0.0
	for i: int in 240:
		await _frames(1)
		_place(FIELD)
		if enemy._state == Enemy.State.LUNGING and not lunged:
			lunged = true
			start_distance = Vector2(enemy.global_position.x - FIELD.x, enemy.global_position.z - FIELD.z).length()
		if player.health.current() < 100 and hit_at < 0.0:
			hit_at = i / 60.0
			break
	_check(lunged and start_distance > perchte.attack_range + 0.5, "Perchte lunges from %.1f m (melee range %.1f)" % [start_distance, perchte.attack_range])
	_check(hit_at > 0.0 and player.health.current() == 100 - perchte.damage, "the lunge lands for %d after %.2f s" % [100 - player.health.current(), hit_at])
	enemy.receive_hit(10000, false, false, null)
	player.health._health = 100.0
	await _seconds(0.2)


func _perks() -> void:
	var bottles: Array[Node] = _find(PerkBottle)
	_check(bottles.size() == 4, "four bottles on the shrine")
	player.points.add(20000)
	var pistol: WeaponData = load("res://data/weapons/pistole.tres")
	player.weapons.give_weapon(pistol)
	await _seconds(0.6)
	var walk_before: float = player._target_speed(Vector2(0, -1))
	for node: Node in bottles:
		var bottle := node as PerkBottle
		# Stand in front of the shrine's middle and look at this bottle: E must pick it, not a neighbour.
		var shrine: Node3D = bottle.get_parent()
		_place(shrine.to_global(Vector3(0.0, 0.0, -0.9)))
		_look_at(bottle.global_position)
		await _frames(2)
		_check(player.interactor._find_target() == bottle, "looking at the %s bottle targets it" % bottle.perk.id)
		var before: int = player.points.total
		bottle.interact(player)
		_check(player.perks.has(bottle.perk) and player.points.total == before - bottle.perk.cost, "%s bought for %d" % [bottle.perk.id, bottle.perk.cost])
		bottle.interact(player)
		_check(player.points.total == before - bottle.perk.cost and bottle.get_interact_prompt(player) == "", "%s once per life" % bottle.perk.id)
	await _frames(2)
	_check(player.health.max_health == 150 and player.health.current() == 150, "Enzian: max health %d, health %d" % [player.health.max_health, player.health.current()])
	_check(is_equal_approx(player.perks.damage_multiplier(), 1.2), "Zirbenschnaps: damage x%.2f" % player.perks.damage_multiplier())
	_check(is_equal_approx(player._target_speed(Vector2(0, -1)), walk_before * 1.15), "Jagertee: walk %.2f -> %.2f m/s" % [walk_before, player._target_speed(Vector2(0, -1))])
	player.weapons.mag = 3
	player.weapons.start_reload()
	_check(is_equal_approx(player.weapons._reload_left, pistol.reload_time * 0.8), "Marillenbrand: reload %.2f s (normally %.2f)" % [player.weapons._reload_left, pistol.reload_time])
	await _seconds(2.0)
	var hud := main.get_node("UI/Hud") as Hud
	_check(hud._perk_icons.get_child_count() == 4, "HUD shows %d perk icons" % hud._perk_icons.get_child_count())


func _chest() -> void:
	var chest := _find(Huettentruhe)[0] as Huettentruhe
	var pool: ChestPool = chest.pool
	# Weights: 5 each for regular guns, so equal shares now; wonder weapons (1) come later.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts: Dictionary = {}
	for i: int in 3000:
		var w: WeaponData = pool.pick(func(_w: WeaponData) -> bool: return false, rng)
		counts[w.id] = counts.get(w.id, 0) + 1
	var even: bool = counts.size() == 3
	for id: StringName in counts:
		even = even and absf(counts[id] / 3000.0 - 1.0 / 3.0) < 0.04
	_check(even, "chest pool shares %s" % counts)
	# Only the pistol in hand, so a free slot.
	while player.weapons.gun_count() > 1:
		player.weapons._slots.remove_at(player.weapons._slots.size() - 1)
	player.weapons._current = -1
	player.weapons._select(0)
	_place(chest.get_interact_position())
	_look_at(chest.global_position + Vector3(0, 0.6, 0))
	await _frames(2)
	_check(player.interactor._find_target() == chest and chest.get_interact_prompt(player).contains("950"), "chest prompt: %s" % chest.get_interact_prompt(player))
	var before: int = player.points.total
	chest.interact(player)
	_check(chest.state == Huettentruhe.State.ROLLING and player.points.total == before - 950, "chest opens for 950")
	await _seconds(pool.roll_time + 0.1)
	_check(chest.state == Huettentruhe.State.OFFERING and chest.offer != null and not player.weapons.has_weapon(chest.offer), "rolled %s, not one already carried" % (chest.offer.id if chest.offer else &"nothing"))
	var offer: WeaponData = chest.offer
	chest.interact(player)
	_check(player.weapons.has_weapon(offer) and player.weapons.gun_count() == 2 and player.weapons.weapon == offer, "took the %s into the free slot" % offer.id)
	await _seconds(1.2)
	_check(chest.state == Huettentruhe.State.CLOSED, "chest closed again")
	# Not taken: it sinks back after offer_time.
	chest.interact(player)
	await _seconds(pool.roll_time + pool.offer_time + 1.2)
	_check(chest.state == Huettentruhe.State.CLOSED and player.weapons.gun_count() == 2, "an offer not taken sinks back in")
	# Both slots full: taking swaps the gun in hand.
	var in_hand: WeaponData = player.weapons.weapon
	chest.interact(player)
	await _seconds(pool.roll_time + 0.1)
	var swap: WeaponData = chest.offer
	_check(chest.get_interact_prompt(player).contains(tr(swap.display_name)), "swap prompt: %s" % chest.get_interact_prompt(player))
	chest.interact(player)
	_check(player.weapons.has_weapon(swap) and not player.weapons.has_weapon(in_hand) and player.weapons.gun_count() == 2, "swapped the %s for the %s" % [in_hand.id, swap.id])
	await _seconds(1.2)


func _fanning() -> void:
	var rep: WeaponData = load("res://data/weapons/repetierer.tres")
	player.weapons.give_weapon(rep)
	await _seconds(0.6)
	var holder: WeaponHolder = player.weapons
	holder.bloom = 0.0
	var hip: float = holder.current_spread()
	holder._fanning = true
	var fanned: float = holder.current_spread()
	holder._fire()
	var cooldown: float = holder._cooldown
	holder._fanning = false
	_check(is_equal_approx(cooldown, 1.0 / rep.rapid_fire_rate) and fanned > hip + rep.rapid_spread - 0.01, "Repetierer fanning: %.2f s between shots (normal %.2f), spread %.1f -> %.1f" % [cooldown, 1.0 / rep.fire_rate, hip, fanned])
	_check(rep.secondary == WeaponData.Secondary.FAN and rep.penetration == 1, "Repetierer: right click fans the lever, goes through one body")


func _ammo_crate() -> void:
	var crate := _find(AmmoCrate)[0] as AmmoCrate
	var holder: WeaponHolder = player.weapons
	for slot: WeaponHolder.GunSlot in holder._slots:
		slot.reserve = 0
	holder.reserve = 0
	_place(crate.get_interact_position())
	_look_at(crate.global_position + Vector3(0, 0.5, 0))
	await _frames(2)
	_check(player.interactor._find_target() == crate, "Lager ammo crate in reach (prompt: %s)" % crate.get_interact_prompt(player))
	var before: int = player.points.total
	crate.interact(player)
	var full: bool = holder.reserve == holder.weapon.reserve_ammo
	for i: int in holder._slots.size():
		if i != holder._current:
			full = full and holder._slots[i].reserve == holder._slots[i].data.reserve_ammo
	_check(full and player.points.total == before - crate.cost, "ammo crate refilled every gun for %d" % crate.cost)
	_check(crate.get_interact_prompt(player) == "", "nothing to buy once full")


func _snow_cannon() -> void:
	var cannon := _find(SnowCannon)[0] as SnowCannon
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	_place(cannon.get_interact_position())
	_look_at(cannon.global_position + Vector3(0, 1.0, 0))
	await _frames(2)
	_check(player.interactor._find_target() == cannon, "snow cannon in reach (prompt: %s)" % cannon.get_interact_prompt(player))
	var victim: Enemy = _spawn(wanderer, Vector3(-6.0, -1.5, 15.5))
	await _frames(5)
	var health: int = victim.health
	var points: int = player.points.total
	cannon.interact(player)
	_check(cannon.is_blowing() and player.points.total == points - cannon.cost, "snow cannon fired up for %d" % cannon.cost)
	await _seconds(2.1)
	_check(victim.health <= health - 2 * cannon.damage_per_second and victim._slow_factor == cannon.slow_factor, "garden enemy frozen: %d -> %d, speed x%.1f" % [health, victim.health, victim._slow_factor])
	_check(player.points.total == points - cannon.cost, "trap damage earns no points")
	await _seconds(cannon.blow_time)
	_check(not cannon.is_blowing() and cannon.get_interact_prompt(player).contains(str(ceili(cannon._cooldown_left))), "then it builds pressure: %s" % cannon.get_interact_prompt(player))
	if victim.is_alive():
		victim.receive_hit(10000, false, false, null)
	await _seconds(0.2)


func _boss_wave() -> void:
	# Straight into wave 5 with the real wave manager.
	_place(Vector3(-2.0, 0.0, 3.5))
	waves._alive = 0
	waves.process_mode = Node.PROCESS_MODE_INHERIT
	waves._start_wave(5)
	var spawned: Dictionary = {}
	for i: int in 60 * 30:
		await _frames(1)
		player.health._health = float(player.health.max_health)
		if waves._phase != WaveManager.Phase.SPAWNING:
			break
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.is_alive():
			spawned[e.data.id] = spawned.get(e.data.id, 0) + 1
	_check(spawned.get(&"krampus", 0) == 1 and spawned.get(&"wanderer", 0) == 6 and spawned.size() == 2, "wave 5 is the Krampus and 6 wanderers: %s" % spawned)
	var krampus := _boss_seen as Enemy
	_check(krampus != null and krampus.max_health == 3500, "boss announced with %d HP" % (krampus.max_health if krampus else 0))
	var hud := main.get_node("UI/Hud") as Hud
	_check(hud._boss_box.visible and hud._banner.text == tr("UI_BOSS_WAVE"), "HUD: boss bar up, banner '%s'" % hud._banner.text)
	if krampus:
		_check(is_equal_approx((krampus.get_node("Visual/HeadHurtbox") as Node3D).scale.x, 1.4), "Krampus hit boxes scaled with the model")
		krampus.receive_hit(10000, false, false, player)
		await _frames(2)
		_check(not hud._boss_box.visible, "boss bar gone with the Krampus")
