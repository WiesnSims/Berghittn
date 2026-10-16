class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, crouch and mouse look.

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _max_pitch: float = deg_to_rad(Constants.PLAYER_MAX_PITCH_DEG)
# 0 = standing, 1 = crouched. Blended so the camera glides instead of snapping.
var _crouch_amount: float = 0.0
var _spawn_transform: Transform3D


func _ready() -> void:
	_spawn_transform = global_transform
	_apply_height(Constants.PLAYER_STAND_HEIGHT)


func spawn_at(spawn: Transform3D) -> void:
	_spawn_transform = spawn
	_respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)


func _physics_process(delta: float) -> void:
	_update_crouch(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not _is_crouching():
		velocity.y = Constants.PLAYER_JUMP_VELOCITY
	_update_horizontal_velocity(delta)
	move_and_slide()
	if global_position.y < Constants.PLAYER_FALL_RESPAWN_Y:
		_respawn()


func _look(relative: Vector2) -> void:
	# Yaw turns the body so movement follows the view; pitch only tilts the head.
	rotate_y(-relative.x * Settings.mouse_sensitivity)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * Settings.mouse_sensitivity, -_max_pitch, _max_pitch)


func _update_horizontal_velocity(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target: Vector3 = global_basis * Vector3(input.x, 0.0, input.y) * _target_speed(input)
	var accel: float = Constants.PLAYER_GROUND_ACCEL if is_on_floor() else Constants.PLAYER_AIR_ACCEL
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y


func _target_speed(input: Vector2) -> float:
	if _is_crouching():
		return Constants.PLAYER_CROUCH_SPEED
	# Sprinting only counts while moving forward, so you cannot sprint backwards or sideways.
	if Input.is_action_pressed("sprint") and input.y < 0.0:
		return Constants.PLAYER_SPRINT_SPEED
	return Constants.PLAYER_WALK_SPEED


func _is_crouching() -> bool:
	return _crouch_amount > 0.0


func _update_crouch(delta: float) -> void:
	# Stay down while something is overhead, otherwise standing up would push us into the ceiling.
	var want_crouch: bool = Input.is_action_pressed("crouch") or (_is_crouching() and not _can_stand())
	_crouch_amount = move_toward(_crouch_amount, 1.0 if want_crouch else 0.0, Constants.PLAYER_CROUCH_BLEND_SPEED * delta)
	_apply_height(lerpf(Constants.PLAYER_STAND_HEIGHT, Constants.PLAYER_CROUCH_HEIGHT, _crouch_amount))


func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (Constants.PLAYER_STAND_HEIGHT - _capsule.height))


func _apply_height(height: float) -> void:
	# Keep the feet planted: the capsule shrinks from the top, the eyes follow.
	_capsule.height = height
	_collision.position.y = height * 0.5
	_head.position.y = height - Constants.PLAYER_EYE_BELOW_TOP


func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
