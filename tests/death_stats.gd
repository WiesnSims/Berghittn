extends Node
## Run: godot --headless --fixed-fps 60 res://tests/death_stats.tscn
## Headless check of the death screen's run: only our own kills count, headshots and their share,
## the favourite weapon is the one with the most kills (melee kills go to the melee weapon), every
## Schnaps counts (again after going down), the personal best keeps the further wave (or more points
## on the same wave), and the screen shows it all. The saved personal best is put back after.

const FLINTE := preload("res://data/weapons/jagdflinte.tres")
const PISTOLE := preload("res://data/weapons/pistole.tres")
const ENZIAN := preload("res://data/perks/enzian.tres")
const OBSTLER := preload("res://data/perks/obstler.tres")

var failures: Array[String] = []


func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().physics_frame
	var player := main.get_node("Player") as Player
	var saved: Array[int] = [Settings.best_wave, Settings.best_points]
	_run_stats(player)
	_record()
	Settings.best_wave = 7
	Settings.best_points = 9000
	var screen := main.get_node("UI/DeathScreen") as DeathScreen
	screen.present(5, 4200, player.stats, Settings.record_run(5, 4200))
	_check(screen.visible, "the death screen shows")
	_check((screen.get_node("%Kills") as Label).text == "5" and (screen.get_node("%Schnaps") as Label).text == "3", "it shows kills and Schnaps")
	_check((screen.get_node("%Headshots") as Label).text == tr("UI_DEATH_SHARE") % [2, 40], "it shows headshots and their share")
	_check((screen.get_node("%Favourite") as Label).text == tr("UI_DEATH_WEAPON") % [tr(FLINTE.display_name), 3], "it shows the favourite weapon and its kills")
	_check(not (screen.get_node("%NewBest") as Label).visible and (screen.get_node("%Best") as Label).text == tr("UI_DEATH_BEST") % [7, 9000], "a worse run shows the old personal best")
	screen.present(8, 100, player.stats, Settings.record_run(8, 100))
	_check((screen.get_node("%NewBest") as Label).visible and not (screen.get_node("%Best") as Label).visible, "a better run shows New personal best")
	Settings.best_wave = saved[0]
	Settings.best_points = saved[1]
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run_stats(player: Player) -> void:
	var stats: PlayerStats = player.stats
	_check(stats.kills == 0 and stats.favourite() == null, "a fresh run has no kills and no favourite")
	player.weapons.give_weapon(FLINTE)
	Events.enemy_killed.emit(null, true, false, player)
	Events.enemy_killed.emit(null, false, false, player)
	Events.enemy_killed.emit(null, true, false, player)
	var other := Node3D.new()
	Events.enemy_killed.emit(null, true, false, other)
	other.free()
	player.weapons.give_weapon(PISTOLE)
	Events.enemy_killed.emit(null, false, false, player)
	Events.enemy_killed.emit(null, false, true, player)
	_check(stats.kills == 5 and stats.headshots == 2, "5 kills of ours, 2 of them headshots (another player's kill not counted)")
	_check(stats.favourite() == FLINTE and stats.kills_with(FLINTE) == 3, "the Jagdflinte is the favourite with 3")
	_check(stats.kills_with(PISTOLE) == 1 and stats.kills_with(player.weapons.melee_weapon) == 1, "the melee kill goes to the melee weapon")
	player.perks.add(ENZIAN)
	player.perks.add(ENZIAN)
	player.perks.add(OBSTLER)
	player.perks.clear()
	player.perks.add(ENZIAN)
	_check(stats.schnaps == 3, "3 Schnaps: one owned twice counts once, again after going down")


func _record() -> void:
	Settings.best_wave = 0
	Settings.best_points = 0
	_check(Settings.record_run(4, 3000), "the first run is a personal best")
	_check(not Settings.record_run(3, 99999), "an earlier wave is not, whatever the points")
	_check(not Settings.record_run(4, 3000), "the same wave and points are not")
	_check(Settings.record_run(4, 3500) and Settings.best_points == 3500, "the same wave with more points is")
	_check(Settings.record_run(6, 10) and Settings.best_wave == 6 and Settings.best_points == 10, "a further wave is, with that run's points")
