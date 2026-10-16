class_name WeaponMotion
extends Node3D
## Moves the held weapons with the body, so they feel carried instead of glued to the screen:
## a figure-8 bob while walking (bigger when sprinting), a lowered sprint pose, a lag behind mouse
## turns, a lean when strafing, a lift while airborne and a dip on landing. Purely visual; the
## viewmodels animate inside this node, so their kicks and reloads stack on top of it.

## Point the turns happen around (camera space): about where the hand holds the guns. Turning around the
## camera instead would swing the gun out of view.
@export var pivot: Vector3 = Vector3(0.15, -0.16, -0.4)
## Bob: metres sideways and up at walking speed, and bob cycles per second at walking speed (one cycle is
## two steps). Faster movement raises the cadence only with the square root of the speed, like real
## strides that get longer rather than quicker, so a sprint bobs a little faster, not frantically.
@export var bob_side: float = 0.012
@export var bob_up: float = 0.009
@export var bob_frequency: float = 0.95
## How fast the bob fades in when starting to walk and out when stopping (per second).
@export var bob_blend_speed: float = 6.0
## Sprint pose: where the gun goes (metres) and how it turns (degrees: pitch down, yaw in, roll).
@export var sprint_offset: Vector3 = Vector3(-0.03, -0.07, 0.03)
@export var sprint_rotation: Vector3 = Vector3(-18.0, 28.0, -12.0)
## Look lag: degrees of lag per pixel of mouse movement, the most it may lag, and how fast it catches up.
@export var look_lag_per_pixel: float = 0.04
@export var look_lag_max: float = 4.0
@export var look_lag_recover: float = 10.0
## Degrees of lean at full strafing speed.
@export var strafe_roll: float = 3.0
## Airborne: metres the gun lags per m/s of vertical speed (limited), and the landing dip per m/s of
## fall speed (limited), which springs back at recover speed.
@export var air_lag_per_speed: float = 0.006
@export var air_lag_max: float = 0.03
@export var land_dip_per_speed: float = 0.008
@export var land_dip_max: float = 0.05
@export var land_recover: float = 8.0
## Smoothing of every motion so nothing snaps (per second).
@export var smoothing: float = 12.0

var _player: Player
@onready var _holder: WeaponHolder = get_parent()
var _bob_phase: float = 0.0
var _bob_amount: float = 0.0
var _sprint: float = 0.0
var _look_lag: Vector2 = Vector2.ZERO
var _land_dip: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _position: Vector3 = Vector3.ZERO
var _rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	_player = owner as Player


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_lag = (_look_lag + motion.screen_relative * look_lag_per_pixel).limit_length(look_lag_max)


func _process(delta: float) -> void:
	if _player == null:
		return
	var velocity: Vector3 = _player.velocity
	var local: Vector3 = _player.global_basis.inverse() * velocity
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	var on_floor: bool = _player.is_on_floor()

	var walk_share: float = flat_speed / Constants.PLAYER_WALK_SPEED if on_floor else 0.0
	_bob_amount = move_toward(_bob_amount, minf(walk_share, 1.6), bob_blend_speed * delta)
	_bob_phase = fmod(_bob_phase + sqrt(walk_share) * bob_frequency * TAU * delta, TAU)
	var sprint_blend: float = 1.0 / Constants.SPRINT_TO_FIRE_TIME
	_sprint = move_toward(_sprint, 1.0 if _player.is_sprinting() else 0.0, sprint_blend * delta)

	if on_floor and not _was_on_floor:
		_land_dip = minf(_fall_speed * land_dip_per_speed, land_dip_max)
	_was_on_floor = on_floor
	_fall_speed = maxf(-velocity.y, 0.0)
	_land_dip = lerpf(_land_dip, 0.0, minf(land_recover * delta, 1.0))
	_look_lag = _look_lag.lerp(Vector2.ZERO, minf(look_lag_recover * delta, 1.0))

	# Aimed, the gun is held tight to the eye: barely any bob, lag or lean.
	var loose: float = 1.0 - 0.85 * _holder.aim_eased()
	# Figure 8: side to side once per two steps, up and down once per step.
	var bob := Vector3(sin(_bob_phase) * bob_side, -absf(cos(_bob_phase)) * bob_up, 0.0) * _bob_amount * loose
	var air: float = 0.0 if on_floor else clampf(-velocity.y * air_lag_per_speed, -air_lag_max, air_lag_max)
	var eased_sprint: float = smoothstep(0.0, 1.0, _sprint)
	var target_position: Vector3 = bob + sprint_offset * eased_sprint + Vector3(0.0, air - _land_dip, 0.0)
	# The gun trails the view: turning right leaves it a little to the left, looking up leaves it low.
	var target_rotation := Vector3(
		deg_to_rad(sprint_rotation.x * eased_sprint + _look_lag.y * loose),
		deg_to_rad(sprint_rotation.y * eased_sprint + _look_lag.x * loose),
		deg_to_rad(sprint_rotation.z * eased_sprint - local.x / Constants.PLAYER_WALK_SPEED * strafe_roll * loose))
	var weight: float = minf(smoothing * delta, 1.0)
	_position = _position.lerp(target_position, weight)
	_rotation = _rotation.lerp(target_rotation, weight)
	var turn := Transform3D(Basis.from_euler(_rotation), Vector3.ZERO)
	transform = Transform3D(Basis.IDENTITY, _position + pivot) * turn * Transform3D(Basis.IDENTITY, -pivot)
