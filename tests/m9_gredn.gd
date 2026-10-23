extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_gredn.tscn
## Headless check of the talking enemies (M9 part 3, Gredn) on the real main scene: every line has
## its voice; an enemy that sees the player says its SPOT line, with the text over its head; one line
## per enemy every 20 s and one every ~3 s overall; a light hit says nothing, a hard one may; last
## words instead of the death cry; nothing from an enemy far from every player; the nearest two lines
## at most on screen; nothing with the chatter setting off.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)

var main: Node
var player: Player
var waves: WaveManager
var gredn: Gredn
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
		player.health._health = float(player.health.max_health)


func _seconds(time: float) -> void:
	await _frames(roundi(time * 60.0))


func _ground(offset: Vector3) -> Vector3:
	var at: Vector3 = FIELD + offset
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, Constants.LAYER_WORLD)
	var hit: Dictionary = main.get_viewport().world_3d.direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else at


func _spawn(id: String, offset: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	var at: Vector3 = _ground(offset)
	enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.data = enemy.data.duplicate()
	enemy.data.speed = 0.0
	enemy.global_position = at
	# No groans (and so no idle lines) in the middle of a check.
	enemy._groan_left = 999.0
	return enemy


func _line_of(enemy: Enemy, moment: Gredn.Moment) -> bool:
	var line: Array = Gredn.LINES[gredn.last_heard] if gredn.last_heard >= 0 else []
	return not line.is_empty() and line[0] == enemy.data.id and line[1] == moment


func _quiet() -> void:
	gredn._gap_left = 0.0
	gredn.last_heard = -1


func _clear() -> void:
	for child: Node in waves.get_children():
		var e := child as Enemy
		if e and e.is_alive():
			e._take_hit(1000000, false, false, null)
	for child: Node in gredn.get_children():
		child.queue_free()
	await _seconds(Constants.ENEMY_CORPSE_TIME + 0.5)


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	gredn = main.get_node("Gredn")
	(player.get_node("Head/Camera3D") as Camera3D).make_current()
	player.global_position = _ground(Vector3.ZERO)
	var saved: bool = Settings.chatter
	Settings.chatter = true
	await _frames(2)

	# Every line has its voice and a moment of its own enemy; every enemy has lines; co-op sends the
	# index in a byte.
	var voiceless: Array = Gredn.LINES.filter(func(l: Array) -> bool: return not Sound.has(l[3]))
	_check(voiceless.is_empty(), "every line has its voice (%s)" % [voiceless])
	_check(Gredn.LINES.size() <= 256, "%d lines fit a byte" % Gredn.LINES.size())
	for id: String in ["wanderer", "tourist", "knappe", "perchte", "krampus"]:
		_check(Gredn.LINES.any(func(l: Array) -> bool: return l[0] == StringName(id) and l[1] == Gredn.Moment.SPOT), "%s has a line on seeing a player" % id)

	gredn.always = true
	_quiet()
	# Sees the player 6 m off: its SPOT line, heard and over its head.
	var near: Enemy = _spawn("wanderer", Vector3(6, 0, 0))
	near.data.speed = 0.0
	await _frames(5)
	_check(_line_of(near, Gredn.Moment.SPOT) and gredn.shown() == 1, "seeing the player: \"%s\"" % (Gredn.LINES[gredn.last_heard][2] if gredn.last_heard >= 0 else "nothing"))
	var label := gredn.get_child(0) as Node3D
	_check(label != null and absf(label.global_position.y - near.global_position.y - Constants.GREDN_HEIGHT) < 0.05, "the text rides over its head")
	_check(near.talk_left > Constants.GREDN_ENEMY_GAP - 1.0 and near._speaking_left > 0.0, "it waits 20 s for the next and does not groan over this one")

	# The same enemy, hit hard right after: nothing (20 s each); another one: not within ~3 s.
	_quiet()
	near.health = 10000
	near.max_health = 10000
	near._take_hit(5000, false, false, null)
	_check(gredn.last_heard == -1, "the same enemy says nothing for 20 s")
	var other: Enemy = _spawn("knappe", Vector3(5, 0, 3))
	other._spotted = true
	await _frames(2)
	_quiet()
	other.max_health = 10000
	other.health = 10000
	gredn._gap_left = Constants.GREDN_GAP_MIN
	other._take_hit(5000, false, false, null)
	_check(gredn.last_heard == -1, "nobody else within ~3 s of a line")
	await _seconds(Constants.GREDN_GAP_MIN + 0.1)
	# A light hit is no reason to talk; a hard one is.
	other._take_hit(500, false, false, null)
	_check(gredn.last_heard == -1, "a light hit says nothing")
	other._take_hit(4000, false, false, null)
	_check(_line_of(other, Gredn.Moment.HIT), "a hard hit: \"%s\"" % (Gredn.LINES[gredn.last_heard][2] if gredn.last_heard >= 0 else "nothing"))

	# Last words instead of the death cry.
	var dying: Enemy = _spawn("tourist", Vector3(4, 0, -3))
	dying._spotted = true
	await _frames(2)
	_quiet()
	dying._take_hit(1000000, false, false, null)
	_check(_line_of(dying, Gredn.Moment.DEATH) and dying._speaking_left > 0.0, "dying: \"%s\" (no cry over it)" % (Gredn.LINES[gredn.last_heard][2] if gredn.last_heard >= 0 else "nothing"))
	await _clear()

	# Far from every player: nothing, not even on dying.
	_quiet()
	var far: Enemy = _spawn("wanderer", Vector3(Constants.GREDN_REACH + 5.0, 0, 0))
	await _frames(5)
	far._take_hit(1000000, false, false, null)
	_check(gredn.last_heard == -1 and gredn.shown() == 0, "nothing from %d m away" % roundi(Constants.GREDN_REACH + 5.0))
	await _clear()

	# Three talk at once: the nearest two show; a nearer fourth takes the farther one's place.
	_quiet()
	var at4: Enemy = _spawn("wanderer", Vector3(4, 0, 0))
	var at8: Enemy = _spawn("tourist", Vector3(8, 0, 2))
	var at12: Enemy = _spawn("knappe", Vector3(12, 0, -2))
	for e: Enemy in [at4, at8, at12]:
		e._spotted = true
	gredn.say(at4, 0)
	gredn.say(at8, 6)
	gredn.say(at12, 12)
	_check(gredn.shown() == 2 and gredn.last_heard == 6, "three at once: the nearest two show (%d)" % gredn.shown())
	var at3: Enemy = _spawn("krampus", Vector3(3, 0, 1))
	at3._spotted = true
	gredn.say(at3, 20)
	await _frames(1)
	var showing: Array = gredn._shown.map(func(s: Array) -> Enemy: return s[0])
	_check(gredn.shown() == 2 and at3 in showing and at4 in showing and not at8 in showing, "a nearer one takes the farther one's place")
	await _clear()

	# The chatter setting off: nothing heard or shown.
	_quiet()
	Settings.chatter = false
	var hushed: Enemy = _spawn("wanderer", Vector3(5, 0, 0))
	await _frames(5)
	_check(gredn.last_heard == -1 and gredn.shown() == 0 and hushed._speaking_left <= 0.0, "chatter off: not a word")
	Settings.chatter = saved
	gredn.always = false
	await _clear()

	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
