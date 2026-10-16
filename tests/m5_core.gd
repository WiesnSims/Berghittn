extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m5_core.tscn
## Headless M5 check on the real main scene: the enemy mix per wave, boss waves, the Perchte lunge,
## bullet penetration, the four Schnaps and their effects, the Hüttentruhe (take, let sink, swap),
## the Repetierer's fanning, the Lager's ammo crate, every Schnaps perk and the Brettljause.

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
	# Spam-clicking sprays, a steady rhythm stays precise.
	_look_at(FIELD + Vector3(30.0, 1.0, 0.0))
	player.weapons.aim_amount = 0.0
	for rhythm: int in [6, 30]:
		player.weapons.bloom = 0.0
		for i: int in 5:
			player.weapons.mag = 8
			player.weapons._fire()
			await _frames(rhythm)
		var spam: bool = rhythm == 6
		_check((player.weapons.bloom >= 4.0) if spam else (player.weapons.bloom < 0.5),
			"pistol at %d clicks/s: bloom %.1f°" % [60 / rhythm, player.weapons.bloom])
	await _shotgun_close()


func _shotgun_close() -> void:
	# Buckshot goes through bodies only up close: three in a row at 2 m, then three at 10 m. Spread off,
	# so every pellet flies down the line.
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	var flinte: WeaponData = load("res://data/weapons/jagdflinte.tres")
	var spread: float = flinte.spread
	flinte.spread = 0.0
	player.weapons.give_weapon(flinte)
	await _seconds(0.6)
	for distance: float in [2.0, 10.0]:
		var row: Array[Enemy] = []
		for i: int in 3:
			row.append(_spawn(wanderer, FIELD + Vector3(distance - 3.0 + i * 1.0, 0.0, 0.0), FIELD + Vector3(-3.0, 0.0, 0.0)))
		await _frames(2)
		for i: int in 3:
			row[i].global_position = FIELD + Vector3(distance - 3.0 + i * 1.0, 0.0, 0.0)
		await _frames(1)
		_look_at(FIELD + Vector3(12.0, 1.0, 0.0))
		player.weapons.bloom = 0.0
		var before: Array[int] = []
		for e: Enemy in row:
			before.append(e.health)
		player.weapons.mag = 2
		player.weapons._fire()
		var after: Array = row.map(func(e: Enemy) -> int: return maxi(e.health, 0) if e.is_alive() else 0)
		var through: bool = after[1] < before[1]
		_check(through if distance < flinte.penetration_range else not through,
			"Jagdflinte at %.0f m %s: health %s -> %s" % [distance, "goes through" if distance < flinte.penetration_range else "stops in the first", before, after])
		for e: Enemy in row:
			if e.is_alive():
				e.receive_hit(10000, false, false, null)
		await _seconds(0.2)
	flinte.spread = spread


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
	_check(bottles.size() == 6, "six bottles on the shrine")
	player.points.add(30000)
	var pistol: WeaponData = load("res://data/weapons/pistole.tres")
	player.weapons.give_weapon(pistol)
	await _seconds(0.6)
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
	var hud := main.get_node("UI/Hud") as Hud
	_check(hud._perk_icons.get_child_count() == 6, "HUD shows %d perk icons" % hud._perk_icons.get_child_count())
	_check(player.health.max_health == 100 and is_equal_approx(player.perks.damage_multiplier(), 1.0), "Schnaps give no plain stats any more")
	await _durchschlag()
	await _boellerschuss()
	await _sturschaedl(hud)
	await _gmiatlichkeit()
	await _grantler()
	await _kraeuter()
	await _brettljause()


func _durchschlag() -> void:
	# The pistol goes through nothing by itself; with the Zirbenschnaps it goes through one.
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	_place(FIELD + Vector3(-3.0, 0.0, 0.0))
	var pair: Array[Enemy] = [_spawn(wanderer, FIELD, FIELD + Vector3(-3, 0, 0)), _spawn(wanderer, FIELD + Vector3(1.2, 0, 0), FIELD + Vector3(-3, 0, 0))]
	await _frames(2)
	pair[0].global_position = FIELD
	pair[1].global_position = FIELD + Vector3(1.2, 0, 0)
	await _frames(1)
	_look_at(FIELD + Vector3(4.0, 1.0, 0.0))
	player.weapons.aim_amount = 1.0
	player.weapons.bloom = 0.0
	var behind: int = pair[1].health
	player.weapons.mag = 8
	player.weapons._fire()
	_check(player.perks.extra_penetration() == 1 and pair[1].health < behind, "Durchschlag: pistol goes through (behind %d -> %d)" % [behind, pair[1].health])
	await _clear_enemies(pair)


func _boellerschuss() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	_place(FIELD)
	var close: Array[Enemy] = [_spawn(wanderer, FIELD + Vector3(2.0, 0, 0), FIELD), _spawn(wanderer, FIELD + Vector3(0, 0, 3.5), FIELD)]
	await _frames(2)
	close[0].global_position = FIELD + Vector3(2.0, 0, 0)
	close[1].global_position = FIELD + Vector3(0, 0, 3.5)
	await _frames(1)
	# Tough enough to survive, so the push shows.
	for e: Enemy in close:
		e.health = 5000
	var before: Array[int] = [close[0].health, close[1].health]
	var start: float = close[0].global_position.distance_to(FIELD)
	player.weapons.mag = 0
	player.weapons.reserve = 64
	player.weapons.start_reload()
	await _frames(1)
	var hurt: bool = close[0].health < before[0] and close[1].health < before[1]
	_check(hurt and close[0].health < close[1].health, "Böllerschuss on an empty reload: %s -> %s (nearer hurts more)" % [before, [close[0].health, close[1].health]])
	_check(main.find_children("*", "Node3D", true, false).any(func(n: Node) -> bool: return n.get_script() == PlayerPerks.BOELLER_BLAST), "the Böller goes off where you stand")
	await _seconds(0.5)
	var now: float = close[0].global_position.distance_to(FIELD)
	_check(now > start + 1.0, "survivors are thrown back (%.1f m -> %.1f m)" % [start, now])
	player.weapons._cancel_reload()
	var after: int = close[0].health
	player.weapons.mag = 0
	player.weapons.start_reload()
	await _frames(1)
	_check(close[0].health == after, "then it needs %.0f s to pack the next charge" % Constants.PERK_BOELLER_COOLDOWN)
	await _seconds(player.weapons._reload_left + 0.2)
	await _clear_enemies(close)


func _sturschaedl(hud: Hud) -> void:
	_place(FIELD)
	player.health._health = 10.0
	player.take_damage(500)
	_check(player.health.current() == 1 and not player.health.is_dead() and player.perks.is_invincible(), "Sturschädl: a deadly hit leaves 1 HP")
	var held: int = player.health.current()
	player.take_damage(500)
	await _frames(1)
	_check(player.health.current() >= held and not player.health.is_dead(), "and nothing gets through for %.0f s" % Constants.PERK_STUR_INVINCIBLE_TIME)
	_check(hud._perk_glow.modulate.a > 0.2 and hud._banner.text == tr("PERK_ENZIAN_SHOUT"), "gold glow on screen, banner '%s'" % hud._banner.text)
	await _seconds(Constants.PERK_STUR_INVINCIBLE_TIME + 0.1)
	_check(not player.perks.is_invincible() and not player.perks._cheat_death(), "once per wave")
	Events.wave_started.emit(2, false)
	_check(player.perks.status(_perk(&"enzian")).dim == false, "ready again next wave")
	player.health.heal_full()


func _gmiatlichkeit() -> void:
	_place(FIELD)
	player.health._health = 40.0
	player.health._since_damage = 0.0
	player.perks._cosy_time = 0.0
	await _seconds(Constants.PERK_COSY_TIME + 1.0)
	# Without it nothing would heal for 5 s; cosy it heals 30/s after 2 s.
	_check(player.health.current() >= 60, "Gmiatlichkeit: standing still heals at once and fast (40 -> %d in 3 s)" % player.health.current())
	player.health.heal_full()


func _grantler() -> void:
	var wanderer: EnemyData = load("res://data/enemies/wanderer.tres")
	_place(FIELD)
	var crowd: Array[Enemy] = []
	for i: int in 4:
		crowd.append(_spawn(wanderer, FIELD + Vector3(cos(i * 1.6) * 3.0, 0, sin(i * 1.6) * 3.0), FIELD))
	await _frames(3)
	_check(is_equal_approx(player.perks.grantler_bonus(), 0.2) and is_equal_approx(player.perks.damage_multiplier(), 1.2), "Grantler: 4 close by, damage x%.2f" % player.perks.damage_multiplier())
	await _clear_enemies(crowd)
	await _frames(2)
	_check(is_equal_approx(player.perks.damage_multiplier(), 1.0), "nobody close, no bonus")


func _kraeuter() -> void:
	player.health._health = 30.0
	for i: int in Constants.PERK_HERBS - 1:
		Events.enemy_killed.emit(null, false, false, player)
	_check(player.perks.herbs == Constants.PERK_HERBS - 1 and player.perks.rausch_left() == 0.0, "Jagamoasta: %d herbs gathered" % player.perks.herbs)
	Events.enemy_killed.emit(null, false, false, player)
	_check(player.health.current() == player.health.max_health and is_equal_approx(player.perks.damage_multiplier(), 2.0) and player.perks.herbs == 0,
		"56 gsunde Kräuter: healed to %d, damage x%.1f" % [player.health.current(), player.perks.damage_multiplier()])
	player.perks._rausch_left = 0.0


func _brettljause() -> void:
	var items: Array[Node] = _find(JauseItem)
	player.points.add(40000)
	_check(items.size() == 3, "three things on the Brettljause")
	for node: Node in items:
		var item := node as JauseItem
		_place(item.global_position + Vector3(0.0, -0.84, -1.0))
		_look_at(item.global_position)
		await _frames(2)
		_check(player.interactor._find_target() == item, "looking at the %s targets it (%s)" % [item.jause.id, item.get_interact_prompt(player)])
		for helping: int in item.jause.max_level + 1:
			item.interact(player)
		_check(player.perks.jause_level(item.jause) == item.jause.max_level and item.get_interact_prompt(player) == tr("UI_JAUSE_FULL") % tr(item.jause.display_name),
			"%s eaten %d times, then enough" % [item.jause.id, item.jause.max_level])
	_check(player.health.max_health == 200, "Speck x5: max health %d" % player.health.max_health)
	_check(is_equal_approx(player.perks.damage_multiplier(), 1.5), "Kasnockn x5: damage x%.2f" % player.perks.damage_multiplier())
	_check(is_equal_approx(player.perks.reload_time_multiplier(), 1.0 / 1.5), "Germknedl x5: reload x%.2f" % player.perks.reload_time_multiplier())
	player.health.heal_full()


func _perk(id: StringName) -> PerkData:
	for perk: PerkData in player.perks.owned:
		if perk.id == id:
			return perk
	return null


func _clear_enemies(list: Array[Enemy]) -> void:
	for e: Enemy in list:
		if e.is_alive():
			e.receive_hit(100000, false, false, null)
	await _seconds(0.2)


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
