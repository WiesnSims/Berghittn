extends Node
## M7 part 3 over the real relay: host and guest in the real main scene, one role per process:
##     node tools/net_test.mjs res://tests/net_specials.tscn
## The guest's gun shows in its hiker's hands on the host, and its Alphorn blast and thrown Kuhglocke
## are replayed there (the bell lures on the host); the host's burning enemy burns on the guest; the
## guest's Mistgabel lifts, carries and hurls the host's enemy; the Krampus-Rute drop is the guest's
## alone; and every event comes to the guest: the Murmeltier caught, die Resi milked, the Bierfassl
## tapped, the Tourist's Eisstöcke, each paid in the guest's own game, with the host's banners; an
## enemy's line (Gredn) picked by the host is heard and shown on the guest; the guest's gun goes on
## the Dengelstock with the host's word, the anvil is busy for the host meanwhile, and the guest's
## hiker shows empty hands, then the Gendarmen-Pistole; the guest's Kraxn shows on its back.

const TIMEOUT: float = 25.0
const ALPHORN: WeaponData = preload("res://data/weapons/alphorn.tres")
const RUTE: WeaponData = preload("res://data/weapons/krampusrute.tres")
const KUHGLOCKE: EquipmentData = preload("res://data/equipment/kuhglocke.tres")
const PISTOLE: WeaponData = preload("res://data/weapons/pistole.tres")

var _main: Node
var _player: Player
var _marks: Dictionary = {}
var _role: String
var _failed: String = ""
var _banners: Array[String] = []


func _ready() -> void:
	if Engine.has_meta("net_specials_done"):
		get_tree().quit(int(Engine.get_meta("net_specials_done")))
		return
	_role = _arg("role", "host")
	Settings.profile = {"name": "Wirt" if _role == "host" else "Gast", "head": 0, "hat": 0, "jacket": 0, "trousers": 0}
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	Events.event_announced.connect(func(text: String) -> void: _banners.append(text))
	var ok: bool = await _run()
	Engine.set_meta("net_specials_done", 0 if ok else 1)
	print("PASS" if ok else "FAIL %s: %s" % [_role, _failed])
	get_tree().quit(0 if ok else 1)


func _run() -> bool:
	var host: bool = _role == "host"
	await get_tree().process_frame
	if host:
		Net.create_room()
		if not await _until(func() -> bool: return Net.in_lobby()):
			return _fail("no room")
		print("ROOM %s" % Net.code)
		if not await _until(func() -> bool: return Net.roster.size() == 2):
			return _fail("guest never came")
		Net.start_match()
	if not await _until(func() -> bool: return Net.in_match() and Coop.events != null):
		return _fail("no match")
	# Nobody goes down in this test, and no event comes unasked.
	_player.health.invincible_left = 9999.0
	var director := _main.get_node("EventDirector") as EventDirector
	director.random_events = false
	if not await _sync("started"):
		return false
	var waves := _main.get_node("WaveManager") as WaveManager
	var other: Hiker = Coop.node_of(2 if host else 1) as Hiker
	# --- the gun in hand, a special shot, a thrown bell ---
	if not host:
		_player.weapons.give_weapon(ALPHORN)
		await get_tree().create_timer(0.5).timeout
		_player.weapons._fire()
		_player.equipment.give(KUHGLOCKE, 1)
		if not _player.equipment.throw():
			return _fail("could not throw the bell")
	else:
		if not await _until(func() -> bool: return other._gun != null and other._gun.visible and other._guns.has(&"alphorn")):
			return _fail("the guest's hiker never held the Alphorn")
		if not await _until(func() -> bool: return _child_with_script(_main.get_node("CoopPlayers"), "alphorn_wave.gd")):
			return _fail("the guest's Alphorn blast was not replayed")
		if not await _until(func() -> bool: return _remote_bell() != null):
			return _fail("no copy of the guest's Kuhglocke")
		if not await _until(func() -> bool: return _remote_bell().is_luring()):
			return _fail("the copied bell never rang (lured)")
	print("weapons: gun in the hiker's hands, Alphorn replayed, bell copied and ringing")
	if not await _sync("weapons"):
		return false
	# --- an enemy: burning, then lifted on the guest's fork ---
	if host:
		waves.begin_break(0.3)
		if not await _until(func() -> bool: return _chasing_enemy(waves) != null):
			return _fail("no enemy came in")
		var chaser: Enemy = _chasing_enemy(waves)
		waves.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(0.3).timeout
		chaser.ignite(10.0, 0, null)
		_note.rpc("enemy", chaser.net_id)
		if not await _until(func() -> bool: return chaser.is_lifted()):
			return _fail("the guest's fork never lifted the host's enemy")
		if not await _until(func() -> bool: return chaser.global_position.distance_to(other.global_position) < 3.5):
			return _fail("the lifted enemy was not carried to the guest (%.1f m)" % chaser.global_position.distance_to(other.global_position))
		if not await _until(func() -> bool: return not chaser.is_lifted()):
			return _fail("never hurled")
	else:
		if not await _until(func() -> bool: return _marks.has("enemy")):
			return _fail("host never picked an enemy")
		var puppet: Enemy = Coop.enemies.by_id(int(_marks["enemy"]))
		if puppet == null:
			return _fail("no puppet for the host's enemy")
		if not await _until(func() -> bool: return puppet._burn_fx != null and puppet._burn_fx.emitting):
			return _fail("the burning enemy does not burn on the guest")
		if not puppet.lift():
			return _fail("could not lift the puppet")
		var forward: Vector3 = -_player.global_basis.z
		for i: int in 90:
			puppet.carry_to(_player.global_position + forward * 1.2 + Vector3.UP * 1.6, -forward)
			await get_tree().physics_frame
		puppet.hurl(forward * 4.0 + Vector3.UP * 3.0, func(_e: Enemy) -> void: pass)
		if not await _until(func() -> bool: return not puppet.puppet_driven()):
			return _fail("the hurled puppet never landed")
	print("enemy: burning shown on the guest, lifted, carried and hurled by the guest's fork")
	if not await _sync("fork"):
		return false
	# --- a line (Gredn): picked by the host, its index sent, heard and shown on the guest ---
	var gredn: Gredn = Gredn.current
	if host:
		var talker: Enemy = null
		for child: Node in waves.get_children():
			var enemy := child as Enemy
			if enemy and enemy.is_alive() and enemy.net_id != 0:
				talker = enemy
		if talker == null:
			return _fail("no enemy left to talk")
		gredn.always = true
		gredn._gap_left = 0.0
		talker.talk_left = 0.0
		var line: int = gredn.talk(talker, Gredn.Moment.SPOT)
		gredn.always = false
		if line < 0:
			return _fail("the host's enemy said nothing")
		_note.rpc("line", line)
	else:
		(_player.get_node("Head/Camera3D") as Camera3D).make_current()
		if not await _until(func() -> bool: return _marks.has("line") and gredn.last_heard == int(_marks["line"])):
			return _fail("the host's line was not heard on the guest (%d)" % gredn.last_heard)
		if gredn.shown() != 1:
			return _fail("the line is not shown over the puppet")
	print("gredn: the host's line heard and shown on the guest")
	if not await _sync("gredn"):
		return false
	if host:
		for child: Node in waves.get_children():
			var enemy := child as Enemy
			if enemy and enemy.is_alive():
				enemy.receive_hit(99999, false, false, null)
	await get_tree().create_timer(0.5).timeout
	# --- the Dengelstock: the guest's pistol, with the host's word on the anvil ---
	var stock := get_tree().get_first_node_in_group("dengelstocks") as Dengelstock
	stock.open()
	if not await _sync("lit"):
		return false
	if not host:
		_player.weapons.give_weapon(PISTOLE)
		await get_tree().create_timer(0.5).timeout
		_player.points.add(Constants.DENGEL_COST[0])
		stock.use(_player, false)
		if not await _until(func() -> bool: return stock.state == Dengelstock.State.FORGING and _player.weapons.weapon == null):
			return _fail("the host never put the guest's pistol on the anvil")
		if _player.points.total != 0 and _player.points.total >= Constants.DENGEL_COST[0]:
			return _fail("the guest did not pay")
		if not await _until(func() -> bool: return stock.state == Dengelstock.State.READY):
			return _fail("the guest's pistol was never forged")
		stock.use(_player, false)
		if _player.weapons.melee_weapon == null or not _player.weapons.has_weapon(PISTOLE) or _player.weapons.weapon == null or _player.weapons.weapon.id != &"pistole_dengelt":
			return _fail("the guest did not get the Gendarmen-Pistole")
	else:
		if not await _until(func() -> bool: return stock.state == Dengelstock.State.FORGING and stock.owner_of_work() == other):
			return _fail("the guest's pistol never went on the host's anvil")
		if stock.prompt_for(_player, false) != tr("UI_DENGEL_BUSY"):
			return _fail("the anvil is not busy for the host: \"%s\"" % stock.prompt_for(_player, false))
		if not await _until(func() -> bool: return other._gun == null):
			return _fail("the guest's hiker still holds a gun")
		if not await _until(func() -> bool: return stock.state == Dengelstock.State.OPEN):
			return _fail("the anvil never came free after the guest took the pistol")
		if not await _until(func() -> bool: return other._gun != null and other._guns.get(&"pistole_dengelt") == other._gun):
			return _fail("the guest's hiker does not hold the Gendarmen-Pistole")
	print("dengelstock: the guest's pistol forged with the host's word, busy for the host, back as the Gendarmen-Pistole")
	if not await _sync("dengel"):
		return false
	# --- die Kraxn (#95): the guest's on its hiker's back, the guns not in hand strapped to it ---
	if not host:
		_player.weapons.add_kraxn()
		_player.weapons.give_weapon(ALPHORN)
		_player.weapons.give_weapon(preload("res://data/weapons/stutzen.tres"))
		if _player.weapons.gun_count() != 3:
			return _fail("the guest's Kraxn holds no third gun (%d)" % _player.weapons.gun_count())
	else:
		if not await _until(func() -> bool: return other._kraxn != null and other._kraxn.visible and other._stowed != null and other._stowed.get_child_count() == 2):
			return _fail("the guest's hiker shows no Kraxn with two guns on it")
	print("kraxn: on the guest's hiker, two guns strapped to it")
	if not await _sync("kraxn"):
		return false
	# --- the Krampus-Rute drop: one, for whoever is first ---
	if host:
		WeaponPickup.spawn(RUTE, _player.global_position + Vector3.FORWARD * 3.0, _main)
	if not await _until(func() -> bool: return _drop() != null):
		return _fail("no drop")
	var drop: WeaponPickup = _drop()
	if not host:
		drop.interact(_player)
		if not await _until(func() -> bool: return _player.weapons.has_weapon(RUTE)):
			return _fail("the guest never got the Rute")
	if not await _until(func() -> bool: return _drop() == null):
		return _fail("the drop stayed after the guest took it")
	if host and _player.weapons.has_weapon(RUTE):
		return _fail("the host got a Rute too")
	print("drop: the Krampus-Rute went to the guest only, gone on both")
	if not await _sync("drop"):
		return false
	# --- the Murmeltier ---
	if host:
		if director.send_murmeltier() == null:
			return _fail("no Murmeltier")
	if not await _until(func() -> bool: return _actor(Murmeltier) != null and (_actor(Murmeltier) as Murmeltier).is_up()):
		return _fail("no Murmeltier up")
	var murmel: Murmeltier = _actor(Murmeltier) as Murmeltier
	if not host:
		if not murmel.copy:
			return _fail("the guest's Murmeltier is no copy")
		var before: int = _player.points.total
		murmel.receive_hit(1, false, false, _player)
		if not await _until(func() -> bool: return _player.points.total == before + Constants.MURMEL_POINTS):
			return _fail("catching it paid %d" % (_player.points.total - before))
	elif not await _until(func() -> bool: return not is_instance_valid(murmel) or murmel._state == Murmeltier.State.CAUGHT):
		return _fail("the host's Murmeltier was never caught")
	print("murmeltier: caught by the guest, paid in the guest's game")
	if not await _sync("murmeltier"):
		return false
	# --- die Resi ---
	if host:
		if director.send_resi() == null:
			return _fail("no Resi")
	if not await _until(func() -> bool: return _actor(Resi) != null):
		return _fail("no Resi on this side")
	var resi: Resi = _actor(Resi) as Resi
	if not host:
		_player.health.invincible_left = 0.0
		_player.health.take_damage(40)
		_player.health.invincible_left = 9999.0
		var hurt: int = _player.health.current()
		var ok: bool = await _until(func() -> bool:
				resi.interact(_player)
				return _player.health.current() > hurt)
		if not ok:
			return _fail("milking the copy never healed the guest")
	elif not await _until(func() -> bool: return resi._state == Resi.State.MILKED):
		return _fail("the host's Resi never got milked")
	print("resi: milked by the guest, healed in the guest's game")
	if not await _sync("resi"):
		return false
	# --- the Bierfassl ---
	if host:
		var fassl: Bierfassl = director.send_fassl()
		if fassl == null:
			return _fail("no Bierfassl")
		await get_tree().create_timer(0.5).timeout
		fassl._come_to_rest()
	if not await _until(func() -> bool: return _actor(Bierfassl) != null and (_actor(Bierfassl) as Bierfassl).is_resting()):
		return _fail("no resting Bierfassl on this side")
	var barrel: Bierfassl = _actor(Bierfassl) as Bierfassl
	if not host:
		var perks: int = _player.perks.owned.size()
		var points: int = _player.points.total
		var ok: bool = await _until(func() -> bool:
				barrel.interact(_player)
				var now_perks: int = _player.perks.owned.size()
				return now_perks > perks or _player.points.total > points)
		if not ok:
			return _fail("tapping the copy gave the guest nothing")
	elif not await _until(func() -> bool: return not is_instance_valid(barrel) or not barrel.is_resting()):
		return _fail("the host's barrel was never tapped")
	print("fassl: tapped by the guest, Freibier in the guest's game")
	if not await _sync("fassl"):
		return false
	# --- the Tourist, escorted by the guest ---
	if host:
		var guest: TouristGuest = director.send_guest()
		if guest == null:
			return _fail("no Tourist")
		_player.global_position += Vector3(0.0, 0.0, 30.0)
		guest.global_position = other.global_position + Vector3.RIGHT
		await get_tree().create_timer(0.5).timeout
		guest._arrive()
	if not host:
		if not await _until(func() -> bool: return _actor(TouristGuest) != null):
			return _fail("no Tourist on the guest")
		if not await _until(func() -> bool: return _player.equipment.item != null and _player.equipment.item.id == &"eisstock"):
			return _fail("the guest never got the Eisstöcke")
		if not _banners.has(tr("EVENT_MURMEL_APPEARS")) or not _banners.has(tr("EVENT_RESI_ARRIVES")):
			return _fail("the host's banners did not come: %s" % [_banners])
	print("tourist: arrived, his Eisstöcke in the guest's game; banners came over")
	await _sync("over")
	if host:
		await get_tree().create_timer(1.0).timeout
	return true


func _chasing_enemy(waves: WaveManager) -> Enemy:
	for child: Node in waves.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive() and enemy.net_id != 0 and enemy._state == Enemy.State.CHASING and not enemy.data.is_boss:
			return enemy
	return null


func _remote_bell() -> Kuhglocke:
	for node: Node in get_tree().get_nodes_in_group("lures"):
		var bell := node as Kuhglocke
		if bell and bell._thrower is Hiker:
			return bell
	return null


func _drop() -> WeaponPickup:
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var pickup := node as WeaponPickup
		if pickup and not pickup.is_queued_for_deletion():
			return pickup
	return null


func _actor(type: Variant) -> Node:
	for node: Node in _main.find_children("*", "", true, false):
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null


func _child_with_script(parent: Node, file: String) -> bool:
	for child: Node in parent.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path.ends_with(file):
			return true
	return false


## Both sides reach `label` before either goes on.
func _sync(label: String) -> bool:
	_mark.rpc(label)
	if await _until(func() -> bool: return _marks.has(label)):
		return true
	return _fail("the other side never reached '%s'" % label)


@rpc("any_peer", "call_remote", "reliable")
func _mark(label: String) -> void:
	_marks[label] = true


@rpc("any_peer", "call_remote", "reliable")
func _note(label: String, value: int) -> void:
	_marks[label] = value


func _until(condition: Callable) -> bool:
	var left: float = TIMEOUT
	while not condition.call():
		if left <= 0.0:
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true


func _fail(why: String) -> bool:
	if _failed == "":
		_failed = why
	return false


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback
