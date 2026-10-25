extends Node
## Run: godot --headless --fixed-fps 60 res://tests/variants.tscn
## Die Bsundan (1.2), headless on the real main scene: the six rare variants are set up (data, model
## with a hat, lines, voices, banner); the wave manager's roll (from wave 5, about 3 %, never on a
## boss wave, one at a time, not twice the same); and each trick: the Kassier's fee and Kassa, the
## Sprengmeister's fuse and blast, the Schönperchte's blessing and her Tafel, the Influencer's stream
## and flash, the Bergführer's Seilschaft, the Trailrunner's charge, throw and crash; and what a
## co-op guest's puppets get.

const IDS: Array[String] = ["kassier", "bergfuehrer", "influencer", "trailrunner", "sprengmeister", "schoenperchte"]

var main: Node
var player: Player
var waves: WaveManager
var gredn: Gredn
var failures: Array[String] = []
# Damage the player took (the health is topped up again each frame).
var hurt: int = 0


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


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	gredn = main.get_node("Gredn")
	waves = main.get_node("WaveManager")
	# The waves stand still at wave 12 (enemies keep moving): the break never ends. The beer garden is
	# open, a long stretch of open ground.
	waves.wave = 12
	waves.zones.unlock(&"terrasse", null)
	waves._break_left = 1.0e9
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.health.damaged.connect(func(amount: int) -> void: hurt += amount)
	Settings.chatter = true
	gredn.always = true
	_data()
	_roll()
	await _kassier()
	await _sprengmeister()
	await _schoenperchte()
	await _influencer()
	await _bergfuehrer()
	await _trailrunner()
	await _puppets()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _data() -> void:
	var wrong: Array[String] = []
	for id: String in IDS:
		var data: EnemyData = load("res://data/enemies/%s.tres" % id)
		var model := data.model.instantiate() as Node3D
		var has_hat: bool = model.find_child("Hat", true, false) is MeshInstance3D
		model.free()
		var own: Array = Gredn.LINES.filter(func(l: Array) -> bool: return l[0] == StringName(id))
		var silent: Array = own.filter(func(l: Array) -> bool: return not Sound.has(l[3]))
		var hat_line: bool = own.any(func(l: Array) -> bool: return l[1] == Gredn.Moment.HAT)
		var banner: String = "EVENT_VARIANT_" + id.to_upper()
		var why: Array[String] = []
		if data.variant_of == null or data.variant == null or data.points_multiplier != 3.0:
			why.append("data")
		if not has_hat or not hat_line:
			why.append("hat")
		if not silent.is_empty():
			why.append("voices %s" % [silent.map(func(l: Array) -> StringName: return l[3])])
		if tr(banner) == banner or tr(data.display_name) == data.display_name:
			why.append("strings")
		if not why.is_empty():
			wrong.append("%s: %s" % [id, ", ".join(why)])
	_check(wrong.is_empty(), "the six variants each have a base, a trick, 3x points, a hat with its line, voiced lines and a banner %s" % [wrong])
	var kassier: EnemyData = load("res://data/enemies/kassier.tres")
	_check(Gredn.lines_for(kassier, Gredn.Moment.SPOT).all(func(i: int) -> bool: return Gredn.LINES[i][0] == &"kassier")
			and Gredn.lines_for(kassier, Gredn.Moment.BARRICADE).all(func(i: int) -> bool: return Gredn.LINES[i][0] == &"wanderer")
			and not Gredn.lines_for(kassier, Gredn.Moment.BARRICADE).is_empty(),
		"a variant says its own lines, and its base enemy's where it has none")
	var ok: bool = Sound.has(&"kassa_ching") and Sound.has(&"fuse_hiss") and Sound.has(&"perchten_schellen")
	_check(ok, "the new sounds are there")


func _roll() -> void:
	var table: WaveTable = waves.wave_table
	var rng := RandomNumberGenerator.new()
	_check(table.pick_variant(4, null, rng) == null, "no variant is allowed before wave 5")
	var early: Dictionary = {}
	for i: int in 200:
		early[table.pick_variant(5, null, rng).id] = true
	_check(early.keys().size() == 3 and not early.has(&"sprengmeister") and not early.has(&"schoenperchte"),
		"in wave 5 only the Kassier, the Bergführer and the Trailrunner %s" % [early.keys()])
	var late: Dictionary = {}
	var twice: bool = false
	var last: EnemyData = null
	for i: int in 400:
		var picked: EnemyData = table.pick_variant(12, last, rng)
		twice = twice or picked == last
		last = picked
		late[picked.id] = true
	_check(late.keys().size() == 6 and not twice, "from wave 10 all six, never the same twice in a row")
	var hits: int = 0
	var tries: int = 5000
	for i: int in tries:
		if waves._roll_variant():
			hits += 1
	_check(hits > tries * 0.015 and hits < tries * 0.05, "a normal spawn is a variant about 3 %% of the time (%d of %d)" % [hits, tries])
	waves.wave = 15
	var on_boss: bool = waves.wave_table.is_boss_wave(15)
	var boss_hits: int = 0
	for i: int in 500:
		if waves._roll_variant():
			boss_hits += 1
	_check(on_boss and boss_hits == 0, "never on a boss wave")
	waves.wave = 12


## Where the player stands: in the beer garden, open ground for 12 m to the east (+X).
const GARDEN := Vector3(-12.0, -0.3, 16.5)


## Sends the variant `id` in `ahead` m east of the player, facing it; the player looking at it.
func _send(id: String, ahead: float, side: float = 0.0, room: int = 0) -> Array[Enemy]:
	player.global_position = GARDEN
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	player.velocity = Vector3.ZERO
	var at := Transform3D(Basis(Vector3.UP, PI * 0.5), GARDEN + Vector3(ahead, 0.0, side))
	return waves.send_variant(load("res://data/enemies/%s.tres" % id), at, room)


## A plain enemy of the wave at `at`.
func _plain(id: String, at: Vector3) -> Enemy:
	return waves._take(load("res://data/enemies/%s.tres" % id), Transform3D(Basis.IDENTITY, at))


func _clear() -> void:
	for child: Node in waves.get_children():
		var enemy := child as Enemy
		if enemy and enemy.is_alive():
			enemy._despawn()
		# Some were held still for a check: back from the pool, they walk again.
		if enemy:
			enemy.set_physics_process(true)
	await _frames(2)


func _kassier() -> void:
	var kassier: Enemy = _send("kassier", 6.0)[0]
	_check(kassier.variant != null and waves.variant_about(), "the Kassier comes, and counts as the variant about")
	_check(waves._roll_variant() == null, "while he lives no other variant is rolled")
	player.points.total = 1000
	kassier._strike(player)
	_check(player.points.total == 1000 - Constants.KASSIER_FEE and kassier.variant.box == Constants.KASSIER_FEE,
		"his blow takes the Mitgliedsbeitrag: -%d (left %d)" % [Constants.KASSIER_FEE, player.points.total])
	player.points.total = 100
	kassier._strike(player)
	_check(player.points.total == 0, "never below 0")
	var before: int = player.points.total
	kassier.receive_hit(100000, false, false, player)
	var expected: int = roundi(Constants.POINTS_KILL_BODY * 3.0) + Constants.KASSIER_KILL + 2 * Constants.KASSIER_FEE
	_check(player.points.total - before == expected, "his kill pays 3x, %d, and every fee back: +%d (%d)" % [Constants.KASSIER_KILL, player.points.total - before, expected])
	await _clear()


func _sprengmeister() -> void:
	var spreng: Enemy = _send("sprengmeister", 5.0)[0]
	var near: Enemy = _plain("wanderer", spreng.global_position + Vector3(1.5, 0, 0))
	var far: Enemy = _plain("wanderer", spreng.global_position + Vector3(9, 0, 0))
	near.set_physics_process(false)
	far.set_physics_process(false)
	var trick = spreng.variant
	await _seconds(0.5)
	_check(trick.lit and spreng.pace() > 1.0, "with the player 5 m off in sight he lights the fuse and hurries")
	var before: int = player.points.total
	# Only the blast counts, not his blows meanwhile.
	for i: int in roundi((Constants.SPRENG_FUSE_TIME + 0.2) * 60.0):
		if spreng.is_alive():
			hurt = 0
		await _frames(1)
	_check(not spreng.is_alive(), "and goes up %.0f s later" % Constants.SPRENG_FUSE_TIME)
	_check(hurt > 0 and hurt <= Constants.SPRENG_PLAYER_DAMAGE, "the blast hurts the player near him (%d)" % hurt)
	_check(not near.is_alive() and far.is_alive(), "and kills an enemy beside him, not one 9 m off")
	_check(player.points.total == before, "a fuse that runs out pays nobody")
	await _clear()
	# Shot early, in a crowd: the blast's kills are the shooter's.
	spreng = _send("sprengmeister", 12.0)[0]
	var crowd: Array[Enemy] = [_plain("wanderer", spreng.global_position + Vector3(1.2, 0, 0)), _plain("wanderer", spreng.global_position + Vector3(-1.2, 0, 0))]
	for enemy: Enemy in crowd:
		enemy.set_physics_process(false)
	hurt = 0
	before = player.points.total
	spreng.receive_hit(100000, false, false, player)
	await _frames(2)
	var paid: int = player.points.total - before
	_check(crowd.all(func(e: Enemy) -> bool: return not e.is_alive()) and paid >= roundi(Constants.POINTS_KILL_BODY * 3.0) + 2 * Constants.POINTS_KILL_BODY,
		"shot in a crowd, his blast kills it, paid to the shooter (+%d)" % paid)
	_check(hurt == 0, "12 m away the player is not hurt")
	await _clear()


func _schoenperchte() -> void:
	var perchte: Enemy = _send("schoenperchte", 5.0)[0]
	var hurtling: Enemy = _plain("knappe", perchte.global_position + Vector3(2, 0, 2))
	hurtling.set_physics_process(false)
	hurtling.health = hurtling.max_health / 4
	var low: int = hurtling.health
	hurt = 0
	var start: Vector3 = perchte.global_position
	perchte.variant.bless_left = 99.0
	await _seconds(2.0)
	_check(hurt == 0 and Enemy._flat(perchte.global_position - start).length() < 1.0, "within 8 m she neither attacks nor comes nearer")
	perchte.variant.bless()
	_check(hurtling.health == low + roundi(hurtling.max_health * Constants.SCHOEN_HEAL), "her blessing heals an enemy near her by %d %%" % roundi(Constants.SCHOEN_HEAL * 100))
	perchte.knock_hat(Vector3.FORWARD, player)
	_check(not perchte.variant.blessing, "her Tafel shot off, the blessing is gone")
	await _seconds(2.0)
	_check(Enemy._flat(perchte.global_position - player.global_position).length() < 3.5, "and she comes for the player like a Perchte")
	await _clear()


func _influencer() -> void:
	var influencer: Enemy = _send("influencer", 10.0)[0]
	var friend: Enemy = _plain("wanderer", influencer.global_position + Vector3(3, 0, 2))
	friend.set_physics_process(false)
	var trick = influencer.variant
	var live: bool = false
	for i: int in 90:
		await _frames(1)
		live = live or trick.live
	_check(live, "10 m off with the player in sight, the Influencer goes live")
	_check(friend.is_hyped() and not influencer.is_hyped(), "the enemies near him get the Likes (faster), not he")
	# The player looks at him: the next flash dazzles.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var lens: Vector3 = influencer.mouth()
	_check(trick.dazzles(camera, lens) == (rad_to_deg((-camera.global_basis.z).angle_to(lens - camera.global_position)) <= Constants.INFLU_FLASH_ANGLE),
		"his flash dazzles only who looks at him")
	trick._dazzle()
	_check(trick.dazzled() > 0.5, "a dazzled screen goes white")
	await _seconds(Constants.INFLU_LIVE_TIME)
	_check(not trick.live and trick.cool_left > 0.0, "after %.0f s he is off air for a while" % Constants.INFLU_LIVE_TIME)
	await _clear()


func _bergfuehrer() -> void:
	var sent: Array[Enemy] = _send("bergfuehrer", 12.0, 0.0, 6)
	var leader: Enemy = sent[0]
	var rope: Array[Enemy] = sent.slice(1)
	_check(sent.size() == 1 + Constants.SEIL_FOLLOWERS and rope.all(func(e: Enemy) -> bool: return e.data.id == &"wanderer"),
		"the Bergführer comes with %d Wanderers" % Constants.SEIL_FOLLOWERS)
	_check(rope[0].roped_to == leader and rope[3].roped_to == rope[2], "roped on in a line behind him")
	await _seconds(2.0)
	_check(leader.variant.rope_shown() > 0, "the rope is drawn between them")
	var gap: float = rope[0].global_position.distance_to(leader.global_position)
	_check(gap < Constants.SEIL_GAP + 1.5, "the first walks close behind him (%.1f m)" % gap)
	rope[1].receive_hit(100000, false, false, player)
	await _frames(2)
	_check(rope[2].roped_to == rope[0], "one killed on the rope: the next is tied to the one before")
	leader.receive_hit(100000, false, false, player)
	await _frames(2)
	var tripped: bool = [rope[0], rope[2], rope[3]].all(func(e: Enemy) -> bool: return e.is_stunned() and e.roped_to == null)
	_check(tripped, "\"Seilriss!\": his death trips everyone still on the rope")
	await _clear()


func _trailrunner() -> void:
	var runner: Enemy = _send("trailrunner", 11.0)[0]
	var trick = runner.variant
	var charged: bool = false
	hurt = 0
	for i: int in 240:
		await _frames(1)
		charged = charged or trick.charging
	_check(charged and hurt > 0, "11 m off, the Trailrunner charges into the player (hurt %d)" % hurt)
	# Straight into the player: thrown along his run.
	trick.charging = true
	player.velocity = Vector3.ZERO
	trick.struck(player)
	_check(player.velocity.length() > Constants.TRAIL_THROW * 0.9, "a charge throws the player (%.1f m/s)" % player.velocity.length())
	trick.charging = false
	player.velocity = Vector3.ZERO
	trick.struck(player)
	_check(player.velocity.length() < 0.1, "a plain blow does not")
	await _clear()
	# Into a wall: down he goes.
	runner = _send("trailrunner", 11.0)[0]
	var wall := StaticBody3D.new()
	wall.collision_layer = Constants.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.0, 0.3)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	box.size = Vector3(0.3, 3.0, 6.0)
	wall.global_position = runner.global_position + Vector3(-4.0, 1.5, 0.0)
	await _frames(2)
	runner._target = player
	runner._start_lunge()
	var crashed: bool = false
	for i: int in 120:
		await _frames(1)
		crashed = crashed or runner.is_stunned()
	_check(crashed, "charging into a wall he goes down, dazed")
	wall.queue_free()
	await _clear()


func _puppets() -> void:
	# A guest's puppets: what the host's cues show.
	var kassier: Enemy = _send("kassier", 6.0)[0]
	kassier.puppet = true
	kassier.puppet_cue(&"fee", 300)
	_check(kassier.variant.kill_bonus() == Constants.KASSIER_KILL + 300, "a puppet Kassier knows the fees in his Kassa")
	var plain: Enemy = _plain("wanderer", GARDEN + Vector3(3, 0, 3))
	plain.puppet = true
	plain.health = 10
	plain.puppet_cue(&"healed", 77)
	_check(plain.health == 77, "a puppet blessed on the host gets its health")
	var runner: Enemy = _send("trailrunner", 8.0)[0]
	runner.puppet = true
	runner.puppet_cue(&"charge", true)
	player.velocity = Vector3.ZERO
	player.take_damage(1, runner)
	_check(player.velocity.length() > Constants.TRAIL_THROW * 0.9, "a guest is thrown by a charging puppet's hit, in their own game")
	for enemy: Enemy in [kassier, plain, runner]:
		enemy.puppet = false
	await _clear()
