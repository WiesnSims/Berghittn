extends Node
## Run: godot --headless --fixed-fps 60 res://tests/huat.tscn
## Huat obschiaßn (1.1.3), headless on the real main scene: which enemies wear a hat; a pistol shot
## through a Wanderer's hat knocks it off for 20 points with "Mei Huat!" and a hat that flies, lands
## and later shrinks away, once; a shot at the face leaves it on; a head pop takes it along without
## hat points; a pooled enemy has it back; a co-op puppet shows it at once, asks the host and is paid
## on the host's word only; and no more than HAT_MAX hats lie about.

const WITH_HAT: Array[String] = ["wanderer", "tourist", "knappe", "wilderer", "venedigermandl"]
const WITHOUT_HAT: Array[String] = ["perchte", "krampus", "bergdohle"]

var main: Node
var player: Player
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


func _run() -> void:
	for i: int in 3:
		await get_tree().physics_frame
	get_tree().paused = false
	player = main.get_node("Player")
	gredn = main.get_node("Gredn")
	main.get_node("WaveManager").process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	Settings.chatter = true
	_models()
	await _shot_off()
	await _face_and_pop()
	await _puppet()
	await _limit()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _models() -> void:
	var wrong: Array[String] = []
	for id: String in WITH_HAT + WITHOUT_HAT:
		var model := (load("res://data/enemies/%s.tres" % id) as EnemyData).model.instantiate() as Node3D
		var hat := model.find_child("Hat", true, false) as MeshInstance3D
		if (hat != null) != (id in WITH_HAT) or (hat and hat.is_in_group(&"head_part")):
			wrong.append(id)
		model.free()
	_check(wrong.is_empty(), "Wanderer, Tourist, Knappe, Wilderer and Mandl wear a hat of their own, the rest none %s" % [wrong])
	var missing: Array[String] = []
	for id: String in WITH_HAT:
		var lines: Array = Gredn.LINES.filter(func(l: Array) -> bool: return l[0] == StringName(id) and l[1] == Gredn.Moment.HAT)
		if lines.is_empty() or lines.any(func(l: Array) -> bool: return not Sound.has(l[3])):
			missing.append(id)
	_check(missing.is_empty() and Sound.has(&"hat_off"), "each has a voiced line for it, and the hat has its sound %s" % [missing])


## An enemy outside the (disabled) wave manager, standing still `ahead` m in front of the player,
## facing away from it (or turned by `turn`).
func _enemy(id: String, ahead: float = 6.0, turn: float = 0.0) -> Enemy:
	var enemy := (main.get_node("WaveManager") as WaveManager).enemy_scene.instantiate() as Enemy
	main.add_child(enemy)
	player.global_position = Vector3(-1, 0, 2)
	player.rotation = Vector3.ZERO
	enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis(Vector3.UP, turn), Vector3(-1, 0, 2.0 - ahead)))
	enemy.set_physics_process(false)
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	return enemy


## Points the player's gun straight at `point`.
func _aim(point: Vector3) -> void:
	var head := player.get_node("Head") as Node3D
	var from: Vector3 = player.weapons.global_position
	player.rotation.y = atan2(-(point.x - from.x), -(point.z - from.z))
	head.rotation.x = 0.0
	await _frames(1)
	from = player.weapons.global_position
	var to: Vector3 = point - from
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	# The last shot's recoil settles first; then the gun's own line is put on the point.
	await _seconds(1.0)
	for i: int in 3:
		var aim: Vector3 = -player.weapons.global_basis.z
		var wanted: Vector3 = (point - player.weapons.global_position).normalized()
		head.rotation.x += asin(clampf(wanted.y, -1.0, 1.0)) - asin(clampf(aim.y, -1.0, 1.0))
		await _frames(1)
	# Areas move into place in the physics space a step later.
	await _frames(3)


func _shoot() -> void:
	var weapons: WeaponHolder = player.weapons
	var gun: WeaponData = weapons.weapon
	var spread: float = gun.spread
	var bloom: float = gun.bloom_per_shot
	gun.spread = 0.0
	gun.bloom_per_shot = 0.0
	weapons.bloom = 0.0
	weapons.mag = maxi(weapons.mag, 1)
	weapons._fire()
	gun.spread = spread
	gun.bloom_per_shot = bloom


func _hat_point(enemy: Enemy) -> Vector3:
	var shape := enemy._hat_box.get_child(0) as CollisionShape3D
	return shape.global_position


func _shot_off() -> void:
	var enemy: Enemy = _enemy("wanderer")
	_check(enemy.has_hat() and enemy._hat_box.collision_layer == Constants.LAYER_HAT, "a fresh Wanderer has his hat on, its box on the hat layer")
	await _aim(_hat_point(enemy))
	var before: int = player.points.total
	var health: int = enemy.health
	var shots: Array[int] = [0]
	Events.hat_shot.connect(func(_e: Node3D, s: Node3D) -> void: shots[0] += 1 if s == player else 0)
	gredn.last_heard = -1
	_shoot()
	var gained: int = player.points.total - before
	var hit: bool = enemy.health < health
	_check(not enemy.has_hat() and shots[0] == 1, "a shot through the hat knocks it off")
	_check(gained == Constants.POINTS_HAT + (Constants.POINTS_HIT if hit else 0), "20 points for it (and the usual 10 if it went on into the head): +%d" % gained)
	_check(not enemy._hat.visible and enemy._hat_box.collision_layer == 0, "the hat is gone from his head, and its box with it")
	_check(gredn.last_heard >= 0 and Gredn.LINES[gredn.last_heard][1] == Gredn.Moment.HAT, "he complains: \"%s\"" % (Gredn.LINES[gredn.last_heard][2] if gredn.last_heard >= 0 else "-"))
	var flying: FlyingHat = _flying_hat()
	_check(flying != null and flying.is_flying() and FlyingHat.count() == 1, "the hat flies off")
	if flying == null:
		return
	var start: Vector3 = flying.global_position
	await _seconds(2.0)
	_check(not flying.is_flying() and flying.global_position.y < 0.4 and Enemy._flat(flying.global_position - start).length() > 0.3,
		"and lands on the floor away from him (%.2f m up, %.2f m off)" % [flying.global_position.y, Enemy._flat(flying.global_position - start).length()])
	# Another shot at where the hat was: nothing more to knock off.
	before = player.points.total
	_shoot()
	_check(player.points.total - before <= Constants.POINTS_HIT and shots[0] == 1, "a second shot there pays no hat again")
	# Back from the pool: the hat is on again.
	enemy.activate(enemy.data, 1, enemy.global_transform)
	enemy.set_physics_process(false)
	_check(enemy.has_hat() and enemy._hat.visible and enemy._hat_box.collision_layer == Constants.LAYER_HAT, "a pooled Wanderer has his hat back")
	await _seconds(Constants.HAT_LIFETIME - 2.0 + Constants.HAT_SHRINK_TIME + 0.2)
	_check(not is_instance_valid(flying) and FlyingHat.count() == 0, "after %.0f s the hat on the floor shrinks away" % Constants.HAT_LIFETIME)
	enemy.queue_free()


func _face_and_pop() -> void:
	var enemy: Enemy = _enemy("tourist")
	var face: Vector3 = enemy._head_shape.global_position + Vector3.DOWN * 0.05
	await _aim(face)
	var before: int = player.points.total
	_shoot()
	_check(enemy.has_hat() and player.points.total - before == Constants.POINTS_HIT, "a shot at the face is a headshot and leaves the hat on")
	# A head pop takes the hat along, but the head was the target: no hat points.
	before = player.points.total
	enemy.receive_hit(1000, true, false, player)
	_check(not enemy.is_alive() and FlyingHat.count() == 1 and player.points.total - before == Constants.POINTS_KILL_HEADSHOT,
		"a head pop sends the hat flying too, with no points for it (+%d)" % (player.points.total - before))
	var perchte: Enemy = _enemy("perchte")
	_check(not perchte.has_hat(), "a Perchte has nothing to knock off")
	perchte.queue_free()
	await _frames(2)
	# The Knappe's helmet sits low, mostly inside the head's box: still a target, from behind too.
	for behind: bool in [true, false]:
		var knappe: Enemy = _enemy("knappe", 6.0, 0.0 if behind else PI)
		await _aim(_hat_point(knappe))
		before = player.points.total
		_shoot()
		_check(not knappe.has_hat() and player.points.total - before >= Constants.POINTS_HAT,
			"a shot at the Knappe's helmet knocks it off (%s, +%d)" % ["from behind" if behind else "facing him", player.points.total - before])
		knappe.queue_free()
		await _frames(2)


func _puppet() -> void:
	var enemy: Enemy = _enemy("knappe")
	enemy.puppet = true
	var asked: Array = []
	var saved: Callable = Enemy.hit_relay
	Enemy.hit_relay = func(e: Enemy, method: StringName, args: Array) -> void: asked.append([e, method, args])
	var hats: int = FlyingHat.count()
	var before: int = player.points.total
	enemy.knock_hat(Vector3.FORWARD, player)
	_check(not enemy.has_hat() and FlyingHat.count() == hats + 1, "co-op: our shot knocks a puppet's helmet off at once")
	_check(asked.size() == 1 and asked[0][1] == &"knock_hat" and player.points.total == before, "and asks the host, paying nothing yet")
	enemy.puppet_hat(Vector3.FORWARD, player)
	_check(player.points.total - before == Constants.POINTS_HAT and FlyingHat.count() == hats + 1, "the host's word pays 20, and no second helmet flies")
	var other := _enemy("wilderer")
	other.puppet = true
	var someone := Node3D.new()
	add_child(someone)
	before = player.points.total
	other.puppet_hat(Vector3.LEFT, someone)
	_check(not other.has_hat() and player.points.total == before, "another player's hat shot shows here, paid to them")
	Enemy.hit_relay = saved
	enemy.puppet = false
	other.puppet = false


func _limit() -> void:
	var enemy: Enemy = _enemy("wanderer")
	for i: int in Constants.HAT_MAX + 3:
		enemy.activate(enemy.data, 1, enemy.global_transform)
		enemy.set_physics_process(false)
		enemy.knock_hat(Vector3.FORWARD, null)
	await _frames(2)
	_check(FlyingHat.count() == Constants.HAT_MAX, "never more than %d hats about (%d)" % [Constants.HAT_MAX, FlyingHat.count()])


func _flying_hat() -> FlyingHat:
	for node: Node in main.find_children("FlyingHat*", "", true, false):
		if node is FlyingHat:
			return node
	return null
