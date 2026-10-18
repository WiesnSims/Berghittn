extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m6_ragdoll.tscn
## Headless check of the enemy models and ragdolls (M6 part 4, #39) on the real main scene: every
## enemy model is a rig built at its size (a skeleton, skinned body and head, the head poppable, a
## ragdoll that is off while it walks), all of them inside the 3 MB model budget; the head hurtbox
## follows the head; a swing raises the arms; a kill turns the body into a ragdoll whose joints hold,
## thrown away from the shooter, frozen after a while and back to a living pose from the pool; and
## a crowd killed at once never simulates more than RAGDOLL_MAX corpses.

const FIELD: Vector3 = Vector3(10.0, -0.3, 31.0)
const IDS: Array[String] = ["wanderer", "tourist", "knappe", "perchte", "krampus"]
const MODELS_DIR: String = "res://assets/models"
const MODEL_BUDGET: int = 3 * 1024 * 1024

var main: Node
var player: Player
var waves: WaveManager
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


func _spawn(id: String, at: Vector3) -> Enemy:
	var enemy: Enemy = waves._create_enemy()
	enemy.activate(load("res://data/enemies/%s.tres" % id), 1, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	return enemy


func _run() -> void:
	await _frames(3)
	get_tree().paused = false
	player = main.get_node("Player")
	waves = main.get_node("WaveManager")
	waves.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("EventDirector").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = FIELD + Vector3(0.0, 0.3, -12.0)
	await _frames(5)
	_models()
	_budget()
	await _head_follows()
	await _swing()
	await _ragdoll()
	await _crowd()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _models() -> void:
	for id: String in IDS:
		var data: EnemyData = load("res://data/enemies/%s.tres" % id)
		var rig := data.model.instantiate() as EnemyRig
		_check(rig != null, "%s model is an EnemyRig" % id)
		if rig == null:
			continue
		var skeleton := rig.get_node_or_null("Skeleton") as Skeleton3D
		var head := rig.get_node_or_null("Skeleton/Head") as MeshInstance3D
		var body := rig.get_node_or_null("Skeleton/Body") as MeshInstance3D
		var ragdoll := rig.get_node_or_null("Skeleton/Ragdoll") as PhysicalBoneSimulator3D
		_check(skeleton != null and skeleton.get_bone_count() == 15, "%s has the 15-bone skeleton" % id)
		_check(body != null and body.skin != null and head != null and head.is_in_group(&"head_part"),
				"%s has a skinned body and a poppable head" % id)
		_check(ragdoll != null and ragdoll.get_child_count() == 11 and ragdoll.process_mode == Node.PROCESS_MODE_DISABLED,
				"%s has an 11-body ragdoll, off until it dies" % id)
		_check(is_equal_approx(rig.build_scale, data.model_scale) and rig.scale == Vector3.ONE,
				"%s is built at its scale (%.2f), not scaled" % [id, data.model_scale])
		if skeleton:
			var neck: float = skeleton.get_bone_rest(skeleton.find_bone("head")).origin.y + skeleton.get_bone_rest(skeleton.find_bone("chest")).origin.y + skeleton.get_bone_rest(0).origin.y
			_check(absf(neck - 1.5 * data.model_scale) < 0.02, "%s neck at %.2f m" % [id, neck])
		rig.free()


func _budget() -> void:
	var total: int = 0
	var dirs: Array[String] = [MODELS_DIR]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file: String in DirAccess.get_files_at(dir):
			total += FileAccess.get_file_as_bytes(dir.path_join(file)).size()
	_check(total > 0 and total < MODEL_BUDGET, "models take %.2f MiB of the 3 MB budget" % (total / 1048576.0))


func _head_follows() -> void:
	# The Perchte hunches: its head is well forward of where it stands.
	var enemy: Enemy = _spawn("perchte", FIELD)
	enemy.set_physics_process(true)
	await _frames(20)
	var head: Vector3 = enemy._rig.head_position()
	_check(enemy._head_shape.global_position.distance_to(head) < 0.01, "the head hurtbox sits on the head")
	var forward: float = (head - enemy.global_position).dot(-enemy.global_basis.z)
	_check(forward > 0.1, "the Perchte's head is hunched forward (%.2f m)" % forward)
	enemy.receive_hit(100000, false, false, null)
	await _frames(2)
	enemy._despawn()


func _swing() -> void:
	var enemy: Enemy = _spawn("wanderer", FIELD)
	var rig: EnemyRig = enemy._rig
	# Measured at the hand: past 90 degrees an arm's Euler angles come apart.
	var hand: int = rig.skeleton.find_bone("hand_l")
	var before: float = rig.skeleton.get_bone_global_pose(hand).origin.y
	enemy._start_attack()
	await _frames(roundi(enemy.data.attack_windup * 60.0))
	var rise: float = rig.skeleton.get_bone_global_pose(hand).origin.y - before
	_check(rise > 0.25, "the swing raises the arms (the hand %.2f m higher)" % rise)
	enemy.receive_hit(100000, false, false, null)
	await _frames(2)
	enemy._despawn()


## How far each ragdoll body's joint is from where its parent body puts it (metres, the worst one).
func _worst_gap(rig: EnemyRig) -> float:
	var skeleton: Skeleton3D = rig.skeleton
	var bones: Dictionary = {}
	for node: Node in rig.get_node("Skeleton/Ragdoll").get_children():
		var body := node as PhysicalBone3D
		bones[body.bone_name] = body.global_transform * body.body_offset.affine_inverse()
	var worst: float = 0.0
	for bone: StringName in bones:
		var index: int = skeleton.find_bone(bone)
		var parent := StringName(skeleton.get_bone_name(skeleton.get_bone_parent(index))) if skeleton.get_bone_parent(index) >= 0 else &""
		if not bones.has(parent):
			continue
		var expected: Vector3 = (bones[parent] as Transform3D) * skeleton.get_bone_rest(index).origin
		worst = maxf(worst, expected.distance_to((bones[bone] as Transform3D).origin))
	return worst


func _ragdoll() -> void:
	for id: String in IDS:
		var enemy: Enemy = _spawn(id, FIELD)
		await _frames(5)
		var rig: EnemyRig = enemy._rig
		var chest := rig.get_node("Skeleton/Ragdoll/chest") as PhysicalBone3D
		var start: float = player.global_position.distance_to(enemy.global_position)
		enemy.receive_hit(100000, false, false, player)
		_check(rig.is_ragdoll(), "%s goes limp when killed" % id)
		await _frames(60)
		_check(_worst_gap(rig) < 0.06, "%s's ragdoll joints hold (worst gap %.3f m)" % [id, _worst_gap(rig)])
		_check(player.global_position.distance_to(chest.global_position) > start + 0.3,
				"%s is thrown away from the shooter" % id)
		_check(chest.global_position.y < enemy.global_position.y + 0.6 * enemy.data.model_scale, "%s has fallen down" % id)
		await _frames(roundi((Constants.RAGDOLL_TIME - 1.0) * 60.0) + 5)
		_check(not rig.is_ragdoll() and rig.is_down(), "%s is frozen where it fell" % id)
		await _frames(roundi((Constants.ENEMY_CORPSE_TIME - Constants.RAGDOLL_TIME + Constants.ENEMY_DEATH_FALL_TIME) * 60.0) + 10)
		_check(not enemy.is_alive() and not enemy.visible, "%s's corpse is gone" % id)
		enemy = _spawn(id, FIELD)
		_check(not enemy._rig.is_down() and enemy._rig.get_node("Skeleton/Ragdoll").process_mode == Node.PROCESS_MODE_DISABLED,
				"%s comes back from the pool standing" % id)
		enemy.receive_hit(100000, false, false, null)
		await _frames(2)
		enemy._despawn()


func _crowd() -> void:
	var crowd: Array[Enemy] = []
	for i: int in 12:
		crowd.append(_spawn(IDS[i % 4], FIELD + Vector3((i % 4) * 1.2 - 2.0, 0.0, (i / 4) * 1.2)))
	await _frames(5)
	for enemy: Enemy in crowd:
		enemy.receive_hit(100000, false, false, player)
	var most: int = 0
	for i: int in 120:
		await get_tree().physics_frame
		most = maxi(most, crowd.filter(func(e: Enemy) -> bool: return e._rig.is_ragdoll()).size())
	_check(most <= Constants.RAGDOLL_MAX and most > 0, "a crowd of 12 killed at once simulates %d ragdolls (max %d)" % [most, Constants.RAGDOLL_MAX])
	_check(crowd.all(func(e: Enemy) -> bool: return not e.is_alive()), "the whole crowd is dead")
	for enemy: Enemy in crowd:
		enemy._despawn()
