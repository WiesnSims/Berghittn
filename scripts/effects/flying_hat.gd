class_name FlyingHat
extends Node3D
## A hat knocked off an enemy (Huat obschiaßn): a plain copy of the hat's mesh that spins away along
## the shot, bounces off what it meets, lands (upright, or now and then upside down), lies there a
## while and then shrinks away. Moved by hand, not a physics body: cheap, and it never gets in
## anyone's way.

## The hats about now, oldest first (at most Constants.HAT_MAX).
static var _about: Array[FlyingHat] = []

var _velocity: Vector3
var _spin_axis: Vector3 = Vector3.RIGHT
var _spin: float = 0.0
var _flying: bool = true
var _flown: float = 0.0
var _bounces: int = 0
var _left: float = Constants.HAT_LIFETIME
var _gone: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## Knocks a hat off: a copy of `mesh` (built in the model's rest space, riding on the head bone)
## starts where the skin draws it now (`placed`: EnemyRig.head_moved), under `parent`, thrown along
## `push` (m/s) and spinning.
static func launch(mesh: Mesh, placed: Transform3D, parent: Node, push: Vector3) -> FlyingHat:
	while _about.size() >= Constants.HAT_MAX:
		_about.pop_front().vanish()
	var centre: Vector3 = mesh.get_aabb().get_center()
	var flying := FlyingHat.new()
	flying.name = "FlyingHat"
	parent.add_child(flying)
	# Turned about its own middle, not the enemy's feet.
	flying.global_transform = Transform3D(placed.basis.orthonormalized(), placed * centre)
	var copy := MeshInstance3D.new()
	copy.mesh = mesh
	copy.position = -centre
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flying.add_child(copy)
	flying._velocity = push
	flying._spin_axis = push.cross(Vector3.UP).normalized() if Vector3(push.x, 0.0, push.z).length() > 0.1 else Vector3.RIGHT
	flying._spin_axis = (flying._spin_axis + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))).normalized()
	flying._spin = Constants.HAT_SPIN * randf_range(0.7, 1.2)
	_about.append(flying)
	return flying


## How many hats are about now (tests).
static func count() -> int:
	return _about.size()


func is_flying() -> bool:
	return _flying


func _exit_tree() -> void:
	_about.erase(self)


func _physics_process(delta: float) -> void:
	# Its time runs from the shot.
	_left -= delta
	if _left <= 0.0:
		vanish()
		return
	if not _flying:
		return
	_flown += delta
	_velocity.y -= _gravity * delta
	var to: Vector3 = global_position + _velocity * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, to, Constants.LAYER_WORLD)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		global_position = to
		global_basis = Basis(_spin_axis, _spin * delta) * global_basis
		# Off the map: nobody will miss it.
		if _flown > 4.0:
			queue_free()
		return
	var normal: Vector3 = hit.normal
	global_position = hit.position + normal * 0.06
	if normal.y > 0.6 and (_velocity.length() < 2.5 or _bounces >= 2):
		_land()
		return
	_bounces += 1
	_velocity = _velocity.bounce(normal) * 0.35
	_spin *= 0.5


## Comes to rest: tips over onto its brim (or, one time in four, its crown) and lies still.
func _land() -> void:
	_flying = false
	var upright := Basis(Vector3.UP, randf() * TAU)
	if randf() < 0.25:
		upright = upright * Basis(Vector3.RIGHT, PI)
	create_tween().tween_property(self, "quaternion", upright.get_rotation_quaternion(), 0.15)


## Shrinks away and is gone.
func vanish() -> void:
	if _gone:
		return
	_gone = true
	_about.erase(self)
	_flying = false
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Constants.HAT_SHRINK_TIME)
	tween.tween_callback(queue_free)
