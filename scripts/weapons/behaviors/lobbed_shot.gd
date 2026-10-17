class_name LobbedShot
extends Node3D
## A shot that falls in an arc and bursts on the first wall, floor or body it touches (or in the air
## after LOBBED_MAX_FLIGHT): the Knödel, the Böller shell. Pooled by its weapon's behavior, which gets
## burst(at, damage, radius, size) called back. Subclasses draw it in _ready and the _on_* hooks.

## Metres from the shot's middle to its skin, for hitting things (times the size).
var hit_radius: float = 0.15
var _launcher: Object
var _velocity: Vector3
var _gravity: float = 9.8
var _damage: int = 0
var _radius: float = 0.0
var _size: float = 1.0
var _flying: bool = false
var _flight: float = 0.0


func is_busy() -> bool:
	return _flying


func launch(launcher: Object, from: Vector3, velocity: Vector3, damage: int, radius: float, size: float) -> void:
	_launcher = launcher
	global_position = from
	_velocity = velocity
	_gravity = launcher.get("data").projectile_gravity
	_damage = damage
	_radius = radius
	_size = size
	_flight = 0.0
	_flying = true
	_on_launch()


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_flight += delta
	_velocity.y -= _gravity * delta
	var step: Vector3 = _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * hit_radius * _size, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, _launcher.get("holder").shooter_exclude())
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_burst(hit.position + hit.normal * 0.15)
		return
	global_position += step
	_on_fly(delta, _velocity)
	if _flight >= Constants.LOBBED_MAX_FLIGHT:
		_burst(global_position)


func _burst(at: Vector3) -> void:
	_flying = false
	global_position = at
	_on_burst(at)
	_launcher.call("burst", at, _damage, _radius, _size)


## Shown and sized for a new shot.
func _on_launch() -> void:
	pass


## Every step in the air (spin it, trail smoke).
func _on_fly(_delta: float, _velocity_now: Vector3) -> void:
	pass


## Gone from the air: hide it, set off its burst effect.
func _on_burst(_at: Vector3) -> void:
	pass
