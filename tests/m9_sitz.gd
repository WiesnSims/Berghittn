extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m9_sitz.tscn
## Headless check of Sitzfleisch (1.1.2) on the real main scene: a player who stays within
## SITZ_RADIUS of one spot for SITZ_TIME of a wave (from SITZ_FIRST_WAVE) gets a Wilderer and
## SITZ_FLOCK Bergdohlen sent after them from the nearest spawn point, counted in the wave and going
## for them over anyone else; a banner says so and the nearest enemy mocks them in dialect. Moving
## starts the clock over; early waves and the break leave them be.

const FIELD: Vector3 = Vector3(2.0, -0.3, 28.0)

var main: Node
var player: Player
var waves: WaveManager
var gredn: Gredn
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


## `seconds` of the watch, in one-second steps (the wave manager itself is held still).
func _sit(seconds: int) -> void:
	for i: int in seconds:
		waves._watch_sitzfleisch(1.0)


func _sent() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for child: Node in waves.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive() and enemy.focus == player:
			out.append(enemy)
	return out


func _run() -> void:
	for i: int in 60:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	gredn = main.get_node("Gredn")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.health.invincible_left = 9999.0
	Events.event_announced.connect(func(text: String) -> void: announced.append(text))
	player.global_position = FIELD
	player.velocity = Vector3.ZERO
	await _frames(3)
	for id: String in ["wanderer", "tourist", "knappe", "perchte", "krampus", "wilderer"]:
		var line: int = -1
		for i: int in Gredn.LINES.size():
			if Gredn.LINES[i][0] == StringName(id) and Gredn.LINES[i][1] == Gredn.Moment.SITZ:
				line = i
		_check(line >= 0 and Sound.has(Gredn.LINES[line][3]), "the %s has a Sitzfleisch line with its voice" % id)
	# Early waves and the break leave a camper be.
	waves.wave = Constants.SITZ_FIRST_WAVE - 1
	waves._phase = WaveManager.Phase.CLEARING
	_sit(roundi(Constants.SITZ_TIME) + 5)
	_check(_sent().is_empty(), "wave %d: nobody is sent" % waves.wave)
	waves.wave = Constants.SITZ_FIRST_WAVE + 1
	waves._phase = WaveManager.Phase.BREAK
	_sit(roundi(Constants.SITZ_TIME) + 5)
	_check(_sent().is_empty(), "in the break: nobody is sent")
	waves._phase = WaveManager.Phase.CLEARING
	# Someone near to mock them.
	var wanderer: Enemy = waves._create_enemy()
	wanderer.activate(load("res://data/enemies/wanderer.tres"), waves.wave, Transform3D(Basis.IDENTITY, FIELD + Vector3(6.0, 0.3, 0.0)))
	wanderer.process_mode = Node.PROCESS_MODE_DISABLED
	gredn.last_heard = -1
	var alive: int = waves._alive
	_sit(roundi(Constants.SITZ_TIME) - 1)
	_check(_sent().is_empty(), "%d s in one spot: not yet" % (roundi(Constants.SITZ_TIME) - 1))
	_sit(1)
	var sent: Array[Enemy] = _sent()
	var wilderer: int = sent.filter(func(e: Enemy) -> bool: return e.data.id == &"wilderer").size()
	var birds: int = sent.filter(func(e: Enemy) -> bool: return e.data.flies).size()
	_check(wilderer == 1 and birds == Constants.SITZ_FLOCK, "%d s: a Wilderer and %d Bergdohlen come for them" % [roundi(Constants.SITZ_TIME), birds])
	_check(waves._alive == alive + sent.size(), "counted in the wave (%d alive)" % waves._alive)
	_check(sent.all(func(e: Enemy) -> bool: return e._nearest_target() == player), "they go for the camper")
	_check(announced.has(tr("EVENT_SITZ")), "a banner: %s" % tr("EVENT_SITZ"))
	_check(gredn.last_heard >= 0 and Gredn.LINES[gredn.last_heard][0] == &"wanderer" and Gredn.LINES[gredn.last_heard][1] == Gredn.Moment.SITZ,
		"the Wanderer nearby mocks them")
	var nearest: Node3D = waves._spawn_point_near(player.global_position)
	_check(sent.all(func(e: Enemy) -> bool: return Vector2(e.global_position.x, e.global_position.z).distance_to(Vector2(nearest.global_position.x, nearest.global_position.z)) < 4.0),
		"from the nearest spawn point at least %d m away (%.0f m)" % [roundi(Constants.SITZ_SPAWN_MIN), nearest.global_position.distance_to(player.global_position)])
	# The clock starts over: after the visit, and when they move.
	_sit(roundi(Constants.SITZ_TIME) - 1)
	_check(_sent().size() == sent.size(), "the clock started over after the visit")
	player.global_position = FIELD + Vector3(Constants.SITZ_RADIUS + 1.0, 0.0, 0.0)
	_sit(1)
	_check(float(waves._sitz[player][1]) == 0.0, "moving starts it over")
	_sit(roundi(Constants.SITZ_TIME) - 1)
	_check(_sent().size() == sent.size(), "so nobody new yet")
	# The sent ones really come: the Wilderer takes aim at them.
	for enemy: Enemy in sent:
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	var hunter: Enemy = sent.filter(func(e: Enemy) -> bool: return e.data.id == &"wilderer")[0]
	var aimed: bool = false
	for i: int in 900:
		await get_tree().physics_frame
		if hunter._state == Enemy.State.AIMING and hunter._target == player:
			aimed = true
			break
	_check(aimed, "the Wilderer takes aim at them (%.0f m)" % hunter.global_position.distance_to(player.global_position))
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
