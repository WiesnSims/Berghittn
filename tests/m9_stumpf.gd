extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_stumpf.tscn
## Headless check of Stumpf (1.1.2) on the real main scene: a doppelt dengelt gun's edge lasts
## STUMPF_KILLS of our kills with it (another player's kill or a plain gun's does not count), the HUD
## shows what is left and warns when it is nearly gone; then it goes dull: dengelt again, keeping what
## ammo still fits, with a banner; the Dengelstock sharpens it again for DENGEL_RESHARPEN_COST, with a
## fresh edge. A doppelt dengelt melee weapon wears down with melee kills the same way.

var main: Node
var player: Player
var weapons: WeaponHolder
var hud: Hud
var stock: Dengelstock
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


func _weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func _kills(count: int, melee: bool = false, by: Node3D = null) -> void:
	for i: int in count:
		Events.enemy_killed.emit(null, false, melee, by if by else player)


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	weapons = player.weapons
	hud = main.get_node("UI/Hud")
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	stock = get_tree().get_first_node_in_group("dengelstocks") as Dengelstock
	await _gun()
	await _resharpen()
	_melee()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _gun() -> void:
	weapons.give_weapon(_weapon("stutzen_dengelt"))
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	_kills(5)
	_check(weapons.edge_left() == -1, "a dengelt gun has no edge to lose")
	weapons.give_weapon(_weapon("stutzen_doppelt"))
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	_check(weapons.weapon.id == &"stutzen_doppelt" and weapons.edge_left() == Constants.STUMPF_KILLS,
		"doppelt dengelt: an edge of %d kills" % weapons.edge_left())
	_check(hud._weapon_label.text.ends_with(tr("UI_EDGE") % Constants.STUMPF_KILLS), "the HUD shows it (%s)" % hud._weapon_label.text)
	var other := Node3D.new()
	add_child(other)
	_kills(10, false, other)
	other.queue_free()
	_kills(1, true)
	_check(weapons.edge_left() == Constants.STUMPF_KILLS, "another player's kills, and our melee kills, do not wear it")
	_kills(Constants.STUMPF_KILLS - Constants.STUMPF_WARN)
	_check(weapons.edge_left() == Constants.STUMPF_WARN and hud._weapon_label.text.ends_with(tr("UI_EDGE") % Constants.STUMPF_WARN),
		"our kills wear it down (%s)" % hud._weapon_label.text)
	_check(hud._banner.text == tr("UI_STUMPF_SOON") % tr("WEAPON_STUTZEN_2"), "nearly dull: a warning (%s)" % hud._banner.text)
	weapons.mag = weapons.weapon.mag_size
	weapons.reserve = 3
	var dulled: Array = []
	weapons.went_dull.connect(func(was: WeaponData, now: WeaponData) -> void: dulled.append([was, now]), CONNECT_ONE_SHOT)
	_kills(Constants.STUMPF_WARN - 1)
	_check(weapons.weapon.id == &"stutzen_doppelt" and dulled.is_empty(), "one kill left: still doppelt dengelt")
	_kills(1)
	await _frames(2)
	var dull: WeaponData = _weapon("stutzen_dengelt")
	_check(weapons.weapon == dull and dulled.size() == 1, "the %dth kill: Stumpf, the %s again" % [Constants.STUMPF_KILLS, tr(weapons.weapon.display_name)])
	_check(weapons.mag == dull.mag_size and weapons.reserve == 3, "what fits stays loaded (%d + %d)" % [weapons.mag, weapons.reserve])
	_check(weapons.gun_count() == 2 and weapons.edge_left() == -1, "in the same slot, no edge any more")
	_check(hud._banner.text == tr("UI_STUMPF") % tr("WEAPON_STUTZEN_2"), "a banner says so (%s)" % hud._banner.text)
	_check(weapons.is_dulled(dull) and weapons.is_dulled(_weapon("stutzen")), "the kind counts as gone dull")


func _resharpen() -> void:
	stock.open()
	var dull: WeaponData = weapons.weapon
	_check(Dengelstock.cost_for(player, dull) == Constants.DENGEL_RESHARPEN_COST and Dengelstock.cost_of(dull) == Constants.DENGEL_COST[1],
		"sharpening it again costs %d, not %d" % [Constants.DENGEL_RESHARPEN_COST, Constants.DENGEL_COST[1]])
	player.points.add(Constants.DENGEL_RESHARPEN_COST)
	_check(stock.prompt_for(player, false) == tr("UI_DENGEL_RESHARPEN") % [tr(dull.display_name), Constants.DENGEL_RESHARPEN_COST],
		"the anvil: \"%s\"" % stock.prompt_for(player, false))
	var before: int = player.points.total
	stock.use(player, false)
	_check(player.points.total == before - Constants.DENGEL_RESHARPEN_COST and stock.state == Dengelstock.State.FORGING, "paid %d, on the anvil" % (before - player.points.total))
	await _seconds(Constants.DENGEL_TIME + 0.2)
	stock.take(player)
	await _seconds(Constants.WEAPON_SWITCH_TIME + 0.1)
	_check(weapons.weapon.id == &"stutzen_doppelt" and weapons.edge_left() == Constants.STUMPF_KILLS and not weapons.is_dulled(dull),
		"doppelt dengelt again, with a fresh edge (%d)" % weapons.edge_left())
	_check(Dengelstock.cost_for(player, _weapon("jagdflinte_dengelt")) == Constants.DENGEL_COST[1], "a kind that never went dull pays the full price")


func _melee() -> void:
	weapons.set_melee(_weapon("schaufel_doppelt"))
	_check(weapons.edge_left(true) == Constants.STUMPF_KILLS and hud._melee_label.text.ends_with(tr("UI_EDGE") % Constants.STUMPF_KILLS),
		"the doppelt dengelt Schaufl has an edge too (%s)" % hud._melee_label.text)
	var gun_edge: int = weapons.edge_left()
	_kills(Constants.STUMPF_KILLS - 1, true)
	_check(weapons.edge_left(true) == 1 and weapons.edge_left() == gun_edge, "melee kills wear it, not the gun's")
	_kills(1, true)
	_check(weapons.melee_weapon == _weapon("schaufel_dengelt") and weapons.is_dulled(_weapon("schaufel")), "and it goes dull: the %s" % tr(weapons.melee_weapon.display_name))
