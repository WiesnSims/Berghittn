class_name EnemyRig
extends Node3D
## The skeleton of an enemy model (M6 part 4, built by tools/models): poses its bones in code (the
## stance it stands in, the walk, and one action at a time: a swing, ripping a board out, a dive
## through a window, the Perchte's crouch and leap, a dance, being dazed, deafened or carried), and turns it
## into a ragdoll when it dies. Bones rotate around the model's own axes (their rest has no turn):
## +X swings a limb forward, -X leans the chest forward, Z spreads an arm.

enum Action { NONE, STRIKE, PULL, CLIMB, CROUCH, LEAP, DANCE, DAZED, CARRIED, DEAFENED }

## Degrees per bone that it stands in (a zombie's arms forward, a hunch).
@export var stance: Dictionary = {}
## Degrees the thighs swing at a full stride, and the arms with them.
@export var stride: float = 28.0
@export var arm_swing: float = 12.0
## Strides per metre walked.
@export var cadence: float = 1.6
## A swing with the right arm only (a weapon in hand), not both.
@export var one_handed: bool = false
## How big it was built against the standard figure (EnemyData.model_scale).
@export var build_scale: float = 1.0

@onready var skeleton: Skeleton3D = $Skeleton
@onready var _ragdoll: PhysicalBoneSimulator3D = $Skeleton/Ragdoll

var _bones: Dictionary = {}
var _rests: Dictionary = {}
# Current and wanted angles (radians) per bone.
var _current: Dictionary = {}
var _phase: float = 0.0
var _walk: float = 0.0
var _action: Action = Action.NONE
var _action_time: float = 0.0
var _action_length: float = 1.0
var _hips_drop: float = 0.0
var _simulating: bool = false
var _frozen: bool = false
var _head_index: int = -1


func _ready() -> void:
	for i: int in skeleton.get_bone_count():
		var bone := StringName(skeleton.get_bone_name(i))
		_bones[bone] = i
		_rests[bone] = skeleton.get_bone_rest(i)
		_current[bone] = _stance(bone)
	_head_index = _bones.get(&"head", -1)
	pose_now()


## Starts an action, lasting `length` seconds (looping ones, dance and carried, until the next).
func play(action: Action, length: float = 1.0) -> void:
	_action = action
	_action_time = 0.0
	_action_length = maxf(length, 0.01)


func stop() -> void:
	_action = Action.NONE


## One step of the pose, walking at `speed` m/s on the flat.
func update(delta: float, speed: float) -> void:
	if _simulating or _frozen:
		return
	_action_time += delta
	if _action_time > _action_length and _action not in [Action.DANCE, Action.CARRIED, Action.CLIMB, Action.DAZED]:
		_action = Action.NONE
	_phase += speed * delta * cadence * PI
	_walk = move_toward(_walk, clampf(speed / 2.0, 0.0, 1.0), delta * 4.0)
	var blend: float = 1.0 - exp(-delta * (22.0 if _action == Action.STRIKE else 12.0))
	for bone: StringName in _bones:
		_current[bone] = (_current[bone] as Vector3).lerp(_target(bone), blend)
		skeleton.set_bone_pose_rotation(_bones[bone], Quaternion.from_euler(_current[bone]))
	var rest: Transform3D = _rests[&"hips"]
	var bob: float = absf(sin(_phase)) * 0.05 * _walk
	_hips_drop = lerpf(_hips_drop, _drop(), blend)
	skeleton.set_bone_pose_position(_bones[&"hips"], rest.origin + Vector3.UP * (bob - _hips_drop) * build_scale)


## Straight into the stance, no blending (a fresh spawn from the pool).
func pose_now() -> void:
	_action = Action.NONE
	_walk = 0.0
	_hips_drop = 0.0
	for bone: StringName in _bones:
		_current[bone] = _stance(bone)
		skeleton.set_bone_pose_rotation(_bones[bone], Quaternion.from_euler(_current[bone]))
	skeleton.set_bone_pose_position(_bones[&"hips"], (_rests[&"hips"] as Transform3D).origin)


## Where the head is now, for the head hurtbox and the head pop (the centre of its skull).
func head_position() -> Vector3:
	var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_head_index)
	return pose * (Vector3.UP * 0.12 * build_scale)


## Goes limp: the bones are handed to physics, pushed by `push` (m/s) at the chest. False if
## the ragdoll is not set up.
func start_ragdoll(push: Vector3) -> bool:
	if _ragdoll == null:
		return false
	_simulating = true
	_frozen = false
	_ragdoll.process_mode = Node.PROCESS_MODE_INHERIT
	for body: PhysicalBone3D in _bodies():
		var index: int = _bones[body.bone_name]
		body.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(index) * body.body_offset
	# A joint is made as its body enters the tree; made while the ragdoll was off (out of the physics
	# space, so it costs nothing while the enemy walks) it holds nothing. So each body enters again,
	# parents first.
	for body: PhysicalBone3D in _bodies():
		_ragdoll.remove_child(body)
		_ragdoll.add_child(body)
	_ragdoll.physical_bones_start_simulation()
	for body: PhysicalBone3D in _bodies():
		var share: float = 1.0 if body.bone_name == &"chest" else 0.6 if body.bone_name == &"head" else 0.35
		body.linear_velocity = push * share
	return true


func is_ragdoll() -> bool:
	return _simulating


## A corpse in ragdoll pose, still falling or frozen.
func is_down() -> bool:
	return _simulating or _frozen


## Stops the physics and keeps the pose it has come to rest in.
func freeze() -> void:
	if not _simulating:
		return
	var poses: Dictionary = {}
	var inverse: Transform3D = skeleton.global_transform.affine_inverse()
	for body: PhysicalBone3D in _bodies():
		poses[body.bone_name] = inverse * body.global_transform * body.body_offset.affine_inverse()
	_ragdoll.physical_bones_stop_simulation()
	_ragdoll.process_mode = Node.PROCESS_MODE_DISABLED
	_simulating = false
	_frozen = true
	# Parents before children (the builder's order): each pose is the bone against its parent.
	var globals: Dictionary = {}
	for i: int in skeleton.get_bone_count():
		var bone := StringName(skeleton.get_bone_name(i))
		var parent: int = skeleton.get_bone_parent(i)
		var parent_global: Transform3D = globals[parent] if parent >= 0 else Transform3D.IDENTITY
		var global: Transform3D
		if poses.has(bone):
			global = poses[bone]
		else:
			global = parent_global * skeleton.get_bone_pose(i)
		globals[i] = global
		var local: Transform3D = parent_global.affine_inverse() * global
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())


## Back to a living pose after the pool takes the corpse back.
func reset() -> void:
	if _simulating:
		_ragdoll.physical_bones_stop_simulation()
		_ragdoll.process_mode = Node.PROCESS_MODE_DISABLED
	_simulating = false
	_frozen = false
	skeleton.reset_bone_poses()
	pose_now()


func _bodies() -> Array[PhysicalBone3D]:
	var bodies: Array[PhysicalBone3D] = []
	for node: Node in _ragdoll.get_children():
		if node is PhysicalBone3D:
			bodies.append(node)
	return bodies


func _stance(bone: StringName) -> Vector3:
	var degrees: Vector3 = stance.get(bone, Vector3.ZERO)
	return degrees * (PI / 180.0)


## How far the hips sink (scale 1 metres): crouching for the leap, or squatting in the dance.
func _drop() -> float:
	match _action:
		Action.CROUCH:
			return 0.22
		Action.DANCE:
			return 0.1 * (0.5 + 0.5 * sin(_action_time * 12.0))
		Action.DEAFENED:
			return 0.08
	return 0.0


func _target(bone: StringName) -> Vector3:
	var angle: Vector3 = _stance(bone)
	var s: float = sin(_phase)
	var walk: float = _walk
	if _action in [Action.CLIMB, Action.CARRIED, Action.DANCE, Action.LEAP, Action.CROUCH, Action.DEAFENED]:
		walk = 0.0
	var side: float = -1.0 if String(bone).ends_with("_r") else 1.0
	var limb: String = String(bone).trim_suffix("_l").trim_suffix("_r")
	# Walking: legs swing in turn, the knee bends as the foot comes through, the arms swing against them.
	match limb:
		"thigh":
			angle.x += deg_to_rad(stride) * s * side * walk
		"shin":
			angle.x -= deg_to_rad(stride * 1.4) * maxf(0.0, -s * side) * walk
		"arm":
			angle.x -= deg_to_rad(arm_swing) * s * side * walk
		"chest":
			angle.y += deg_to_rad(4.0) * s * walk
	var t: float = clampf(_action_time / _action_length, 0.0, 1.0)
	match _action:
		Action.STRIKE:
			angle = _strike(limb, side, t, angle)
		Action.PULL:
			# Reach in, then rip the board out and stagger back with it.
			var reach: float = t / 0.55 if t < 0.55 else 1.0 - (t - 0.55) / 0.45
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(lerpf(30.0, 95.0, reach)), 0.0, 0.0)
				"forearm":
					angle = Vector3(deg_to_rad(lerpf(60.0, 5.0, reach)), 0.0, 0.0)
				"chest":
					angle.x = deg_to_rad(lerpf(8.0, -15.0, reach))
		Action.CLIMB:
			# Head first through the opening, arms stretched out ahead, legs straight behind.
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(165.0), 0.0, deg_to_rad(-8.0) * side)
				"forearm", "shin", "thigh":
					angle = Vector3(deg_to_rad(5.0 if limb == "forearm" else -5.0 if limb == "shin" else 0.0), 0.0, 0.0)
				"chest", "head":
					angle = Vector3.ZERO
		Action.CROUCH:
			match limb:
				"thigh":
					angle = Vector3(deg_to_rad(70.0), 0.0, deg_to_rad(-6.0) * side)
				"shin":
					angle = Vector3(deg_to_rad(-100.0), 0.0, 0.0)
				"chest":
					angle.x = deg_to_rad(-35.0)
				"arm":
					angle = Vector3(deg_to_rad(-25.0), 0.0, deg_to_rad(-25.0) * side)
				"forearm":
					angle = Vector3(deg_to_rad(40.0), 0.0, 0.0)
		Action.LEAP:
			# Claws out ahead, legs flung back.
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(115.0), 0.0, deg_to_rad(-20.0) * side)
				"forearm":
					angle = Vector3(deg_to_rad(20.0), 0.0, 0.0)
				"thigh":
					angle = Vector3(deg_to_rad(-30.0), 0.0, 0.0)
				"shin":
					angle = Vector3(deg_to_rad(-60.0), 0.0, 0.0)
				"chest":
					angle.x = deg_to_rad(-20.0)
		Action.DANCE:
			# A Schuhplattler: arms up and waving, a heel kicked up to be slapped, in turn.
			var beat: float = sin(_action_time * 6.0)
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(20.0), 0.0, deg_to_rad(-150.0 + 25.0 * beat * side) * side)
				"forearm":
					angle = Vector3(deg_to_rad(40.0 + 30.0 * beat), 0.0, 0.0)
				"thigh":
					angle = Vector3(deg_to_rad(maxf(0.0, beat * side) * 60.0), 0.0, 0.0)
				"shin":
					angle = Vector3(deg_to_rad(-maxf(0.0, beat * side) * 110.0), 0.0, 0.0)
				"head":
					angle = Vector3(0.0, 0.0, deg_to_rad(12.0) * beat)
		Action.DAZED:
			# Arms hanging, head lolling.
			var sway: float = sin(_action_time * 5.0)
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(-6.0) * side)
				"forearm":
					angle = Vector3(deg_to_rad(10.0), 0.0, 0.0)
				"head":
					angle = Vector3(deg_to_rad(-25.0), 0.0, deg_to_rad(25.0) * sway)
				"chest":
					angle = Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(6.0) * sway)
		Action.DEAFENED:
			# The Ehrensalve: hands clapped over the ears, hunched, knees bent, the head shaking.
			var shake: float = sin(_action_time * 16.0)
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(30.0), 0.0, deg_to_rad(-80.0) * side)
				"forearm":
					angle = Vector3(0.0, 0.0, deg_to_rad(-150.0) * side)
				"chest":
					angle = Vector3(deg_to_rad(-22.0), 0.0, 0.0)
				"head":
					angle = Vector3(deg_to_rad(-15.0), deg_to_rad(18.0) * shake, 0.0)
				"thigh":
					angle = Vector3(deg_to_rad(25.0), 0.0, deg_to_rad(-4.0) * side)
				"shin":
					angle = Vector3(deg_to_rad(-40.0), 0.0, 0.0)
		Action.CARRIED:
			# Flailing on the fork.
			var flail: float = sin(_action_time * 14.0 + side)
			match limb:
				"arm":
					angle = Vector3(deg_to_rad(60.0 + 50.0 * flail), 0.0, deg_to_rad(-60.0) * side)
				"forearm":
					angle = Vector3(deg_to_rad(30.0 + 30.0 * flail), 0.0, 0.0)
				"thigh":
					angle = Vector3(deg_to_rad(30.0 * flail), 0.0, 0.0)
				"shin":
					angle = Vector3(deg_to_rad(-40.0 - 30.0 * flail), 0.0, 0.0)
	return angle


## The swing: arms raised high through the windup (the moment to back off), then down hard.
func _strike(limb: String, side: float, t: float, angle: Vector3) -> Vector3:
	var windup: float = 0.65
	var raised: float = t / windup if t < windup else 1.0 - (t - windup) / (1.0 - windup) * 1.6
	var swinging: bool = not one_handed or side < 0.0
	match limb:
		"arm":
			if swinging:
				return Vector3(deg_to_rad(lerpf(70.0, 165.0, clampf(raised, -0.4, 1.0))), 0.0, deg_to_rad(-10.0) * side)
		"forearm":
			if swinging:
				return Vector3(deg_to_rad(lerpf(10.0, 60.0, clampf(raised, 0.0, 1.0))), 0.0, 0.0)
		"chest":
			return Vector3(deg_to_rad(lerpf(-25.0, 10.0, clampf(raised, 0.0, 1.0))), 0.0, 0.0)
	return angle
