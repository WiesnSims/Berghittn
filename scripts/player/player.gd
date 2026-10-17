class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, crouch and mouse look. Health, points, weapons and
## interaction live in child nodes.

signal died

@onready var health: PlayerHealth = $Health
@onready var points: PlayerPoints = $Points
@onready var perks: PlayerPerks = $Perks
@onready var equipment: PlayerEquipment = $Equipment
@onready var interactor: Interactor = $Interactor
@onready var weapons: WeaponHolder = $Head/Camera3D/WeaponHolder
@onready var _head: Node3D = $Head
@onready var _camera: CameraRecoil = $Head/Camera3D
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _max_pitch: float = deg_to_rad(Constants.PLAYER_MAX_PITCH_DEG)
# 0 = standing, 1 = crouched. Blended so the camera glides instead of snapping.
var _crouch_amount: float = 0.0
var _spawn_transform: Transform3D
var _sprinting: bool = false
# Field of view without aiming; aiming zooms from here to the gun's aim_fov.
var _base_fov: float = 75.0
var _time: float = 0.0


func _ready() -> void:
	_spawn_transform = global_transform
	_apply_height(Constants.PLAYER_STAND_HEIGHT)
	_base_fov = _camera.fov
	weapons.set_owner_body(self)
	weapons.fired.connect(_on_fired)
	health.died.connect(_on_died)


func spawn_at(spawn: Transform3D) -> void:
	_spawn_transform = spawn
	_respawn()


## Actually running at sprint speed (not just holding Shift against a wall). Guns cannot fire meanwhile.
func is_sprinting() -> bool:
	return _sprinting


func is_targetable() -> bool:
	return not health.is_dead()


## `attacker` lets a raised guard (the Schmarrnpfanne) catch hits from the front.
func take_damage(amount: int, attacker: Node3D = null) -> void:
	if weapons.block(attacker):
		amount = roundi(amount * weapons.melee_weapon.block_share)
	health.take_damage(amount)


func is_crouching() -> bool:
	return _is_crouching()


## A jolt of the view that is not a shot (the Böllerschuss going off at your feet).
func kick_view(pitch_degrees: float, yaw_degrees: float) -> void:
	_camera.kick(pitch_degrees, yaw_degrees)


## A shove that is not the player's own doing (the Handböller's double charge kicking back).
func push(velocity_change: Vector3) -> void:
	velocity += velocity_change


## The view trembles for a moment (the Alphorn's blast).
func shake_view(degrees: float) -> void:
	_camera.shake(degrees)


func _unhandled_input(event: InputEvent) -> void:
	if health.is_dead():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)


func _process(delta: float) -> void:
	_time += delta
	var aim: float = weapons.aim_eased() if weapons.weapon else 0.0
	var aim_fov: float = weapons.weapon.aim_fov if weapons.weapon else _base_fov
	_camera.fov = lerpf(_base_fov, aim_fov, aim)
	# Holding a scope steady is hard: the aim drifts in a slow figure 8, less when crouched.
	var sway: float = Constants.SCOPE_SWAY_DEGREES * (0.5 if _is_crouching() else 1.0) if weapons.is_scoped() else 0.0
	var phase: float = _time * Constants.SCOPE_SWAY_SPEED * TAU
	_camera.sway = Vector2(sin(phase * 2.0) * 0.5, sin(phase)) * deg_to_rad(sway)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
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
	# Zoomed in, the same mouse movement turns the view less, so the aim stays as steady on screen;
	# aiming slows it further for fine adjustments.
	var aim: float = weapons.aim_eased() if weapons.weapon else 0.0
	var sensitivity: float = Settings.mouse_sensitivity * lerpf(1.0, Settings.aim_sensitivity, aim) 			* tan(deg_to_rad(_camera.fov) * 0.5) / tan(deg_to_rad(_base_fov) * 0.5)
	rotate_y(-relative.x * sensitivity)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * sensitivity, -_max_pitch, _max_pitch)


func _update_horizontal_velocity(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed: float = _base_speed(input)
	var target: Vector3 = global_basis * Vector3(input.x, 0.0, input.y) * speed
	var accel: float = Constants.PLAYER_GROUND_ACCEL if is_on_floor() else Constants.PLAYER_AIR_ACCEL
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	_sprinting = speed == Constants.PLAYER_SPRINT_SPEED and horizontal.length() > Constants.PLAYER_WALK_SPEED * 0.8


func _base_speed(input: Vector2) -> float:
	if _is_crouching():
		return Constants.PLAYER_CROUCH_SPEED
	if weapons.is_aiming():
		return Constants.PLAYER_WALK_SPEED * weapons.weapon.aim_move_multiplier
	if weapons.is_blocking():
		return Constants.PLAYER_WALK_SPEED * weapons.melee_weapon.aim_move_multiplier
	if weapons.is_playing():
		return Constants.PLAYER_WALK_SPEED * weapons.weapon.aim_move_multiplier
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


func _on_fired(rounds: int) -> void:
	var strength: float = rounds * (weapons.weapon.rapid_recoil_multiplier if weapons.is_fanning() else 1.0)
	_camera.kick(weapons.weapon.recoil_pitch * strength, weapons.weapon.recoil_yaw * strength)


func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO


func _on_died() -> void:
	weapons.process_mode = Node.PROCESS_MODE_DISABLED
	weapons.visible = false
	# Drop to the floor and roll onto one side, so the death reads before the screen appears.
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_head, "position:y", Constants.PLAYER_CROUCH_HEIGHT * 0.3, Constants.PLAYER_DEATH_FALL_TIME)
	tween.tween_property(_head, "rotation:z", deg_to_rad(70.0), Constants.PLAYER_DEATH_FALL_TIME)
	died.emit()
	Events.player_died.emit(self)
