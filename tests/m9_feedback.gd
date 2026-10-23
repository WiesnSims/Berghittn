extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_feedback.tscn
## M9 part 2, headless: the kill streaks and their bonus points (a chain of 3, 5 and 8; more than one
## with one shot; every third headshot kill in a row), another player's kills and a broken chain
## not counting, the kill marker and the streak banner, and damage numbers only with the setting on.

var failures: Array[String] = []
var _streaks: Array[String] = []
var _kills: int = 0


func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().physics_frame
	var player := main.get_node("Player") as Player
	# main starts in its (pausing) menu.
	get_tree().paused = false
	# Nothing comes to eat us while the test waits out its pauses.
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("EventDirector") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var feedback: KillFeedback = player.feedback
	feedback.streak.connect(func(text: String, _bonus: int) -> void: _streaks.append(text))
	feedback.killed.connect(func(_head: bool) -> void: _kills += 1)
	var saved: bool = Settings.damage_numbers

	# A chain of 8 body kills, half a second apart.
	var before: int = player.points.total
	for i: int in 8:
		if i > 0:
			await _wait(0.5)
		_kill(player, false)
	var paid: int = player.points.total - before - 8 * Constants.POINTS_KILL_BODY
	_check(_streaks == ["STREAK_DREIERPACK", "STREAK_GMETZL", "STREAK_BLUATBAD"], "a chain of 8: Dreierpack, Gmetzl, Bluatbad (%s)" % [_streaks])
	_check(paid == Constants.STREAK_BONUS_3 + Constants.STREAK_BONUS_5 + Constants.STREAK_BONUS_8, "their bonus points were paid (%d)" % paid)
	_check(_kills == 8, "a kill marker for every kill")
	var hud := main.get_node("UI/Hud") as Hud
	_check(hud._streak_label.text == tr("UI_STREAK") % [tr("STREAK_BLUATBAD"), Constants.STREAK_BONUS_8] and hud._streak_label.modulate.a > 0.5, "the banner under the crosshair says '%s'" % hud._streak_label.text)
	_check((hud.get_node("%Crosshair") as Crosshair)._kill_left > 0.0, "the crosshair shows the kill X")

	# A pause breaks the chain; someone else's kills count for nothing.
	_streaks.clear()
	await _wait(Constants.KILL_STREAK_GAP + 0.5)
	var other := Node3D.new()
	add_child(other)
	for i: int in 3:
		Events.enemy_killed.emit(null, true, false, other)
	_kill(player, false)
	await _wait(0.5)
	_kill(player, false)
	_check(feedback.chain == 2 and _streaks.is_empty(), "the chain starts over after a pause, others' kills not counted (chain %d)" % feedback.chain)

	# Three with one shot: two times the multi bonus, one banner; it also makes the chain 5.
	await _wait(Constants.KILL_STREAK_GAP + 0.5)
	_streaks.clear()
	before = player.points.total
	for i: int in 3:
		_kill(player, false)
	paid = player.points.total - before - 3 * Constants.POINTS_KILL_BODY
	_check(_streaks == ["STREAK_ZWOA", "STREAK_DREIERPACK"], "three with one shot: Zwoa auf oan Streich, then the chain's Dreierpack (%s)" % [_streaks])
	_check(paid == 2 * Constants.STREAK_BONUS_MULTI + Constants.STREAK_BONUS_3, "two multi bonuses and the Dreierpack (%d)" % paid)

	# Headshots in a row, broken by a body shot.
	await _wait(Constants.KILL_STREAK_GAP + 0.5)
	_streaks.clear()
	for head: bool in [true, true, false, true, true, true]:
		_kill(player, head)
		await _wait(Constants.KILL_STREAK_GAP + 0.5)
	_check(_streaks == ["STREAK_SCHAEDLWEH"], "Schädlweh only for three headshot kills in a row (%s)" % [_streaks])

	# Damage numbers: off by default, there with the setting.
	var target := Node3D.new()
	main.add_child(target)
	Settings.damage_numbers = false
	var count: int = main.get_child_count()
	Events.enemy_damaged.emit(target, 40, false, player)
	_check(main.get_child_count() == count, "no damage number with the setting off")
	Settings.damage_numbers = true
	Events.enemy_damaged.emit(target, 40, true, player)
	Events.enemy_damaged.emit(target, 40, true, other)
	_check(main.get_child_count() == count + 1, "one number for our hit, none for another player's")
	var number := main.get_child(count) as Node3D
	_check(number.get_child(0) is Label3D and (number.get_child(0) as Label3D).text == "40", "it shows the damage")
	await _wait(Constants.DAMAGE_NUMBER_TIME + 0.2)
	_check(main.get_child_count() == count, "and is gone after %.1f s" % Constants.DAMAGE_NUMBER_TIME)
	Settings.damage_numbers = saved
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _kill(player: Player, head: bool) -> void:
	Events.enemy_killed.emit(null, head, false, player)


func _wait(seconds: float) -> void:
	var frames: int = roundi(seconds * Engine.physics_ticks_per_second)
	for i: int in frames:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)
